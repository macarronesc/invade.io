#!/usr/bin/env bash
# Render the Play Store trailer from the real game: scripts/render_trailer.sh [lang]
# Needs Godot 4.7.2, xvfb-run and ffmpeg. Output: build/trailer/invadeio-trailer-<lang>.mp4
set -euo pipefail
cd "$(dirname "$0")/.."
lang="${1:-en}"
out="build/trailer"
mkdir -p "$out"
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --write-movie "$out/raw-$lang.avi" --fixed-fps 30 \
  res://scenes/tests/store_trailer.tscn -- "--lang=$lang"
ffmpeg -loglevel error -y -i "$out/raw-$lang.avi" -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p \
  -c:a aac -b:a 192k -movflags +faststart "$out/invadeio-trailer-$lang.mp4"
rm "$out/raw-$lang.avi"
echo "$out/invadeio-trailer-$lang.mp4"
