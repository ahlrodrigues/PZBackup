# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [SemVer](https://semver.org/).

## [1.4.0] - 2026-10-18

### Added
- **Pinned backups.** *Pin* / *Unpin* button in the F9 window (`[PIN]` tag in the list).
  Pinned backups are never removed by the rotation and don't count toward `KEEP` / `$Keep`.
  From a terminal: `pz-backup.sh pin N` / `unpin N` (Windows: `pz-backup.ps1 pin N`).
  Pins are stored in `BackupsSaves/.pinned`.
- **Backup details in the F9 window**, up to 8 color-coded lines for the selected backup:
  character and profession, days survived, zombie kills; in-game date and time; health %,
  bites, scratches and lacerations (red **BITTEN!**); approximate vanilla town, coordinates
  and floor, indoors/outdoors/in a vehicle; hunger, thirst, tiredness and panic; 3 best
  skills, strength, fitness and weight. Every field is read defensively (B41 and B42 API
  names), and a field the game doesn't provide is simply left out. `list` and the terminal
  restore show a summary with health and a *BITTEN* flag.
- **Mod check on restore.** Each backup stores the mod list active when it was taken. The F9
  window says whether it matches the mods active now, and the confirm dialog names the mods
  that are only in the backup or only active now. The terminal restore lists them with `-`/`+`.
- **Safe auto-restore.** When you die, the auto-restore picks the newest backup that is
  **not bitten** and **not taken within the death margin** (default 60 s; option *Margin
  before death*: off, 30 s, 1, 2, 5 min). The log says how many were skipped. The mod now
  writes the time of death (line 3 of `pzbackup_estado.txt`); deaths are kept in
  `BackupsSaves/.deaths`.
- **Automatic backups wait during danger**: zombies chasing or within 8 tiles on the same
  floor, panic ≥ 50%, bleeding, on fire, health < 25%. Retries every `DANGER_RETRY` (20 s)
  and logs when it resumes. The final backup is skipped if the game closed in danger.
  F7/F8 never wait. Option *Postpone automatic backups while in danger* (on).
- **Colored backup list with a legend**: red = bitten, yellow = danger at backup time /
  right before a death / health < 50% / failed verification, green = normal, grey = no
  details. The confirm dialog warns about bitten and right-before-death backups.
- **Notes**: **F7** backs up with a note; **Note** button in F9 names any backup; terminal
  `note N "text"`. Shown in the list and the details (max 60 characters).
- **Save safety**: waits until the save stops changing (`QUIET_SECONDS`, 3 s, up to 30 s)
  before copying; verifies each copy (files and sizes, plus `players.db` `quick_check` on
  Linux) and copies again once if the game wrote in the middle; marks failures.
- **Backup before a game update**: when Steam's build number of Project Zomboid changes,
  every world gets a **pinned** backup before the new version opens it
  (`UPDATE_BACKUP`, origin tag `[ATUALIZACAO]`).
- **Low disk space**: automatic backups pause below `MIN_FREE_MB` (1024) with a warning at
  most every 30 min; F7/F8 still try.
- **Tiered retention**: besides the `KEEP` newest, 1 per hour of the last `KEEP_HOURLY`
  (24) hours and 1 per in-game day of the last `KEEP_GAME_DAYS` (14) game days.
- **Incremental backups**: unchanged files are hard links to the previous backup
  (`rsync --link-dest` on Linux, `CreateHardLink` on Windows/NTFS; full copy otherwise).
  Details show size and MB new.
- Details panel also shows how the backup was made (source, size, MB new), the danger at
  backup time, the distance to a death and the note.
- New mod ↔ script files: `pzbackup_info.txt` (mod → script, `key=value`, refreshed every
  10 in-game minutes and before each F8), `pzbackup_fixar.txt` (mod → script) and
  `pzbackup_detalhes.txt` (script → mod, `name|pinned|key=value|...`). The script passes
  every field through, so future fields only need a mod update. Details are kept in
  `BackupsSaves/.info/`.
- Workshop description rewritten: every feature explained on its own, in both languages.

- **Version everywhere**: options page "PZ Backup X.Y.Z" with a version title; F9 window
  shows `mod X | script Y` (red when they differ); warning on game start when mod and
  script versions differ; `pz-backup.sh version` / `pz-backup.ps1 version`; the script's
  heartbeat (`pzbackup_ativo.txt`) carries its version on line 2; version in the Workshop
  description footer and in `console.txt`.
- `tools/bump-version.sh X.Y.Z` sets the version in all 9 places (mod.info,
  `PZBackup_Version.lua`, both scripts, README, LEIAME, CHANGELOG `[Unreleased]` →
  `[X.Y.Z] - date` + release link); `--check` verifies them. `prepare-workshop.sh` refuses
  to build the upload folder when versions differ.
- `tools/publish.sh`: after downloading the patch and the release zip, does everything up
  to the Workshop "Update" click — applies the patch (or replaces/updates an older delivery
  of the same version), checks versions, pushes commit and tag to Forgejo, creates the
  GitHub release with the zip once the mirror has the tag (`gh`), installs the new
  `pz-backup.sh` locally and builds the Workshop folder. Safe to run again.

### Changed
- The F9 window is larger (720×700) to fit the legend, the details and the *Pin* / *Note* buttons.
- LEIAME: fixed the outdated language line in the feature table.
- Windows: the per-world rotation no longer uses `-Filter`, so world names with `[` `]`
  are matched correctly.

### Compatibility
- `pzbackup_lista.txt` keeps its `name|label` format: a v1.4 script works with a v1.3 mod
  and vice versa (without the new features until both are updated).
- Backups made before v1.4 show *No details*; they restore normally and can be pinned.

## [1.3.0] - 2026-10-18

### Changed
- **Language now follows the game by default.** The *Portugues (pt-BR)* checkbox became a
  **Language** list in *Options → Mods → PZ Backup*: **Automatic (game language)** (default),
  **English** or **Portugues (pt-BR)**. With *Automatic*, a game in Portuguese (`PT`/`PTBR`)
  shows the mod in Portuguese; any other language shows it in English.
- The script still follows the mod (`idioma=pt|en` in `pzbackup_config.txt`, now the resolved
  language); `LANGUAGE` / `$Language` still forces one.
- `console.txt` logs both the mod language and the detected game language.

### Upgrading
- Your old checkbox choice isn't carried over: the list starts on *Automatic*. If you play the
  game in English but want the mod in Portuguese (or the opposite), pick it once in the list.

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

[1.4.0]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v1.4.0
[1.3.0]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v1.3.0
[1.2.0]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v1.2.0
[1.1.1]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v1.1.1
[1.1.0]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v1.1.0
[1.0.1]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v1.0.1
[1.0.0]: https://github.com/ahlrodrigues/PZBackup/releases/tag/v1.0.0
