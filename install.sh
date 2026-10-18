#!/bin/bash
# instalar.sh — Instalador do PZ Backup. Verifica o sistema e instala a versão certa.
# Uso: bash instalar.sh

PACOTE="$(cd "$(dirname "$0")" && pwd)"
verde() { printf '  \033[32m- %s\033[0m\n' "$1"; }
erro()  { printf '\n\033[31mERRO: %s\033[0m\n' "$1"; exit 1; }

echo
echo "=== Instalador PZ Backup ==="
echo

# 1. Sistema operacional
case "$(uname -s)" in
  Linux) ;;
  MINGW*|MSYS*|CYGWIN*)
    erro "Você está no Windows. Feche este terminal e dê dois cliques em instalar.bat." ;;
  Darwin)
    erro "macOS ainda não é suportado." ;;
  *)
    erro "Sistema não reconhecido: $(uname -s)" ;;
esac
verde "Sistema: Linux"

# 2. Onde o jogo guarda os saves (Steam nativa ou Flatpak)
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
[ -z "$BASE" ] && erro "Pasta Zomboid não encontrada. Abra o Project Zomboid uma vez antes de instalar."

TIPO="Steam nativa"
case "$BASE" in "$FLATPAK_HOME"/*) TIPO="Steam Flatpak" ;; esac
verde "Pasta do jogo: $BASE ($TIPO)"

# 3. Mod
mkdir -p "$BASE/mods"
rm -rf "$BASE/mods/PZBackup"
cp -r "$PACOTE/arquivos/mod/PZBackup" "$BASE/mods/PZBackup"
mkdir -p "$BASE/mods/PZBackup/common"
verde "Mod instalado em $BASE/mods/PZBackup"

# 4. Script
install -m 755 "$PACOTE/arquivos/linux/pz-backup.sh" "$BASE/pz-backup.sh"
verde "Script instalado em $BASE/pz-backup.sh"

# 5. Dependências opcionais
command -v python3 >/dev/null || echo "  ! python3 não encontrado: sem bipes e sem verificação extra do players.db (o mod ainda detecta a morte)"
command -v paplay >/dev/null || command -v pw-play >/dev/null || command -v aplay >/dev/null \
  || echo "  ! Nenhum player de áudio (paplay/pw-play/aplay): sem bipes"

# 6. O que falta fazer
cat <<EOF

=== Pronto! Faltam dois passos ===

1) Steam > botão direito em Project Zomboid > Propriedades > Geral >
   Opções de inicialização. Cole no campo de texto:

   $BASE/pz-backup.sh jogo %command%

2) No jogo: menu principal > Mods > ative "PZ Backup" (e também no seu save).

Dentro do jogo: F8 faz um backup manual, F9 abre a janela de restauração (com o botão Ver log).
Ao morrer, o backup mais recente é restaurado sozinho (desligue em Opções > Mods).
Para restaurar pelo terminal (com o jogo FECHADO):
   $BASE/pz-backup.sh list
   $BASE/pz-backup.sh restore N

EOF
