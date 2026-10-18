#!/bin/bash
# update-from-zip.sh — brings a downloaded PZBackup-repositorio.zip into your
# local git repository and prepares everything that comes after.
#
# Usage: bash tools/update-from-zip.sh [ZIP] [options]
#   ZIP           default: the newest ~/Downloads/PZBackup-repositorio*.zip
#   --repo DIR    local git repository (default: ~/Projetos/PZBackup)
#   --install     also reinstall the mod and script on this PC (install.sh)
#   --commit      git add + commit with the version from mod.info (no push)
#   --ascii | --minimal | --public   passed to workshop/prepare-workshop.sh
#
# What it does:
#   1. unzips into a temporary folder
#   2. copies everything into the repository, keeping .git and removing files
#      that no longer exist in the zip
#   3. shows what changed (git status)
#   4. builds the Workshop upload folder (prepare-workshop.sh)
#   5. optional: reinstalls locally / commits
set -e

# Re-run from a temporary copy: this file itself gets replaced in step 2
if [ -z "$PZB_SELF_COPY" ]; then
  TMP_SELF=$(mktemp)
  cp "$0" "$TMP_SELF"
  PZB_SELF_COPY="$TMP_SELF" exec bash "$TMP_SELF" "$@"
fi
trap 'rm -f "$PZB_SELF_COPY"; [ -n "$WORK" ] && rm -rf "$WORK"' EXIT

ok()   { printf '  \033[32m- %s\033[0m\n' "$1"; }
warn() { printf '  \033[33m! %s\033[0m\n' "$1"; }
fail() { printf '\n\033[31mERROR: %s\033[0m\n' "$1"; exit 1; }

REPO="$HOME/Projetos/PZBackup"
ZIP=""; INSTALL=0; COMMIT=0; WS_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift ;;
    --install) INSTALL=1 ;;
    --commit) COMMIT=1 ;;
    --ascii|--minimal|--public) WS_ARGS+=("$1") ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    -*) fail "Unknown option: $1 (see --help)" ;;
    *) ZIP="$1" ;;
  esac
  shift
done

echo
echo "=== PZ Backup: update from zip ==="
echo

# 1. Zip
if [ -z "$ZIP" ]; then
  ZIP=$(ls -t "$HOME"/Downloads/PZBackup-repositorio*.zip 2>/dev/null | head -1)
  [ -z "$ZIP" ] && fail "No PZBackup-repositorio*.zip in ~/Downloads. Pass the path: $0 /path/to/file.zip"
fi
[ -f "$ZIP" ] || fail "File not found: $ZIP"
ok "Zip: $ZIP ($(date -r "$ZIP" '+%d/%m %H:%M'))"

command -v unzip >/dev/null || fail "unzip not found."
WORK=$(mktemp -d)
unzip -q "$ZIP" -d "$WORK/x"
SRC="$WORK/x"
# accept a zip with everything inside a single top folder too
if [ ! -f "$SRC/install.sh" ]; then
  inner=$(find "$SRC" -mindepth 1 -maxdepth 1 -type d | head -1)
  [ -f "$inner/install.sh" ] && SRC="$inner"
fi
[ -f "$SRC/install.sh" ] && [ -d "$SRC/workshop" ] \
  || fail "This doesn't look like the repository zip (use PZBackup-repositorio.zip, not the release zip)."
NEW_VER=$(grep '^modversion=' "$SRC/files/mod/PZBackup/42/mod.info" | cut -d= -f2)
ok "Version in the zip: $NEW_VER"

# 2. Repository
[ -d "$REPO/.git" ] || fail "$REPO is not a git repository. Use --repo /path/to/PZBackup"
OLD_VER=$(grep '^modversion=' "$REPO/files/mod/PZBackup/42/mod.info" 2>/dev/null | cut -d= -f2)
if command -v rsync >/dev/null; then
  rsync -a --delete --exclude '.git/' "$SRC/" "$REPO/"
else
  find "$REPO" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  cp -a "$SRC/." "$REPO/"
fi
chmod +x "$REPO/install.sh" "$REPO/files/linux/pz-backup.sh" "$REPO/workshop/prepare-workshop.sh" "$REPO/tools/"*.sh 2>/dev/null || true
ok "Repository updated: $REPO (${OLD_VER:-?} -> $NEW_VER)"

# 3. What changed
echo
echo "--- git status ---"
git -C "$REPO" status --short || true
echo

# 4. Workshop folder
bash "$REPO/workshop/prepare-workshop.sh" "${WS_ARGS[@]}"

# 5. Optional
if [ "$INSTALL" = 1 ]; then
  echo
  bash "$REPO/install.sh"
fi

if [ "$COMMIT" = 1 ]; then
  if [ -n "$(git -C "$REPO" status --porcelain)" ]; then
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m "PZ Backup $NEW_VER"
    ok "Commit created: PZ Backup $NEW_VER"
  else
    warn "Nothing to commit: the repository already matches the zip"
  fi
fi

cat <<EOF

=== Next steps ===
  1. Workshop: start the game > Workshop > Create and update items > PZBackup
  2. Git:      cd "$REPO"
EOF
[ "$COMMIT" = 1 ] || echo "               git add -A && git commit -m \"PZ Backup $NEW_VER\""
cat <<EOF
               git push          (Forgejo mirrors it to GitHub)
  3. Release:  on GitHub, create/edit tag v$NEW_VER and attach PZBackup-v$NEW_VER.zip
EOF
