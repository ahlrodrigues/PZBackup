#!/bin/bash
# pz-backup.sh — automatic and manual save backups for Project Zomboid (Linux)
# Version 1.4.0 — https://github.com/ahlrodrigues/PZBackup — MIT License
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
#   pz-backup.sh pin N       -> pin backup N: never removed by the rotation
#   pz-backup.sh unpin N     -> unpin backup N (it goes back into the rotation)
#   pz-backup.sh note N "text" -> name backup N (empty text removes the note)
#   pz-backup.sh clean       -> remove dead-character saves now (game CLOSED)
#   pz-backup.sh log [N]     -> show the last N log lines (default 30)
#   pz-backup.sh version     -> show the script version
#   pz-backup.sh game %command% -> for Steam's Launch Options: runs automatic backups
#                      while the game is open and stops when it closes
#                      (also serves the PZ Backup mod's keys and restore window)
#   Older Portuguese command names still work: jogo = game, limpar = clean.

VERSION="1.4.0"                           # updated by tools/bump-version.sh

# ---------------- Settings ----------------
INTERVAL=5                                # minutes between automatic backups
KEEP=10                                   # newest backups kept per world (pinned ones don't count)
KEEP_HOURLY=24                            # also keep 1 backup per hour of the last N hours (0 = off)
KEEP_GAME_DAYS=14                         # also keep 1 backup per in-game day, last N game days (0 = off)
HARDLINKS=1                               # 1 = incremental: unchanged files are hard links to the
                                          #     previous backup (needs rsync), 0 = full copies
MIN_FREE_MB=1024                          # automatic backups stop below this free space (MB)
QUIET_SECONDS=3                           # wait until the save hasn't changed for this long
VERIFY=1                                  # check every backup after copying (and players.db)
UPDATE_BACKUP=1                           # pinned backup of every world when Steam updates the game
DEATH_MARGIN=""                           # auto-restore skips backups this close to the death (s):
                                          #   empty = follow the mod option (default 60)
DANGER_WAIT=""                            # postpone automatic backups while in danger:
                                          #   empty = follow the mod option (default on), 1 / 0
DANGER_RETRY=20                           # seconds between tries while a backup is postponed
KEEP_REPLACED=5                           # replaced saves kept (in total)
REMOVE_DEAD=""                            # dead-character saves when the game closes:
                                          #   empty = follow the mod option (default: on)
                                          #   1 = always remove, 0 = never remove
SOUND=1                                   # 1 = beep on backup/restore, 0 = silent
SOUND_OK=""                               # optional: your own success .wav
SOUND_ERROR=""                            # optional: your own error .wav
LANGUAGE=""                               # messages: empty = follow the mod's Language option; "pt" or "en"
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
INFO_DIR="$DESTINO/.info"                 # per-backup details (character, days, kills, mods)
PINS="$DESTINO/.pinned"                   # pinned backups, one name per line
MORTES="$DESTINO/.deaths"                 # recorded deaths: "mode/world|unix time" per line
BUILDID_ARQ="$DESTINO/.buildid"           # last game build seen (Steam), for the update backup
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

# Message language: follows the mod's Language option (Automatic = game language);
# the mod writes the result, idioma=pt|en, into pzbackup_config.txt. LANGUAGE forces one.
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

# ---------------- Mod options read by the script ----------------
# conf_mod <key> -> value from pzbackup_config.txt (empty if missing)
conf_mod() {
  sed -n "s/^$1=//p" "$LUA_DIR/pzbackup_config.txt" 2>/dev/null | head -n1 | tr -d '\r'
}

margem_morte() {
  local m="${DEATH_MARGIN:-$(conf_mod margem_morte)}"
  case "$m" in ''|*[!0-9]*) echo 60 ;; *) echo "$m" ;; esac
}

adiar_perigo_ativo() {
  case "$DANGER_WAIT" in 1) return 0 ;; 0) return 1 ;; esac
  [ "$(conf_mod adiar_perigo)" != 0 ]
}

# Danger reasons right now ("zumbis,panico"), from pzbackup_perigo.txt.
# Only trusted if written in the last 15 s (the mod refreshes it every ~2-10 s).
perigo_agora() {
  local arq="$LUA_DIR/pzbackup_perigo.txt" l flag motivos ts
  [ -f "$arq" ] || return 1
  l=$(head -n1 "$arq" | tr -d '\r')
  IFS='|' read -r flag motivos ts <<< "$l"
  [ "$flag" = 1 ] || return 1
  case "$ts" in ''|*[!0-9]*) return 1 ;; esac
  [ $(( $(date +%s) - ts )) -le 15 ] || return 1
  echo "$motivos"
}

