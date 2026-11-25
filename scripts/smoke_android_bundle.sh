#!/usr/bin/env bash
# Run only on a disposable emulator. Test the release APK generated from the AAB.
set -euo pipefail

bundle="${1:?usage: smoke_android_bundle.sh unsigned.aab}"
package=macarronesc.invadeio
launcher="$package/com.godot.game.GodotAppLauncher"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

test "$(adb shell getprop ro.kernel.qemu | tr -d '\r')" = 1
abis="$(adb shell getprop ro.product.cpu.abilist | tr -d '\r')"
[[ ",$abis," == *,arm64-v8a,* ]] || { echo "Emulator cannot run the arm64 bundle: $abis" >&2; exit 1; }

keytool -genkeypair -keystore "$work/test.p12" -alias smoke -keyalg RSA -keysize 2048 \
	-validity 2 -dname 'CN=Android smoke test only' -storepass android -keypass android
java -jar "${BUNDLETOOL_JAR:?}" build-apks --bundle="$bundle" --output="$work/app.apks" \
	--mode=universal --ks="$work/test.p12" --ks-key-alias=smoke --ks-pass=pass:android --key-pass=pass:android
unzip -p "$work/app.apks" universal.apk > "$work/app.apk"
adb install --abi arm64-v8a "$work/app.apk"
adb shell svc wifi disable
adb shell svc data disable
adb logcat -c
trap 'status=$?; if (( status != 0 )); then adb logcat -d -t 300 || true; adb logcat -d -b crash || true; fi; rm -rf "$work"' EXIT
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n "$launcher" | tee "$work/start"
grep -qx 'Status: ok' "$work/start"
pid="$(adb shell pidof -s "$package" | tr -d '\r')"
[[ "$pid" =~ ^[0-9]+$ ]]
# Cold launch and the first battle run asynchronously after the activity resumes.
sleep 15
adb logcat -d --pid="$pid" > "$work/logcat"
cat "$work/logcat"
grep -Fq 'Completed initialization for Godot plugin SentryAndroidGodotPlugin' "$work/logcat"
grep -Fq 'OpenGL API OpenGL ES' "$work/logcat"
test "$(adb shell pidof -s "$package" | tr -d '\r')" = "$pid"
adb shell dumpsys activity activities > "$work/activities"
grep -E 'mResumedActivity|topResumedActivity' "$work/activities" | grep -F "$package/com.godot.game.GodotApp"
if grep -Ei 'FATAL EXCEPTION|Fatal signal|NoSuchMethodError|NoSuchFieldError|UnsatisfiedLinkError|NoClassDefFoundError|ClassNotFoundException|JNI DETECTED ERROR' "$work/logcat"; then
	exit 1
fi
echo "Minified arm64 app is still running and in the foreground."
