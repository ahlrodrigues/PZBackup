#!/bin/bash
# pz-backup.sh — automatic and manual save backups for Project Zomboid (Linux)
# Version 1.2.0 — https://github.com/ahlrodrigues/PZBackup — MIT License
#
# Requires: bash. Recommended: python3 (beeps and players.db death check)
#           and paplay/pw-play/aplay (sound). Without python3 backups still work.
#
# Usage:
#   pz-backup.sh save        -> back up now (bind it to a keyboard shortcut)
#   pz-backup.sh loop        -> back up every INTERVAL minutes (leave it running)
#   pz-backup.sh list        -> list existing backups
#   pz-backup.sh restore     -> restore the most recent backup (game CLOSED)
#   pz-backup.sh restore N   -> restore backup number N from the list (1 = newest)
#   pz-backup.sh clean       -> remove dead-character saves now (game CLOSED)
#   pz-backup.sh log [N]     -> show the last N log lines (default 30)
#   pz-backup.sh game %command% -> for Steam's Launch Options: runs automatic backups
#                      while the game is open and stops when it closes
#                      (also serves the PZ Backup mod's keys and restore window)
#   Older Portuguese command names still work: jogo = game, limpar = clean.

# ---------------- Settings ----------------
INTERVAL=5                                # minutes between automatic backups
KEEP=10                                   # backups kept per world
KEEP_REPLACED=5                           # replaced saves kept (in total)
REMOVE_DEAD=""                            # dead-character saves when the game closes:
                                          #   empty = follow the mod option (default: on)
                                          #   1 = always remove, 0 = never remove
SOUND=1                                   # 1 = beep on backup/restore, 0 = silent
SOUND_OK=""                               # optional: your own success .wav
SOUND_ERROR=""                            # optional: your own error .wav
LANGUAGE=""                               # messages: empty = follow the mod/system; "pt" or "en"
# ------------------------------------------

# Game folder: detects native Steam or Flatpak Steam automatically.
# (Inside the Flatpak, $HOME already points to ~/.var/app/com.valvesoftware.Steam,
#  so the same script works from Steam and from a keyboard shortcut.)
FLATPAK_HOME="$HOME/.var/app/com.valvesoftware.Steam"
BASE="$HOME/Zomboid"; SAVES="$BASE/Saves"
for b in "$HOME/Zomboid" "$FLATPAK_HOME/Zomboid"; do
  for s in Saves saves; do                # accepts "Saves" or "saves"
    if [ -d "$b/$s" ]; then BASE="$b"; SAVES="$b/$s"; break 2; fi
  done
done
DESTINO="$BASE/BackupsSaves"              # where backups are kept


mkdir -p "$DESTINO"
SUBST="$DESTINO/replaced"                 # saves replaced by a restore or removed by cleanup
# Migration: older versions used the "substituidos" folder
if [ -d "$DESTINO/substituidos" ] && [ ! -e "$SUBST" ]; then mv "$DESTINO/substituidos" "$SUBST"; fi
LUA_DIR="$BASE/Lua"                       # folder where the PZ Backup mod exchanges messages
ORIGEM="MANUAL"                           # log tag: MANUAL, MOD, AUTO, FINAL, RESTAURO

