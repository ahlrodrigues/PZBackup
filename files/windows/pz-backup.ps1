# pz-backup.ps1 — automatic and manual save backups for Project Zomboid (Windows)
# Version 1.3.0 — https://github.com/ahlrodrigues/PZBackup — MIT License
#
# Usage (PowerShell):
#   pz-backup.ps1 save        -> back up now
#   pz-backup.ps1 loop        -> back up every $Interval minutes (keep the window open)
#   pz-backup.ps1 list        -> list existing backups
#   pz-backup.ps1 restore     -> restore the most recent backup (game CLOSED)
#   pz-backup.ps1 restore N   -> restore backup number N from the list (1 = newest)
#   pz-backup.ps1 game        -> starts the game through Steam, backs up while it's open,
#                                serves the mod's keys and takes a final backup on exit
#   pz-backup.ps1 choose      -> shows the list and asks which backup to restore
#   pz-backup.ps1 clean       -> remove dead-character saves now (game CLOSED)
#   pz-backup.ps1 log         -> show the last log lines
#   Older Portuguese action names still work: jogo = game, escolher = choose, limpar = clean.

param([string]$Acao = "", [int]$Numero = 1)

# ---------------- Settings ----------------
$Interval     = 5                                # minutes between automatic backups
$Keep         = 10                               # backups kept per world
$KeepReplaced = 5                                # replaced saves kept (in total)
$RemoveDead   = ""                               # dead-character saves when the game closes:
                                                 #   "" = follow the mod option (default: on)
                                                 #   "1" = always remove, "0" = never remove
$Sound        = $true                            # $false = silent
$Language     = ""                               # messages: "" = follow the mod's Language option; "pt" or "en"
# ------------------------------------------
$SteamAppId = 108600                             # Project Zomboid on Steam
$Processos = @("ProjectZomboid64", "ProjectZomboid32", "ProjectZomboid")

$Base = Join-Path $env:USERPROFILE "Zomboid"
$Saves = Join-Path $Base "Saves"
$Destino = Join-Path $Base "BackupsSaves"
$LuaDir = Join-Path $Base "Lua"
$Log = Join-Path $Destino "pz-backup.log"
$script:Origem = "MANUAL"
$Utf8 = New-Object System.Text.UTF8Encoding($false)   # UTF-8 without BOM (easier for Lua)

New-Item -ItemType Directory -Force -Path $Destino | Out-Null
$Subst = Join-Path $Destino "replaced"           # saves replaced by a restore or removed by cleanup
# Migration: older versions used the "substituidos" folder
$antigo = Join-Path $Destino "substituidos"
if ((Test-Path $antigo) -and -not (Test-Path $Subst)) { Move-Item $antigo $Subst }

function Tocar([string]$Tipo) {
    if (-not $Sound) { return }
    try {
        if ($Tipo -eq "erro") { [System.Media.SystemSounds]::Hand.Play() }
        else { [System.Media.SystemSounds]::Asterisk.Play() }
    } catch { }
}

