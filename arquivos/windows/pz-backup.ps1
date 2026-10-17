# pz-backup.ps1 — Backup periódico e manual do save do Project Zomboid (Windows)
# Versao 1.0.1 — https://github.com/ahlrodrigues/PZBackup — Licenca MIT
#
# Uso (PowerShell):
#   pz-backup.ps1 save        -> faz um backup agora
#   pz-backup.ps1 loop        -> faz backup a cada $Intervalo minutos (deixe a janela aberta)
#   pz-backup.ps1 list        -> lista os backups existentes
#   pz-backup.ps1 restore     -> restaura o backup mais recente (com o jogo FECHADO)
#   pz-backup.ps1 restore N   -> restaura o N-ésimo backup da lista (1 = mais recente)
#   pz-backup.ps1 jogo        -> abre o jogo pela Steam, faz backups enquanto ele estiver
#                                aberto, atende a tecla do mod e faz um backup final ao fechar
#   pz-backup.ps1 escolher    -> mostra a lista e pergunta qual backup restaurar
#   pz-backup.ps1 limpar      -> remove agora o save do personagem morto (jogo FECHADO)

param([string]$Acao = "", [int]$Numero = 1)

$Intervalo = 5                                   # minutos entre backups automáticos
$Manter    = 10                                  # quantos backups manter por mundo
$ManterSubst = 5                                 # quantos saves substituidos manter (no total)
$ApagarMortos = ""                               # saves de personagem morto ao fechar o jogo:
                                                 #   "" = segue a opcao do mod (padrao: ligado)
                                                 #   "1" = sempre remove, "0" = nunca remove
$Som       = $true                               # $false = silencioso
$SteamAppId = 108600                             # Project Zomboid na Steam
$Processos = @("ProjectZomboid64", "ProjectZomboid32", "ProjectZomboid")

$Base = Join-Path $env:USERPROFILE "Zomboid"
$Saves = Join-Path $Base "Saves"
$Destino = Join-Path $Base "BackupsSaves"
$LuaDir = Join-Path $Base "Lua"
$Log = Join-Path $Destino "pz-backup.log"
$script:Origem = "MANUAL"
$Utf8 = New-Object System.Text.UTF8Encoding($false)   # UTF-8 sem BOM (o Lua lê melhor)

New-Item -ItemType Directory -Force -Path $Destino | Out-Null

function Tocar([string]$Tipo) {
    if (-not $Som) { return }
    try {
        if ($Tipo -eq "erro") { [System.Media.SystemSounds]::Hand.Play() }
        else { [System.Media.SystemSounds]::Asterisk.Play() }
    } catch { }
}

