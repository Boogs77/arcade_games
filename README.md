# 🕹️ Arcade Games

Games and SD card catalog of the **Arcade6502**, the cabinet version of the miniVIC (W65C02S, TMS9918A,
2x AY-3-8910, two JAMMA control panels, no keyboard), run by the
[Arcade BIOS](https://github.com/Boogs77/arcade_bios) front-end.

This repository holds:
- `arcade.json`: the list of the cabinet games with their texts, pictures, save zones, controls and credit
  settings, read by [bo6502-SDbuilder](https://github.com/Boogs77/bo6502-SDbuilder) to build the cabinet SD card;
- `previews/`: the gameplay picture of every entry;
- `tools/check_catalog.py`: checks `arcade.json` and prints the game pages as the front-end shows them;
- later: the common library for arcade games (`lib/`), the games adapted from
  [miniVIC_games](https://github.com/Boogs77/miniVIC_games) and new games (vasm).

---

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
| `credits.coins` | coins for one credit (1-9) |

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
2. Arcade catalog from sector `24576` (`$00C00000`), format of the Arcade BIOS (`ARCADE.md` of arcade_bios):
   header `"ARCD"`, index of 32 bytes per entry, page of 8 sectors per entry (text, 128x96 preview patterns
   and colours). Entries sorted as described above; the slot of each entry is its real SD slot.
3. The save area (from sector `32768`) is never written.

Not stored on the SD yet (catalog version 1): `zone`, `controls` and `credits`. They will go into the unused
index bytes `+3`-`+5` with catalog version 2, together with the credits and the SERVICE menu of the Arcade BIOS.

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
| COIN P1 / P2 | credits (coming: the front-end ignores them for now, free play) |
| P1 START + P2 START for 2 s | back to the front-end (Arcade BIOS) |

---

*Created by Boogs77 - 2026*
