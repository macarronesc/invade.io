#!/usr/bin/env bash
#
# Comprueba un paquete de Google Play sin Android Studio y sin publicarlo:
# firma, 64 bits, alineación de 16 KB, permisos, contenido y que no viaja código de test.
#
#   bash scripts/verify_play_bundle.sh build/android/invadeio.aab                # paquete de Play
#   bash scripts/verify_play_bundle.sh build/android/invadeio.apk                # APK suelto
#   bash scripts/verify_play_bundle.sh build/android/invadeio.aab build/.../invadeio.apk
#
# El AAB comprueba además la firma (necesita un JDK) y la alineación de 16 KB de la
# librería nativa. El APK se comprueba con aapt2 (target/min SDK, arquitecturas, permisos).
# Sale con error (1) en la primera comprobación que falle, así que sirve de puerta en CI.

set -euo pipefail

TARGET="${1:-build/android/invadeio.aab}"
BUNDLE=""
APK=""
if [[ "$TARGET" == *.apk ]]; then
	APK="$TARGET"
else
	BUNDLE="$TARGET"
	APK="${2:-}"
fi

PACKAGE="macarronesc.invadeio"
EXPECTED_TARGET_SDK="36"
EXPECTED_MIN_SDK="24"
MIN_PAGE_ALIGN=16384

fail=0
ok()   { printf '  [OK]   %s\n' "$1"; }
bad()  { printf '  [FALLO] %s\n' "$1"; fail=1; }
die()  { printf 'ERROR: %s\n' "$1" >&2; exit 2; }
need() { command -v "$1" >/dev/null 2>&1 || die "falta '$1' en el sistema ($2)"; }