# Remove acentos do texto mostrado dentro do jogo (a fonte do jogo pode nao ter)
function Sem-Acento([string]$t) {
    ($t.Normalize([Text.NormalizationForm]::FormD).ToCharArray() |
        Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' }) -join ''
}

function Avisar([string]$Msg, [string]$Tipo = "ok") {
    Write-Host $Msg
    $linha = "{0}  {1,-10} {2}" -f (Get-Date -Format "dd/MM HH:mm:ss"), "[$($script:Origem)]", $Msg
    [IO.File]::AppendAllText($Log, $linha + "`r`n", $Utf8)
    Tocar $Tipo
    # Repassa o resultado para o mod mostrar na tela do jogo
    if (Test-Path $LuaDir) {
        $id = [DateTime]::UtcNow.Ticks
        [IO.File]::WriteAllText((Join-Path $LuaDir "pzbackup_status.txt"),
            (Sem-Acento "$id|$Tipo|[$($script:Origem)] $Msg") + "`n", $Utf8)
    }
}

# Save em uso = pasta de mundo modificada mais recentemente (Saves\<modo>\<mundo>)
function Save-Atual {
    if (-not (Test-Path $Saves)) { return $null }
    Get-ChildItem $Saves -Directory | ForEach-Object { Get-ChildItem $_.FullName -Directory } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

# No Windows a detecção de morte depende do mod PZ Backup
# (aviso só vale se atualizado nas últimas 12 h)
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
    if (-not $origem) { Avisar "Nenhum save encontrado em $Saves" "erro"; return }

    $modo = $origem.Parent.Name
    $mundo = $origem.Name
    if ((Estado-Personagem) -eq "morto") {
        Avisar "Personagem MORTO em $mundo - backup NAO feito. Use: pz-backup.ps1 restore" "erro"
        return
    }

    $carimbo = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $alvo = Join-Path $Destino "${modo}__${mundo}__${carimbo}"
    if (Test-Path $alvo) { $alvo = "$alvo-$PID" }
    try {
        Copy-Item $origem.FullName $alvo -Recurse -ErrorAction Stop
        (Get-Item $alvo).LastWriteTime = Get-Date
        Avisar "Backup feito: $mundo ($carimbo)"
    } catch {
        Avisar "FALHA no backup de ${mundo}: $($_.Exception.Message)" "erro"; return
    }

    # Mantém só os $Manter mais recentes deste mundo
    Get-ChildItem $Destino -Directory -Filter "${modo}__${mundo}__*" |
        Sort-Object Name -Descending | Select-Object -Skip $Manter |
        Remove-Item -Recurse -Force
    Atualizar-Lista
}

# Backups do mais recente para o mais antigo (ordena pela data no nome)
function Backups-Ordenados {
    Get-ChildItem $Destino -Directory | Where-Object { $_.Name -like "*__*__*" } |
        Sort-Object { ($_.Name -split "__")[-1] } -Descending
}

# Gera Zomboid\Lua\pzbackup_lista.txt para a janela de restauração do mod
# Formato: nome|rótulo  (ex.: Survivor__Mundo__2026-10-14_14-35-07|14/10 14:35:07  -  Mundo)
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

# A opcao "remover saves de personagem morto" esta ligada?
function Apagar-Mortos-Ativo {
    if ($ApagarMortos -eq "1") { return $true }
    if ($ApagarMortos -eq "0") { return $false }
    $cfg = Join-Path $LuaDir "pzbackup_config.txt"
    if (-not (Test-Path $cfg)) { return $false }          # sem o mod: nao remove nada
    return [bool](Select-String -Path $cfg -Pattern '^apagar_mortos=1' -Quiet)
}

# Remove da pasta Saves o mundo onde o personagem morreu (so com o jogo FECHADO).
# No Windows a informacao vem do mod (pzbackup_estado.txt: "morto" + modo/mundo).
# O save nao e apagado na hora: vai para BackupsSaves\substituidos (os 5 mais recentes ficam).
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
    $subst = Join-Path $Destino "substituidos"
    New-Item -ItemType Directory -Force -Path $subst | Out-Null
    foreach ($w in $candidatos) {
        if (-not (Test-Path $w)) { continue }
        $m = Split-Path (Split-Path $w -Parent) -Leaf
        Move-Item $w (Join-Path $subst "${m}__${mundo}__$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')")
        Avisar "Save de personagem morto removido de Carregar: $mundo (guardado em substituidos)"
    }
    [IO.File]::WriteAllText($est, "limpo`n$alvo`n", $Utf8)    # aviso ja tratado
    Get-ChildItem $subst -Directory | Where-Object { $_.Name -like "*__*__*" } |
        Sort-Object { ($_.Name -split "__")[-1] } -Descending | Select-Object -Skip $ManterSubst |
        Remove-Item -Recurse -Force
}

# Núcleo da restauração: recebe o NOME do backup (sem perguntar nada)
function Restaurar-Nome([string]$Nome) {
    $escolhido = Join-Path $Destino $Nome
    if (-not $Nome -or -not (Test-Path $escolhido)) { Avisar "Backup nao encontrado: $Nome" "erro"; return $false }
    $partes = $Nome -split "__"
    $modo = $partes[0]
    $mundo = ($partes[1..($partes.Count - 2)] -join "__")
    $destinoSave = Join-Path (Join-Path $Saves $modo) $mundo

    # Guarda o save atual (ex.: personagem morto) em vez de apagar
    $subst = Join-Path $Destino "substituidos"
    New-Item -ItemType Directory -Force -Path $subst | Out-Null
    if (Test-Path $destinoSave) {
        Move-Item $destinoSave (Join-Path $subst "${modo}__${mundo}__$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')")
    }
    # Mantém só os $ManterSubst substituídos mais recentes (pela data no nome)
    Get-ChildItem $subst -Directory | Where-Object { $_.Name -like "*__*__*" } |
        Sort-Object { ($_.Name -split "__")[-1] } -Descending | Select-Object -Skip $ManterSubst |
        Remove-Item -Recurse -Force
    New-Item -ItemType Directory -Force -Path (Split-Path $destinoSave) | Out-Null
    try {
        Copy-Item $escolhido $destinoSave -Recurse -ErrorAction Stop
        (Get-Item $destinoSave).LastWriteTime = Get-Date   # vira o save mais recente
        # O estado "morto" era do save antigo: nao pode valer para o restaurado
        if (Test-Path $LuaDir) {
            [IO.File]::WriteAllText((Join-Path $LuaDir "pzbackup_estado.txt"), "restaurado`n$modo/$mundo`n", $Utf8)
        }
        Avisar "Save restaurado: $Nome"
        return $true
    } catch {
        Avisar "FALHA ao restaurar ${Nome}: $($_.Exception.Message)" "erro"
        return $false
    }
}

