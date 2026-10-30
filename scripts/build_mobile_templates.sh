#!/usr/bin/env bash
# Build candidates only; installing/promoting them is a separate, reviewed step.
set -euo pipefail

case "${1:-}" in
    android|ios) platform="$1" ;;
    *) echo 'usage: build_mobile_templates.sh android|ios BUILD_DIRECTORY' >&2; exit 1 ;;
esac
[[ -n "${2:-}" ]] || { echo 'BUILD_DIRECTORY is required' >&2; exit 1; }
[[ "${GODOT_VERSION:-4.7.2}" == 4.7.2 ]] || { echo 'Update the pinned engine source with GODOT_VERSION' >&2; exit 1; }
if [[ "$platform" == ios && "$(uname -s)" != Darwin ]]; then
    echo 'iOS templates require macOS and Xcode' >&2
    exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$2"
work="$(cd "$2" && pwd)"
commit=ed1daf0bf001b61586d9930840f2f1394092c079
archive="$work/godot-source.tar.gz"
source="$work/godot-$commit"
if [[ ! -f "$archive" ]]; then
    curl --fail --location --retry 3 "https://codeload.github.com/godotengine/godot/tar.gz/$commit" -o "$archive"
fi
python3 - "$archive" <<'PY'
import hashlib, pathlib, sys
expected = "e607e9985e1c201bc9cdc1aec8a120f0c3f53b9603f1f828e2b748534a2471ef"
if hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest() != expected:
    raise SystemExit("Godot source checksum mismatch")
PY
if [[ ! -d "$source" ]]; then tar -xzf "$archive" -C "$work"; fi
if [[ ! -x "$work/venv/bin/scons" ]]; then
    python3 -m venv "$work/venv"
    "$work/venv/bin/python" -m pip install --require-hashes -r "$root/tools/requirements-mobile-templates.txt"
fi

cd "$source"
# iOS platform defaults override profile values unless Metal is also set on the command line.
args=("platform=$platform" arch=arm64 metal=no "profile=$root/tools/mobile_template_profile.py")
"$work/venv/bin/scons" -j "${BUILD_JOBS:-2}" "${args[@]}" target=template_debug
if [[ "$platform" == android ]]; then
    "$work/venv/bin/scons" -j "${BUILD_JOBS:-2}" "${args[@]}" target=template_release
    # Invoke Gradle directly: Godot's generate_android_binaries callback does not check its exit code.
    (cd platform/android/java && ./gradlew generateGodotTemplates --no-daemon)
    test -s bin/android_source.zip
    cp bin/android_source.zip "$work/android_source.zip"
else
    "$work/venv/bin/scons" -j "${BUILD_JOBS:-2}" "${args[@]}" target=template_release generate_bundle=yes
    test -s bin/godot_ios.zip
    cp bin/godot_ios.zip "$work/ios.zip"
fi
printf 'Built %s candidate templates in %s\n' "$platform" "$work"