# "zumbis,panico" -> readable text in the message language
texto_perigo() {
  local c out=""
  for c in ${1//,/ }; do
    case "$c" in
      zumbis)    c=$(msg "zumbis perto" "zombies close") ;;
      panico)    c=$(msg "pânico alto" "high panic") ;;
      sangrando) c=$(msg "sangrando" "bleeding") ;;
      fogo)      c=$(msg "pegando fogo" "on fire") ;;
      saude)     c=$(msg "pouca saúde" "low health") ;;
    esac
    out="${out:+$out, }$c"
  done
  printf '%s' "$out"
}

# ---------------- Time helpers ----------------
# Unix time of a backup, from the date in its name (local time)
backup_epoch() {
  local c="${1##*__}"
  c=${c:0:19}
  date -d "${c:0:10} ${c:11:2}:${c:14:2}:${c:17:2}" +%s 2>/dev/null || echo 0
}

# ---------------- Deaths ----------------
# Records the death reported by the mod (pzbackup_estado.txt line 3) once
registrar_morte() {
  local est="$LUA_DIR/pzbackup_estado.txt" l1 mm ts
  [ -f "$est" ] || return 0
  l1=$(sed -n 1p "$est" | tr -d '\r'); [ "$l1" = morto ] || return 0
  mm=$(sed -n 2p "$est" | tr -d '\r'); ts=$(sed -n 3p "$est" | tr -d '\r')
  case "$ts" in ''|*[!0-9]*) return 0 ;; esac
  grep -qxF -- "$mm|$ts" "$MORTES" 2>/dev/null || echo "$mm|$ts" >> "$MORTES"
}

# Seconds between a backup and the next recorded death of its world,
# printed only if within the death margin (empty otherwise)
morte_seg() {
  local nome="$1" modo mundo b m melhor="" d ts
  [ -f "$MORTES" ] || return 0
  modo=${nome%%__*}; mundo=${nome#*__}; mundo=${mundo%__*}
  b=$(backup_epoch "$nome"); m=$(margem_morte)
  [ "$m" -gt 0 ] || return 0
  while IFS='|' read -r d ts; do
    { [ "$d" = "$modo/$mundo" ] || [ "$d" = "/$mundo" ]; } || continue
    case "$ts" in ''|*[!0-9]*) continue ;; esac
    if [ "$ts" -ge "$b" ] && [ $((ts - b)) -le "$m" ]; then
      [ -z "$melhor" ] || [ $((ts - b)) -lt "$melhor" ] && melhor=$((ts - b))
    fi
  done < "$MORTES"
  printf '%s' "$melhor"
}

# Picks the backup for the auto-restore of "mode/world": the newest one that is
# neither bitten nor within the death margin. Falls back to the newest not bitten,
# then to the newest. Prints the name; explains the choice on stderr (for the log).
backup_seguro() {
  local alvo="$1" morte="$2" modo="${1%%/*}" mundo="${1#*/}" m d nome b mord
  local pulados_m=0 pulados_p=0 primeiro="" sem_mordida="" escolhido=""
  m=$(margem_morte)
  while IFS= read -r d; do
    nome=${d##*/}; b=$(backup_epoch "$nome")
    [ -z "$primeiro" ] && primeiro="$nome"
    mord=$(info_campo "$nome" mordidas)
    if [ -n "$mord" ] && [ "$mord" != 0 ]; then pulados_m=$((pulados_m + 1)); continue; fi
    [ -z "$sem_mordida" ] && sem_mordida="$nome"
    if [ -n "$morte" ] && [ "$m" -gt 0 ] && [ "$b" -le "$morte" ] && [ $((morte - b)) -lt "$m" ]; then
      pulados_p=$((pulados_p + 1)); continue
    fi
    escolhido="$nome"; break
  done < <(ls -d "$DESTINO/${modo}__${mundo}__"* 2>/dev/null | sort -r)
  [ -z "$escolhido" ] && escolhido=${sem_mordida:-$primeiro}
  echo "$pulados_m $pulados_p" >&2
  printf '%s' "$escolhido"
}

# ---------------- Disk and copy ----------------
livre_mb() { df -Pm "$1" 2>/dev/null | awk 'NR==2 {print $4}'; }
tamanho_mb() { du -sm "$1" 2>/dev/null | awk '{print $1}'; }

# Waits (up to 30 s) until no file in the save changed in the last QUIET_SECONDS,
# so the copy doesn't catch the game in the middle of writing
esperar_quieto() {
  local dir="$1" n=0
  [ "${QUIET_SECONDS:-0}" -gt 0 ] || return 0
  while [ $n -lt 30 ]; do
    find "$dir" -type f -newermt "@$(( $(date +%s) - QUIET_SECONDS ))" 2>/dev/null | grep -q . || return 0
    sleep 1; n=$((n + 1))
  done
  return 1
}

# Newest backup of a world (for the incremental copy), excluding one name
anterior_do_mundo() {
  ls -d "$DESTINO/${1}__${2}__"* 2>/dev/null | sort -r | grep -vxF -- "$3" | head -n1
}

# copiar <source> <target> <previous backup or empty>
copiar() {
  local origem="$1" alvo="$2" ant="$3"
  if [ "$HARDLINKS" = 1 ] && [ -n "$ant" ] && [ -d "$ant" ] && command -v rsync >/dev/null; then
    rsync -a --delete --link-dest="$ant" "$origem/" "$alvo/"
  else
    rm -rf -- "$alvo"; cp -a "$origem" "$alvo"
  fi
}

# Same files with the same sizes in both folders? Also checks players.db (python3).
copia_confere() {
  local a="$1" b="$2"
  [ "$VERIFY" = 1 ] || return 0
  [ "$(cd "$a" && find . -type f -printf '%s %p\n' | sort)" = "$(cd "$b" && find . -type f -printf '%s %p\n' | sort)" ] || return 1
  if [ -f "$b/players.db" ] && command -v python3 >/dev/null; then
    [ "$(python3 - "$b/players.db" <<'PY' 2>/dev/null
import sqlite3, sys
con = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True, timeout=2)
print(con.execute("PRAGMA quick_check").fetchone()[0])
PY
)" = ok ] || return 1
  fi
  return 0
}

