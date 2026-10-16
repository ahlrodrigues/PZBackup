#!/bin/bash
# pz-backup.sh — Backup periódico e manual do save do Project Zomboid (Linux)
#
# Requisitos: bash. Recomendado: python3 (bipes e checagem de morte pelo players.db)
#             e paplay/pw-play/aplay (som). Sem python3 o backup funciona normalmente.
#
# Uso:
#   pz-backup.sh save      -> faz um backup agora (ligue a um atalho de teclado)
#   pz-backup.sh loop      -> faz backup a cada INTERVALO minutos (deixe rodando)
#   pz-backup.sh list      -> lista os backups existentes
#   pz-backup.sh restore   -> restaura o backup mais recente (com o jogo FECHADO)
#   pz-backup.sh restore N -> restaura o N-ésimo backup da lista (1 = mais recente)
#   pz-backup.sh limpar    -> remove agora os saves de personagem morto (jogo FECHADO)
#   pz-backup.sh jogo %command% -> para as Opções de Inicialização da Steam:
#                     liga o backup automático junto com o jogo e desliga ao fechar
#                     (também atende a tecla do mod PZ Backup, se instalado)

INTERVALO=5                               # minutos entre backups automáticos
MANTER=10                                 # quantos backups manter (por mundo)
MANTER_SUBST=5                            # quantos saves substituídos manter (no total)
APAGAR_MORTOS=""                          # saves de personagem morto ao fechar o jogo:
                                          #   vazio = segue a opção do mod (padrão: ligado)
                                          #   1 = sempre remove, 0 = nunca remove
# Pasta do jogo: detecta Steam nativa ou Steam Flatpak automaticamente.
# (Dentro do Flatpak o $HOME já aponta para ~/.var/app/com.valvesoftware.Steam,
#  então o mesmo script funciona dentro da Steam e no atalho de teclado.)
FLATPAK_HOME="$HOME/.var/app/com.valvesoftware.Steam"
BASE="$HOME/Zomboid"; SAVES="$BASE/Saves"
for b in "$HOME/Zomboid" "$FLATPAK_HOME/Zomboid"; do
  for s in Saves saves; do                # aceita "Saves" ou "saves"
    if [ -d "$b/$s" ]; then BASE="$b"; SAVES="$b/$s"; break 2; fi
  done
done
DESTINO="$BASE/BackupsSaves"              # onde os backups ficam

SOM=1                                     # 1 = toca som ao salvar/restaurar, 0 = silencioso
SOM_OK=""                                 # opcional: seu próprio .wav de sucesso
SOM_ERRO=""                               # opcional: seu próprio .wav de erro

mkdir -p "$DESTINO"
LUA_DIR="$BASE/Lua"                       # pasta onde o mod PZ Backup troca mensagens
ORIGEM="MANUAL"                           # marcação no log: MANUAL, MOD, AUTO, FINAL, RESTAURO

# Gera os bipes (.wav) uma única vez, sem depender de programas extras além do python3
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
            env = min(1, i / 400, (n - i) / 400)          # evita estalos
            v = 0.45 * env * math.sin(2 * math.pi * freq * i / taxa) if freq else 0
            dados += struct.pack("<h", int(v * 32767))
    with wave.open(arq, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(taxa); w.writeframes(dados)
d = sys.argv[1]
bipes(f"{d}/ok.wav",   [(880, .09), (0, .05), (1320, .14)])    # dois bipes subindo
bipes(f"{d}/erro.wav", [(330, .18), (0, .06), (220, .30)])     # dois bipes descendo
PY
}

