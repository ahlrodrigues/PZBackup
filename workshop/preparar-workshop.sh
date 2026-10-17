#!/bin/bash
# Monta a pasta de envio para a Steam Workshop em <Zomboid>/Workshop/PZBackup
# a partir do código do repositório. Depois: jogo > Workshop > Criar e atualizar.
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
for b in "$HOME/Zomboid" "$HOME/.var/app/com.valvesoftware.Steam/Zomboid"; do
  [ -d "$b" ] && { BASE="$b"; break; }
done
[ -z "$BASE" ] && { echo "Pasta Zomboid não encontrada."; exit 1; }

DEST="$BASE/Workshop/PZBackup"
ID=""
# preserva o id que o jogo grava no workshop.txt após o primeiro envio
[ -f "$DEST/workshop.txt" ] && ID=$(grep '^id=' "$DEST/workshop.txt" || true)

rm -rf "$DEST/Contents"
mkdir -p "$DEST/Contents/mods"
cp -r "$REPO/arquivos/mod/PZBackup" "$DEST/Contents/mods/PZBackup"
rm -f "$DEST/Contents/mods/PZBackup/common/.gitkeep"
mkdir -p "$DEST/Contents/mods/PZBackup/common"
cp "$REPO/workshop/preview.png" "$DEST/preview.png"
{ [ -n "$ID" ] && echo "$ID"; cat "$REPO/workshop/workshop.txt"; } > "$DEST/workshop.txt"

echo "Pasta pronta: $DEST"
find "$DEST" -type f | sed "s#^$DEST/#  #" | sort
[ -n "$ID" ] && echo "(mantido $ID: o envio vai ATUALIZAR o item existente)"
echo
echo "Agora: abra o jogo > Workshop > Criar e atualizar conteúdo > PZBackup."
