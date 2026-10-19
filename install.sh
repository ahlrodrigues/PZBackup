#!/bin/bash
# install.sh — PZ Backup installer. Checks the OS and installs the right version.
# Usage: bash install.sh

PKG="$(cd "$(dirname "$0")" && pwd)"
ok()   { printf '  \033[32m- %s\033[0m\n' "$1"; }
warn() { printf '  \033[33m! %s\033[0m\n' "$1"; }
fail() { printf '\n\033[31mERROR: %s\033[0m\n' "$1"; exit 1; }

echo
echo "=== PZ Backup installer ==="
echo

# 1. Operating system
case "$(uname -s)" in
  Linux) ;;
  MINGW*|MSYS*|CYGWIN*)
    fail "You're on Windows. Close this terminal and double-click install.bat." ;;
  Darwin)
    fail "macOS is not supported yet." ;;
  *)
    fail "Unknown system: $(uname -s)" ;;
esac
ok "System: Linux"

# 2. Where the game keeps its saves (native Steam or Flatpak)
FLATPAK_HOME="$HOME/.var/app/com.valvesoftware.Steam"
BASE=""
for b in "$HOME/Zomboid" "$FLATPAK_HOME/Zomboid"; do
  if [ -d "$b/Saves" ] || [ -d "$b/saves" ]; then BASE="$b"; break; fi
done
if [ -z "$BASE" ]; then
  for b in "$HOME/Zomboid" "$FLATPAK_HOME/Zomboid"; do
    [ -d "$b" ] && { BASE="$b"; break; }
  done
fi
[ -z "$BASE" ] && fail "Zomboid folder not found. Start Project Zomboid once before installing."

KIND="native Steam"
case "$BASE" in "$FLATPAK_HOME"/*) KIND="Flatpak Steam" ;; esac
ok "Game folder: $BASE ($KIND)"

# 3. Mod
mkdir -p "$BASE/mods"
rm -rf "$BASE/mods/PZBackup"
cp -r "$PKG/files/mod/PZBackup" "$BASE/mods/PZBackup"
rm -f "$BASE/mods/PZBackup/common/.gitkeep"
mkdir -p "$BASE/mods/PZBackup/common"
ok "Mod installed in $BASE/mods/PZBackup"

# 4. Script
install -m 755 "$PKG/files/linux/pz-backup.sh" "$BASE/pz-backup.sh"
ok "Script installed in $BASE/pz-backup.sh"

# 5. Optional dependencies
command -v python3 >/dev/null || warn "python3 not found: no beeps and no extra players.db death check (the mod still detects deaths)"
command -v rsync >/dev/null || warn "rsync not found: backups will be full copies instead of incremental (install rsync to save disk space)"
command -v paplay >/dev/null || command -v pw-play >/dev/null || command -v aplay >/dev/null \
  || warn "No audio player found (paplay/pw-play/aplay): no beeps"

# 6. What's left to do
cat <<EOF

=== Done! Two more steps ===

1) Steam > right-click Project Zomboid > Properties > General >
   Launch Options. Paste this into the text field:

   $BASE/pz-backup.sh game %command%

2) In game: main menu > Mods > enable "PZ Backup" (also in your save's mod list).

In game: F8 = backup now, F9 = restore window (with a View log button).
When you die, the latest backup is restored by itself (turn off in Options > Mods).
To restore from the terminal (with the game CLOSED):
   $BASE/pz-backup.sh list
   $BASE/pz-backup.sh restore N

EOF
