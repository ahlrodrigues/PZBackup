# instalar-windows.ps1 — instala o PZ Backup no Windows (chamado pelo instalar.bat)

$ErrorActionPreference = "Stop"
$Pacote  = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # pasta onde está o instalar.bat
$Zomboid = Join-Path $env:USERPROFILE "Zomboid"

function Passo([string]$t) { Write-Host "  - $t" -ForegroundColor Green }
function Falha([string]$t) { Write-Host "`nERRO: $t" -ForegroundColor Red; Read-Host "`nPressione Enter para fechar" | Out-Null; exit 1 }

Write-Host "`n=== Instalador PZ Backup (Windows) ===`n" -ForegroundColor Cyan

if (-not (Test-Path $Zomboid)) {
    Falha "Pasta $Zomboid nao encontrada. Abra o Project Zomboid uma vez antes de instalar."
}
Write-Host "Pasta do jogo: $Zomboid`n"

# 1. Mod
$mods = Join-Path $Zomboid "mods"
New-Item -ItemType Directory -Force -Path $mods | Out-Null
$modDestino = Join-Path $mods "PZBackup"
if (Test-Path $modDestino) { Remove-Item $modDestino -Recurse -Force }
Copy-Item (Join-Path $Pacote "arquivos\mod\PZBackup") $modDestino -Recurse
New-Item -ItemType Directory -Force -Path (Join-Path $modDestino "common") | Out-Null
Passo "Mod instalado em $modDestino"

# 2. Script
$script = Join-Path $Zomboid "pz-backup.ps1"
Copy-Item (Join-Path $Pacote "arquivos\windows\pz-backup.ps1") $script -Force
Unblock-File $script -ErrorAction SilentlyContinue
Passo "Script instalado em $script"

# 3. Atalhos na Área de Trabalho
$desktop = [Environment]::GetFolderPath("Desktop")
$shell = New-Object -ComObject WScript.Shell
$ps = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

function Criar-Atalho([string]$nome, [string]$acao, [string]$tecla, [int]$janela, [string]$icone) {
    $lnk = $shell.CreateShortcut((Join-Path $desktop "$nome.lnk"))
    $lnk.TargetPath = $ps
    $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script`" $acao"
    $lnk.WorkingDirectory = $Zomboid
    $lnk.WindowStyle = $janela          # 1 = normal, 7 = minimizada
    if ($tecla) { $lnk.Hotkey = $tecla }
    if ($icone) { $lnk.IconLocation = $icone }
    $lnk.Save()
}

Criar-Atalho "Project Zomboid + Backup" "jogo" "" 7 "$env:SystemRoot\System32\shell32.dll,137"
Passo "Atalho 'Project Zomboid + Backup' (abre o jogo com backup automatico)"
Criar-Atalho "PZ Backup - Salvar agora" "save" "CTRL+ALT+B" 7 "$env:SystemRoot\System32\shell32.dll,258"
Passo "Atalho 'PZ Backup - Salvar agora' (tecla Ctrl+Alt+B)"
Criar-Atalho "PZ Backup - Restaurar" "escolher" "" 1 "$env:SystemRoot\System32\shell32.dll,238"
Passo "Atalho 'PZ Backup - Restaurar' (lista e restaura backups)"

Write-Host "`n=== Pronto! ===`n" -ForegroundColor Cyan
Write-Host "Falta so um passo:"
Write-Host "  No jogo: menu principal > Mods > ative 'PZ Backup' (e tambem no seu save).`n"
Write-Host "A partir de agora, abra o jogo pelo atalho 'Project Zomboid + Backup'"
Write-Host "na Area de Trabalho. No jogo: F8 = backup manual, F9 = restaurar.`n"
Read-Host "Pressione Enter para fechar" | Out-Null