# Generates the beeps (.wav) once, needing nothing but python3
gerar_bipes() {
  local dir="$DESTINO/.sons"
  [ -f "$dir/ok.wav" ] && [ -f "$dir/erro.wav" ] && return 0
  command -v python3 >/dev/null || return 1
  mkdir -p "$dir"
  python3 - "$dir" <<'PY'
import math, struct, sys, wave
def bipes(arq, notas):
    taxa, dados = 44100, b""
    for freq, dur in notas:
        n = int(taxa * dur)
        for i in range(n):
            env = min(1, i / 400, (n - i) / 400)          # avoids clicks
            v = 0.45 * env * math.sin(2 * math.pi * freq * i / taxa) if freq else 0
            dados += struct.pack("<h", int(v * 32767))
    with wave.open(arq, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(taxa); w.writeframes(dados)
d = sys.argv[1]
bipes(f"{d}/ok.wav",   [(880, .09), (0, .05), (1320, .14)])    # two rising beeps
bipes(f"{d}/erro.wav", [(330, .18), (0, .06), (220, .30)])     # two falling beeps
PY
}

tocar() {
  [ "$SOUND" = 1 ] || return 0
  local arq
  if [ "$1" = erro ]; then arq=${SOUND_ERROR:-$DESTINO/.sons/erro.wav}; else arq=${SOUND_OK:-$DESTINO/.sons/ok.wav}; fi
  [ -f "$arq" ] || gerar_bipes
  [ -f "$arq" ] || { printf '\a'; return; }
  if   command -v paplay >/dev/null; then paplay "$arq" 2>/dev/null &
  elif command -v pw-play >/dev/null; then pw-play "$arq" 2>/dev/null &
  elif command -v aplay  >/dev/null; then aplay -q "$arq" 2>/dev/null &
  elif command -v flatpak-spawn >/dev/null; then
    # Inside the Flatpak: play through the host (needs the permission from the README)
    ( flatpak-spawn --host paplay "$arq" 2>/dev/null || flatpak-spawn --host aplay -q "$arq" 2>/dev/null ) &
  else printf '\a'                        # last resort: terminal bell
  fi
}

# Strips accents from text shown in game (the game font may lack them)
sem_acento() {
  # byte-by-byte replacement: works in any locale (doesn't depend on UTF-8)
  LC_ALL=C sed 's/á/a/g; s/à/a/g; s/â/a/g; s/ã/a/g; s/ä/a/g; s/é/e/g; s/è/e/g; s/ê/e/g; s/ë/e/g; s/í/i/g; s/ì/i/g; s/î/i/g; s/ï/i/g; s/ó/o/g; s/ò/o/g; s/ô/o/g; s/õ/o/g; s/ö/o/g; s/ú/u/g; s/ù/u/g; s/û/u/g; s/ü/u/g; s/ç/c/g; s/ñ/n/g; s/Á/A/g; s/À/A/g; s/Â/A/g; s/Ã/A/g; s/Ä/A/g; s/É/E/g; s/È/E/g; s/Ê/E/g; s/Ë/E/g; s/Í/I/g; s/Ì/I/g; s/Î/I/g; s/Ï/I/g; s/Ó/O/g; s/Ò/O/g; s/Ô/O/g; s/Õ/O/g; s/Ö/O/g; s/Ú/U/g; s/Ù/U/g; s/Û/U/g; s/Ü/U/g; s/Ç/C/g; s/Ñ/N/g; s/—/-/g'
}

# Message language: English by default; Portuguese when the mod's pt-BR option is on
# (the mod writes idioma=pt|en into pzbackup_config.txt). LANGUAGE forces one.
idioma() {
  if [ -n "$LANGUAGE" ]; then echo "$LANGUAGE"; return; fi
  local cfg="$LUA_DIR/pzbackup_config.txt"
  if   grep -q '^idioma=en' "$cfg" 2>/dev/null; then echo en
  elif grep -q '^idioma=pt' "$cfg" 2>/dev/null; then echo pt
  else echo en                            # default: English
  fi
}
# msg "Portuguese text" "English text"
msg() { if [ "$(idioma)" = en ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

# Copies the last log lines to Zomboid/Lua (the mod can only read files there)
espelhar_log() {
  [ -d "$LUA_DIR" ] && [ -f "$DESTINO/pz-backup.log" ] || return 0
  tail -n 150 "$DESTINO/pz-backup.log" | sem_acento > "$LUA_DIR/pzbackup_log.txt.tmp" &&
    mv -f "$LUA_DIR/pzbackup_log.txt.tmp" "$LUA_DIR/pzbackup_log.txt"
}

# avisar "message" [erro]
avisar() {
  local rot="$ORIGEM"                     # tag in the message language
  if [ "$(idioma)" = en ]; then
    case "$ORIGEM" in RESTAURO) rot=RESTORE ;; LIMPEZA) rot=CLEANUP ;; esac
  fi
  echo "$1"
  printf '%s  %-10s %s\n' "$(date '+%d/%m %H:%M:%S')" "[$rot]" "$1" >> "$DESTINO/pz-backup.log"
  espelhar_log
  tocar "${2:-ok}"
  # Hands the result to the mod to show on screen
  [ -d "$LUA_DIR" ] && printf '%s|%s|%s\n' "$(date +%s%N)" "${2:-ok}" "[$rot] $1" | sem_acento > "$LUA_DIR/pzbackup_status.txt"
  command -v notify-send >/dev/null && notify-send "Project Zomboid" "$1"
  return 0
}

# Current save = most recently modified world folder (Saves/<mode>/<world>)
save_atual() {
  ls -dt "$SAVES"/*/*/ 2>/dev/null | head -n1 | sed 's:/$::'
}

# Checks the save's players.db to see if the character is dead.
# Looks for any table with an isDead column (the game's format).
# Output: "morto" (dead), "vivo" (alive) or "desconhecido" (unknown: the backup goes ahead).
estado_personagem() {
  # 1) Notice from the PZ Backup mod (only valid if updated in the last 12 h)
  local est="$LUA_DIR/pzbackup_estado.txt"
  if [ -f "$est" ] && [ -n "$(find "$est" -mmin -720 2>/dev/null)" ]; then
    grep -q '^morto' "$est" && { echo morto; return; }
  fi
  # 2) Read players.db directly
  estado_db "$1"
}

# players.db only (no mod notice): "morto" if ALL characters in the save
# are dead, "vivo" if any is alive, "desconhecido" if it can't be read
estado_db() {
  local db="$1/players.db"
  [ -f "$db" ] && command -v python3 >/dev/null || { echo desconhecido; return; }
  python3 - "$db" <<'PY' 2>/dev/null || echo desconhecido
import sqlite3, sys
con = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True, timeout=2)
estados = []
for (tab,) in con.execute("SELECT name FROM sqlite_master WHERE type='table'"):
    cols = [c[1].lower() for c in con.execute(f'PRAGMA table_info("{tab}")')]
    if "isdead" in cols:
        estados += [r[0] for r in con.execute(f'SELECT isDead FROM "{tab}"')]
if not estados:
    print("desconhecido")
elif all(e in (1, "1", True) for e in estados):
    print("morto")
else:
    print("vivo")
PY
}