# MB in the backup that aren't shared with older backups (hard links)
novos_mb() {
  find "$1" -type f -links 1 -printf '%s\n' 2>/dev/null | awk '{s += $1} END {printf "%d", (s + 524287) / 1048576}'
}

# ---------------- Backup ----------------
# Core copy, no checks about death/danger. Arguments:
#   copiar_backup <save folder> <note or empty> <pin: 1/0>
# Uses ORIGEM as the backup's source tag. Returns 0 ok, 1 failure.
copiar_backup() {
  local origem="$1" nota="$2" pin="$3" modo mundo carimbo alvo ant conf=ok novos
  modo=$(basename "$(dirname "$origem")")
  mundo=$(basename "$origem")
  carimbo=$(date +%Y-%m-%d_%H-%M-%S)
  alvo="$DESTINO/${modo}__${mundo}__${carimbo}"
  [ -e "$alvo" ] && alvo="${alvo}-$$"     # two backups in the same second
  ant=$(anterior_do_mundo "$modo" "$mundo" "$alvo")

  esperar_quieto "$origem" || avisar "$(msg "O save continuou mudando por 30 s; copiando mesmo assim" "The save kept changing for 30 s; copying anyway")" erro
  if ! copiar "$origem" "$alvo" "$ant"; then
    rm -rf -- "$alvo"
    avisar "$(msg "FALHA no backup de $mundo" "Backup FAILED for $mundo")" erro; return 1
  fi
  # The game may have written during the copy: wait and copy again once
  if ! copia_confere "$origem" "$alvo"; then
    esperar_quieto "$origem"
    copiar "$origem" "$alvo" "$ant" && copia_confere "$origem" "$alvo" || conf=falha
  fi
  touch "$alvo"

  guardar_info "$alvo" "$modo" "$mundo"
  novos=$(novos_mb "$alvo")
  {
    echo "origem=$ORIGEM"
    echo "tamanho_mb=$(tamanho_mb "$alvo")"
    echo "novos_mb=$novos"
    [ -n "$nota" ] && echo "nota=$(printf '%s' "$nota" | tr -d '|\r\n' | cut -c1-60)"
    [ "$conf" = falha ] && echo "integridade=falha"
  } >> "$INFO_DIR/$(basename "$alvo").txt"
  [ "$pin" = 1 ] && { touch "$PINS"; fixado "$(basename "$alvo")" || basename "$alvo" >> "$PINS"; }

  if [ "$conf" = falha ]; then
    avisar "$(msg "Backup feito, mas a VERIFICAÇÃO falhou: $mundo ($carimbo). Prefira outro backup" "Backup done, but VERIFICATION failed: $mundo ($carimbo). Prefer another backup")" erro
  else
    avisar "$(msg "Backup feito: $mundo ($carimbo, $novos MB novos)" "Backup done: $mundo ($carimbo, $novos MB new)")"
  fi
  aplicar_retencao "$modo" "$mundo"
  atualizar_lista
  return 0
}