# aapt2 vive en build-tools del SDK de Android, que puede no estar en el PATH
find_aapt2() {
	command -v aapt2 2>/dev/null && return 0
	ls -1 "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/nonexistent}}"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# El identificador es permanente y no se puede corregir después: mejor detectarlo aquí
if [[ ! "$PACKAGE" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]]; then
	bad "el identificador '$PACKAGE' no es válido en Android (minúsculas, dos o más segmentos, sin guiones)"
fi

# --------------------------------------------------------------------------
# Paquete AAB: firma, contenido y alineación de 16 KB
# --------------------------------------------------------------------------
if [ -n "$BUNDLE" ]; then
	need unzip "apt install unzip"
	need readelf "apt install binutils"
	need jarsigner "viene con el JDK"
	[ -f "$BUNDLE" ] || die "no existe el paquete: $BUNDLE"

	echo "Verificando $BUNDLE ($(du -h "$BUNDLE" | cut -f1))"

	unzip -tq "$BUNDLE" >/dev/null 2>&1 && ok "el archivo es un ZIP íntegro" || bad "el ZIP está dañado"
	LIST="$(unzip -l "$BUNDLE" 2>/dev/null || true)"
	[ -n "$LIST" ] || die "no se pudo leer el contenido de $BUNDLE"

	if grep -q "base/manifest/AndroidManifest.xml" <<<"$LIST"; then
		ok "incluye el manifiesto"
	else
		bad "no incluye base/manifest/AndroidManifest.xml"
	fi

	ENGINE_SO="base/lib/arm64-v8a/libgodot_android.so"
	if grep -q "$ENGINE_SO" <<<"$LIST"; then
		ok "incluye la librería nativa arm64-v8a"
	else
		bad "falta $ENGINE_SO (¿se exportó sin arm64-v8a?)"
	fi

	if grep -qE "base/lib/(armeabi-v7a|x86|x86_64)/" <<<"$LIST"; then
		bad "incluye arquitecturas de 32 bits o x86 (Play exige 64 bits; usa sólo arm64-v8a)"
	else
		ok "sin arquitecturas de 32 bits ni x86"
	fi

	if grep -q "assets/data/geo.json" <<<"$LIST"; then
		ok "incluye la geografía real (geo.json)"
	else
		bad "falta assets/data/geo.json: el mapa se vería sin costas ni ciudades"
	fi

	if grep -qE "(scenes|scripts)/tests/" <<<"$LIST"; then
		bad "incluye escenas o scripts de test (revisa exclude_filter)"
	else
		ok "sin código de test"
	fi

	# Las librerías nativas deben viajar sin comprimir: es lo que permite la alineación de 16 KB
	if unzip -v "$BUNDLE" "$ENGINE_SO" 2>/dev/null | grep -qE "Stored"; then
		ok "la librería nativa viaja sin comprimir"
	else
		bad "la librería nativa viaja comprimida (compress_native_libraries debe ser false)"
	fi

	SIGN_OUT="$(jarsigner -verify -certs "$BUNDLE" 2>&1 || true)"
	if grep -q "jar verified" <<<"$SIGN_OUT"; then
		ok "el paquete está firmado y la firma es válida"
		grep -oE "CN=[^,]*" <<<"$SIGN_OUT" | head -1 | sed 's/^/         certificado: /' || true
	else
		bad "el paquete no está firmado o la firma no verifica (Play lo rechazará)"
	fi

	if grep -q "$ENGINE_SO" <<<"$LIST"; then
		unzip -p "$BUNDLE" "$ENGINE_SO" >"$TMP/engine.so"
		ALIGNS="$(readelf -lW "$TMP/engine.so" | awk '$1 == "LOAD" { print $NF }' || true)"
		if [ -z "$ALIGNS" ]; then
			bad "no se pudieron leer los segmentos LOAD de la librería nativa"
		else
			small=0
			for a in $ALIGNS; do
				[ "$((a))" -lt "$MIN_PAGE_ALIGN" ] && small=1
			done
			if [ "$small" -eq 0 ]; then
				ok "segmentos ELF alineados a 16 KB ($(tr '\n' ' ' <<<"$ALIGNS"))"
			else
				bad "hay segmentos ELF por debajo de 16 KB: el juego no arrancaría en dispositivos de 16 KB"
			fi
		fi
	fi

	# Cualquier otra librería de arm64 (libc++_shared.so...) también debe estar a 16 KB
	for so in $(grep -oE "^ +[0-9]+ +[0-9-]+ +[0-9:]+ +base/lib/arm64-v8a/[^ ]+\.so" <<<"$LIST" | awk '{ print $NF }' | sort -u); do
		[ "$so" = "$ENGINE_SO" ] && continue
		unzip -p "$BUNDLE" "$so" >"$TMP/extra.so"
		for a in $(readelf -lW "$TMP/extra.so" | awk '$1 == "LOAD" { print $NF }'); do
			if [ "$((a))" -lt "$MIN_PAGE_ALIGN" ]; then
				bad "$(basename "$so") tiene segmentos ELF por debajo de 16 KB"
				continue 2
			fi
		done
		ok "$(basename "$so") alineado a 16 KB"
	done

	MANIFEST="$TMP/AndroidManifest.xml"
	unzip -p "$BUNDLE" "base/manifest/AndroidManifest.xml" >"$MANIFEST" 2>/dev/null || true
	if [ -s "$MANIFEST" ]; then
		STRINGS="$(strings -el "$MANIFEST" || true)"
		if grep -qF "$PACKAGE" <<<"$STRINGS"; then
			ok "el identificador es $PACKAGE"
		else
			bad "el manifiesto no declara $PACKAGE"
		fi
		if grep -qF "android.permission.VIBRATE" <<<"$STRINGS"; then
			ok "declara VIBRATE (vibración de las órdenes)"
		else
			bad "no declara VIBRATE: la vibración no funcionaría"
		fi
		if grep -qF "android.permission.INTERNET" <<<"$STRINGS"; then
			bad "declara INTERNET: la declaración de datos de Play dejaría de ser cierta"
		else
			ok "sin permiso INTERNET (sin acceso a red)"
		fi
		if grep -qF "debuggable" <<<"$STRINGS"; then
			bad "el paquete está marcado como depurable: Play no acepta builds de depuración"
		else
			ok "no está marcado como depurable"
		fi
	fi

	# Si algo del paquete no cuadra, se muestra su estructura para diagnosticar sin otra ejecución
	if [ "$fail" -ne 0 ]; then
		echo "  --- contenido relevante de $(basename "$BUNDLE") ---"
		grep -E "base/lib/|base/manifest/|geo\.json" <<<"$LIST" | head -12 | sed 's/^/    /' || true
	fi
fi

# --------------------------------------------------------------------------
# APK: target/min SDK, arquitecturas y permisos declarados
# --------------------------------------------------------------------------
if [ -n "$APK" ] && [ -f "$APK" ]; then
	AAPT2="$(find_aapt2 || true)"
	if [ -z "$AAPT2" ]; then
		echo "  [INFO] aapt2 no está instalado: se omiten las comprobaciones de $APK"
	else
		echo "Verificando el APK $APK"
		BADGING="$("$AAPT2" dump badging "$APK" 2>/dev/null || true)"
		# aapt2 antiguo imprime sdkVersion y el nuevo minSdkVersion: se aceptan las dos formas
		# (|| true: con set -e, un grep sin resultados abortaría el script)
		TARGET_SDK="$(grep -oE "targetSdkVersion:'[0-9]+'" <<<"$BADGING" | grep -oE "[0-9]+" | head -1 || true)"
		MIN_SDK="$(grep -oE "minSdkVersion:'[0-9]+'" <<<"$BADGING" | grep -oE "[0-9]+" | head -1 || true)"
		if [ -z "$MIN_SDK" ]; then
			MIN_SDK="$(grep -oE "^sdkVersion:'[0-9]+'" <<<"$BADGING" | grep -oE "[0-9]+" | head -1 || true)"
		fi
		if [ "$TARGET_SDK" = "$EXPECTED_TARGET_SDK" ]; then
			ok "target SDK $EXPECTED_TARGET_SDK"
		else
			bad "target SDK distinto de $EXPECTED_TARGET_SDK (encontrado: ${TARGET_SDK:-no declarado})"
		fi
		# Play no impone un min SDK, pero el motor necesita 24 y el paquete debe declararlo
		MIN_REQUIRED=21
		if [ -z "$MIN_SDK" ]; then
			bad "el APK no declara minSdkVersion: el sistema no sabría en qué dispositivos instalar"
		elif [ "$MIN_SDK" -lt "$MIN_REQUIRED" ]; then
			bad "min SDK $MIN_SDK: por debajo de Android 5.0 (API $MIN_REQUIRED)"
		elif [ "$MIN_SDK" != "$EXPECTED_MIN_SDK" ]; then
			echo "  [AVISO] min SDK $MIN_SDK (el preset AAB fija $EXPECTED_MIN_SDK: Godot usa 29 por defecto si el renderizador es Vulkan)"
		else
			ok "min SDK $MIN_SDK"
		fi
		CODES="$(grep -oE "native-code: '.*'" <<<"$BADGING" || echo "native-code: ''")"
		if grep -q "arm64-v8a" <<<"$CODES"; then
			ok "arquitectura arm64-v8a presente en el APK"
		else
			bad "el APK no incluye arm64-v8a"
		fi
		# Godot añade INTERNET sólo a las exportaciones de depuración con depurador remoto:
		# se tolera en un APK de pruebas, nunca se exige, y nunca puede aparecer en release.
		PERMS="$(grep -oE "uses-permission: name='android\.permission\.[A-Z_]+'" <<<"$BADGING" | sed "s/.*'\(.*\)'/\1/" | sort -u || true)"
		if grep -q "application-debuggable" <<<"$BADGING"; then
			echo "  [INFO] APK de depuración (no se publica)"
			PERMS="$(grep -vx "android.permission.INTERNET" <<<"$PERMS" || true)"
		fi
		if [ "$PERMS" = "android.permission.VIBRATE" ]; then
			ok "permisos esperados (sólo VIBRATE)"
		else
			bad "permisos inesperados en el APK: ${PERMS:-ninguno}"
		fi
	fi
elif [ -n "$APK" ]; then
	die "no existe el APK: $APK"
fi

echo
if [ "$fail" -eq 0 ]; then
	echo "Todo correcto: el paquete cumple los requisitos comprobables de Google Play."
else
	echo "Hay comprobaciones fallidas: no subas este paquete a Play Console." >&2
fi
exit "$fail"
