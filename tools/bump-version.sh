#!/bin/bash
# bump-version.sh — sets the PZ Backup version everywhere it appears, in one go.
#
# Usage (from anywhere inside the repository):
#   bash tools/bump-version.sh 1.4.1     -> sets version 1.4.1 in every file
#   bash tools/bump-version.sh --check   -> only checks that every file agrees
#                                          (exit 1 if not; prepare-workshop.sh runs it)
#
# Files kept in sync:
#   files/mod/PZBackup/42/mod.info                         modversion=
#   files/mod/PZBackup/42/media/lua/shared/PZBackup_Version.lua   PZBackup.VERSAO
#                                         (shown in Options > Mods, the F9 window, console.txt)
#   files/linux/pz-backup.sh                               "# Version" line + VERSION=
#   files/windows/pz-backup.ps1                            "# Version" line + $Versao =
#   README.md / LEIAME.md                                  "Version" / "Versão" line
#   CHANGELOG.md                                           "## [Unreleased]" becomes
#                                                          "## [X.Y.Z] - today" (+ release link)
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

MODINFO=files/mod/PZBackup/42/mod.info
LUAVER=files/mod/PZBackup/42/media/lua/shared/PZBackup_Version.lua
SH=files/linux/pz-backup.sh
PS=files/windows/pz-backup.ps1

# Version found in each file (one "file: version" per line)
versoes() {
  echo "mod.info: $(sed -n 's/^modversion=\([0-9.]*\).*/\1/p' "$MODINFO")"
  echo "PZBackup_Version.lua: $(sed -n 's/^PZBackup.VERSAO = "\([0-9.]*\)".*/\1/p' "$LUAVER")"
  echo "pz-backup.sh (header): $(sed -n 's/^# Version \([0-9.]*\) .*/\1/p' "$SH")"
  echo "pz-backup.sh (VERSION): $(sed -n 's/^VERSION="\([0-9.]*\)".*/\1/p' "$SH")"
  echo "pz-backup.ps1 (header): $(sed -n 's/^# Version \([0-9.]*\) .*/\1/p' "$PS" | tr -d '\r')"
  echo "pz-backup.ps1 (\$Versao): $(sed -n 's/^\$Versao = "\([0-9.]*\)".*/\1/p' "$PS" | tr -d '\r')"
  echo "README.md: $(sed -n 's/^Version \([0-9.]*\) .*/\1/p' README.md)"
  echo "LEIAME.md: $(sed -n 's/^Versão \([0-9.]*\) .*/\1/p' LEIAME.md)"
  echo "CHANGELOG.md: $(sed -n 's/^## \[\([0-9][0-9.]*\)\].*/\1/p' CHANGELOG.md | head -n1)"
}

verificar() {
  local lista unicas
  lista=$(versoes)
  unicas=$(echo "$lista" | sed 's/^[^:]*: //' | sort -u)
  if [ "$(echo "$unicas" | wc -l)" -eq 1 ] && [ -n "$unicas" ]; then
    echo "Version $unicas everywhere."
    return 0
  fi
  echo "Versions DON'T match:"
  echo "$lista" | sed 's/^/  /'
  echo "Fix with: bash tools/bump-version.sh X.Y.Z"
  return 1
}

case "${1:-}" in
  --check) verificar; exit $? ;;
  ''|-h|--help) sed -n '2,17p' "$0"; exit 0 ;;
esac

NOVA="$1"
[[ "$NOVA" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Version must be X.Y.Z (e.g. 1.4.1), got: $NOVA"; exit 1; }
ATUAL=$(sed -n 's/^modversion=\([0-9.]*\).*/\1/p' "$MODINFO")
HOJE=$(date +%Y-%m-%d)

sed -i "s/^modversion=.*/modversion=$NOVA/" "$MODINFO"
sed -i "s/^PZBackup.VERSAO = \".*\"/PZBackup.VERSAO = \"$NOVA\"/" "$LUAVER"
sed -i "s/^# Version [0-9.]* /# Version $NOVA /; s/^VERSION=\"[0-9.]*\"/VERSION=\"$NOVA\"/" "$SH"
# The .ps1 has CRLF line endings: the substitutions keep the \r at the end of each line
sed -i "s/^# Version [0-9.]* /# Version $NOVA /; s/^\\\$Versao = \"[0-9.]*\"/\$Versao = \"$NOVA\"/" "$PS"
sed -i "s/^Version [0-9.]* /Version $NOVA /" README.md
sed -i "s/^Versão [0-9.]* /Versão $NOVA /" LEIAME.md

# CHANGELOG: [Unreleased] -> [X.Y.Z] - today; otherwise add an empty section on top
if ! grep -q "^## \[$NOVA\]" CHANGELOG.md; then
  if grep -q '^## \[Unreleased\]' CHANGELOG.md; then
    sed -i "s/^## \[Unreleased\].*/## [$NOVA] - $HOJE/" CHANGELOG.md
  else
    awk -v v="$NOVA" -v d="$HOJE" '!feito && /^## \[/ { print "## [" v "] - " d "\n\n### Changed\n- (describe the changes)\n"; feito = 1 } { print }' \
      CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
    echo "CHANGELOG.md: added an empty [$NOVA] section — describe the changes there."
  fi
  if ! grep -q "^\[$NOVA\]:" CHANGELOG.md; then
    awk -v v="$NOVA" '!feito && /^\[[0-9][0-9.]*\]: / { print "[" v "]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v" v; feito = 1 } { print }' \
      CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
  fi
fi

echo "Version $ATUAL -> $NOVA"
verificar
echo
echo "Next: review CHANGELOG.md, commit, push to Forgejo, then"
echo "      bash workshop/prepare-workshop.sh --public"