fazer_backup() {
  local origem; origem=$(save_atual)
  [ -z "$origem" ] && { avisar "$(msg "Nenhum save encontrado em $SAVES" "No save found in $SAVES")" erro; return 1; }

  # Don't bury the good backups under a dead character
  if [ "$(estado_personagem "$origem")" = morto ]; then
    avisar "$(msg "Personagem MORTO em $(basename "$origem") — backup NÃO feito. F9 ou pz-backup.sh restore" "Character is DEAD in $(basename "$origem") — backup NOT taken. F9 or pz-backup.sh restore")" erro
    return 2
  fi

  local modo mundo carimbo alvo
  modo=$(basename "$(dirname "$origem")")
  mundo=$(basename "$origem")
  carimbo=$(date +%Y-%m-%d_%H-%M-%S)
  alvo="$DESTINO/${modo}__${mundo}__${carimbo}"
  [ -e "$alvo" ] && alvo="${alvo}-$$"     # two backups in the same second

  if cp -a "$origem" "$alvo" && touch "$alvo"; then
    avisar "$(msg "Backup feito: $mundo ($carimbo)" "Backup done: $mundo ($carimbo)")"
  else
    avisar "$(msg "FALHA no backup de $mundo" "Backup FAILED for $mundo")" erro; return 1
  fi

  # Keep only the KEEP newest for this world
  # (one line per folder: works with spaces in the world name)
  ls -d "$DESTINO/${modo}__${mundo}__"* 2>/dev/null | sort -r | tail -n +$((KEEP + 1)) |
    while IFS= read -r velho; do rm -rf -- "$velho"; done
  atualizar_lista
}

