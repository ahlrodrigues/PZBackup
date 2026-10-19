# pz-backup.ps1 — automatic and manual save backups for Project Zomboid (Windows)
# Version 1.4.0 — https://github.com/ahlrodrigues/PZBackup — MIT License
#
# Usage (PowerShell):
#   pz-backup.ps1 save        -> back up now
#   pz-backup.ps1 loop        -> back up every $Interval minutes (keep the window open)
#   pz-backup.ps1 list        -> list existing backups
#   pz-backup.ps1 restore     -> restore the most recent backup (game CLOSED)
#   pz-backup.ps1 restore N   -> restore backup number N from the list (1 = newest)
#   pz-backup.ps1 pin N       -> pin backup N: never removed by the rotation
#   pz-backup.ps1 unpin N     -> unpin backup N (it goes back into the rotation)
#   pz-backup.ps1 note N "text" -> name backup N (empty text removes the note)
#   pz-backup.ps1 game       -> starts the game through Steam, backs up while it's open,
#                                serves the mod's keys and takes a final backup on exit
#   pz-backup.ps1 choose      -> shows the list and asks which backup to restore
#   pz-backup.ps1 clean       -> remove dead-character saves now (game CLOSED)
#   pz-backup.ps1 log         -> show the last log lines
#   pz-backup.ps1 version     -> show the script version
#   Older Portuguese action names still work: jogo = game, escolher = choose, limpar = clean.

param([string]$Acao = "", [int]$Numero = 1, [string]$Texto = "")

$Versao = "1.4.0"                                # updated by tools/bump-version.sh

# ---------------- Settings ----------------
$Interval     = 5                                # minutes between automatic backups
$Keep         = 10                               # newest backups kept per world (pinned ones don't count)
$KeepHourly   = 24                               # also keep 1 backup per hour of the last N hours (0 = off)
$KeepGameDays = 14                               # also keep 1 backup per in-game day, last N game days (0 = off)
$Hardlinks    = $true                            # incremental: unchanged files are hard links to the previous
                                                 #   backup (NTFS); $false = full copies
$MinFreeMB    = 1024                             # automatic backups stop below this free space (MB)
$QuietSeconds = 3                                # wait until the save hasn't changed for this long
$Verify       = $true                            # check every backup after copying (files and sizes)
$UpdateBackup = $true                            # pinned backup of every world when Steam updates the game
$DeathMargin  = ""                               # auto-restore skips backups this close to the death (s):
                                                 #   "" = follow the mod option (default 60)
$DangerWait   = ""                               # postpone automatic backups while in danger:
                                                 #   "" = follow the mod option (default on), "1" / "0"
$DangerRetry  = 20                               # seconds between tries while a backup is postponed
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
$InfoDir = Join-Path $Destino ".info"            # per-backup details (character, days, kills, mods)
$Pins = Join-Path $Destino ".pinned"             # pinned backups, one name per line
$Mortes = Join-Path $Destino ".deaths"           # recorded deaths: "mode/world|unix time" per line
$BuildIdArq = Join-Path $Destino ".buildid"      # last game build seen (Steam), for the update backup
$script:Adiado = $false
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

# ---------------- Mod options read by the script ----------------
function Conf-Mod([string]$Chave) {
    $cfg = Join-Path $LuaDir "pzbackup_config.txt"
    if (-not (Test-Path -LiteralPath $cfg)) { return "" }
    $l = Get-Content -LiteralPath $cfg -Encoding UTF8 | Where-Object { $_.StartsWith("$Chave=") } | Select-Object -First 1
    if ($l) { return $l.Substring($Chave.Length + 1).Trim() }
    return ""
}

function Margem-Morte {
    $m = if ($DeathMargin -ne "") { $DeathMargin } else { Conf-Mod "margem_morte" }
    if ($m -match '^\d+$') { return [int]$m }
    return 60
}

function Adiar-Perigo-Ativo {
    if ($DangerWait -eq "1") { return $true }
    if ($DangerWait -eq "0") { return $false }
    return ((Conf-Mod "adiar_perigo") -ne "0")
}

