#!/usr/bin/env bash
#
# Activa R8 (minify) sólo en la build release de la plantilla Gradle ya instalada en android/build.
# Godot 4.7.2 no lo expone en el preset; /android/ no se versiona, así que se aplica tras instalarla:
#
#   godot --headless --path . --install-android-build-template --export-debug "Android" build/android/invadeio.apk
#   bash scripts/enable_android_r8.sh
#   godot --headless --path . --export-release "Android AAB" build/android/invadeio.aab   # sin reinstalar
#
# Es idempotente: ejecutarlo dos veces no duplica la configuración.

set -euo pipefail

BUILD_DIR="${1:-android/build}"
GRADLE="$BUILD_DIR/build.gradle"
MARKER="// invadeio: R8 release"

if [[ ! -f "$GRADLE" ]]; then
	echo "No existe $GRADLE: instala antes la plantilla Android (--install-android-build-template)" >&2
	exit 1
fi

cp "$(dirname "$0")/../tools/android/proguard-rules.pro" "$BUILD_DIR/invadeio-proguard-rules.pro"
mkdir -p "$BUILD_DIR/res/raw"
cp "$(dirname "$0")/../tools/android/macarronesc_invadeio_keep.xml" "$BUILD_DIR/res/raw/"

if grep -qF "$MARKER" "$GRADLE"; then
	if ! grep -Fq 'shrinkResources true' "$GRADLE"; then
		echo 'Reinstala la plantilla Android para actualizar el bloque R8 y vuelve a ejecutar el script.' >&2
		exit 1
	fi
	echo "R8 ya estaba activado en $GRADLE"
	exit 0
fi

cat >>"$GRADLE" <<EOF

$MARKER
android {
    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'invadeio-proguard-rules.pro'
        }
    }
}
EOF
echo "R8 activado para release en $GRADLE"