tocar() {
  [ "$SOM" = 1 ] || return 0
  local arq
  if [ "$1" = erro ]; then arq=${SOM_ERRO:-$DESTINO/.sons/erro.wav}; else arq=${SOM_OK:-$DESTINO/.sons/ok.wav}; fi
  [ -f "$arq" ] || gerar_bipes
  [ -f "$arq" ] || { printf '\a'; return; }
  if   command -v paplay >/dev/null; then paplay "$arq" 2>/dev/null &
  elif command -v pw-play >/dev/null; then pw-play "$arq" 2>/dev/null &
  elif command -v aplay  >/dev/null; then aplay -q "$arq" 2>/dev/null &
  elif command -v flatpak-spawn >/dev/null; then
    # Dentro do Flatpak: toca o som pelo sistema (precisa da permissão do README)
    ( flatpak-spawn --host paplay "$arq" 2>/dev/null || flatpak-spawn --host aplay -q "$arq" 2>/dev/null ) &
  else printf '\a'                        # último recurso: bipe do terminal
  fi
}

# Remove acentos do texto mostrado dentro do jogo (a fonte do jogo pode não ter)
sem_acento() {
  # substituição byte a byte: funciona em qualquer localidade (não depende de UTF-8)
  LC_ALL=C sed 's/á/a/g; s/à/a/g; s/â/a/g; s/ã/a/g; s/ä/a/g; s/é/e/g; s/è/e/g; s/ê/e/g; s/ë/e/g; s/í/i/g; s/ì/i/g; s/î/i/g; s/ï/i/g; s/ó/o/g; s/ò/o/g; s/ô/o/g; s/õ/o/g; s/ö/o/g; s/ú/u/g; s/ù/u/g; s/û/u/g; s/ü/u/g; s/ç/c/g; s/ñ/n/g; s/Á/A/g; s/À/A/g; s/Â/A/g; s/Ã/A/g; s/Ä/A/g; s/É/E/g; s/È/E/g; s/Ê/E/g; s/Ë/E/g; s/Í/I/g; s/Ì/I/g; s/Î/I/g; s/Ï/I/g; s/Ó/O/g; s/Ò/O/g; s/Ô/O/g; s/Õ/O/g; s/Ö/O/g; s/Ú/U/g; s/Ù/U/g; s/Û/U/g; s/Ü/U/g; s/Ç/C/g; s/Ñ/N/g; s/—/-/g'
}

# avisar "mensagem" [erro]
avisar() {
  echo "$1"
  printf '%s  %-10s %s\n' "$(date '+%d/%m %H:%M:%S')" "[$ORIGEM]" "$1" >> "$DESTINO/pz-backup.log"
  tocar "${2:-ok}"
  # Repassa o resultado para o mod mostrar na tela do jogo
  [ -d "$LUA_DIR" ] && printf '%s|%s|%s\n' "$(date +%s%N)" "${2:-ok}" "[$ORIGEM] $1" | sem_acento > "$LUA_DIR/pzbackup_status.txt"
  command -v notify-send >/dev/null && notify-send "Project Zomboid" "$1"
  return 0
}

# Save em uso = pasta de mundo modificada mais recentemente (Saves/<modo>/<mundo>)
save_atual() {
  ls -dt "$SAVES"/*/*/ 2>/dev/null | head -n1 | sed 's:/$::'
}

# Verifica no players.db do save se o personagem está morto.
# Procura qualquer tabela com a coluna isDead (formato usado pelo jogo).
# Saída: "morto", "vivo" ou "desconhecido" (se não der para ler, o backup segue normal).
estado_personagem() {
  # 1) Aviso do mod PZ Backup (só vale se atualizado nas últimas 12 h)
  local est="$LUA_DIR/pzbackup_estado.txt"
  if [ -f "$est" ] && [ -n "$(find "$est" -mmin -720 2>/dev/null)" ]; then
    grep -q '^morto' "$est" && { echo morto; return; }
  fi
  # 2) Leitura direta do players.db
  estado_db "$1"
}