# Lists backups newest first (sorted by the date in the name)
backups_ordenados() {
  for d in "$DESTINO"/*__*__*; do
    [ -d "$d" ] && echo "${d##*__}|$d"
  done | sort -r | cut -d'|' -f2-
}

listar() {
  backups_ordenados | nl -w2 -s'  ' | sed "s:$DESTINO/::"
}

# Writes Zomboid/Lua/pzbackup_lista.txt for the mod's restore window
# Format: name|label  (e.g. Survivor__World__2026-10-14_14-35-07|14/10 14:35:07  -  World)
atualizar_lista() {
  [ -d "$LUA_DIR" ] || return 0
  local d nome data mundo tmp="$LUA_DIR/.pzbackup_lista.tmp"
  backups_ordenados | while read -r d; do
    nome=$(basename "$d")
    mundo=${nome#*__}; mundo=${mundo%__*}
    # 2026-10-14_14-35-07 -> 14/10 14:35:07
    data=$(echo "${nome##*__}" | sed -E 's/^([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2})-([0-9]{2})-([0-9]{2}).*/\3\/\2 \4:\5:\6/')
    # the name (before "|") is untouched; only the displayed label loses accents
    echo "$nome|$(echo "$data  -  $mundo" | sem_acento)"
  done > "$tmp" && mv -f "$tmp" "$LUA_DIR/pzbackup_lista.txt"
}

# Game running? (Linux executable or the game's main Java class)
jogo_aberto() {
  pgrep -f '(^|/)ProjectZomboid(64|32)?( |$)|^[^ ]*java .*zombie\.gameStates\.MainScreenState' >/dev/null 2>&1
}

