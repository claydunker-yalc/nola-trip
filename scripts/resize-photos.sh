#!/usr/bin/env bash
# resize-photos.sh
# -------------------------------------------------------------------
# Why this exists:
#   The carousel on index.html pulls photos from /photos. Originals
#   from a phone are 2-5 MB each and would make the page painfully
#   slow on mobile. This script takes everything in /photos-raw and
#   produces web-optimized JPEGs (~200-400 KB each) in /photos.
#
# How to use:
#   1. Drop full-resolution photos into /photos-raw (.jpg/.JPG/.jpeg).
#   2. Run:  ./scripts/resize-photos.sh
#   3. Optimized JPEGs land in /photos with the same base name.
#
# Decisions baked in:
#   - Long edge capped at 1600px. Big enough for retina displays,
#     small enough to keep file size reasonable.
#   - JPEG quality 80%. Visually indistinguishable from 100% for
#     photos but ~3x smaller on disk.
#   - Uses macOS-native `sips`. No npm/Python dependency.
#   - .MP4/.MOV/.HEIC files are skipped. (HEIC support could be
#     added later via `sips -s format jpeg`.)
#   - Output filenames are lowercased to .jpg for consistent paths.
#
# Dependencies: macOS (sips is built-in).
# -------------------------------------------------------------------

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAW_DIR="$REPO_ROOT/photos-raw"
OUT_DIR="$REPO_ROOT/photos"
MAX_EDGE=1600
QUALITY=80

if [ ! -d "$RAW_DIR" ]; then
  echo "Error: $RAW_DIR does not exist."
  exit 1
fi

mkdir -p "$OUT_DIR"

count=0
skipped=0

shopt -s nullglob nocaseglob
for src in "$RAW_DIR"/*.jpg "$RAW_DIR"/*.jpeg; do
  [ -f "$src" ] || continue
  base="$(basename "$src")"
  name="${base%.*}"
  dest="$OUT_DIR/$name.jpg"

  # Skip if dest already exists and is newer than the source
  if [ -f "$dest" ] && [ "$dest" -nt "$src" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  sips -s format jpeg \
       -s formatOptions "$QUALITY" \
       -Z "$MAX_EDGE" \
       "$src" --out "$dest" >/dev/null
  count=$((count + 1))
  printf "  resized: %s\n" "$name.jpg"
done
shopt -u nocaseglob

echo ""
echo "Done. Resized $count file(s); skipped $skipped already up-to-date."

# Write manifest.json — the carousel JS reads this list at runtime
# so adding/removing photos requires no HTML edits, just a re-run.
manifest="$OUT_DIR/manifest.json"
{
  printf '['
  first=1
  for f in "$OUT_DIR"/*.jpg; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    if [ $first -eq 1 ]; then
      first=0
      printf '\n  "%s"' "$name"
    else
      printf ',\n  "%s"' "$name"
    fi
  done
  printf '\n]\n'
} > "$manifest"

total=$(ls "$OUT_DIR"/*.jpg 2>/dev/null | wc -l | tr -d ' ')
echo "Wrote manifest with $total photo(s) → $manifest"