# Só o players.db (sem o aviso do mod): "morto" se TODOS os personagens do save
# estão mortos, "vivo" se algum está vivo, "desconhecido" se não der para ler
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
  [ -z "$origem" ] && { avisar "Nenhum save encontrado em $SAVES" erro; return 1; }

  # Não salva por cima dos backups bons se o personagem morreu
  if [ "$(estado_personagem "$origem")" = morto ]; then
    avisar "Personagem MORTO em $(basename "$origem") — backup NÃO feito. Use: pz-backup.sh restore" erro
    return 2
  fi

  local modo mundo carimbo alvo
  modo=$(basename "$(dirname "$origem")")
  mundo=$(basename "$origem")
  carimbo=$(date +%Y-%m-%d_%H-%M-%S)
  alvo="$DESTINO/${modo}__${mundo}__${carimbo}"
  [ -e "$alvo" ] && alvo="${alvo}-$$"     # dois backups no mesmo segundo

  if cp -a "$origem" "$alvo" && touch "$alvo"; then
    avisar "Backup feito: $mundo ($carimbo)"
  else
    avisar "FALHA no backup de $mundo" erro; return 1
  fi

  # Mantém só os MANTER mais recentes deste mundo
  # (uma linha por pasta: funciona com espaços no nome do mundo)
  ls -d "$DESTINO/${modo}__${mundo}__"* 2>/dev/null | sort -r | tail -n +$((MANTER + 1)) |
    while IFS= read -r velho; do rm -rf -- "$velho"; done
  atualizar_lista
}

# Lista backups do mais recente para o mais antigo (ordena pela data no nome)
backups_ordenados() {
  for d in "$DESTINO"/*__*__*; do
    [ -d "$d" ] && echo "${d##*__}|$d"
  done | sort -r | cut -d'|' -f2-
}

listar() {
  backups_ordenados | nl -w2 -s'  ' | sed "s:$DESTINO/::"
}

# Gera Zomboid/Lua/pzbackup_lista.txt para a janela de restauração do mod
# Formato: nome|rótulo  (ex.: Survivor__Mundo__2026-10-14_14-35-07|14/10 14:35:07  -  Mundo)
atualizar_lista() {
  [ -d "$LUA_DIR" ] || return 0
  local d nome data mundo tmp="$LUA_DIR/.pzbackup_lista.tmp"
  backups_ordenados | while read -r d; do
    nome=$(basename "$d")
    mundo=${nome#*__}; mundo=${mundo%__*}
    # 2026-10-14_14-35-07 -> 14/10 14:35:07
    data=$(echo "${nome##*__}" | sed -E 's/^([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2})-([0-9]{2})-([0-9]{2}).*/\3\/\2 \4:\5:\6/')
    # o nome (antes do "|") fica intacto; só o rótulo exibido perde acentos
    echo "$nome|$(echo "$data  -  $mundo" | sem_acento)"
  done > "$tmp" && mv -f "$tmp" "$LUA_DIR/pzbackup_lista.txt"
}

# Jogo aberto? (executável do Linux ou classe principal do Java do jogo)
jogo_aberto() {
  pgrep -f '(^|/)ProjectZomboid(64|32)?( |$)|^[^ ]*java .*zombie\.gameStates\.MainScreenState' >/dev/null 2>&1
}

