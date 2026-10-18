# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [SemVer](https://semver.org/).

## [1.2.0] - 2026-10-18

### Changed
- **English is now the main language** of the whole project. Portuguese (pt-BR) became an option:
  *Options → Mods → PZ Backup → Portugues (pt-BR)*. The mod no longer follows the game's language.
- Scripts speak English by default (or Portuguese if the option is ticked); `LANGUAGE`
  forces one or the other. Confirmations accept `y` or `s`.
- English file and folder names: `install.sh`, `install.bat`, `files/`,
  `files/windows/install-windows.ps1`, `workshop/prepare-workshop.sh`,
  `PZBackupRestore.lua`, `PZBackup_Strings.lua`.
- Installers in English. Windows shortcuts: *PZ Backup - Save now* and *PZ Backup - Restore*
  (the old Portuguese ones are removed on reinstall).
- English commands: `game`, `clean` and `choose` (Windows). The old `jogo`, `limpar` and
  `escolher` still work — your Steam launch option doesn't need to change.
- English script settings: `INTERVAL`, `KEEP`, `KEEP_REPLACED`, `REMOVE_DEAD`, `SOUND`,
  `LANGUAGE` (on Windows: `$Interval`, `$Keep`, `$KeepReplaced`, `$RemoveDead`, `$Sound`,
  `$Language`). If you had changed any value, redo it in the new file.
- The `BackupsSaves/substituidos` folder is now `BackupsSaves/replaced`; the old one is
  migrated automatically on the first run.
- Mod messages in `console.txt` are in English (`[PZBackup] loaded ...`).

### Added
- `tools/update-from-zip.sh` (for maintainers): copies a downloaded repository zip into the
  local git repo, shows `git status`, builds the Workshop folder and can reinstall/commit.
- `prepare-workshop.sh` options: `--ascii` (strip accents), `--minimal` (one-line
  description) and `--public`; it also reports the description size and warns when `id=` is missing.

### Fixed
- Workshop upload failing with "error requesting Steam to update the item": the description
  had an emoji and special symbols that the game doesn't pass cleanly to Steam. The Workshop
  text now uses plain ASCII symbols (`-`, `->`); `--ascii` also strips accents if needed.

## [1.1.1] - 2026-10-18

### Fixed
- Game language detection: the mod looked for "PT" anywhere in the text returned by the
  game and could show the F9 window (and everything else) in Portuguese with the game in English.
  It now compares the exact language code (`PT`/`PTBR` = Portuguese, anything else = English).
- The detected language is logged to `console.txt`.

## [1.1.0] - 2026-10-18

### Added
- **Mod in English and Portuguese**: follows the game's language (options, windows, death panel, warnings).
- **"View log" button** in the F9 window and in *Options → Mods*: last 150 lines, newest
  on top, colored by type (backup, restore, failure).
- `pz-backup.sh log` / `pz-backup.ps1 log` command.
- Script messages in PT or EN according to the game's language (`IDIOMA` forces one);
  `[RESTORE]`/`[CLEANUP]` tags in English.
- "How it works" and "Died? Now what?" diagrams (PT and EN) in `docs/img/`.

### Changed
- New cover and icon, colorful and in the game's mood (original art).
- README (EN), LEIAME (PT-BR) and Workshop description rewritten: more detailed and
  less like a fridge manual.

## [1.0.1] - 2026-10-16

### Changed
- **Mod ID is now `PZBackupAHLR`** (was `PZBackupAhlr`). Existing users need to
  re-enable it in their saves (*Load → save → Mods*); mod options go back to defaults.
- Workshop description: Build line updated (tested on 42.21.0) and duplicate Mod ID
  removed — the game adds `Workshop ID` and `Mod ID` by itself.
- Links to the Workshop page in the README and LEIAME.

### Fixed
- `preparar-workshop.sh` (now `prepare-workshop.sh`) also copies `mod.info` to the root of
  the mod folder; without it the Workshop upload failed ("missing a mod.info file").

## [1.0.0] - 2026-10-16

First public release.

### Added
- Automatic backup every 5 minutes while the game is open, plus a final backup on exit.
- Manual backup with the **F8** key (mod) or a system shortcut (`pz-backup.sh save`).
- In-game restore window (**F9** or *Options → Mods*): the game closes, restores and reopens.
- Auto-restore on death: 10 s countdown, restores the world's latest backup and
  reopens the game — just click *Continue*. Can be turned off in the mod options.
- Death protection: no backup is made while the character is dead.
- Removal of the dead character's save when the game closes (moved to `substituidos/`).
  Can be turned off in the mod options.
- Retention: 10 backups per world and 5 replaced saves.
- Log with the source of each action: `[AUTO]`, `[MOD]`, `[MANUAL]`, `[FINAL]`, `[RESTAURO]`, `[LIMPEZA]`.
- Sound alerts (Linux: beeps generated with Python; Windows: system sounds).
- Installers for Linux (native and Flatpak Steam) and Windows 10/11.
- In-game warning, with the repository address, when the script isn't installed.

[1.2.0]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v1.2.0
[1.1.1]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v1.1.1
[1.1.0]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v1.1.0
[1.0.1]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v1.0.1
[1.0.0]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v1.0.0