# Space check: automatic backups stop below MIN_FREE_MB (plus the save size
# when the copy can't be incremental). Warns at most every 30 min.
espaco_ok() {
  local origem="$1" livre precisa=$MIN_FREE_MB marca="$DESTINO/.aviso_espaco"
  livre=$(livre_mb "$DESTINO")
  [ -n "$livre" ] || return 0
  { [ "$HARDLINKS" = 1 ] && command -v rsync >/dev/null; } || precisa=$((precisa + $(tamanho_mb "$origem")))
  [ "$livre" -ge "$precisa" ] && return 0
  if [ -z "$(find "$marca" -mmin -30 2>/dev/null)" ]; then
    touch "$marca"
    avisar "$(msg "POUCO ESPAÇO: $livre MB livres (mínimo $precisa MB). Backup automático pausado — libere espaço ou apague backups antigos" "LOW DISK SPACE: $livre MB free (minimum $precisa MB). Automatic backup paused — free some space or delete old backups")" erro
  fi
  return 1
}

# Backup of the current save, with the checks. Returns:
#   0 ok, 1 failure, 2 character dead, 3 postponed (danger), 4 no space
fazer_backup() {
  local origem nota="${1:-}" perigo
  origem=$(save_atual)
  [ -z "$origem" ] && { avisar "$(msg "Nenhum save encontrado em $SAVES" "No save found in $SAVES")" erro; return 1; }

  # Don't bury the good backups under a dead character
  if [ "$(estado_personagem "$origem")" = morto ]; then
    avisar "$(msg "Personagem MORTO em $(basename "$origem") — backup NÃO feito. F9 ou pz-backup.sh restore" "Character is DEAD in $(basename "$origem") — backup NOT taken. F9 or pz-backup.sh restore")" erro
    return 2
  fi

  # Automatic backups wait while the character is in danger (F8 never waits)
  case "$ORIGEM" in AUTO|FINAL)
    if adiar_perigo_ativo && perigo=$(perigo_agora); then
      if [ "$ORIGEM" = FINAL ]; then
        avisar "$(msg "Backup final pulado: o jogo fechou em perigo ($(texto_perigo "$perigo"))" "Final backup skipped: the game closed in danger ($(texto_perigo "$perigo"))")" erro
      elif [ -z "${ADIADO:-}" ]; then
        avisar "$(msg "Perigo ($(texto_perigo "$perigo")) — backup automático adiado até acalmar" "Danger ($(texto_perigo "$perigo")) — automatic backup postponed until it calms down")" erro
      fi
      ADIADO=1
      return 3
    fi
    espaco_ok "$origem" || return 4 ;;
  esac
  [ -n "${ADIADO:-}" ] && [ "$ORIGEM" = AUTO ] && avisar "$(msg "Perigo passou — fazendo o backup adiado" "Danger is over — taking the postponed backup")"
  ADIADO=""
  copiar_backup "$origem" "$nota" 0
}

# Automatic backup that keeps trying every DANGER_RETRY s while postponed
backup_automatico() {
  local rc
  while true; do
    fazer_backup; rc=$?
    [ $rc -eq 3 ] || return $rc
    sleep "$DANGER_RETRY"
    jogo_aberto || [ "${PZB_SEM_JOGO:-}" = 1 ] || return 3
  done
}