# Mantém só os MANTER_SUBST saves substituídos mais recentes (pela data no nome)
limpar_substituidos() {
  local dir="$DESTINO/substituidos" d
  [ -d "$dir" ] || return 0
  for d in "$dir"/*__*__*; do
    [ -d "$d" ] && echo "${d##*__}|$d"
  done | sort -r | cut -d'|' -f2- | tail -n +$((MANTER_SUBST + 1)) |
    while IFS= read -r d; do rm -rf -- "$d"; done
}

# A opção "remover saves de personagem morto" está ligada?
apagar_mortos_ativo() {
  case "$APAGAR_MORTOS" in 1) return 0 ;; 0) return 1 ;; esac
  local cfg="$LUA_DIR/pzbackup_config.txt"
  [ -f "$cfg" ] || return 1               # sem o mod: não remove nada
  grep -q '^apagar_mortos=1' "$cfg"
}

# Remove da pasta Saves os mundos onde o personagem morreu (só com o jogo FECHADO).
# O save não é apagado na hora: vai para BackupsSaves/substituidos (os 5 mais recentes ficam).
# Decide por mundo:
#   - players.db diz "morto"                         -> remove
#   - players.db diz "vivo"                          -> mantém (ex.: personagem novo no mesmo mundo)
#   - players.db ilegível e o mod avisou morte nele   -> remove
limpar_mortos() {
  apagar_mortos_ativo || return 0
  local est="$LUA_DIR/pzbackup_estado.txt" mundo_mod="" w modo mundo estado n=0
  if [ -f "$est" ] && head -n1 "$est" | grep -q '^morto'; then
    mundo_mod=$(sed -n 2p "$est" | tr -d '\r')
  fi
  mkdir -p "$DESTINO/substituidos"
  for w in "$SAVES"/*/*/; do
    w=${w%/}; [ -d "$w" ] || continue
    modo=$(basename "$(dirname "$w")"); mundo=$(basename "$w")
    [ "$modo" = Multiplayer ] && continue  # saves de servidor: nunca mexe
    estado=$(estado_db "$w")
    if [ "$estado" = morto ] || { [ "$estado" = desconhecido ] && [ -n "$mundo_mod" ] &&
         { [ "$mundo_mod" = "$modo/$mundo" ] || [ "$mundo_mod" = "/$mundo" ]; }; }; then
      mv "$w" "$DESTINO/substituidos/${modo}__${mundo}__$(date +%Y-%m-%d_%H-%M-%S)" &&
        { avisar "Save de personagem morto removido de Carregar: $mundo (guardado em substituidos)"; n=$((n+1)); }
    fi
  done
  [ -n "$mundo_mod" ] && printf 'limpo\n%s\n' "$mundo_mod" > "$est"   # aviso já tratado
  [ $n -gt 0 ] && limpar_substituidos
  return 0
}

