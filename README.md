<p align="center"><img src="docs/img/capa.png" alt="PZ Backup" width="360"></p>

# PZ Backup — because Knox County doesn't do second chances (but we do)

**Downloads:** <https://github.com/ahlrodrigues/PZBackup/releases> ·
**Steam Workshop:** <https://steamcommunity.com/sharedfiles/filedetails/?id=3821180981> ·
*Português:* [LEIAME.md](LEIAME.md)
Version 1.1.1 · Mod ID `PZBackupAHLR` · Workshop ID `3821180981` · [MIT](LICENSE) license · Build 42

You spent three weeks building the perfect base. Double fence, farm, generator,
enough canned beans to survive the apocalypse twice. Then you opened one door
without looking and... yeah. We've all been there.

**PZ Backup** copies your save **while you play** — automatically every 5 minutes,
and whenever you hit **F8**. Died? It restores the latest backup, reopens the game,
and you just click **Continue**. No terminal, no copying folders by hand, no crying
on Discord.

> "Isn't that cheating?" — It's *your* game. Play it however makes you happy.
> Want it hardcore? Turn auto-restore off in the options. 😉

---

## What it does

| Feature | How it works |
|---|---|
| 🕐 **Automatic backup** | Every 5 min, only while the game is running |
| ⌨️ **Backup right now** | **F8** in game |
| ⏪ **Restore from the game** | **F9** (or *Options → Mods → PZ Backup*): pick a backup, the game closes, restores and reopens by itself |
| 💀 **Died? Undo!** | 10 s countdown, then the latest backup of **that world** is restored. Then just **Continue** |
| 🛡️ **No zombie-fying your backups** | No backups are taken while your character is dead — the good ones stay safe |
| 🧹 **Auto cleanup** | When the game closes, the dead character's save leaves the *Load* list (it's kept, relax) |
| 📜 **View log** | In-game button shows everything PZ Backup did, color-coded |
| 🌎 **English & PT-BR** | The mod speaks your game's language |
| 🗂️ **History** | 10 backups per world + 5 replaced saves just in case |
| 🔊 **Beeps** | Two rising beeps = all good. Two falling = something's off |

## How it works (the nerdy part, in 20 seconds)

![How PZ Backup works](docs/img/como-funciona-en.png)

Project Zomboid's Lua runs in a sandbox and **can't copy folders**. So PZ Backup
comes in two parts that pass notes to each other:

1. **The mod** (Workshop or `mods/` folder): keys, windows, on-screen messages, and
   the snitch that tells the script when you die.
2. **The script** (this repository): the muscle. Copies, restores and reopens the
   game. Bash on Linux, PowerShell on Windows.

They talk through `.txt` files in `Zomboid/Lua/` (details at the end).
**The Workshop mod alone doesn't back up anything** — you need the script too.

## You died? Happens. Now what?

![You died? Now what?](docs/img/morreu-en.png)

1. You die. A panel pops up with a **10-second** countdown.
2. You can **Restore now**, **Choose another** backup, or **Cancel** (F9 also cancels
   and opens the list).
3. When the countdown ends, the game closes by itself, the script restores the
   **latest backup of the world you died in**, and the game reopens.
4. On the main menu, click **Continue**. Alive again, a few minutes earlier. We won't
   tell anyone.

> ⚠️ **Bites are forever.** If the latest backup was taken *after* a bite (or with
> 14 zombies on your tail), use **Choose another** and go back one or two.

<!--
## Screenshots

Add the screenshots to docs/img/ with these names and remove this comment:

![Mod options](docs/img/tela-opcoes-en.png)
![F9 window](docs/img/tela-f9-en.png)
![Death panel](docs/img/tela-morte-en.png)
![Log window](docs/img/tela-log-en.png)
-->

---

## Installation