# Keep only the KEEP_REPLACED newest replaced saves (by the date in the name)
limpar_substituidos() {
  local dir="$SUBST" d
  [ -d "$dir" ] || return 0
  for d in "$dir"/*__*__*; do
    [ -d "$d" ] && echo "${d##*__}|$d"
  done | sort -r | cut -d'|' -f2- | tail -n +$((KEEP_REPLACED + 1)) |
    while IFS= read -r d; do rm -rf -- "$d"; done
}

# Is the "remove dead-character saves" option on?
apagar_mortos_ativo() {
  case "$REMOVE_DEAD" in 1) return 0 ;; 0) return 1 ;; esac
  local cfg="$LUA_DIR/pzbackup_config.txt"
  [ -f "$cfg" ] || return 1               # no mod: remove nothing
  grep -q '^apagar_mortos=1' "$cfg"
}

# Removes worlds where the character died from the Saves folder (game CLOSED only).
# The save isn't deleted right away: it goes to BackupsSaves/replaced (the 5 newest are kept).
# Decided per world:
#   - players.db says "morto" (dead)                 -> remove
#   - players.db says "vivo" (alive)                 -> keep (e.g. new character in the same world)
#   - players.db unreadable and the mod reported death -> remove
limpar_mortos() {
  apagar_mortos_ativo || return 0
  local est="$LUA_DIR/pzbackup_estado.txt" mundo_mod="" w modo mundo estado n=0
  if [ -f "$est" ] && head -n1 "$est" | grep -q '^morto'; then
    mundo_mod=$(sed -n 2p "$est" | tr -d '\r')
  fi
  mkdir -p "$SUBST"
  for w in "$SAVES"/*/*/; do
    w=${w%/}; [ -d "$w" ] || continue
    modo=$(basename "$(dirname "$w")"); mundo=$(basename "$w")
    [ "$modo" = Multiplayer ] && continue  # server saves: never touched
    estado=$(estado_db "$w")
    if [ "$estado" = morto ] || { [ "$estado" = desconhecido ] && [ -n "$mundo_mod" ] &&
         { [ "$mundo_mod" = "$modo/$mundo" ] || [ "$mundo_mod" = "/$mundo" ]; }; }; then
      mv "$w" "$SUBST/${modo}__${mundo}__$(date +%Y-%m-%d_%H-%M-%S)" &&
        { avisar "$(msg "Save de personagem morto removido de Carregar: $mundo (guardado em replaced)" "Dead character's save removed from Load: $mundo (kept in replaced)")"; n=$((n+1)); }
    fi
  done
  [ -n "$mundo_mod" ] && printf 'limpo\n%s\n' "$mundo_mod" > "$est"   # notice handled
  [ $n -gt 0 ] && limpar_substituidos
  return 0
}

# Restore core: takes the backup NAME (asks nothing)
restaurar_nome() {
  local nome="$1" escolhido="$DESTINO/$1"
  [ -n "$nome" ] && [ -d "$escolhido" ] || { avisar "$(msg "Backup não encontrado: $nome" "Backup not found: $nome")" erro; return 1; }

  local modo mundo destino_save
  modo=${nome%%__*}
  mundo=${nome#*__}; mundo=${mundo%__*}
  destino_save="$SAVES/$modo/$mundo"

  # Keep the current save (e.g. dead character) instead of deleting it
  # (outside the Saves folder so it doesn't show in the game's save list)
  mkdir -p "$SUBST" "$SAVES/$modo"
  [ -d "$destino_save" ] && mv "$destino_save" "$SUBST/${modo}__${mundo}__$(date +%Y-%m-%d_%H-%M-%S)"
  limpar_substituidos
  if cp -a "$escolhido" "$destino_save"; then
    touch "$destino_save"                 # becomes the newest save (top of the game's list)
    # The "morto" state belonged to the old save, not the restored one
    [ -d "$LUA_DIR" ] && printf 'restaurado\n%s/%s\n' "$modo" "$mundo" > "$LUA_DIR/pzbackup_estado.txt"
    avisar "$(msg "Save restaurado: $nome" "Save restored: $nome")"
  else
    avisar "$(msg "FALHA ao restaurar $nome" "Restore FAILED: $nome")" erro; return 1
  fi
}

# Reminder shown after each restore
aviso_mods() {
  if [ "$(idioma)" = en ]; then cat <<'TXT'

HEADS UP: the restored save comes back with the mod list it had when the backup was taken.
When loading, check Load > (your save) > Mods: re-enable PZ Backup and the mods you use,
and disable the ones you don't want. If a mod doesn't respond, disable and re-enable it.
TXT
  else cat <<'TXT'

ATENÇÃO: o save restaurado volta com a lista de mods de quando o backup foi feito.
Ao carregar, confira em Carregar > (seu save) > Mods: reative o PZ Backup e os mods
que você usa, e desative os que não quiser. Se um mod não responder, desative e reative.
TXT
  fi
}

# Restore from the terminal: pick by list number and confirm
restaurar() {
  # The game reads the save list only on startup: restoring while it's open
  # keeps the save out of "Load" until the game restarts.
  if jogo_aberto; then
    avisar "$(msg "Feche o Project Zomboid antes de restaurar (o jogo só lê a lista de saves ao abrir)" "Close Project Zomboid before restoring (the game only reads the save list on startup)")" erro
    return 1
  fi

  local n="${1:-1}" escolhido nome
  escolhido=$(backups_ordenados | sed -n "${n}p")
  [ -z "$escolhido" ] && { msg "Backup $n não encontrado." "Backup $n not found."; echo; return 1; }
  nome=$(basename "$escolhido")

  msg "Restaurar: " "Restore:   "; echo "$nome"
  msg "Em:        " "Into:      "; echo "$SAVES/${nome%%__*}/$(n=${nome#*__}; echo "${n%__*}")"
  read -rp "$(msg "Confirmar restauração? (s/N): " "Confirm restore? (y/N): ")" ok
  case "$ok" in s|S|y|Y) ;; *) msg "Cancelado." "Cancelled."; echo; return 1 ;; esac
  restaurar_nome "$nome" && { msg "Pode abrir o jogo." "You can start the game now."; echo; aviso_mods; }
}

