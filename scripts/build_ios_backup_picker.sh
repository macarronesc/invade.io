#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build="$root/build/ios/backup_picker"
headers="$build/headers"
archive="$build/godot-headers.zip"
url="https://github.com/godot-mobile-plugins/godot-headers/releases/download/4.7.2-stable/godot-headers-4.7.2-stable.zip"
sha256="5d0b8ef6b3b4508d626fe93dc3dd1137c396a0f1c611a41c0af37a720f3ca852"

mkdir -p "$build"
if [[ ! -f "$headers/core/version.h" ]]; then
	curl --fail --location --retry 3 "$url" -o "$archive"
	echo "$sha256  $archive" | shasum -a 256 -c -
	mkdir -p "$headers"
	unzip -q -o "$archive" -d "$headers"
fi

sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
src="$root/ios/plugins/backup_file_picker/backup_file_picker.mm"
obj="$build/backup_file_picker.o"
lib="$root/ios/plugins/backup_file_picker/BackupFilePicker.a"
config="$root/ios/plugins/backup_file_picker/BackupFilePicker.gdip"

xcrun --sdk iphoneos clang++ \
	-arch arm64 -isysroot "$sdk" -miphoneos-version-min=15.0 \
	-std=c++17 -fobjc-arc -fmodules -fcxx-modules -fno-exceptions -fno-rtti \
	-DIOS_ENABLED -DUNIX_ENABLED -DPTRCALL_ENABLED -DTYPED_METHOD_BIND \
	-I"$headers" -I"$headers/platform/ios" -I"$headers/drivers/apple_embedded" \
	-c "$src" -o "$obj"
libtool -static -o "$lib" "$obj"
cp "$root/ios/plugins/backup_file_picker/BackupFilePicker.gdip.in" "$config"