function Agora-Unix { [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }

# Danger reasons right now ("zumbis,panico") or $null, from pzbackup_perigo.txt
# (only trusted if written in the last 15 s)
function Perigo-Agora {
    $arq = Join-Path $LuaDir "pzbackup_perigo.txt"
    if (-not (Test-Path -LiteralPath $arq)) { return $null }
    $p = ((Get-Content -LiteralPath $arq -TotalCount 1) -as [string]).Trim() -split '\|'
    if ($p.Count -lt 3 -or $p[0] -ne "1" -or $p[2] -notmatch '^\d+$') { return $null }
    if ((Agora-Unix) - [long]$p[2] -gt 15) { return $null }
    return $p[1]
}

function Texto-Perigo([string]$Codigos) {
    $nomes = @{
        zumbis    = (Msg "zumbis perto" "zombies close"); panico = (Msg "panico alto" "high panic")
        sangrando = (Msg "sangrando" "bleeding");        fogo   = (Msg "pegando fogo" "on fire")
        saude     = (Msg "pouca saude" "low health")
    }
    (($Codigos -split ',') | Where-Object { $_ } | ForEach-Object { if ($nomes[$_]) { $nomes[$_] } else { $_ } }) -join ", "
}

# Unix time of a backup, from the date in its name (local time)
function Backup-Epoch([string]$Nome) {
    $c = ($Nome -split "__")[-1]
    if ($c.Length -lt 19) { return 0 }
    try {
        $dt = [DateTime]::ParseExact($c.Substring(0, 19), "yyyy-MM-dd_HH-mm-ss", [Globalization.CultureInfo]::InvariantCulture)
        return ([DateTimeOffset]::new($dt)).ToUnixTimeSeconds()
    } catch { return 0 }
}

# ---------------- Deaths ----------------
function Registrar-Morte {
    $est = Join-Path $LuaDir "pzbackup_estado.txt"
    if (-not (Test-Path -LiteralPath $est)) { return }
    $l = @(Get-Content -LiteralPath $est -TotalCount 3)
    if ($l.Count -lt 3 -or $l[0].Trim() -ne "morto" -or $l[2].Trim() -notmatch '^\d+$') { return }
    $linha = "$($l[1].Trim())|$($l[2].Trim())"
    if ((Test-Path -LiteralPath $Mortes) -and (@(Get-Content -LiteralPath $Mortes) -contains $linha)) { return }
    [IO.File]::AppendAllText($Mortes, "$linha`n", $Utf8)
}

# Seconds between a backup and the next recorded death of its world, if within the margin ("" otherwise)
function Morte-Seg([string]$Nome) {
    if (-not (Test-Path -LiteralPath $Mortes)) { return "" }
    $m = Margem-Morte; if ($m -le 0) { return "" }
    $partes = $Nome -split "__"
    $modo = $partes[0]; $mundo = ($partes[1..($partes.Count - 2)] -join "__")
    $b = Backup-Epoch $Nome; $melhor = $null
    foreach ($l in (Get-Content -LiteralPath $Mortes)) {
        $x = $l -split '\|'
        if ($x.Count -lt 2 -or ($x[0] -ne "$modo/$mundo" -and $x[0] -ne "/$mundo") -or $x[1] -notmatch '^\d+$') { continue }
        $d = [long]$x[1] - $b
        if ($d -ge 0 -and $d -le $m -and ($null -eq $melhor -or $d -lt $melhor)) { $melhor = $d }
    }
    if ($null -eq $melhor) { return "" }
    return "$melhor"
}

# Auto-restore pick for "mode/world": newest backup neither bitten nor within the death margin;
# else newest not bitten; else newest. Returns @{ Nome; PuladosM; PuladosP }
function Backup-Seguro([string]$Alvo, [string]$Morte) {
    $modo, $mundo = $Alvo -split '/', 2
    $m = Margem-Morte
    $r = @{ Nome = ""; PuladosM = 0; PuladosP = 0 }
    $primeiro = ""; $semMordida = ""
    $lista = Get-ChildItem -LiteralPath $Destino -Directory | Where-Object { $_.Name.StartsWith("${modo}__${mundo}__") } |
        Sort-Object Name -Descending
    foreach ($b in $lista) {
        if (-not $primeiro) { $primeiro = $b.Name }
        $mord = Info-Campo $b.Name "mordidas"
        if ($mord -and $mord -ne "0") { $r.PuladosM++; continue }
        if (-not $semMordida) { $semMordida = $b.Name }
        $e = Backup-Epoch $b.Name
        if ($Morte -match '^\d+$' -and $m -gt 0 -and $e -le [long]$Morte -and ([long]$Morte - $e) -lt $m) { $r.PuladosP++; continue }
        $r.Nome = $b.Name; return $r
    }
    $r.Nome = if ($semMordida) { $semMordida } else { $primeiro }
    return $r
}

# ---------------- Disk and copy ----------------
function Livre-MB {
    try {
        $raiz = [IO.Path]::GetPathRoot((Resolve-Path -LiteralPath $Destino).Path)
        return [math]::Floor(([IO.DriveInfo]::new($raiz)).AvailableFreeSpace / 1MB)
    } catch { return $null }
}
function Tamanho-MB([string]$Dir) {
    $s = (Get-ChildItem -LiteralPath $Dir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    return [math]::Ceiling([double]$s / 1MB)
}

# Waits (up to 30 s) until no file in the save changed in the last $QuietSeconds
function Esperar-Quieto([string]$Dir) {
    if ($QuietSeconds -le 0) { return $true }
    for ($n = 0; $n -lt 30; $n++) {
        $limite = (Get-Date).AddSeconds(-$QuietSeconds)
        $mexeu = Get-ChildItem -LiteralPath $Dir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $limite } | Select-Object -First 1
        if (-not $mexeu) { return $true }
        Start-Sleep 1
    }
    return $false
}

# Fast hard links on Windows (CreateHardLinkW); elsewhere New-Item (used by the tests on Linux)
$script:LinkApi = $null
function Criar-Link([string]$Novo, [string]$Existente) {
    if ($null -eq $script:LinkApi) {
        $script:LinkApi = $false
        if ($env:OS -eq "Windows_NT") {
            try {
                Add-Type -Namespace PZB -Name Link -MemberDefinition '[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool CreateHardLink(string lpFileName, string lpExistingFileName, IntPtr lpSecurityAttributes);' -ErrorAction Stop
                $script:LinkApi = $true
            } catch { }
        }
    }
    if ($script:LinkApi) { return [PZB.Link]::CreateHardLink($Novo, $Existente, [IntPtr]::Zero) }
    try { New-Item -ItemType HardLink -Path $Novo -Target $Existente -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

# Copies a save into a backup folder. With $Hardlinks and a previous backup, files with the same
# size and modification time as in the previous backup become hard links. Returns the MB copied.
function Copiar([string]$Origem, [string]$Alvo, [string]$Anterior) {
    if (Test-Path -LiteralPath $Alvo) { Remove-Item -LiteralPath $Alvo -Recurse -Force }
    $usarLinks = $Hardlinks -and $Anterior -and (Test-Path -LiteralPath $Anterior)
    if (-not $usarLinks) {
        Copy-Item -LiteralPath $Origem $Alvo -Recurse -ErrorAction Stop
        return (Tamanho-MB $Alvo)
    }
    $raiz = (Resolve-Path -LiteralPath $Origem).Path.TrimEnd('\', '/')
    $copiados = 0L
    New-Item -ItemType Directory -Force -Path $Alvo | Out-Null
    foreach ($d in (Get-ChildItem -LiteralPath $raiz -Recurse -Directory)) {
        New-Item -ItemType Directory -Force -Path (Join-Path $Alvo $d.FullName.Substring($raiz.Length + 1)) | Out-Null
    }
    foreach ($f in (Get-ChildItem -LiteralPath $raiz -Recurse -File)) {
        $rel = $f.FullName.Substring($raiz.Length + 1)
        $novo = Join-Path $Alvo $rel
        $velho = Join-Path $Anterior $rel
        $linkou = $false
        if (Test-Path -LiteralPath $velho) {
            $v = Get-Item -LiteralPath $velho
            if ($v.Length -eq $f.Length -and $v.LastWriteTimeUtc -eq $f.LastWriteTimeUtc) { $linkou = Criar-Link $novo $velho }
        }
        if (-not $linkou) {
            Copy-Item -LiteralPath $f.FullName $novo -ErrorAction Stop
            (Get-Item -LiteralPath $novo).LastWriteTimeUtc = $f.LastWriteTimeUtc
            $copiados += $f.Length
        }
    }
    return [math]::Ceiling([double]$copiados / 1MB)
}

# Same files with the same sizes in both folders?
function Copia-Confere([string]$A, [string]$B) {
    if (-not $Verify) { return $true }
    $lista = {
        param($d)
        $r = (Resolve-Path -LiteralPath $d).Path.TrimEnd('\', '/')
        (Get-ChildItem -LiteralPath $r -Recurse -File | ForEach-Object { "$($_.Length) $($_.FullName.Substring($r.Length + 1))" } | Sort-Object) -join "`n"
    }
    return ((& $lista $A) -eq (& $lista $B))
}

# Newest backup of a world (for the incremental copy), excluding one name
function Anterior-Do-Mundo([string]$Modo, [string]$Mundo, [string]$Exceto) {
    $b = Get-ChildItem -LiteralPath $Destino -Directory | Where-Object { $_.Name.StartsWith("${Modo}__${Mundo}__") -and $_.FullName -ne $Exceto } |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($b) { return $b.FullName }
    return ""
}

# ---------------- Backup ----------------
# Core copy, no death/danger checks. Uses $script:Origem as the backup's source tag.
function Copiar-Backup($Origem, [string]$Nota = "", [bool]$Fixar = $false) {
    $modo = $Origem.Parent.Name
    $mundo = $Origem.Name
    $carimbo = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $alvo = Join-Path $Destino "${modo}__${mundo}__${carimbo}"
    if (Test-Path -LiteralPath $alvo) { $alvo = "$alvo-$PID" }
    $ant = Anterior-Do-Mundo $modo $mundo $alvo
    if (-not (Esperar-Quieto $Origem.FullName)) {
        Avisar (Msg "O save continuou mudando por 30 s; copiando mesmo assim" "The save kept changing for 30 s; copying anyway") "erro"
    }
    $conf = "ok"
    try {
        $novos = Copiar $Origem.FullName $alvo $ant
        # The game may have written during the copy: wait and copy again once
        if (-not (Copia-Confere $Origem.FullName $alvo)) {
            [void](Esperar-Quieto $Origem.FullName)
            $novos = Copiar $Origem.FullName $alvo $ant
            if (-not (Copia-Confere $Origem.FullName $alvo)) { $conf = "falha" }
        }
        (Get-Item -LiteralPath $alvo).LastWriteTime = Get-Date
    } catch {
        Remove-Item -LiteralPath $alvo -Recurse -Force -ErrorAction SilentlyContinue
        Avisar (Msg "FALHA no backup de ${mundo}: $($_.Exception.Message)" "Backup FAILED for ${mundo}: $($_.Exception.Message)") "erro"; return $false
    }
    $nome = Split-Path $alvo -Leaf
    Guardar-Info $alvo $modo $mundo
    $extra = @("origem=$($script:Origem)", "tamanho_mb=$(Tamanho-MB $alvo)", "novos_mb=$novos")
    $notaLimpa = ($Nota -replace '[|\r\n]', '')
    if ($notaLimpa.Length -gt 60) { $notaLimpa = $notaLimpa.Substring(0, 60) }
    if ($notaLimpa) { $extra += "nota=$notaLimpa" }
    if ($conf -eq "falha") { $extra += "integridade=falha" }
    [IO.File]::AppendAllText((Join-Path $InfoDir "$nome.txt"), (($extra -join "`n") + "`n"), $Utf8)
    if ($Fixar -and -not (Fixado $nome)) { [IO.File]::AppendAllText($Pins, "$nome`n", $Utf8) }

    if ($conf -eq "falha") {
        Avisar (Msg "Backup feito, mas a VERIFICACAO falhou: $mundo ($carimbo). Prefira outro backup" "Backup done, but VERIFICATION failed: $mundo ($carimbo). Prefer another backup") "erro"
    } else {
        Avisar (Msg "Backup feito: $mundo ($carimbo, $novos MB novos)" "Backup done: $mundo ($carimbo, $novos MB new)")
    }
    Aplicar-Retencao $modo $mundo
    Atualizar-Lista
    return $true
}

# Automatic backups stop below $MinFreeMB (plus the save size when the copy can't be incremental)
function Espaco-Ok($Origem) {
    $livre = Livre-MB
    if ($null -eq $livre) { return $true }
    $precisa = $MinFreeMB
    if (-not $Hardlinks) { $precisa += (Tamanho-MB $Origem.FullName) }
    if ($livre -ge $precisa) { return $true }
    $marca = Join-Path $Destino ".aviso_espaco"
    if (-not (Test-Path -LiteralPath $marca) -or (Get-Item -LiteralPath $marca -Force).LastWriteTime -lt (Get-Date).AddMinutes(-30)) {
        [IO.File]::WriteAllText($marca, "", $Utf8)
        Avisar (Msg "POUCO ESPACO: $livre MB livres (minimo $precisa MB). Backup automatico pausado - libere espaco ou apague backups antigos" "LOW DISK SPACE: $livre MB free (minimum $precisa MB). Automatic backup paused - free some space or delete old backups") "erro"
    }
    return $false
}

# Backup of the current save, with the checks. Returns "ok", "falha", "morto", "adiado" or "espaco"
function Fazer-Backup([string]$Nota = "") {
    $origem = Save-Atual
    if (-not $origem) { Avisar (Msg "Nenhum save encontrado em $Saves" "No save found in $Saves") "erro"; return "falha" }

    $mundo = $origem.Name
    if ((Estado-Personagem) -eq "morto") {
        Avisar (Msg "Personagem MORTO em $mundo - backup NAO feito. F9 ou o atalho Restaurar" "Character is DEAD in $mundo - backup NOT taken. F9 or the Restore shortcut") "erro"
        return "morto"
    }
    # Automatic backups wait while the character is in danger (F8 never waits)
    if ($script:Origem -in "AUTO", "FINAL") {
        $perigo = $null
        if (Adiar-Perigo-Ativo) { $perigo = Perigo-Agora }
        if ($perigo) {
            if ($script:Origem -eq "FINAL") {
                Avisar (Msg "Backup final pulado: o jogo fechou em perigo ($(Texto-Perigo $perigo))" "Final backup skipped: the game closed in danger ($(Texto-Perigo $perigo))") "erro"
            } elseif (-not $script:Adiado) {
                Avisar (Msg "Perigo ($(Texto-Perigo $perigo)) - backup automatico adiado ate acalmar" "Danger ($(Texto-Perigo $perigo)) - automatic backup postponed until it calms down") "erro"
            }
            $script:Adiado = $true
            return "adiado"
        }
        if (-not (Espaco-Ok $origem)) { return "espaco" }
    }
    if ($script:Adiado -and $script:Origem -eq "AUTO") {
        Avisar (Msg "Perigo passou - fazendo o backup adiado" "Danger is over - taking the postponed backup")
    }
    $script:Adiado = $false
    if (Copiar-Backup $origem $Nota $false) { return "ok" }
    return "falha"
}

# ---------------- Retention ----------------
# Per world, without touching pinned backups: the $Keep newest, plus the newest of each real
# hour of the last $KeepHourly hours, plus the newest of each in-game day of the last
# $KeepGameDays game days (counted from the newest backup).
function Aplicar-Retencao([string]$Modo, [string]$Mundo) {
    $agora = Agora-Unix
    $fixados = Ler-Fixados
    $horas = @{}; $dias = @{}; $n = 0; $nDias = 0
    $lista = Get-ChildItem -LiteralPath $Destino -Directory | Where-Object { $_.Name.StartsWith("${Modo}__${Mundo}__") } |
        Sort-Object Name -Descending
    foreach ($b in $lista) {
        if ($fixados -contains $b.Name) { continue }
        $n++; $manter = $n -le $Keep
        $e = Backup-Epoch $b.Name
        $hora = ($b.Name -split "__")[-1]; if ($hora.Length -ge 13) { $hora = $hora.Substring(0, 13) }
        if ($KeepHourly -gt 0 -and ($agora - $e) -le ($KeepHourly * 3600) -and -not $horas.ContainsKey($hora)) {
            $horas[$hora] = 1; $manter = $true
        }
        $dia = Info-Campo $b.Name "data_jogo"
        if ($dia -and -not $dias.ContainsKey($dia)) {
            $dias[$dia] = 1; $nDias++
            if ($nDias -le $KeepGameDays) { $manter = $true }
        }
        if (-not $manter) {
            Remove-Item -LiteralPath $b.FullName -Recurse -Force
            Remove-Item -LiteralPath (Join-Path $InfoDir "$($b.Name).txt") -Force -ErrorAction SilentlyContinue
        }
    }
}

# Saves the mod's character info next to the backup (only if it belongs to this world).
# The current danger (pzbackup_perigo.txt) replaces the one in the info (~25 s old).
function Guardar-Info([string]$Alvo, [string]$Modo, [string]$Mundo) {
    New-Item -ItemType Directory -Force -Path $InfoDir | Out-Null
    $dest = Join-Path $InfoDir "$(Split-Path $Alvo -Leaf).txt"
    [IO.File]::WriteAllText($dest, "", $Utf8)
    $info = Join-Path $LuaDir "pzbackup_info.txt"
    if (-not (Test-Path -LiteralPath $info)) { return }
    $linhas = @(Get-Content -LiteralPath $info -Encoding UTF8)
    $m = $linhas | Where-Object { $_ -like "mundo=*" } | Select-Object -First 1
    if (-not $m) { return }
    $m = $m.Substring(6).Trim()
    if ($m -ne "$Modo/$Mundo" -and $m -ne "/$Mundo") { return }
    $linhas = @($linhas | Where-Object { $_ -notlike "perigo=*" })
    $perigo = Perigo-Agora
    if ($perigo) { $linhas += "perigo=$perigo" }
    [IO.File]::WriteAllText($dest, (($linhas -join "`n") + "`n"), $Utf8)
}

# ---------------- Game update ----------------
# Steam build of Project Zomboid (appmanifest_108600.acf), searching every Steam library
function BuildId-Atual {
    $raizes = @()
    try { $raizes += (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath } catch { }
    $raizes += "${env:ProgramFiles(x86)}\Steam", (Join-Path $env:USERPROFILE ".steam/steam"), (Join-Path $env:USERPROFILE ".local/share/Steam")
    foreach ($r in ($raizes | Where-Object { $_ })) {
        $libs = @($r)
        $vdf = Join-Path $r "steamapps/libraryfolders.vdf"
        if (Test-Path -LiteralPath $vdf) {
            $libs += (Select-String -LiteralPath $vdf -Pattern '"path"\s+"(.+)"' | ForEach-Object { $_.Matches[0].Groups[1].Value -replace '\\\\', '\' })
        }
        foreach ($lib in $libs) {
            $acf = Join-Path $lib "steamapps/appmanifest_108600.acf"
            if (Test-Path -LiteralPath $acf) {
                $mt = Select-String -LiteralPath $acf -Pattern '"buildid"\s+"(\d+)"' | Select-Object -First 1
                if ($mt) { return $mt.Matches[0].Groups[1].Value }
            }
        }
    }
    return ""
}

function Verificar-Atualizacao {
    if (-not $UpdateBackup) { return }
    $atual = BuildId-Atual
    if (-not $atual) { return }
    $antigo = if (Test-Path -LiteralPath $BuildIdArq) { (Get-Content -LiteralPath $BuildIdArq -TotalCount 1).Trim() } else { "" }
    if ($antigo -and $antigo -ne $atual) {
        $script:Origem = "ATUALIZACAO"
        Avisar (Msg "Jogo atualizado (build $antigo -> $atual): backup fixado de todos os mundos antes de abrir" "Game updated (build $antigo -> $atual): pinned backup of every world before starting")
        if (Test-Path -LiteralPath $Saves) {
            foreach ($w in (Get-ChildItem -LiteralPath $Saves -Directory | Where-Object { $_.Name -ne "Multiplayer" } |
                            ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Directory })) {
                [void](Copiar-Backup $w (Msg "antes da atualizacao $antigo -> $atual" "before update $antigo -> $atual") $true)
            }
        }
    }
    [IO.File]::WriteAllText($BuildIdArq, "$atual`n", $Utf8)
}

# Info-Campo <backup name> <key> -> value from that backup's details ("" if none)
function Info-Campo([string]$Nome, [string]$Chave) {
    $arq = Join-Path $InfoDir "$Nome.txt"
    if (-not (Test-Path -LiteralPath $arq)) { return "" }
    $l = Get-Content -LiteralPath $arq -Encoding UTF8 | Where-Object { $_.StartsWith("$Chave=") } | Select-Object -First 1
    if ($l) { return $l.Substring($Chave.Length + 1).Trim() }
    return ""
}

# One-line summary: "John Doe, day 12, 340 kills, health 87%, BITTEN"
function Resumo-Info([string]$Nome) {
    $pers = Info-Campo $Nome "personagem"; $dias = Info-Campo $Nome "dias"; $mortes = Info-Campo $Nome "mortes"
    $saude = Info-Campo $Nome "saude"; $mord = Info-Campo $Nome "mordidas"
    if (-not ($pers + $dias)) { return "" }
    $r = Msg "$pers, dia $dias, $mortes zumbis" "$pers, day $dias, $mortes kills"
    if ($saude) { $r += (Msg ", saude $saude%" ", health $saude%") }
    if ($mord -and $mord -ne "0") { $r += (Msg ", MORDIDO" ", BITTEN") }
    return $r
}

# All details of a backup, one "key=value" per entry (without the world line)
function Info-Campos([string]$Nome) {
    $arq = Join-Path $InfoDir "$Nome.txt"
    if (-not (Test-Path -LiteralPath $arq)) { return @() }
    @(Get-Content -LiteralPath $arq -Encoding UTF8 | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match '^[\w]+=' -and $_ -notlike "mundo=*" })
}

# ---------------- Pinned backups ----------------
function Ler-Fixados {
    if (-not (Test-Path -LiteralPath $Pins)) { return @() }
    return @(Get-Content -LiteralPath $Pins -Encoding UTF8 | Where-Object { $_ })
}
function Fixado([string]$Nome) { return (Ler-Fixados) -contains $Nome }

function Fixar([string]$Nome, [string]$Acao) {
    if (-not $Nome -or -not (Test-Path -LiteralPath (Join-Path $Destino $Nome))) {
        Avisar (Msg "Backup nao encontrado: $Nome" "Backup not found: $Nome") "erro"; return
    }
    $lista = @(Ler-Fixados | Where-Object { $_ -ne $Nome })
    if ($Acao -eq "pin") { $lista += $Nome }
    $texto = if ($lista.Count) { ($lista -join "`n") + "`n" } else { "" }
    [IO.File]::WriteAllText($Pins, $texto, $Utf8)
    if ($Acao -eq "pin") {
        Avisar (Msg "Backup fixado (nunca sera apagado pela rotacao): $Nome" "Backup pinned (never removed by the rotation): $Nome")
    } else {
        Avisar (Msg "Backup desafixado (volta para a rotacao): $Nome" "Backup unpinned (back in the rotation): $Nome")
    }
    Atualizar-Lista
}

# Sets (or removes, with empty text) a backup's note
function Anotar([string]$Nome, [string]$Texto) {
    if (-not $Nome -or -not (Test-Path -LiteralPath (Join-Path $Destino $Nome))) {
        Avisar (Msg "Backup nao encontrado: $Nome" "Backup not found: $Nome") "erro"; return
    }
    $Texto = ($Texto -replace '[|\r\n]', '').Trim()
    if ($Texto.Length -gt 60) { $Texto = $Texto.Substring(0, 60) }
    New-Item -ItemType Directory -Force -Path $InfoDir | Out-Null
    $arq = Join-Path $InfoDir "$Nome.txt"
    $linhas = if (Test-Path -LiteralPath $arq) { @(Get-Content -LiteralPath $arq -Encoding UTF8 | Where-Object { $_ -and $_ -notlike "nota=*" }) } else { @() }
    if ($Texto) { $linhas += "nota=$Texto" }
    $conteudo = if ($linhas.Count) { ($linhas -join "`n") + "`n" } else { "" }
    [IO.File]::WriteAllText($arq, $conteudo, $Utf8)
    if ($Texto) { Avisar (Msg "Nota salva: $Texto" "Note saved: $Texto") } else { Avisar (Msg "Nota removida" "Note removed") }
    Atualizar-Lista
}

# Handles the mod's commands (pzbackup_fixar.txt): "pin <name>", "unpin <name>", "note <name>|<text>"
function Processar-Fixar {
    $arq = Join-Path $LuaDir "pzbackup_fixar.txt"
    if (-not (Test-Path -LiteralPath $arq)) { return }
    $proc = Join-Path $LuaDir ".pzbackup_fixar.proc"
    try { Move-Item -LiteralPath $arq $proc -Force -ErrorAction Stop } catch { return }
    foreach ($linha in (Get-Content -LiteralPath $proc -Encoding UTF8)) {
        $linha = $linha.Trim()
        if ($linha.StartsWith("pin ")) { Fixar $linha.Substring(4) "pin" }
        elseif ($linha.StartsWith("unpin ")) { Fixar $linha.Substring(6) "unpin" }
        elseif ($linha.StartsWith("note ")) { $x = $linha.Substring(5) -split '\|', 2; Anotar $x[0] ($(if ($x.Count -gt 1) { $x[1] } else { "" })) }
    }
    Remove-Item -LiteralPath $proc -Force -ErrorAction SilentlyContinue
}

# Drops details and pins of backups that no longer exist
function Limpar-Meta {
    if (Test-Path -LiteralPath $InfoDir) {
        Get-ChildItem -LiteralPath $InfoDir -File -Filter "*.txt" |
            Where-Object { -not (Test-Path -LiteralPath (Join-Path $Destino $_.BaseName)) } |
            Remove-Item -Force
    }
    if (Test-Path -LiteralPath $Pins) {
        $vivos = @(Ler-Fixados | Where-Object { Test-Path -LiteralPath (Join-Path $Destino $_) })
        $texto = if ($vivos.Count) { ($vivos -join "`n") + "`n" } else { "" }
        [IO.File]::WriteAllText($Pins, $texto, $Utf8)
    }
}

# Mods that differ between a backup and the current game (from the mod's last info)
# Returns lines "- id" (in the backup, not active now) and "+ id" (active now, not in the backup)
function Diferenca-Mods([string]$Nome) {
    $antes = Info-Campo $Nome "mods"
    $info = Join-Path $LuaDir "pzbackup_info.txt"
    if (-not $antes -or -not (Test-Path -LiteralPath $info)) { return @() }
    $l = Get-Content -LiteralPath $info -Encoding UTF8 | Where-Object { $_ -like "mods=*" } | Select-Object -First 1
    if (-not $l) { return @() }
    $a = @($antes -split ';' | ForEach-Object { $_.TrimStart('\') } | Where-Object { $_ } | Sort-Object -Unique)
    $b = @($l.Substring(5).Trim() -split ';' | ForEach-Object { $_.TrimStart('\') } | Where-Object { $_ } | Sort-Object -Unique)
    @($a | Where-Object { $b -notcontains $_ } | ForEach-Object { "- $_" }) +
    @($b | Where-Object { $a -notcontains $_ } | ForEach-Object { "+ $_" })
}

# Backups newest first (sorted by the date in the name)
function Backups-Ordenados {
    Get-ChildItem $Destino -Directory | Where-Object { $_.Name -like "*__*__*" } |
        Sort-Object { ($_.Name -split "__")[-1] } -Descending
}

# Writes for the mod's restore window:
#   Zomboid\Lua\pzbackup_lista.txt     name|label  (e.g. Survivor__World__2026-10-14_14-35-07|14/10 14:35:07  -  World)
#   Zomboid\Lua\pzbackup_detalhes.txt  name|pinned(1/0)|key=value|key=value...  (all the mod's info,
#                                      passed through as-is: new fields need no script change)
# (two files so a v1.3 mod still reads the list it knows)
function Atualizar-Lista {
    if (-not (Test-Path $LuaDir)) { return }
    Limpar-Meta
    $fixados = Ler-Fixados
    $linhas = @(); $detalhes = @()
    foreach ($b in Backups-Ordenados) {
        $partes = $b.Name -split "__"
        $mundo = ($partes[1..($partes.Count - 2)] -join "__")
        $rotulo = $partes[-1]
        if ($partes[-1] -match '^(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})') {
            $rotulo = "{0}/{1} {2}:{3}:{4}" -f $Matches[3], $Matches[2], $Matches[4], $Matches[5], $Matches[6]
        }
        $linhas += "$($b.Name)|" + (Sem-Acento "$rotulo  -  $mundo")
        $fixo = if ($fixados -contains $b.Name) { "1" } else { "0" }
        $campos = @(Info-Campos $b.Name | ForEach-Object { Sem-Acento ($_ -replace '\|', '') })
        $ms = Morte-Seg $b.Name; if ($ms) { $campos += "morte_seg=$ms" }
        $detalhes += (@("$($b.Name)|$fixo") + $campos) -join "|"
    }
    $texto = if ($linhas.Count) { ($linhas -join "`n") + "`n" } else { "" }
    $textoDet = if ($detalhes.Count) { ($detalhes -join "`n") + "`n" } else { "" }
    [IO.File]::WriteAllText((Join-Path $LuaDir "pzbackup_detalhes.txt"), $textoDet, $Utf8)
    [IO.File]::WriteAllText((Join-Path $LuaDir "pzbackup_lista.txt"), $texto, $Utf8)
}

function Listar {
    $i = 1
    $fixados = Ler-Fixados
    foreach ($b in Backups-Ordenados) {
        $extra = ""
        if ($fixados -contains $b.Name) { $extra = " [PIN]" }
        $nota = Info-Campo $b.Name "nota"; if ($nota) { $extra += " `"$nota`"" }
        if (Info-Campo $b.Name "perigo") { $extra += " " + (Msg "[PERIGO]" "[DANGER]") }
        $ms = Morte-Seg $b.Name; if ($ms) { $extra += " " + (Msg "[${ms}s ANTES DA MORTE]" "[${ms}s BEFORE DEATH]") }
        if ((Info-Campo $b.Name "integridade") -eq "falha") { $extra += " " + (Msg "[VERIFICACAO FALHOU]" "[VERIFY FAILED]") }
        $r = Resumo-Info $b.Name
        if ($r) { $extra += "  ($r)" }
        "{0,2}  {1}{2}" -f $i, $b.Name, $extra; $i++
    }
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
    $r = Resumo-Info $nome
    if ($r) { Write-Host ((Msg "Detalhes:  " "Details:   ") + $r) }
    $dif = @(Diferenca-Mods $nome)
    if ($dif.Count) {
        Write-Host (Msg "Mods diferentes de agora (- so no backup, + so agora):" "Mods differ from now (- only in the backup, + only now):") -ForegroundColor Yellow
        $dif | ForEach-Object { Write-Host "  $_" }
    }
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
    if (-not (Jogo-Aberto)) { Verificar-Atualizacao }   # pinned backup of every world if Steam updated the game

    while ($true) {
        $script:Origem = "AUTO"
        if (-not (Jogo-Aberto)) { Start-Process "steam://rungameid/$SteamAppId" }
        if (-not (Esperar-Jogo)) {
            Avisar (Msg "O jogo nao abriu em 3 minutos - backup automatico cancelado" "The game didn't start within 3 minutes - automatic backup cancelled") "erro"; return
        }
        Atualizar-Lista
        Avisar (Msg "Jogo iniciado - PZ Backup $Versao, backup automatico a cada $Interval min" "Game started - PZ Backup $Versao, automatic backup every $Interval min")

        $proximo = (Get-Date).AddMinutes($Interval)
        while (Jogo-Aberto) {
            # Heartbeat for the mod (Unix time in seconds)
            [IO.File]::WriteAllText($ativo, "$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())`n$Versao`n", $Utf8)
            if (Test-Path $pedido) {                 # mod key (optional "nota=" line)
                $nota = Get-Content $pedido -Encoding UTF8 | Where-Object { $_ -like "nota=*" } | Select-Object -First 1
                $nota = if ($nota) { $nota.Substring(5).Trim() } else { "" }
                Remove-Item $pedido -Force
                $script:Origem = "MOD"; [void](Fazer-Backup $nota); $script:Origem = "AUTO"
            }
            Registrar-Morte
            if (Test-Path (Join-Path $LuaDir "pzbackup_fixar.txt")) {   # mod's Pin/Unpin button
                $script:Origem = "MOD"; Processar-Fixar; $script:Origem = "AUTO"
            }
            if ((Get-Date) -ge $proximo) {
                # Postponed while in danger: try again every $DangerRetry s
                if ((Fazer-Backup) -eq "adiado") { $proximo = (Get-Date).AddSeconds($DangerRetry) }
                else { $proximo = (Get-Date).AddMinutes($Interval) }
            }
            Start-Sleep 1
        }
        Remove-Item $ativo -Force -ErrorAction SilentlyContinue
        Start-Sleep 3                                 # let the game finish writing
        Registrar-Morte

        # Restore requested from the mod window: restore and relaunch the game
        if (Test-Path $restauro) {
            $nome = (Get-Content $restauro -TotalCount 1).Trim()
            Remove-Item $restauro -Force
            # "AUTO mode/world" (death with auto-restore): that world's last SAFE backup
            # (not bitten, not within the death margin)
            if ($nome -like "AUTO *") {
                $alvoAuto = $nome.Substring(5)
                $est = @(Get-Content (Join-Path $LuaDir "pzbackup_estado.txt") -TotalCount 3 -ErrorAction SilentlyContinue)
                $morte = if ($est.Count -ge 3) { $est[2].Trim() } else { "" }
                $esc = Backup-Seguro $alvoAuto $morte
                $nome = $esc.Nome
                $script:Origem = "RESTAURO"
                if (-not $nome) {
                    Avisar (Msg "Sem backup de $(($alvoAuto -split '/', 2)[1]) para restaurar automaticamente" "No backup of $(($alvoAuto -split '/', 2)[1]) to auto-restore") "erro"
                } elseif ($esc.PuladosM -gt 0 -or $esc.PuladosP -gt 0) {
                    Avisar (Msg "Restauracao automatica: pulei $($esc.PuladosM) backup(s) mordido(s) e $($esc.PuladosP) feito(s) a menos de $(Margem-Morte) s da morte" "Auto-restore: skipped $($esc.PuladosM) bitten backup(s) and $($esc.PuladosP) taken less than $(Margem-Morte) s before the death")
                }
            }
            $script:Origem = "RESTAURO"
            if ($nome -and (Restaurar-Nome $nome)) {
                Avisar (Msg "Reabrindo o jogo com o backup restaurado. Confira os mods do save ao carregar (reative/desative)" "Reopening the game with the restored backup. Check the save's mods when loading (re-enable/disable)")
                continue
            }
        }
        $script:Origem = "FINAL"; [void](Fazer-Backup)   # skipped if the game closed in danger
        $script:Origem = "LIMPEZA"; Limpar-Mortos      # if the option is on
        return
    }
}

switch ($Acao) {
    "save"    { $script:Origem = "MANUAL"; [void](Fazer-Backup $Texto) }
    "loop"    { $script:Origem = "AUTO"
                Avisar (Msg "Backup automatico a cada $Interval min (feche a janela para parar)" "Automatic backup every $Interval min (close this window to stop)")
                while ($true) {
                    Start-Sleep ($Interval * 60)
                    while ((Fazer-Backup) -eq "adiado") { Start-Sleep $DangerRetry }
                } }
    { $_ -in "note", "nota" } {
                $lista = @(Backups-Ordenados)
                if (-not $PSBoundParameters.ContainsKey('Numero') -or $Numero -lt 1 -or $Numero -gt $lista.Count) {
                    Write-Host (Msg "Uso: pz-backup.ps1 note N `"texto`" (numero da lista: pz-backup.ps1 list)" "Usage: pz-backup.ps1 note N `"text`" (number from: pz-backup.ps1 list)")
                } else { $script:Origem = "MANUAL"; Anotar $lista[$Numero - 1].Name $Texto } }
    "list"    { Listar }
    { $_ -in "version", "--version", "-v" } { "PZ Backup $Versao" }
    "log"     { if (Test-Path $Log) { Get-Content $Log -Tail 30 -Encoding UTF8 } else { Msg "Log vazio." "Log is empty." } }
    { $_ -in "clean", "limpar" } { if (Jogo-Aberto) { Avisar (Msg "Feche o Project Zomboid antes de limpar" "Close Project Zomboid before cleaning up") "erro" }
                else { $script:Origem = "LIMPEZA"; $RemoveDead = "1"; Limpar-Mortos } }
    "restore" { $script:Origem = "RESTAURO"; Restaurar $Numero }
    { $_ -in "pin", "unpin" } {
                $lista = @(Backups-Ordenados)
                if (-not $PSBoundParameters.ContainsKey('Numero') -or $Numero -lt 1 -or $Numero -gt $lista.Count) {
                    Write-Host (Msg "Uso: pz-backup.ps1 $Acao N (numero da lista: pz-backup.ps1 list)" "Usage: pz-backup.ps1 $Acao N (number from: pz-backup.ps1 list)")
                } else { $script:Origem = "MANUAL"; Fixar $lista[$Numero - 1].Name $Acao } }
    { $_ -in "game", "jogo" } { Modo-Jogo }
    { $_ -in "choose", "escolher" } {             # used by the "PZ Backup - Restore" shortcut
                $script:Origem = "RESTAURO"
                Listar
                $n = Read-Host ("`n" + (Msg "Numero do backup para restaurar (Enter = cancelar)" "Backup number to restore (Enter = cancel)"))
                if ($n -match '^\d+$') { Restaurar ([int]$n) } else { Write-Host (Msg "Cancelado." "Cancelled.") }
                Read-Host ("`n" + (Msg "Pressione Enter para fechar" "Press Enter to close")) | Out-Null }
    default   { Get-Content $PSCommandPath -TotalCount 20 | Select-Object -Skip 1 }
}
