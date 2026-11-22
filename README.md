# 🕹️ Arcade Games

Games and SD card catalog of the **Arcade6502**, the cabinet version of the miniVIC (W65C02S, TMS9918A,
2x AY-3-8910, a single JAMMA interface with the controls of both players, no keyboard), run by the
[Arcade BIOS](https://github.com/Boogs77/arcade_bios) front-end.

This repository holds:
- `arcade.json`: the list of the cabinet games with their texts, pictures, save zones, controls and credit
  settings, read by [bo6502-SDbuilder](https://github.com/Boogs77/bo6502-SDbuilder) to build the cabinet SD card;
- `previews/`: the gameplay picture of every entry;
- `tools/check_catalog.py`: checks `arcade.json` and prints the game pages as the front-end shows them;
- `games/`: the games adapted from [miniVIC_games](https://github.com/Boogs77/miniVIC_games) for the cabinet
  (credits, START, button 3), built into `bin/`;
- `lib/arcade.asm`: the common library of the cabinet games (vasm);
- `tools/build.ps1`, `tools/arcade_sim.js`: build and test the games.

---

## 🎬 Videos

Five-minute explanatory videos, in Italian and English, with subtitles. Click a picture to watch the video on YouTube.

**The Arcade6502 cabinet: front-end, credits and catalog**

<table><tr>
<td align="center"><a href="https://youtu.be/8jpY8511fZo"><img src="https://img.youtube.com/vi/8jpY8511fZo/mqdefault.jpg" width="300" alt="The Arcade6502 cabinet: front-end, credits and catalog (Italiano)"></a><br>Italiano</td>
</tr></table>

## 📋 The catalog: `arcade.json`

```json
{
  "format": "arcade-catalog", "version": 1,
  "title": "MINIVIC ARCADE",
  "songs": "all",
  "entries": [
    {
      "id": "dune_ranger",
      "name": "Dune Ranger",
      "kind": "game",
      "bin": { "source": "minivic", "file": "dune_ranger.bin" },
      "zone": 28,
      "inspired": "Moon Patrol",
      "maker": "Original game",
      "players": "1-2",
      "description": "An original side-scrolling rover game ...",
      "preview": "previews/dune_ranger.png",
      "controls": { "buttons": 2, "start": false },
      "credits": { "mode": "launch", "default": "free", "coins": 1 }
    }
  ]
}
```

| Field | Meaning |
| :--- | :--- |
| `title` | cabinet title, at most 31 characters (catalog header `+16`) |
| `songs` | `"all"`: the SD also gets all the songs of the SDbuilder (`songs.txt`), played by the Jukebox |
| `id` | file name of the entry, a stable key |
| `name` | name in the front-end list, at most 23 characters |
| `kind` | `game` or `music` (the Jukebox) |
| `bin.source` | `minivic` = `bin/` of miniVIC_games (unchanged games), `apps` = `bin/` of miniVIC_apps, `arcade` = `bin/` of this repository |
| `bin.file` | the program, loaded at `$0FD0` with entry `$0FD0`, like on the miniVIC SD |
| `zone` | fixed save zone of the game (records, saved games); an adapted game keeps the zone of its miniVIC version; `null` for music |
| `inspired`, `maker`, `players` | lines 0 and 1 of the game page (see below) |
| `description` | free text, wrapped at 30 columns, at most 14 lines |
| `preview` | gameplay picture: 8-bit RGB/RGBA PNG, 512x384 or 256x192, reduced to 128x96 on the SD |
| `controls.buttons` | buttons used by the game (1-3) |
| `controls.start` | the game reads START itself |
| `credits.mode` | `launch`: the front-end asks for a credit before starting the game (games not adapted yet); `game`: the game handles coins and START itself |
| `credits.default` | `free` (free play) or `coin`: factory setting, the SERVICE menu can change it per game |
| `credits.coins` | coins for one credit: always 1 |

The front-end lists the entries in **alphabetical order** of `name`, with the music entry last: the order in the
file does not matter.

### 📄 Game page

Lines 0 and 1 are built from `inspired`, `maker` and `players`, then come the description lines:

| Case | Line 0 | Line 1 |
| :--- | :--- | :--- |
| `inspired` set | `Inspired by: <inspired>` (or `After <inspired>` if longer than 31) | `<maker> - Players: <players>` |
| no `inspired` | `<maker>` | `Players: <players>` |
| `kind` = `music` | as above | `<players>` as it is (e.g. `Music player`) |

`tools/check_catalog.py` is the reference implementation (`header_lines`, `wrap`).

---

## 💾 Building the cabinet SD (bo6502-SDbuilder)

The cabinet SD is separate from the full miniVIC SD (`update_sd.py --mode full` does not change):

1. BOGS directory with the programs of `arcade.json` only, plus the songs when `songs` is `"all"`
   (no applications, no keyboard versions).
2. Arcade catalog from sector `24576` (`$00C00000`), format of the Arcade BIOS
   ([`ARCADE.md`](https://github.com/Boogs77/arcade_bios/blob/main/ARCADE.md) of arcade_bios):
   header `"ARCD"`, index of 32 bytes per entry, page of 8 sectors per entry (text, 128x96 preview patterns
   and colours). Entries sorted as described above; the slot of each entry is its real SD slot.
3. The save area (from sector `32768`) is never written.

With catalog version 2 the SD also stores `controls` and `credits` (index byte `+3`: bit 0 `credits.default` is
`coin`, bit 1 `credits.mode` is `game`, bit 2 `controls.start`, bit 3 three buttons) and `zone` (index byte `+4`,
0 = none). The Arcade BIOS uses them for the credits, FREE PLAY or COIN per game. The full layout is in the
[bo6502-SDbuilder](https://github.com/Boogs77/bo6502-SDbuilder#arcade-sd-the-arcade6502-cabinet) README.

---

## 🔧 Checking the catalog

```sh
python tools/check_catalog.py                      # errors and warnings, exit code 1 on errors
python tools/check_catalog.py --show dune_ranger   # print one game page (or --show all)
```

The binaries are looked up in the sibling folders `../MiniVIC Games/bin` and `../MiniVIC Apps/bin`
(options `--minivic`, `--apps`, `--arcade`).

---

## 🎮 Cabinet controls

| Input | Use |
| :--- | :--- |
| START | starts a game (P1 START = 1 player, P2 START = 2 players, in adapted games) |
| BUTTON 1, 2 | as on the miniVIC |
| BUTTON 3 | when a game needs it |
| COIN P1 / P2 | one coin = one credit, at most 9 (counted by the Arcade BIOS); FREE PLAY is chosen per game in the system test |
| P1 START + P2 START for 2 s | back to the front-end (Arcade BIOS) |

---

## 👾 Adapted games

| Game | Zone | Button 3 | Notes |
| :--- | :---: | :--- | :--- |
| 1vs1 | 2 | shoots or jumps, like button 1 | P1 START = 1 player against the computer, P2 START = 2 players; START works during the title music |
| Asteroids | 8 | thrust, like UP (the THRUST button of the original) | |
| Breakout | 7 | serves, like buttons 1 and 2 | |
| Brick Drop | 54 | - | |
| Bubbles | 20 | - | |
| Centipede | 3 | fires, like buttons 1 and 2 | START works during the title music |
| Cheese Chase | 51 | - | |
| Cloud Raider | 23 | - | |
| Core Runner | 26 | - | |
| Crystal Gardens | 24 | - | records RAM moved to `$0D00` (sector buffer over the player blocks) and `$0F00` to make room for the library |
| Deep Space Miner | 27 | - | |
| Defender | 11 | hyperspace (today buttons 1 and 2 together) | |
| Dune Ranger | 28 | - | |
| Exerion | 19 | - | |
| Ghost & Ghust | 31 | - | |
| Gravitar | 16 | thrust, like UP (the THRUST button of the original) | |
| Haunted Keep | 52 | shoots the bow, like button 1 | |
| Hedge Hop | 40 | - | |
| Joust | 18 | flaps, like button 1 | |
| Lighthouse Keeper | 42 | jumps, like button 1 | |
| Lix | 50 | - | |
| Lunar Lander | 5 | main engine, like UP and the other buttons | screen copy moved to `$4800` to make room for the library |
| Missile Command | 4 | fires from the right base | on the cabinet buttons 1-3 = left, centre, right base as on the original (an empty base: the nearest one); elsewhere button 1 = nearest, 2 = centre |
| Mole Hole | 41 | ice ray, like button 1 | |
| Moon Cresta | 14 | fires and retro rockets, like button 1 | |
| Paint Duel | 43 | sprint, like button 1 | P1 START = 1 player against the computer, P2 START = 2 players |
| Pastry Panic | 53 | icing sugar, like button 1 | |
| Quantum | 17 | brakes, like buttons 1 and 2 | |
| Radar Scope | 12 | laser, like button 1 | |
| Robert | 22 | long jump, like button 1 | the first round has no enemies, as on the miniVIC: a game left alone does not end |
| Robo Vac | 38 | - | |
| Room | 34 | - | |
| Sky Squirrel | 33 | - | |
| Sky Tug | 29 | - | |
| Space Firebird | 13 | - | |
| Space Invaders | 9 | fires, like buttons 1 and 2 | pilot game; CREDIT also on the bottom row during the game, as on the cabinet |
| Special Forces | 25 | - | |
| Stargate | 15 | hyperspace (today buttons 1 and 2 together) | |
| Super Carlo | 30 | jumps, like button 1 | |
| Tank | 1 | fires, like button 2 | P1 START = 1 player against the computer, P2 START = 2 players; START works during the title music |
| The Warriors | 6 | special move (today buttons 1 and 2 together) | P1 START = 1 player against the computer, P2 START = 2 players |
| Turbo Horizon | 55 | - | |
| Warlords | 10 | catches and throws, like buttons 1 and 2 | START works during the demo of the four computers and on the table of the records |
| Wormer | 32 | - | |

Little 6502 Guy, Times Tables and the three Zork adventures have no game to start with START: they stay as on
the miniVIC, in `launch` mode (the Arcade BIOS takes the credit when they are chosen in the menu).

Every adapted game works the same way:
- **title**: `INSERT COIN`, `PRESS 1P START` (one credit), `PRESS 1P OR 2P START` (two credits or more, or
  free play) and `CREDIT 0n` / `FREE PLAY`; **P1 START** = 1 player (1 credit), **P2 START** = 2 players
  (2 credits); a coin inserted during the game updates the credit shown;
- **inputs**: 8 bits (UP, DOWN, LEFT, RIGHT, BUTTON 1-3, START) instead of the 6 of the miniVIC;
- **game over**: back to the title after 10 s if nobody presses a button (attract mode);
- same save zone as the miniVIC game, so the records stay the same;
- without the credit entries of the Arcade BIOS the game runs in free play, and on a miniVIC
  (no Arcade BIOS) BUTTON 1 = 1 player, BUTTON 2 = 2 players.

### 📚 `lib/arcade.asm`

| Routine | Use |
| :--- | :--- |
| `ARC_INIT` | A = most players of the game (1-2): finds the Arcade BIOS and its credits |
| `ARC_JOY` | A = player 1, X = player 2, 1 = pressed (bit 6 BUTTON 3, bit 7 START on the cabinet) |
| `ARC_START` | at every frame of the title: A = players of the game that starts (credits taken, also kept in `ARC_PLAYERS`), 0 = none |
| `ARC_STATE` | C = 1 when the texts changed: `ARC_MSG` points to the title line (20 characters), `ARC_CTXT` is the credit line (9 characters) |
| `ARC_DIRTY`, `ARC_HOLD` | draw the texts again at the next `ARC_STATE`; the buttons held now are not new presses |
| `ARC_TSET`, `ARC_TICK` | a timer of A/X frames; `ARC_TICK` at every frame gives C = 1 when it is over (GAME OVER back to the title) |

The game gives 24 bytes of free RAM in `ARC_VAR` (`$07C0` in the adapted games) and includes the library with `include "../lib/arcade.asm"`.
It uses the Arcade BIOS entries `JT_ARC_CREDITS` (`$FD86`: A = credits, C = 1 free play) and
`JT_ARC_USE_CREDIT` (`$FD89`: A = credits to take, C = 1 not enough).

### 🔨 Build and test

```sh
powershell -File tools/build.ps1                  # all the games of games/ into bin/
powershell -File tools/build.ps1 space_invaders   # one game
```

The path of `vasm6502_oldstyle.exe` goes in the first line of `vasm.path` (not in git) or in the `VASM`
variable. `tools/arcade_sim.js` is the headless emulator of miniVIC_games (`tools/minivic.js`) with the
Arcade BIOS entries, the COIN inputs and the credits counted at every NMI. `node tools/test_credits.js [game ...]`
runs every adapted game in it: no start without credits, one coin = one credit, P2 START needs two credits, at
most 9 credits, free play, Arcade BIOS without credits, miniVIC buttons, and back to the title after GAME OVER.

---

## ⚖️ Disclaimer

The games in this repository are the cabinet versions of the [miniVIC_games](https://github.com/Boogs77/miniVIC_games),
**fan-made tributes** to classic arcade games, written from scratch in 65C02 assembly as a **non-commercial,
educational and demonstration project**.

* All titles, characters, artwork, sounds and trademarks of the original games (such as *Asteroids*, *Breakout*,
  *Bubbles*, *Centipede*, *Defender*, *Exerion*, *Gravitar*, *Joust*, *Lunar Lander*, *Missile Command*,
  *Moon Cresta*, *Quantum*, *Radar Scope*, *Space Firebird*, *Space Invaders*, *Stargate*, *Street Fighter* and
  *Warlords*) belong to their **respective owners**. Their names, and the maker and year in `arcade.json`, are used
  only to identify the games that inspired these versions.
* This project is **not affiliated with, endorsed or sponsored by** any of the rights holders, and claims no rights
  over the original games.
* No original program code or ROM data has been used: graphics and sounds are new re-creations, and the pictures in
  `previews/` are screenshots of these versions. The Zork I-III story files are not in this repository: they come
  from bo6502-SDbuilder, which puts them on the SD card under the MIT License that Microsoft released them with.
  *Zork* is a trademark of its owner.
* The songs of the MiniVIC Jukebox are described in the credits of
  [bo6502-SDbuilder](https://github.com/Boogs77/bo6502-SDbuilder#credits).
* No commercial use is intended. If you are a rights holder and have any concern, please
  [open an issue](https://github.com/Boogs77/arcade_games/issues) and the material will be reviewed or removed promptly.

---

*Created by Boogs77 - 2026*