case "$1" in
  save)    ORIGEM="MANUAL"; fazer_backup ;;
  loop)    ORIGEM="AUTO"; avisar "$(msg "Backup automático a cada $INTERVAL min (Ctrl+C para parar)" "Automatic backup every $INTERVAL min (Ctrl+C to stop)")"
           while true; do sleep $((INTERVAL * 60)); fazer_backup; done ;;
  list)    listar ;;
  log)     tail -n "${2:-30}" "$DESTINO/pz-backup.log" 2>/dev/null || echo "$(msg "Log vazio." "Log is empty.")" ;;
  clean|limpar)
           if jogo_aberto; then avisar "$(msg "Feche o Project Zomboid antes de limpar" "Close Project Zomboid before cleaning up")" erro; exit 1; fi
           ORIGEM="LIMPEZA"; REMOVE_DEAD=1; limpar_mortos ;;
  game|jogo)
           shift
           [ $# -eq 0 ] && { msg "Uso na Steam (Opções de inicialização): $0 game %command%" "Steam usage (Launch Options): $0 game %command%"; echo; exit 1; }
           mkdir -p "$LUA_DIR"
           PEDIDO="$LUA_DIR/pzbackup_pedido.txt"
           PEDIDO_RESTAURO="$LUA_DIR/pzbackup_restaurar.txt"
           ATIVO="$LUA_DIR/pzbackup_ativo.txt"
           rm -f "$PEDIDO" "$PEDIDO_RESTAURO"
           espelhar_log
           while true; do
             ORIGEM="AUTO"
             atualizar_lista
             ( trap 'kill $SP 2>/dev/null; exit 0' TERM
               while true; do
                 sleep $((INTERVAL * 60)) & SP=$!; wait $SP
                 fazer_backup
               done ) &
             LOOP_PID=$!
             # Heartbeat for the mod + serves the backup key (every 1 s)
             ( trap 'kill $SP 2>/dev/null; exit 0' TERM
               while true; do
                 date +%s > "$ATIVO"
                 if [ -f "$PEDIDO" ]; then
                   rm -f "$PEDIDO"
                   ORIGEM="MOD"; fazer_backup
                 fi
                 sleep 1 & SP=$!; wait $SP
               done ) &
             MOD_PID=$!
             avisar "$(msg "Jogo iniciado — backup automático a cada $INTERVAL min" "Game started — automatic backup every $INTERVAL min")"
             "$@"; RC=$?                   # runs the game and waits for it to close
             # Stops the loops (each kills its own "sleep" on TERM)
             kill "$LOOP_PID" "$MOD_PID" 2>/dev/null
             wait "$LOOP_PID" "$MOD_PID" 2>/dev/null
             rm -f "$ATIVO"

             # Restore requested from the mod window: restore and relaunch the game
             if [ -f "$PEDIDO_RESTAURO" ]; then
               NOME=$(head -n1 "$PEDIDO_RESTAURO" | tr -d '\r')
               rm -f "$PEDIDO_RESTAURO"
               # "AUTO mode/world" (death with auto-restore): that world's newest backup
               if [ "${NOME#AUTO }" != "$NOME" ]; then
                 ALVO=${NOME#AUTO }
                 NOME=$(ls -d "$DESTINO/${ALVO%%/*}__${ALVO#*/}__"* 2>/dev/null | sort -r | head -n1)
                 NOME=${NOME##*/}
                 [ -z "$NOME" ] && { ORIGEM="RESTAURO"; avisar "$(msg "Sem backup de ${ALVO#*/} para restaurar automaticamente" "No backup of ${ALVO#*/} to auto-restore")" erro; }
               fi
               sleep 3                     # let the game finish writing
               ORIGEM="RESTAURO"
               if [ -n "$NOME" ] && restaurar_nome "$NOME"; then
                 avisar "$(msg "Reabrindo o jogo com o backup restaurado. Confira os mods do save ao carregar (reative/desative)" "Reopening the game with the restored backup. Check the save's mods when loading (re-enable/disable)")"
                 continue
               fi
             fi
             ORIGEM="FINAL"; fazer_backup  # final backup, game already closed
             ORIGEM="LIMPEZA"; limpar_mortos # remove dead-character saves (if the option is on)
             exit $RC
           done ;;
  restore) ORIGEM="RESTAURO"; restaurar "$2" ;;
  *)       sed -n '2,19p' "$0" ;;
esac