# ---------------- Retention ----------------
# Per world, without touching pinned backups:
#   - the KEEP newest;
#   - plus the newest of each real hour of the last KEEP_HOURLY hours;
#   - plus the newest of each in-game day (from the details) of the last KEEP_GAME_DAYS
#     game days, counted from the newest backup.
aplicar_retencao() {
  local modo="$1" mundo="$2" agora d nome b hora dia n=0
  local -A manter=() horas=() dias=()
  local ndias=0
  agora=$(date +%s)
  # Newest first. Every backup "marks" its real hour and its game day the first
  # time one is seen, so days/hours already covered by newer backups count too.
  while IFS= read -r d; do
    nome=${d##*/}
    fixado "$nome" && continue
    n=$((n + 1))
    b=$(backup_epoch "$nome")
    hora=${nome##*__}; hora=${hora:0:13}
    dia=$(info_campo "$nome" data_jogo)
    [ $n -le "$KEEP" ] && manter[$nome]=1
    if [ "$KEEP_HOURLY" -gt 0 ] && [ $((agora - b)) -le $((KEEP_HOURLY * 3600)) ] && [ -z "${horas[$hora]:-}" ]; then
      horas[$hora]=1; manter[$nome]=1
    fi
    if [ -n "$dia" ] && [ -z "${dias[$dia]:-}" ]; then
      dias[$dia]=1; ndias=$((ndias + 1))
      [ "$ndias" -le "$KEEP_GAME_DAYS" ] && manter[$nome]=1
    fi
    [ -n "${manter[$nome]:-}" ] || { rm -rf -- "$d"; rm -f -- "$INFO_DIR/$nome.txt"; }
  done < <(ls -d "$DESTINO/${modo}__${mundo}__"* 2>/dev/null | sort -r)
}

# Saves the mod's character info (pzbackup_info.txt) next to the backup,
# only if it belongs to this world. The current danger (pzbackup_perigo.txt)
# replaces the one in the info, which can be ~25 s old.
guardar_info() {
  local alvo="$1" modo="$2" mundo="$3" info="$LUA_DIR/pzbackup_info.txt" m dest perigo
  mkdir -p "$INFO_DIR"
  dest="$INFO_DIR/$(basename "$alvo").txt"
  : > "$dest"
  [ -f "$info" ] || return 0
  m=$(sed -n 's/^mundo=//p' "$info" | head -n1 | tr -d '\r')
  [ "$m" = "$modo/$mundo" ] || [ "$m" = "/$mundo" ] || return 0
  grep -v '^perigo=' "$info" | tr -d '\r' > "$dest"
  perigo=$(perigo_agora) && echo "perigo=$perigo" >> "$dest"
  return 0
}

# Pinned backup of every world when Steam updated the game since the last run
# (the new build may convert the saves). Uses the buildid in appmanifest_108600.acf.
buildid_atual() {
  local f
  for f in "$HOME/.steam/steam/steamapps" "$HOME/.local/share/Steam/steamapps" \
           "$FLATPAK_HOME/.local/share/Steam/steamapps" "$HOME/.steam/root/steamapps"; do
    [ -f "$f/appmanifest_108600.acf" ] || continue
    sed -n 's/.*"buildid"[[:space:]]*"\([0-9]*\)".*/\1/p' "$f/appmanifest_108600.acf" | head -n1
    return 0
  done
  # Other Steam libraries listed in libraryfolders.vdf
  for f in "$HOME/.steam/steam/steamapps/libraryfolders.vdf" "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf" \
           "$FLATPAK_HOME/.local/share/Steam/steamapps/libraryfolders.vdf"; do
    [ -f "$f" ] || continue
    sed -n 's/.*"path"[[:space:]]*"\(.*\)".*/\1/p' "$f" | while IFS= read -r lib; do
      [ -f "$lib/steamapps/appmanifest_108600.acf" ] &&
        sed -n 's/.*"buildid"[[:space:]]*"\([0-9]*\)".*/\1/p' "$lib/steamapps/appmanifest_108600.acf" | head -n1
    done | head -n1
    return 0
  done
}

verificar_atualizacao() {
  [ "$UPDATE_BACKUP" = 1 ] || return 0
  local atual antigo w n=0
  atual=$(buildid_atual); [ -n "$atual" ] || return 0
  antigo=$(cat "$BUILDID_ARQ" 2>/dev/null)
  if [ -n "$antigo" ] && [ "$antigo" != "$atual" ]; then
    ORIGEM="ATUALIZACAO"
    avisar "$(msg "Jogo atualizado (build $antigo -> $atual): backup fixado de todos os mundos antes de abrir" "Game updated (build $antigo -> $atual): pinned backup of every world before starting")"
    for w in "$SAVES"/*/*/; do
      w=${w%/}; [ -d "$w" ] || continue
      [ "$(basename "$(dirname "$w")")" = Multiplayer ] && continue
      copiar_backup "$w" "$(msg "antes da atualização $antigo -> $atual" "before update $antigo -> $atual")" 1 && n=$((n + 1))
    done
  fi
  echo "$atual" > "$BUILDID_ARQ"
}

# info_campo <backup name> <key> -> value from that backup's details (empty if none)
info_campo() {
  [ -f "$INFO_DIR/$1.txt" ] || return 0
  sed -n "s/^$2=//p" "$INFO_DIR/$1.txt" | head -n1 | tr -d '\r'
}

# ---------------- Pinned backups ----------------
fixado() { [ -f "$PINS" ] && grep -qxF -- "$1" "$PINS"; }

# fixar <name> pin|unpin
fixar() {
  local nome="$1" acao="$2"
  [ -n "$nome" ] && [ -d "$DESTINO/$nome" ] || { avisar "$(msg "Backup não encontrado: $nome" "Backup not found: $nome")" erro; return 1; }
  touch "$PINS"
  if [ "$acao" = pin ]; then
    fixado "$nome" || echo "$nome" >> "$PINS"
    avisar "$(msg "Backup fixado (nunca será apagado pela rotação): $nome" "Backup pinned (never removed by the rotation): $nome")"
  else
    grep -vxF -- "$nome" "$PINS" > "$PINS.tmp"; mv -f "$PINS.tmp" "$PINS"
    avisar "$(msg "Backup desafixado (volta para a rotação): $nome" "Backup unpinned (back in the rotation): $nome")"
  fi
  atualizar_lista
}

# anotar <name> <text>: sets (or removes, with empty text) a backup's note
anotar() {
  local nome="$1" texto arq
  texto=$(printf '%s' "$2" | tr -d '|\r\n' | cut -c1-60)
  [ -n "$nome" ] && [ -d "$DESTINO/$nome" ] || { avisar "$(msg "Backup não encontrado: $nome" "Backup not found: $nome")" erro; return 1; }
  mkdir -p "$INFO_DIR"; arq="$INFO_DIR/$nome.txt"; touch "$arq"
  grep -v '^nota=' "$arq" > "$arq.tmp"; mv -f "$arq.tmp" "$arq"
  if [ -n "$texto" ]; then
    echo "nota=$texto" >> "$arq"
    avisar "$(msg "Nota salva: $texto" "Note saved: $texto")"
  else
    avisar "$(msg "Nota removida" "Note removed")"
  fi
  atualizar_lista
}

# Handles the mod's commands (pzbackup_fixar.txt):
#   "pin <name>", "unpin <name>", "note <name>|<text>"
processar_fixar() {
  local arq="$LUA_DIR/pzbackup_fixar.txt" tmp="$LUA_DIR/.pzbackup_fixar.proc" linha
  [ -f "$arq" ] || return 0
  mv -f "$arq" "$tmp" 2>/dev/null || return 0
  while IFS= read -r linha || [ -n "$linha" ]; do
    linha=${linha%$'\r'}
    case "$linha" in
      "pin "*)   fixar "${linha#pin }" pin ;;
      "unpin "*) fixar "${linha#unpin }" unpin ;;
      "note "*)  linha=${linha#note }; anotar "${linha%%|*}" "${linha#*|}" ;;
    esac
  done < "$tmp"
  rm -f "$tmp"
}