# Restauração pelo atalho/terminal: escolhe pelo número e pede confirmação
function Restaurar([int]$N) {
    # O jogo só lê a lista de saves ao abrir: restaurar com ele aberto
    # faz o save não aparecer em "Carregar" até reiniciar o jogo.
    if (Jogo-Aberto) {
        Avisar "Feche o Project Zomboid antes de restaurar (o jogo so le a lista de saves ao abrir)" "erro"
        return
    }
    $lista = @(Backups-Ordenados)
    if ($N -lt 1 -or $N -gt $lista.Count) { Write-Host "Backup $N nao encontrado."; return }
    $nome = $lista[$N - 1].Name
    $partes = $nome -split "__"
    Write-Host "Restaurar: $nome"
    Write-Host "Em:        $(Join-Path (Join-Path $Saves $partes[0]) ($partes[1..($partes.Count - 2)] -join '__'))"
    $ok = Read-Host "Confirmar restauracao? (s/N)"
    if ($ok -ne "s") { Write-Host "Cancelado."; return }
    if (Restaurar-Nome $nome) {
        Write-Host "Pode abrir o jogo."
        Write-Host "`nATENCAO: o save restaurado volta com a lista de mods de quando o backup foi feito.`nAo carregar, confira em Carregar > (seu save) > Mods: reative o PZ Backup e os mods`nque voce usa, e desative os que nao quiser. Se um mod nao responder, desative e reative." -ForegroundColor Yellow
    }
}

function Jogo-Aberto { [bool](Get-Process -Name $Processos -ErrorAction SilentlyContinue) }

function Esperar-Jogo {
    Write-Host "Aguardando o Project Zomboid abrir..."
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

    while ($true) {
        $script:Origem = "AUTO"
        if (-not (Jogo-Aberto)) { Start-Process "steam://rungameid/$SteamAppId" }
        if (-not (Esperar-Jogo)) {
            Avisar "O jogo nao abriu em 3 minutos - backup automatico cancelado" "erro"; return
        }
        Atualizar-Lista
        Avisar "Jogo iniciado - backup automatico a cada $Intervalo min"

        $proximo = (Get-Date).AddMinutes($Intervalo)
        while (Jogo-Aberto) {
            # Sinal de vida para o mod (hora Unix em segundos)
            [IO.File]::WriteAllText($ativo, "$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())`n", $Utf8)
            if (Test-Path $pedido) {                 # tecla do mod
                Remove-Item $pedido -Force
                $script:Origem = "MOD"; Fazer-Backup; $script:Origem = "AUTO"
            }
            if ((Get-Date) -ge $proximo) {
                Fazer-Backup
                $proximo = (Get-Date).AddMinutes($Intervalo)
            }
            Start-Sleep 1
        }
        Remove-Item $ativo -Force -ErrorAction SilentlyContinue
        Start-Sleep 3                                 # deixa o jogo terminar de gravar

        # Restauração pedida pela janela do mod: restaura e reabre o jogo
        if (Test-Path $restauro) {
            $nome = (Get-Content $restauro -TotalCount 1).Trim()
            Remove-Item $restauro -Force
            # "AUTO modo/mundo" (morte com restauracao automatica): backup mais recente desse mundo
            if ($nome -like "AUTO *") {
                $alvo = $nome.Substring(5) -split '/', 2
                $ultimo = Get-ChildItem $Destino -Directory -Filter "$($alvo[0])__$($alvo[1])__*" |
                    Sort-Object Name -Descending | Select-Object -First 1
                $nome = if ($ultimo) { $ultimo.Name } else { "" }
                if (-not $nome) { $script:Origem = "RESTAURO"; Avisar "Sem backup de $($alvo[1]) para restaurar automaticamente" "erro" }
            }
            $script:Origem = "RESTAURO"
            if ($nome -and (Restaurar-Nome $nome)) {
                Avisar "Reabrindo o jogo com o backup restaurado. Confira os mods do save ao carregar (reative/desative)"
                continue
            }
        }
        $script:Origem = "FINAL"; Fazer-Backup
        $script:Origem = "LIMPEZA"; Limpar-Mortos      # se a opcao estiver ligada
        return
    }
}

switch ($Acao) {
    "save"    { $script:Origem = "MANUAL"; Fazer-Backup }
    "loop"    { $script:Origem = "AUTO"
                Avisar "Backup automatico a cada $Intervalo min (feche a janela para parar)"
                while ($true) { Start-Sleep ($Intervalo * 60); Fazer-Backup } }
    "list"    { Listar }
    "limpar"  { if (Jogo-Aberto) { Avisar "Feche o Project Zomboid antes de limpar" "erro" }
                else { $script:Origem = "LIMPEZA"; $ApagarMortos = "1"; Limpar-Mortos } }
    "restore" { $script:Origem = "RESTAURO"; Restaurar $Numero }
    "jogo"    { Modo-Jogo }
    "escolher" {                                  # usado pelo atalho "PZ Backup - Restaurar"
                $script:Origem = "RESTAURO"
                Listar
                $n = Read-Host "`nNumero do backup para restaurar (Enter = cancelar)"
                if ($n -match '^\d+$') { Restaurar ([int]$n) } else { Write-Host "Cancelado." }
                Read-Host "`nPressione Enter para fechar" | Out-Null }
    default   { Get-Content $PSCommandPath -TotalCount 14 | Select-Object -Skip 1 }
}