**First things first:** start Project Zomboid at least once so the `Zomboid` folder
exists. Then grab `PZBackup-vX.Y.Z.zip` from
[Releases](https://github.com/ahlrodrigues/PZBackup/releases) and extract it.

> The installers and the script's terminal messages are in Portuguese for now —
> the in-game texts follow your game's language. Commands below are all you need.

### 🐧 Linux (native Steam or Flatpak)

```bash
bash instalar.sh
```

The installer finds your `Zomboid` folder, installs the mod and the script, and
prints the exact command to paste into Steam: right-click **Project Zomboid →
Properties → General → Launch Options**:

```
/home/YOUR_USER/Zomboid/pz-backup.sh jogo %command%
```

That's it: just play through Steam as usual. The script starts with the game and
stops when it closes.

### 🪟 Windows 10/11

Double-click **`instalar.bat`**. If Windows gets suspicious ("unknown publisher"),
click *More info → Run anyway*.

It creates three desktop shortcuts:

| Shortcut | What it's for |
|---|---|
| **Project Zomboid + Backup** | Starts the game with backups on. **Always play through this one.** |
| **PZ Backup - Salvar agora** | Manual backup (also **Ctrl+Alt+B**) |
| **PZ Backup - Restaurar** | Lists your backups and restores the one you pick |

> On Windows, launching straight from Steam does **not** start automatic backups.
> Steam on Windows can't "wrap" the game with a script, so the shortcut does that job.

### Then, in game

Main menu → **Mods** → enable **PZ Backup** (also in your save's mod list).

> **Prefer the Workshop?** [Subscribe to the mod](https://steamcommunity.com/sharedfiles/filedetails/?id=3821180981)
> and use the package just for the script. Don't keep the Workshop mod and the
> `Zomboid/mods/PZBackup` copy at the same time — same Mod ID, they'll fight.

### Requirements

| | Linux | Windows |
|---|---|---|
| Project Zomboid Build 42 | required | required |
| Bash / PowerShell | ships with the OS | ships with Windows 10/11 |
| **Python 3** | **recommended** | not needed |
| `paplay`, `pw-play` or `aplay` | recommended (beeps) | not needed |

**Without Python 3 on Linux** backups still work, but there are no beeps (sounds are
generated with Python) and death detection relies only on the mod. Check with
`python3 --version`.

---

## Using it

### ⌨️ Keys

| Key | What it does |
|---|---|
| **F8** | Back up now. You'll see "Backup requested..." and then "Backup done" |
| **F9** | Restore window (and during the death countdown: cancels it and opens the list) |

Both can be changed in *Options → Mods → PZ Backup*.

### ⏪ Restore a backup of your choice

1. **F9** (or *Options → Mods → PZ Backup → Restore a backup...*).
2. Pick one — **#1 is the newest** — and click **Restore**.
3. Confirm. The game closes, restores and reopens by itself.
4. In *Load*, the restored save is at the top.

**Why does the game have to close?** It only reads the save list on startup.
Restoring while it's open would make the save vanish from the list — not the vibe.

From a terminal, **with the game closed**:

- **Linux:** `pz-backup.sh list`, then `pz-backup.sh restore N`
- **Windows:** the *PZ Backup - Restaurar* shortcut

### 🔌 After restoring: check your mods

The save comes back **with the mod list it had when the backup was taken**. When
loading: *Load → your save → Mods*. Re-enable **PZ Backup** and your other mods. If
F8/F9 go silent, disable and re-enable PZ Backup in that save.

### 📍 Where the restored save shows up

With the world's **original name** — the backup date is dropped:

| | Example |
|---|---|
| Backup | `BackupsSaves/Sandbox__2026-10-06_13-54-21__2026-10-14_14-20-51` |
| Restored to | `Saves/Sandbox/2026-10-06_13-54-21` |

And yes, the world name is the date it was **created**. If you see "13" there, it's
1 PM, not the 13th. (We got confused too.)

The backup stays in `BackupsSaves`, and the save that was there before (the dead
one) goes to `BackupsSaves/substituidos/`. Nothing disappears by accident.

### 🧹 Dead-save cleanup

With this option on (default), **when the game closes** the save where your
character died leaves the *Load* list. It isn't deleted right away: it goes to
`substituidos/` (the 5 most recent are kept).

| | How it works |
|---|---|
| Toggle | *Options → Mods → PZ Backup → "Remove dead-character saves..."* |
| When | Only after the game closes. Never mid-game |
| New character in the same world | The save stays. It only goes if **every** character in it is dead |
| Multiplayer | `Saves/Multiplayer` is never touched |
| Mod not enabled | Nothing is removed |

How it knows you died: on **Linux** it reads each save's `players.db` (with
Python 3) — it even catches old saves of dead characters. On **Windows** it uses the
mod's death notice. To clean up right now, with the game closed:
`pz-backup.sh limpar` / `pz-backup.ps1 limpar`.

### 📜 View log

**View log** button in the F9 window or in *Options → Mods → PZ Backup → View log...*
Shows the last 150 lines, newest first, color-coded:

| Color | Meaning |
|---|---|
| 🟢 Green | Automatic/final backup, all good |
| 🔵 Blue | Backup from F8 or a shortcut |
| 🟡 Yellow | Restore or cleanup |
| 🔴 Red | Failure, dead character, something went wrong |

From a terminal: `pz-backup.sh log` (or `pz-backup.ps1 log`). The full log lives in
`BackupsSaves/pz-backup.log`.

| Tag | Source |
|---|---|
| `[AUTO]` | Every-5-minutes backup |
| `[MOD]` | F8 key |
| `[MANUAL]` | System shortcut or `save` command |
| `[FINAL]` | When the game closes |
| `[RESTORE]` | Restore |
| `[CLEANUP]` | Dead save removed from *Load* |

---

## Options and settings

**In game** (*Options → Mods → PZ Backup*): F8/F9 keys, restore on death, remove
dead saves, *Restore a backup...* and *View log...* buttons.

**At the top of the script** (`pz-backup.sh` or `pz-backup.ps1`):

| Variable | Default | What for |
|---|---|---|
| `INTERVALO` / `$Intervalo` | 5 | Minutes between automatic backups |
| `MANTER` / `$Manter` | 10 | Backups kept per world |
| `MANTER_SUBST` / `$ManterSubst` | 5 | Replaced saves kept |
| `SOM` / `$Som` | on | Beeps |
| `APAGAR_MORTOS` / `$ApagarMortos` | empty | Empty = follow the mod; `1` always; `0` never |
| `IDIOMA` / `$Idioma` | empty | Empty = follow the mod; `pt` or `en` to force |

## Where things live

| What | Linux | Windows |
|---|---|---|
| Backups and log | `~/Zomboid/BackupsSaves/` | `%USERPROFILE%\Zomboid\BackupsSaves\` |
| Script | `~/Zomboid/pz-backup.sh` | `%USERPROFILE%\Zomboid\pz-backup.ps1` |
| Mod | `~/Zomboid/mods/PZBackup/` | `%USERPROFILE%\Zomboid\mods\PZBackup\` |

On Flatpak Steam without home access, use `~/.var/app/com.valvesoftware.Steam/Zomboid`
instead of `~/Zomboid` (the installer figures it out).

---

## Something broke? 🔧

| Symptom | What to do |
|---|---|
| F8 does nothing | Look for `PZBackup` in `Zomboid/console.txt` — you should see `[PZBackup] carregado`. Check the mod is enabled **in the save** |
| "Backup requested" and nothing happens | The script isn't running. Linux: check the launch option. Windows: play through the *Project Zomboid + Backup* shortcut |
| "Backup script is not running" | Same as above 👆 |
| (Linux) The game won't start | Remove the launch option and run `chmod +x ~/Zomboid/pz-backup.sh` |
| (Windows) Shortcut opens and closes | Run `instalar.bat` again |
| Restored save doesn't show up | The game was open during the restore. Close and reopen it |
| "Close Project Zomboid before restoring" | Really close it (main menu isn't enough) or use F9 |
| F8/F9 silent after a restore | Re-enable PZ Backup in *Load → save → Mods* |
| Red error counter in game | Check `Zomboid/console.txt`. If the error doesn't mention `PZBackup`, it's another mod |

Bug hunting: `grep -an -B3 -A10 "PZBackup" ~/Zomboid/console.txt | tail -60`

---

## Under the hood: how the mod and the script talk

Through text files in `Zomboid/Lua/`:

| File | Direction | Content |
|---|---|---|
| `pzbackup_pedido.txt` | mod → script | backup request (F8) |
| `pzbackup_restaurar.txt` | mod → script | backup to restore on exit, or `AUTO mode/world` |
| `pzbackup_estado.txt` | mod → script | `vivo`, `morto`, `restaurado` or `limpo` + `mode/world` |
| `pzbackup_config.txt` | mod → script | `apagar_mortos=1/0`, `idioma=pt/en` |
| `pzbackup_status.txt` | script → mod | `id\|ok\|message` or `id\|erro\|message` |
| `pzbackup_lista.txt` | script → mod | available backups: `name\|label` |
| `pzbackup_ativo.txt` | script → mod | script heartbeat (every 1 s) |
| `pzbackup_log.txt` | script → mod | last 150 log lines (for *View log*) |

---

Made with ☕ and way too many pointless deaths in Muldraugh.
[MIT](LICENSE) © Antonio Henrique (ahlrodrigues)
