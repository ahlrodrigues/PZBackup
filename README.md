# PZ Backup — save backups for Project Zomboid (Build 42)

**Português:** veja o [LEIAME.md](LEIAME.md) para a documentação completa em português.

Backs up your save **while you play** — automatically every 5 minutes and whenever you
press a key. If your character dies, PZ Backup can restore the latest backup by itself:
the game closes, the save is restored, the game reopens and you just click **Continue**.

| Feature | How it works |
|---|---|
| Automatic backup | Every 5 min, only while the game is running |
| Manual backup | **F8** in game |
| Restore in game | **F9** or *Options → Mods → PZ Backup → Restore backup...* |
| Auto-restore on death | 10 s countdown, restores the latest backup of that world, reopens the game (on by default) |
| Death protection | No backups are taken while the character is dead — good backups are kept |
| Dead-save cleanup | When the game closes, the save where the character died leaves the *Load* list (on by default) |
| History | Keeps the 10 most recent backups per world |

## Why two parts?

Project Zomboid's Lua sandbox cannot copy folders. So PZ Backup has:

1. **The mod** (Steam Workshop or `mods/` folder): keys, restore window, on-screen
   messages, death detection, options.
2. **The script** (this repository): does the actual copying. Bash on Linux,
   PowerShell on Windows.

**Installing only the mod from the Workshop is not enough** — install the script too.

## Installation

Download the latest **`PZBackup-vX.Y.Z.zip`** from
[Releases](https://github.com/ahlrodrigues/PZBackup/releases) and extract it.
Open Project Zomboid at least once before installing.

### Linux (native Steam or Flatpak)

```bash
bash instalar.sh
```

The installer finds your `Zomboid` folder, installs the mod and the script, and prints
the exact command to paste into **Steam → Project Zomboid → Properties → General →
Launch Options**, for example:

```
/home/YOUR_USER/Zomboid/pz-backup.sh jogo %command%
```

Requirements: Bash. Recommended: Python 3 (beeps and death check via `players.db`)
and `paplay`, `pw-play` or `aplay` (sound).

### Windows 10/11

Double-click **`instalar.bat`**. It installs the mod and the script and creates three
desktop shortcuts. **Always start the game with "Project Zomboid + Backup"** — on
Windows, launching straight from Steam does not start the automatic backup.

### Then, in game

Main menu → **Mods** → enable **PZ Backup** (also in your save's mod list).

## Restoring

- **Automatic, on death:** wait for the countdown (or click *Restore now*), then click
  **Continue**. Use *Choose another* if the latest backup was taken after a bite.
- **In game:** press **F9**, pick a backup, confirm.
- **Terminal, with the game closed:** `pz-backup.sh list` and `pz-backup.sh restore N`.

The restored save keeps the world's original folder name. The save it replaces is moved
to `Zomboid/BackupsSaves/substituidos/` (the 5 most recent are kept).

## Options

*Options → Mods → PZ Backup*: backup and restore keys, auto-restore on death, and
dead-save cleanup. Script settings (interval, how many backups to keep, sound) are at
the top of `pz-backup.sh` / `pz-backup.ps1`.

## Troubleshooting

Look for `[PZBackup]` lines in `Zomboid/console.txt`, and check
`Zomboid/BackupsSaves/pz-backup.log`. See the *Problemas* table in
[LEIAME.md](LEIAME.md) for common issues.

## License

[MIT](LICENSE) © Antonio Henrique (ahlrodrigues)
