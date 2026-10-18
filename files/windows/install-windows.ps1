# install-windows.ps1 — installs PZ Backup on Windows (called by install.bat)

$ErrorActionPreference = "Stop"
$Pkg     = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # folder that contains install.bat
$Zomboid = Join-Path $env:USERPROFILE "Zomboid"

function Step([string]$t) { Write-Host "  - $t" -ForegroundColor Green }
function Fail([string]$t) { Write-Host "`nERROR: $t" -ForegroundColor Red; Read-Host "`nPress Enter to close" | Out-Null; exit 1 }

Write-Host "`n=== PZ Backup installer (Windows) ===`n" -ForegroundColor Cyan

if (-not (Test-Path $Zomboid)) {
    Fail "Folder $Zomboid not found. Start Project Zomboid once before installing."
}
Write-Host "Game folder: $Zomboid`n"

# 1. Mod
$mods = Join-Path $Zomboid "mods"
New-Item -ItemType Directory -Force -Path $mods | Out-Null
$modDest = Join-Path $mods "PZBackup"
if (Test-Path $modDest) { Remove-Item $modDest -Recurse -Force }
Copy-Item (Join-Path $Pkg "files\mod\PZBackup") $modDest -Recurse
Remove-Item (Join-Path $modDest "common\.gitkeep") -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Join-Path $modDest "common") | Out-Null
Step "Mod installed in $modDest"

# 2. Script
$script = Join-Path $Zomboid "pz-backup.ps1"
Copy-Item (Join-Path $Pkg "files\windows\pz-backup.ps1") $script -Force
Unblock-File $script -ErrorAction SilentlyContinue
Step "Script installed in $script"

# 3. Desktop shortcuts
$desktop = [Environment]::GetFolderPath("Desktop")
$shell = New-Object -ComObject WScript.Shell
$ps = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

# Remove the shortcuts from older versions (Portuguese names)
foreach ($old in @("PZ Backup - Salvar agora", "PZ Backup - Restaurar")) {
    Remove-Item (Join-Path $desktop "$old.lnk") -Force -ErrorAction SilentlyContinue
}

function New-Shortcut([string]$name, [string]$action, [string]$hotkey, [int]$window, [string]$icon) {
    $lnk = $shell.CreateShortcut((Join-Path $desktop "$name.lnk"))
    $lnk.TargetPath = $ps
    $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script`" $action"
    $lnk.WorkingDirectory = $Zomboid
    $lnk.WindowStyle = $window          # 1 = normal, 7 = minimized
    if ($hotkey) { $lnk.Hotkey = $hotkey }
    if ($icon) { $lnk.IconLocation = $icon }
    $lnk.Save()
}

New-Shortcut "Project Zomboid + Backup" "game" "" 7 "$env:SystemRoot\System32\shell32.dll,137"
Step "Shortcut 'Project Zomboid + Backup' (starts the game with automatic backup)"
New-Shortcut "PZ Backup - Save now" "save" "CTRL+ALT+B" 7 "$env:SystemRoot\System32\shell32.dll,258"
Step "Shortcut 'PZ Backup - Save now' (hotkey Ctrl+Alt+B)"
New-Shortcut "PZ Backup - Restore" "choose" "" 1 "$env:SystemRoot\System32\shell32.dll,238"
Step "Shortcut 'PZ Backup - Restore' (lists and restores backups)"

Write-Host "`n=== Done! ===`n" -ForegroundColor Cyan
Write-Host "One step left:"
Write-Host "  In game: main menu > Mods > enable 'PZ Backup' (also in your save).`n"
Write-Host "From now on, start the game with the 'Project Zomboid + Backup'"
Write-Host "desktop shortcut. In game: F8 = backup now, F9 = restore.`n"
Read-Host "Press Enter to close" | Out-Null