# Núcleo da restauração: recebe o NOME do backup (sem perguntar nada)
restaurar_nome() {
  local nome="$1" escolhido="$DESTINO/$1"
  [ -n "$nome" ] && [ -d "$escolhido" ] || { avisar "Backup não encontrado: $nome" erro; return 1; }

  local modo mundo destino_save
  modo=${nome%%__*}
  mundo=${nome#*__}; mundo=${mundo%__*}
  destino_save="$SAVES/$modo/$mundo"

  # Guarda o save atual (ex.: personagem morto) em vez de apagar
  # (fica fora da pasta Saves para não aparecer na lista de saves do jogo)
  mkdir -p "$DESTINO/substituidos" "$SAVES/$modo"
  [ -d "$destino_save" ] && mv "$destino_save" "$DESTINO/substituidos/${modo}__${mundo}__$(date +%Y-%m-%d_%H-%M-%S)"
  limpar_substituidos
  if cp -a "$escolhido" "$destino_save"; then
    touch "$destino_save"                 # vira o save mais recente (topo da lista do jogo)
    # O estado "morto" era do save antigo: não pode valer para o restaurado
    [ -d "$LUA_DIR" ] && printf 'restaurado\n%s/%s\n' "$modo" "$mundo" > "$LUA_DIR/pzbackup_estado.txt"
    avisar "Save restaurado: $nome"
  else
    avisar "FALHA ao restaurar $nome" erro; return 1
  fi
}

# Lembrete exibido após cada restauração
aviso_mods() {
  cat <<'TXT'

ATENÇÃO: o save restaurado volta com a lista de mods de quando o backup foi feito.
Ao carregar, confira em Carregar > (seu save) > Mods: reative o PZ Backup e os mods
que você usa, e desative os que não quiser. Se um mod não responder, desative e reative.
TXT
}

# Restauração pelo terminal: escolhe pelo número da lista e pede confirmação
restaurar() {
  # O jogo só lê a lista de saves ao abrir: restaurar com ele aberto
  # faz o save não aparecer em "Carregar" até reiniciar o jogo.
  if jogo_aberto; then
    avisar "Feche o Project Zomboid antes de restaurar (o jogo só lê a lista de saves ao abrir)" erro
    return 1
  fi

  local n="${1:-1}" escolhido nome
  escolhido=$(backups_ordenados | sed -n "${n}p")
  [ -z "$escolhido" ] && { echo "Backup $n não encontrado."; return 1; }
  nome=$(basename "$escolhido")

  echo "Restaurar: $nome"
  echo "Em:        $SAVES/${nome%%__*}/$(n=${nome#*__}; echo "${n%__*}")"
  read -rp "Confirmar restauração? (s/N): " ok
  [ "$ok" != "s" ] && { echo "Cancelado."; return 1; }
  restaurar_nome "$nome" && { echo "Pode abrir o jogo."; aviso_mods; }
}

case "$1" in
  save)    ORIGEM="MANUAL"; fazer_backup ;;
  loop)    ORIGEM="AUTO"; avisar "Backup automático a cada $INTERVALO min (Ctrl+C para parar)"
           while true; do sleep $((INTERVALO * 60)); fazer_backup; done ;;
  list)    listar ;;
  limpar)  if jogo_aberto; then avisar "Feche o Project Zomboid antes de limpar" erro; exit 1; fi
           ORIGEM="LIMPEZA"; APAGAR_MORTOS=1; limpar_mortos ;;
  jogo)    shift
           [ $# -eq 0 ] && { echo "Uso na Steam: $0 jogo %command%"; exit 1; }
           mkdir -p "$LUA_DIR"
           PEDIDO="$LUA_DIR/pzbackup_pedido.txt"
           PEDIDO_RESTAURO="$LUA_DIR/pzbackup_restaurar.txt"
           ATIVO="$LUA_DIR/pzbackup_ativo.txt"
           rm -f "$PEDIDO" "$PEDIDO_RESTAURO"
           while true; do
             ORIGEM="AUTO"
             atualizar_lista
             ( trap 'kill $SP 2>/dev/null; exit 0' TERM
               while true; do
                 sleep $((INTERVALO * 60)) & SP=$!; wait $SP
                 fazer_backup
               done ) &
             LOOP_PID=$!
             # Sinal de vida para o mod + atende a tecla de backup (a cada 1 s)
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
             avisar "Jogo iniciado — backup automático a cada $INTERVALO min"
             "$@"; RC=$?                   # roda o jogo e espera ele fechar
             # Encerra os laços (cada um mata o próprio "sleep" ao receber TERM)
             kill "$LOOP_PID" "$MOD_PID" 2>/dev/null
             wait "$LOOP_PID" "$MOD_PID" 2>/dev/null
             rm -f "$ATIVO"

             # Restauração pedida pela janela do mod: restaura e reabre o jogo
             if [ -f "$PEDIDO_RESTAURO" ]; then
               NOME=$(head -n1 "$PEDIDO_RESTAURO" | tr -d '\r')
               rm -f "$PEDIDO_RESTAURO"
               # "AUTO modo/mundo" (morte com restauração automática): backup mais recente desse mundo
               if [ "${NOME#AUTO }" != "$NOME" ]; then
                 ALVO=${NOME#AUTO }
                 NOME=$(ls -d "$DESTINO/${ALVO%%/*}__${ALVO#*/}__"* 2>/dev/null | sort -r | head -n1)
                 NOME=${NOME##*/}
                 [ -z "$NOME" ] && { ORIGEM="RESTAURO"; avisar "Sem backup de ${ALVO#*/} para restaurar automaticamente" erro; }
               fi
               sleep 3                     # deixa o jogo terminar de gravar
               ORIGEM="RESTAURO"
               if [ -n "$NOME" ] && restaurar_nome "$NOME"; then
                 avisar "Reabrindo o jogo com o backup restaurado. Confira os mods do save ao carregar (reative/desative)"
                 continue
               fi
             fi
             ORIGEM="FINAL"; fazer_backup  # backup final, com o jogo já fechado
             ORIGEM="LIMPEZA"; limpar_mortos # remove saves de personagem morto (se a opção estiver ligada)
             exit $RC
           done ;;
  restore) ORIGEM="RESTAURO"; restaurar "$2" ;;
  *)       sed -n '2,17p' "$0" ;;
esac
