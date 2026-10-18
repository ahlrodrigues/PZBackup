#!/bin/bash
# Builds the Steam Workshop upload folder at <Zomboid>/Workshop/PZBackup
# from the repository. Then: game > Workshop > Create and update items.
#
# Usage: bash workshop/prepare-workshop.sh [--ascii | --minimal] [--public]
#   (no option)  full description; symbols the game can't pass to Steam are removed
#   --ascii      also strips Portuguese accents (try this if the upload fails)
#   --minimal    one-line description (last resort, to rule out the text)
#   --public     visibility=public instead of what workshop.txt says
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
MODE=normal; PUBLIC=0
for a in "$@"; do
  case "$a" in
    --ascii) MODE=ascii ;;
    --minimal) MODE=minimal ;;
    --public) PUBLIC=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "Unknown option: $a (see --help)"; exit 1 ;;
  esac
done

for b in "$HOME/Zomboid" "$HOME/.var/app/com.valvesoftware.Steam/Zomboid"; do
  [ -d "$b" ] && { BASE="$b"; break; }
done
[ -z "$BASE" ] && { echo "Zomboid folder not found."; exit 1; }

DEST="$BASE/Workshop/PZBackup"
ID=""
# keep the id the game writes into workshop.txt after the first upload
[ -f "$DEST/workshop.txt" ] && ID=$(grep '^id=' "$DEST/workshop.txt" || true)
[ -f "$DEST/workshop.txt.completo" ] && [ -z "$ID" ] && ID=$(grep '^id=' "$DEST/workshop.txt.completo" || true)
rm -f "$DEST/workshop.txt.completo"

rm -rf "$DEST/Contents"
mkdir -p "$DEST/Contents/mods"
cp -r "$REPO/files/mod/PZBackup" "$DEST/Contents/mods/PZBackup"
rm -f "$DEST/Contents/mods/PZBackup/common/.gitkeep"
mkdir -p "$DEST/Contents/mods/PZBackup/common"
# The Workshop uploader also looks for mod.info at the mod folder root
# (besides 42/), otherwise it fails with "missing a mod.info file"
cp "$DEST/Contents/mods/PZBackup/42/mod.info"   "$DEST/Contents/mods/PZBackup/mod.info"
cp "$DEST/Contents/mods/PZBackup/42/poster.png" "$DEST/Contents/mods/PZBackup/poster.png"
cp "$DEST/Contents/mods/PZBackup/42/icon.png"   "$DEST/Contents/mods/PZBackup/icon.png"
cp "$REPO/workshop/preview.png" "$DEST/preview.png"

# The game hands the text to Steam through Java and mangles some characters
# (emoji break the upload: "error requesting Steam to update the item").
# Byte-level sed (LC_ALL=C) works in any locale.
safe_symbols() {
  LC_ALL=C sed -E 's/\xF0[\x80-\xBF]{3}//g; s/—/-/g; s/–/-/g; s/→/->/g; s/⚠ ?//g; s/·/|/g; s/[“”]/"/g; s/[‘’]/'"'"'/g; s/…/.../g'
}
no_accents() {
  LC_ALL=C sed 's/á/a/g; s/à/a/g; s/â/a/g; s/ã/a/g; s/é/e/g; s/ê/e/g; s/í/i/g; s/ó/o/g; s/ô/o/g; s/õ/o/g; s/ú/u/g; s/ü/u/g; s/ç/c/g; s/Á/A/g; s/À/A/g; s/Â/A/g; s/Ã/A/g; s/É/E/g; s/Ê/E/g; s/Í/I/g; s/Ó/O/g; s/Ô/O/g; s/Õ/O/g; s/Ú/U/g; s/Ç/C/g'
}

{
  [ -n "$ID" ] && echo "$ID"
  case "$MODE" in
    normal)  safe_symbols < "$REPO/workshop/workshop.txt" ;;
    ascii)   safe_symbols < "$REPO/workshop/workshop.txt" | no_accents ;;
    minimal) grep -v '^description=' "$REPO/workshop/workshop.txt" | safe_symbols | grep -v '^tags=\|^visibility='
             echo "description=Save backups and undo death in Project Zomboid Build 42. Needs the free PZ Backup script: https://github.com/ahlrodrigues/PZBackup"
             grep '^tags=\|^visibility=' "$REPO/workshop/workshop.txt" ;;
  esac
} > "$DEST/workshop.txt"
[ "$PUBLIC" = 1 ] && sed -i 's/^visibility=.*/visibility=public/' "$DEST/workshop.txt"

DESC_BYTES=$(grep '^description=' "$DEST/workshop.txt" | sed 's/^description=//' | wc -c)
ODD=$(LC_ALL=C grep -c -P '[^\x00-\x7F]' "$DEST/workshop.txt" || true)

echo "Folder ready: $DEST"
find "$DEST" -type f | sed "s#^$DEST/#  #" | sort
echo
echo "Description mode: $MODE  |  $DESC_BYTES bytes (Steam limit 8000)  |  lines with non-ASCII: $ODD"
echo "$(grep '^title=' "$DEST/workshop.txt")"
echo "$(grep '^visibility=' "$DEST/workshop.txt")"
if [ -n "$ID" ]; then
  echo "(kept $ID: the upload will UPDATE the existing item)"
else
  echo "WARNING: no id= found. The upload will create a NEW item."
  echo "         To update the existing one: sed -i '1i id=3821180981' \"$DEST/workshop.txt\""
fi
echo
echo "Now: start the game > Workshop > Create and update items > PZBackup."
[ "$MODE" = normal ] && echo "If it fails with \"error requesting Steam to update the item\", run again with --ascii."
exit 0