# Strips accents from text shown in game (the game font may lack them)
function Sem-Acento([string]$t) {
    ($t.Normalize([Text.NormalizationForm]::FormD).ToCharArray() |
        Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' }) -join ''
}

# Message language: follows the mod's Language option (Automatic = game language);
# the mod writes the result, idioma=pt|en, into pzbackup_config.txt
function Idioma-Atual {
    if ($Language) { return $Language }
    $cfg = Join-Path $LuaDir "pzbackup_config.txt"
    if (Test-Path $cfg) {
        if (Select-String -Path $cfg -Pattern '^idioma=en' -Quiet) { return "en" }
        if (Select-String -Path $cfg -Pattern '^idioma=pt' -Quiet) { return "pt" }
    }
    return "en"                                  # default: English
}
# Msg "Portuguese text" "English text"
function Msg([string]$Pt, [string]$En) { if ((Idioma-Atual) -eq "en") { $En } else { $Pt } }

# Copies the last log lines to Zomboid\Lua (the mod can only read files there)
function Espelhar-Log {
    if (-not (Test-Path $LuaDir) -or -not (Test-Path $Log)) { return }
    $ultimas = Get-Content $Log -Tail 150 -Encoding UTF8 | ForEach-Object { Sem-Acento $_ }
    [IO.File]::WriteAllText((Join-Path $LuaDir "pzbackup_log.txt"), (($ultimas -join "`n") + "`n"), $Utf8)
}

function Avisar([string]$Msg, [string]$Tipo = "ok") {
    $rot = $script:Origem                        # tag in the message language
    if ((Idioma-Atual) -eq "en") {
        if ($rot -eq "RESTAURO") { $rot = "RESTORE" } elseif ($rot -eq "LIMPEZA") { $rot = "CLEANUP" }
    }
    Write-Host $Msg
    $linha = "{0}  {1,-10} {2}" -f (Get-Date -Format "dd/MM HH:mm:ss"), "[$rot]", $Msg
    [IO.File]::AppendAllText($Log, $linha + "`r`n", $Utf8)
    Espelhar-Log
    Tocar $Tipo
    # Hands the result to the mod to show on screen
    if (Test-Path $LuaDir) {
        $id = [DateTime]::UtcNow.Ticks
        [IO.File]::WriteAllText((Join-Path $LuaDir "pzbackup_status.txt"),
            (Sem-Acento "$id|$Tipo|[$rot] $Msg") + "`n", $Utf8)
    }
}

# Current save = most recently modified world folder (Saves\<mode>\<world>)
function Save-Atual {
    if (-not (Test-Path $Saves)) { return $null }
    Get-ChildItem $Saves -Directory | ForEach-Object { Get-ChildItem $_.FullName -Directory } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

# On Windows, death detection relies on the PZ Backup mod
# (the notice is only valid if updated in the last 12 h)
function Estado-Personagem {
    $est = Join-Path $LuaDir "pzbackup_estado.txt"
    if ((Test-Path $est) -and ((Get-Item $est).LastWriteTime -gt (Get-Date).AddHours(-12))) {
        if ((Get-Content $est -TotalCount 1) -match "^morto") { return "morto" }
        return "vivo"
    }
    return "desconhecido"
}

function Fazer-Backup {
    $origem = Save-Atual
    if (-not $origem) { Avisar (Msg "Nenhum save encontrado em $Saves" "No save found in $Saves") "erro"; return }

    $modo = $origem.Parent.Name
    $mundo = $origem.Name
    if ((Estado-Personagem) -eq "morto") {
        Avisar (Msg "Personagem MORTO em $mundo - backup NAO feito. F9 ou o atalho Restaurar" "Character is DEAD in $mundo - backup NOT taken. F9 or the Restore shortcut") "erro"
        return
    }

    $carimbo = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $alvo = Join-Path $Destino "${modo}__${mundo}__${carimbo}"
    if (Test-Path $alvo) { $alvo = "$alvo-$PID" }
    try {
        Copy-Item $origem.FullName $alvo -Recurse -ErrorAction Stop
        (Get-Item $alvo).LastWriteTime = Get-Date
        Avisar (Msg "Backup feito: $mundo ($carimbo)" "Backup done: $mundo ($carimbo)")
    } catch {
        Avisar (Msg "FALHA no backup de ${mundo}: $($_.Exception.Message)" "Backup FAILED for ${mundo}: $($_.Exception.Message)") "erro"; return
    }

    # Keep only the $Keep newest for this world
    Get-ChildItem $Destino -Directory -Filter "${modo}__${mundo}__*" |
        Sort-Object Name -Descending | Select-Object -Skip $Keep |
        Remove-Item -Recurse -Force
    Atualizar-Lista
}

# Backups newest first (sorted by the date in the name)
function Backups-Ordenados {
    Get-ChildItem $Destino -Directory | Where-Object { $_.Name -like "*__*__*" } |
        Sort-Object { ($_.Name -split "__")[-1] } -Descending
}

# Writes Zomboid\Lua\pzbackup_lista.txt for the mod's restore window
# Format: name|label  (e.g. Survivor__World__2026-10-14_14-35-07|14/10 14:35:07  -  World)
function Atualizar-Lista {
    if (-not (Test-Path $LuaDir)) { return }
    $linhas = foreach ($b in Backups-Ordenados) {
        $partes = $b.Name -split "__"
        $mundo = ($partes[1..($partes.Count - 2)] -join "__")
        $rotulo = $partes[-1]
        if ($partes[-1] -match '^(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})') {
            $rotulo = "{0}/{1} {2}:{3}:{4}" -f $Matches[3], $Matches[2], $Matches[4], $Matches[5], $Matches[6]
        }
        "$($b.Name)|" + (Sem-Acento "$rotulo  -  $mundo")
    }
    $texto = if ($linhas) { ($linhas -join "`n") + "`n" } else { "" }
    [IO.File]::WriteAllText((Join-Path $LuaDir "pzbackup_lista.txt"), $texto, $Utf8)
}

function Listar {
    $i = 1
    foreach ($b in Backups-Ordenados) { "{0,2}  {1}" -f $i, $b.Name; $i++ }
}

# Is the "remove dead-character saves" option on?
function Apagar-Mortos-Ativo {
    if ($RemoveDead -eq "1") { return $true }
    if ($RemoveDead -eq "0") { return $false }
    $cfg = Join-Path $LuaDir "pzbackup_config.txt"
    if (-not (Test-Path $cfg)) { return $false }          # no mod: remove nothing
    return [bool](Select-String -Path $cfg -Pattern '^apagar_mortos=1' -Quiet)
}

# Removes the world where the character died from the Saves folder (game CLOSED only).
# On Windows the info comes from the mod (pzbackup_estado.txt: "morto" + mode/world).
# The save isn't deleted right away: it goes to BackupsSaves\replaced (the 5 newest are kept).
function Limpar-Mortos {
    if (-not (Apagar-Mortos-Ativo)) { return }
    $est = Join-Path $LuaDir "pzbackup_estado.txt"
    if (-not (Test-Path $est)) { return }
    $linhas = @(Get-Content $est -TotalCount 2)
    if ($linhas.Count -lt 2 -or $linhas[0] -notmatch '^morto') { return }
    $alvo = $linhas[1].Trim()
    $partes = $alvo -split '/', 2
    $modo = $partes[0]; $mundo = $partes[1]
    if (-not $mundo -or $modo -eq "Multiplayer") { return }

    $candidatos = if ($modo) { @(Join-Path (Join-Path $Saves $modo) $mundo) }
                  else { @(Get-ChildItem $Saves -Directory | ForEach-Object { Join-Path $_.FullName $mundo }) }
    $subst = $Subst
    New-Item -ItemType Directory -Force -Path $subst | Out-Null
    foreach ($w in $candidatos) {
        if (-not (Test-Path $w)) { continue }
        $m = Split-Path (Split-Path $w -Parent) -Leaf
        Move-Item $w (Join-Path $subst "${m}__${mundo}__$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')")
        Avisar (Msg "Save de personagem morto removido de Carregar: $mundo (guardado em replaced)" "Dead character's save removed from Load: $mundo (kept in replaced)")
    }
    [IO.File]::WriteAllText($est, "limpo`n$alvo`n", $Utf8)    # notice handled
    Get-ChildItem $subst -Directory | Where-Object { $_.Name -like "*__*__*" } |
        Sort-Object { ($_.Name -split "__")[-1] } -Descending | Select-Object -Skip $KeepReplaced |
        Remove-Item -Recurse -Force
}

# Restore core: takes the backup NAME (asks nothing)
function Restaurar-Nome([string]$Nome) {
    $escolhido = Join-Path $Destino $Nome
    if (-not $Nome -or -not (Test-Path $escolhido)) { Avisar (Msg "Backup nao encontrado: $Nome" "Backup not found: $Nome") "erro"; return $false }
    $partes = $Nome -split "__"
    $modo = $partes[0]
    $mundo = ($partes[1..($partes.Count - 2)] -join "__")
    $destinoSave = Join-Path (Join-Path $Saves $modo) $mundo

    # Keep the current save (e.g. dead character) instead of deleting it
    $subst = $Subst
    New-Item -ItemType Directory -Force -Path $subst | Out-Null
    if (Test-Path $destinoSave) {
        Move-Item $destinoSave (Join-Path $subst "${modo}__${mundo}__$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')")
    }
    # Keep only the $KeepReplaced newest replaced saves (by the date in the name)
    Get-ChildItem $subst -Directory | Where-Object { $_.Name -like "*__*__*" } |
        Sort-Object { ($_.Name -split "__")[-1] } -Descending | Select-Object -Skip $KeepReplaced |
        Remove-Item -Recurse -Force
    New-Item -ItemType Directory -Force -Path (Split-Path $destinoSave) | Out-Null
    try {
        Copy-Item $escolhido $destinoSave -Recurse -ErrorAction Stop
        (Get-Item $destinoSave).LastWriteTime = Get-Date   # becomes the newest save
        # The "morto" state belonged to the old save, not the restored one
        if (Test-Path $LuaDir) {
            [IO.File]::WriteAllText((Join-Path $LuaDir "pzbackup_estado.txt"), "restaurado`n$modo/$mundo`n", $Utf8)
        }
        Avisar (Msg "Save restaurado: $Nome" "Save restored: $Nome")
        return $true
    } catch {
        Avisar (Msg "FALHA ao restaurar ${Nome}: $($_.Exception.Message)" "Restore FAILED: ${Nome}: $($_.Exception.Message)") "erro"
        return $false
    }
}

# Restore from the shortcut/terminal: pick by number and confirm
function Restaurar([int]$N) {
    # The game reads the save list only on startup: restoring while it's open
    # keeps the save out of "Load" until the game restarts.
    if (Jogo-Aberto) {
        Avisar (Msg "Feche o Project Zomboid antes de restaurar (o jogo so le a lista de saves ao abrir)" "Close Project Zomboid before restoring (the game only reads the save list on startup)") "erro"
        return
    }
    $lista = @(Backups-Ordenados)
    if ($N -lt 1 -or $N -gt $lista.Count) { Write-Host (Msg "Backup $N nao encontrado." "Backup $N not found."); return }
    $nome = $lista[$N - 1].Name
    $partes = $nome -split "__"
    Write-Host ((Msg "Restaurar: " "Restore:   ") + $nome)
    Write-Host ((Msg "Em:        " "Into:      ") + (Join-Path (Join-Path $Saves $partes[0]) ($partes[1..($partes.Count - 2)] -join "__")))
    $ok = Read-Host (Msg "Confirmar restauracao? (s/N)" "Confirm restore? (y/N)")
    if ($ok -notmatch '^[sSyY]$') { Write-Host (Msg "Cancelado." "Cancelled."); return }
    if (Restaurar-Nome $nome) {
        Write-Host (Msg "Pode abrir o jogo." "You can start the game now.")
        Write-Host (Msg "`nATENCAO: o save restaurado volta com a lista de mods de quando o backup foi feito.`nAo carregar, confira em Carregar > (seu save) > Mods: reative o PZ Backup e os mods`nque voce usa, e desative os que nao quiser. Se um mod nao responder, desative e reative." "`nHEADS UP: the restored save comes back with the mod list it had when the backup was taken.`nWhen loading, check Load > (your save) > Mods: re-enable PZ Backup and the mods you use,`nand disable the ones you don't want. If a mod doesn't respond, disable and re-enable it.") -ForegroundColor Yellow
    }
}

function Jogo-Aberto { [bool](Get-Process -Name $Processos -ErrorAction SilentlyContinue) }

function Esperar-Jogo {
    Write-Host (Msg "Aguardando o Project Zomboid abrir..." "Waiting for Project Zomboid to start...")
    $espera = 0
    while (-not (Jogo-Aberto)) {
        Start-Sleep 2; $espera += 2
        if ($espera -ge 180) { return $false }
    }
    return $true
}

function Modo-Jogo {
    New-Item -ItemType Directory -Force -Path $LuaDir | Out-Null
    $pedido   = Join-Path $LuaDir "pzbackup_pedido.txt"
    $restauro = Join-Path $LuaDir "pzbackup_restaurar.txt"
    $ativo    = Join-Path $LuaDir "pzbackup_ativo.txt"
    Remove-Item $pedido, $restauro -Force -ErrorAction SilentlyContinue
    Espelhar-Log

    while ($true) {
        $script:Origem = "AUTO"
        if (-not (Jogo-Aberto)) { Start-Process "steam://rungameid/$SteamAppId" }
        if (-not (Esperar-Jogo)) {
            Avisar (Msg "O jogo nao abriu em 3 minutos - backup automatico cancelado" "The game didn't start within 3 minutes - automatic backup cancelled") "erro"; return
        }
        Atualizar-Lista
        Avisar (Msg "Jogo iniciado - backup automatico a cada $Interval min" "Game started - automatic backup every $Interval min")

        $proximo = (Get-Date).AddMinutes($Interval)
        while (Jogo-Aberto) {
            # Heartbeat for the mod (Unix time in seconds)
            [IO.File]::WriteAllText($ativo, "$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())`n", $Utf8)
            if (Test-Path $pedido) {                 # mod key
                Remove-Item $pedido -Force
                $script:Origem = "MOD"; Fazer-Backup; $script:Origem = "AUTO"
            }
            if ((Get-Date) -ge $proximo) {
                Fazer-Backup
                $proximo = (Get-Date).AddMinutes($Interval)
            }
            Start-Sleep 1
        }
        Remove-Item $ativo -Force -ErrorAction SilentlyContinue
        Start-Sleep 3                                 # let the game finish writing

        # Restore requested from the mod window: restore and relaunch the game
        if (Test-Path $restauro) {
            $nome = (Get-Content $restauro -TotalCount 1).Trim()
            Remove-Item $restauro -Force
            # "AUTO mode/world" (death with auto-restore): that world's newest backup
            if ($nome -like "AUTO *") {
                $alvo = $nome.Substring(5) -split '/', 2
                $ultimo = Get-ChildItem $Destino -Directory -Filter "$($alvo[0])__$($alvo[1])__*" |
                    Sort-Object Name -Descending | Select-Object -First 1
                $nome = if ($ultimo) { $ultimo.Name } else { "" }
                if (-not $nome) { $script:Origem = "RESTAURO"; Avisar (Msg "Sem backup de $($alvo[1]) para restaurar automaticamente" "No backup of $($alvo[1]) to auto-restore") "erro" }
            }
            $script:Origem = "RESTAURO"
            if ($nome -and (Restaurar-Nome $nome)) {
                Avisar (Msg "Reabrindo o jogo com o backup restaurado. Confira os mods do save ao carregar (reative/desative)" "Reopening the game with the restored backup. Check the save's mods when loading (re-enable/disable)")
                continue
            }
        }
        $script:Origem = "FINAL"; Fazer-Backup
        $script:Origem = "LIMPEZA"; Limpar-Mortos      # if the option is on
        return
    }
}

switch ($Acao) {
    "save"    { $script:Origem = "MANUAL"; Fazer-Backup }
    "loop"    { $script:Origem = "AUTO"
                Avisar (Msg "Backup automatico a cada $Interval min (feche a janela para parar)" "Automatic backup every $Interval min (close this window to stop)")
                while ($true) { Start-Sleep ($Interval * 60); Fazer-Backup } }
    "list"    { Listar }
    "log"     { if (Test-Path $Log) { Get-Content $Log -Tail 30 -Encoding UTF8 } else { Msg "Log vazio." "Log is empty." } }
    { $_ -in "clean", "limpar" } { if (Jogo-Aberto) { Avisar (Msg "Feche o Project Zomboid antes de limpar" "Close Project Zomboid before cleaning up") "erro" }
                else { $script:Origem = "LIMPEZA"; $RemoveDead = "1"; Limpar-Mortos } }
    "restore" { $script:Origem = "RESTAURO"; Restaurar $Numero }
    { $_ -in "game", "jogo" } { Modo-Jogo }
    { $_ -in "choose", "escolher" } {             # used by the "PZ Backup - Restore" shortcut
                $script:Origem = "RESTAURO"
                Listar
                $n = Read-Host ("`n" + (Msg "Numero do backup para restaurar (Enter = cancelar)" "Backup number to restore (Enter = cancel)"))
                if ($n -match '^\d+$') { Restaurar ([int]$n) } else { Write-Host (Msg "Cancelado." "Cancelled.") }
                Read-Host ("`n" + (Msg "Pressione Enter para fechar" "Press Enter to close")) | Out-Null }
    default   { Get-Content $PSCommandPath -TotalCount 16 | Select-Object -Skip 1 }
}