# Drops details and pins of backups that no longer exist
limpar_meta() {
  local f n
  for f in "$INFO_DIR"/*.txt; do
    [ -f "$f" ] || continue
    n=$(basename "$f" .txt); [ -d "$DESTINO/$n" ] || rm -f -- "$f"
  done
  if [ -f "$PINS" ]; then
    while IFS= read -r n; do [ -n "$n" ] && [ -d "$DESTINO/$n" ] && echo "$n"; done < "$PINS" > "$PINS.tmp"
    mv -f "$PINS.tmp" "$PINS"
  fi
}

# Lists backups newest first (sorted by the date in the name)
backups_ordenados() {
  for d in "$DESTINO"/*__*__*; do
    [ -d "$d" ] && echo "${d##*__}|$d"
  done | sort -r | cut -d'|' -f2-
}

# One-line summary of a backup's details: "John Doe, day 12, 340 kills, health 87%, BITTEN"
resumo_info() {
  local pers dias mortes saude mord r
  pers=$(info_campo "$1" personagem); dias=$(info_campo "$1" dias); mortes=$(info_campo "$1" mortes)
  saude=$(info_campo "$1" saude); mord=$(info_campo "$1" mordidas)
  [ -z "$pers$dias" ] && return 0
  r=$(msg "$pers, dia $dias, $mortes zumbis" "$pers, day $dias, $mortes kills")
  [ -n "$saude" ] && r="$r$(msg ", saúde $saude%" ", health $saude%")"
  [ -n "$mord" ] && [ "$mord" != 0 ] && r="$r$(msg ", MORDIDO" ", BITTEN")"
  printf '%s' "$r"
}

# All details of a backup, one "key=value" per line (without the world line)
info_campos() {
  [ -f "$INFO_DIR/$1.txt" ] || return 0
  grep -v '^mundo=' "$INFO_DIR/$1.txt" | tr -d '\r' | grep '='
}

listar() {
  local i=0 d nome extra nota ms
  backups_ordenados | while IFS= read -r d; do
    i=$((i + 1)); nome=$(basename "$d"); extra=""
    fixado "$nome" && extra=" [PIN]"
    nota=$(info_campo "$nome" nota); [ -n "$nota" ] && extra="$extra \"$nota\""
    [ -n "$(info_campo "$nome" perigo)" ] && extra="$extra $(msg "[PERIGO]" "[DANGER]")"
    ms=$(morte_seg "$nome"); [ -n "$ms" ] && extra="$extra $(msg "[${ms}s ANTES DA MORTE]" "[${ms}s BEFORE DEATH]")"
    [ "$(info_campo "$nome" integridade)" = falha ] && extra="$extra $(msg "[VERIFICAÇÃO FALHOU]" "[VERIFY FAILED]")"
    [ -n "$(resumo_info "$nome")" ] && extra="$extra  ($(resumo_info "$nome"))"
    printf '%2d  %s%s\n' "$i" "$nome" "$extra"
  done
}

# Writes for the mod's restore window:
#   Zomboid/Lua/pzbackup_lista.txt     name|label  (e.g. Survivor__World__2026-10-14_14-35-07|14/10 14:35:07  -  World)
#   Zomboid/Lua/pzbackup_detalhes.txt  name|pinned(1/0)|key=value|key=value...  (all the mod's info,
#                                      passed through as-is: new fields need no script change)
# (two files so a v1.3 mod still reads the list it knows)
atualizar_lista() {
  [ -d "$LUA_DIR" ] || return 0
  limpar_meta
  local d nome data mundo fixo ms tmp="$LUA_DIR/.pzbackup_lista.tmp" tmpd="$LUA_DIR/.pzbackup_detalhes.tmp"
  : > "$tmpd"
  backups_ordenados | while read -r d; do
    nome=$(basename "$d")
    mundo=${nome#*__}; mundo=${mundo%__*}
    # 2026-10-14_14-35-07 -> 14/10 14:35:07
    data=$(echo "${nome##*__}" | sed -E 's/^([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2})-([0-9]{2})-([0-9]{2}).*/\3\/\2 \4:\5:\6/')
    fixo=0; fixado "$nome" && fixo=1
    # the name (before "|") is untouched; only the displayed text loses accents
    { printf '%s|%s' "$nome" "$fixo"
      info_campos "$nome" | tr -d '|' | sem_acento | while IFS= read -r c; do printf '|%s' "$c"; done
      ms=$(morte_seg "$nome"); [ -n "$ms" ] && printf '|morte_seg=%s' "$ms"
      echo; } >> "$tmpd"
    echo "$nome|$(echo "$data  -  $mundo" | sem_acento)"
  done > "$tmp" && mv -f "$tmp" "$LUA_DIR/pzbackup_lista.txt" && mv -f "$tmpd" "$LUA_DIR/pzbackup_detalhes.txt"
}

# Mods that differ between a backup and the current game (from the mod's last info)
# Output: lines "- id" (in the backup, not active now) and "+ id" (active now, not in the backup)
diferenca_mods() {
  local antes agora
  antes=$(info_campo "$1" mods)
  [ -n "$antes" ] && [ -f "$LUA_DIR/pzbackup_info.txt" ] || return 0
  agora=$(sed -n 's/^mods=//p' "$LUA_DIR/pzbackup_info.txt" | head -n1 | tr -d '\r')
  comm -3 <(tr ';' '\n' <<< "$antes" | sed 's/^\\*//' | grep -v '^$' | sort -u) \
          <(tr ';' '\n' <<< "$agora" | sed 's/^\\*//' | grep -v '^$' | sort -u) |
    sed -E 's/^\t(.*)/+ \1/; t; s/^/- /'
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
  [ -n "$(resumo_info "$nome")" ] && { msg "Detalhes:  " "Details:   "; resumo_info "$nome"; echo; }
  local dif; dif=$(diferenca_mods "$nome")
  if [ -n "$dif" ]; then
    msg "Mods diferentes de agora (- só no backup, + só agora):" "Mods differ from now (- only in the backup, + only now):"; echo
    echo "$dif" | sed 's/^/  /'
  fi
  read -rp "$(msg "Confirmar restauração? (s/N): " "Confirm restore? (y/N): ")" ok
  case "$ok" in s|S|y|Y) ;; *) msg "Cancelado." "Cancelled."; echo; return 1 ;; esac
  restaurar_nome "$nome" && { msg "Pode abrir o jogo." "You can start the game now."; echo; aviso_mods; }
}

case "$1" in
  save)    ORIGEM="MANUAL"; fazer_backup "${2:-}" ;;
  loop)    ORIGEM="AUTO"; avisar "$(msg "Backup automático a cada $INTERVAL min (Ctrl+C para parar)" "Automatic backup every $INTERVAL min (Ctrl+C to stop)")"
           while true; do sleep $((INTERVAL * 60)); PZB_SEM_JOGO=1 backup_automatico; done ;;
  list)    listar ;;
  version|--version|-v) echo "PZ Backup $VERSION" ;;
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
           verificar_atualizacao         # pinned backup of every world if Steam updated the game
           while true; do
             ORIGEM="AUTO"
             atualizar_lista
             ( trap 'kill $SP 2>/dev/null; exit 0' TERM
               while true; do
                 sleep $((INTERVAL * 60)) & SP=$!; wait $SP
                 backup_automatico         # waits while the character is in danger
               done ) &
             LOOP_PID=$!
             # Heartbeat for the mod + serves the backup key (every 1 s)
             ( trap 'kill $SP 2>/dev/null; exit 0' TERM
               while true; do
                 printf '%s\n%s\n' "$(date +%s)" "$VERSION" > "$ATIVO"
                 if [ -f "$PEDIDO" ]; then
                   NOTA=$(sed -n 's/^nota=//p' "$PEDIDO" | head -n1 | tr -d '\r')
                   rm -f "$PEDIDO"
                   ORIGEM="MOD"; fazer_backup "$NOTA"
                 fi
                 registrar_morte
                 [ -f "$LUA_DIR/pzbackup_fixar.txt" ] && { ORIGEM="MOD"; processar_fixar; }
                 sleep 1 & SP=$!; wait $SP
               done ) &
             MOD_PID=$!
             avisar "$(msg "Jogo iniciado — PZ Backup $VERSION, backup automático a cada $INTERVAL min" "Game started — PZ Backup $VERSION, automatic backup every $INTERVAL min")"
             "$@"; RC=$?                   # runs the game and waits for it to close
             # Stops the loops (each kills its own "sleep" on TERM)
             kill "$LOOP_PID" "$MOD_PID" 2>/dev/null
             wait "$LOOP_PID" "$MOD_PID" 2>/dev/null
             rm -f "$ATIVO"

             registrar_morte
             # Restore requested from the mod window: restore and relaunch the game
             if [ -f "$PEDIDO_RESTAURO" ]; then
               NOME=$(head -n1 "$PEDIDO_RESTAURO" | tr -d '\r')
               rm -f "$PEDIDO_RESTAURO"
               # "AUTO mode/world" (death with auto-restore): that world's last SAFE backup
               # (not bitten, not within the death margin)
               if [ "${NOME#AUTO }" != "$NOME" ]; then
                 ALVO=${NOME#AUTO }
                 MORTE=$(sed -n 3p "$LUA_DIR/pzbackup_estado.txt" 2>/dev/null | tr -d '\r')
                 case "$MORTE" in *[!0-9]*) MORTE="" ;; esac
                 PULOS=$(mktemp)
                 NOME=$(backup_seguro "$ALVO" "$MORTE" 2> "$PULOS")
                 read -r PM PP < "$PULOS"; rm -f "$PULOS"
                 ORIGEM="RESTAURO"
                 if [ -z "$NOME" ]; then
                   avisar "$(msg "Sem backup de ${ALVO#*/} para restaurar automaticamente" "No backup of ${ALVO#*/} to auto-restore")" erro
                 elif [ "${PM:-0}" -gt 0 ] || [ "${PP:-0}" -gt 0 ]; then
                   avisar "$(msg "Restauração automática: pulei ${PM:-0} backup(s) mordido(s) e ${PP:-0} feito(s) a menos de $(margem_morte) s da morte" "Auto-restore: skipped ${PM:-0} bitten backup(s) and ${PP:-0} taken less than $(margem_morte) s before the death")"
                 fi
               fi
               sleep 3                     # let the game finish writing
               ORIGEM="RESTAURO"
               if [ -n "$NOME" ] && restaurar_nome "$NOME"; then
                 avisar "$(msg "Reabrindo o jogo com o backup restaurado. Confira os mods do save ao carregar (reative/desative)" "Reopening the game with the restored backup. Check the save's mods when loading (re-enable/disable)")"
                 continue
               fi
             fi
             ORIGEM="FINAL"; fazer_backup  # final backup, game already closed (skipped if it closed in danger)
             ORIGEM="LIMPEZA"; limpar_mortos # remove dead-character saves (if the option is on)
             exit $RC
           done ;;
  restore) ORIGEM="RESTAURO"; restaurar "$2" ;;
  note|nota)
           ALVO=$(backups_ordenados | sed -n "${2:-0}p")
           [ -z "$ALVO" ] && { msg "Uso: $0 note N \"texto\" (número da lista: $0 list)" "Usage: $0 note N \"text\" (number from: $0 list)"; echo; exit 1; }
           ORIGEM="MANUAL"; anotar "$(basename "$ALVO")" "${3:-}" ;;
  pin|unpin)
           ALVO=$(backups_ordenados | sed -n "${2:-0}p")
           [ -z "$ALVO" ] && { msg "Uso: $0 $1 N (número da lista: $0 list)" "Usage: $0 $1 N (number from: $0 list)"; echo; exit 1; }
           ORIGEM="MANUAL"; fixar "$(basename "$ALVO")" "$1" ;;
  *)       sed -n '2,23p' "$0" ;;
esac
