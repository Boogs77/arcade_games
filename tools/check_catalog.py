#!/usr/bin/env python3
"""Checks arcade.json, the catalog of the Arcade6502 SD card, and shows the game pages as the
Arcade BIOS will draw them.

    python tools/check_catalog.py                  # check everything, print a summary
    python tools/check_catalog.py --show dune_ranger   # also print the text page of one entry
    python tools/check_catalog.py --show all       # every page

The binaries are looked up in the folders of --minivic, --apps and --arcade (defaults: the
sibling folders ../MiniVIC Games/bin, ../MiniVIC Apps/bin and bin/ of this repository).
Exit code 0 = no errors (warnings allowed), 1 = errors.
"""
import argparse, json, re, struct, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEXT_COLS, DESC_LINES, LINE_MAX, NAME_MAX, TITLE_MAX = 30, 14, 31, 23, 31
KINDS = {'game': 1, 'music': 2}
SOURCES = ('minivic', 'apps', 'arcade')


def wrap(text, cols=TEXT_COLS):
    """words wrapped at `cols` columns (same rule as the catalog writer)"""
    lines, cur = [], ''
    for w in text.split():
        if not cur:
            cur = w[:cols]
        elif len(cur) + 1 + len(w) <= cols:
            cur += ' ' + w
        else:
            lines.append(cur)
            cur = w[:cols]
    if cur:
        lines.append(cur)
    return lines


def header_lines(e):
    """lines 0 and 1 of the page: inspiring game, maker and players"""
    insp, maker, players = e.get('inspired', ''), e.get('maker', ''), e.get('players', '')
    if e['kind'] == 'game' and players:
        players = 'Players: ' + players
    if insp:
        l0 = f'Inspired by: {insp}'
        if len(l0) > LINE_MAX:
            l0 = f'After {insp}'
        l1 = ' - '.join(x for x in (maker, players) if x)
    else:
        l0, l1 = maker, players
    return l0, l1


def page_lines(e):
    """the 16 text lines of the page (line 0, line 1, then the description)"""
    return list(header_lines(e)) + wrap(e.get('description', ''))


def png_size(path):
    """(width, height, bit depth, colour type) of a PNG file"""
    d = path.read_bytes()
    if d[:8] != b'\x89PNG\r\n\x1a\n' or d[12:16] != b'IHDR':
        raise ValueError('not a PNG file')
    w, h, depth, ctype = struct.unpack('>IIBB', d[16:26])
    return w, h, depth, ctype


def check(cat, dirs):
    errors, warnings = [], []
    err = lambda where, msg: errors.append(f'{where}: {msg}')
    warn = lambda where, msg: warnings.append(f'{where}: {msg}')

    if cat.get('format') != 'arcade-catalog' or cat.get('version') != 1:
        err('arcade.json', 'format must be "arcade-catalog", version 1')
    title = cat.get('title', '')
    if not title or len(title) > TITLE_MAX or not title.isascii():
        err('title', f'1-{TITLE_MAX} ASCII characters')
    entries = cat.get('entries', [])
    if not 1 <= len(entries) <= 255:
        err('entries', '1-255 entries')

    ids, zones = set(), {}
    for e in entries:
        where = e.get('id', '?')
        if not re.fullmatch(r'[a-z0-9_]+', where):
            err(where, 'id: lower case letters, digits and _')
        if where in ids:
            err(where, 'duplicate id')
        ids.add(where)
        name = e.get('name', '')
        if not name or len(name) > NAME_MAX or not name.isascii():
            err(where, f'name: 1-{NAME_MAX} ASCII characters ("{name}")')
        if e.get('kind') not in KINDS:
            err(where, 'kind: game or music')
            continue
        b = e.get('bin', {})
        if b.get('source') not in SOURCES:
            err(where, f'bin.source: one of {", ".join(SOURCES)}')
        else:
            f = dirs[b['source']] / b.get('file', '')
            if not f.is_file():
                err(where, f'binary not found: {f}')
            elif f.stat().st_size > 0x7000:
                err(where, f'binary longer than 28 KB: {f.stat().st_size} bytes')
        z = e.get('zone')
        if e['kind'] == 'game':
            if not isinstance(z, int) or not 1 <= z <= 255:
                err(where, 'zone: the fixed save zone, 1-255')
            elif z in zones:
                err(where, f'zone {z} already used by {zones[z]}')
            else:
                zones[z] = where
        elif z is not None:
            err(where, 'zone: null for music')
        for k in ('inspired', 'maker', 'players', 'description'):
            if not e.get(k, '').isascii():
                err(where, f'{k}: ASCII only')
        l0, l1 = header_lines(e)
        for n, l in ((0, l0), (1, l1)):
            if len(l) > LINE_MAX:
                err(where, f'page line {n} longer than {LINE_MAX}: "{l}"')
        if not l0:
            warn(where, 'no inspiring game and no maker: page line 0 is empty')
        desc = wrap(e.get('description', ''))
        if not desc:
            warn(where, 'no description')
        if len(desc) > DESC_LINES:
            err(where, f'description takes {len(desc)} lines, at most {DESC_LINES} of {TEXT_COLS} columns')
        p = ROOT / e.get('preview', '')
        if not e.get('preview'):
            warn(where, 'no preview picture')
        elif not p.is_file():
            err(where, f'preview not found: {e["preview"]}')
        else:
            try:
                w, h, depth, ctype = png_size(p)
                if (w, h) not in ((512, 384), (256, 192)) or depth != 8 or ctype not in (2, 6):
                    err(where, f'preview must be an 8-bit RGB/RGBA PNG of 512x384 or 256x192 ({w}x{h})')
            except ValueError as x:
                err(where, f'preview: {x}')
        c = e.get('controls', {})
        if c.get('buttons') not in (1, 2, 3) or not isinstance(c.get('start'), bool):
            err(where, 'controls: buttons 1-3, start true/false')
        c = e.get('credits', {})
        if c.get('mode') not in ('launch', 'game') or c.get('default') not in ('free', 'coin') \
                or c.get('coins') not in range(1, 10):
            err(where, 'credits: mode launch/game, default free/coin, coins 1-9')
        if c.get('mode') == 'game' and not e.get('controls', {}).get('start'):
            err(where, 'credits.mode "game" needs a game that uses START (controls.start)')
    if not any(e.get('kind') == 'music' for e in entries) and cat.get('songs'):
        warn('songs', 'songs requested but no music entry (Jukebox) in the list')
    return errors, warnings


def show(e):
    print(f'+{"-" * 32}+  {e["name"]} ({e["id"]}, zone {e.get("zone")})')
    for l in page_lines(e):
        print(f'| {l:<30} |')
    print(f'+{"-" * 32}+')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('catalog', nargs='?', default=ROOT / 'arcade.json', type=Path)
    ap.add_argument('--minivic', type=Path, default=ROOT.parent / 'MiniVIC Games' / 'bin')
    ap.add_argument('--apps', type=Path, default=ROOT.parent / 'MiniVIC Apps' / 'bin')
    ap.add_argument('--arcade', type=Path, default=ROOT / 'bin')
    ap.add_argument('--show', metavar='ID', help='print the page of one entry, or "all"')
    a = ap.parse_args()
    cat = json.loads(a.catalog.read_text(encoding='utf8'))
    errors, warnings = check(cat, {'minivic': a.minivic, 'apps': a.apps, 'arcade': a.arcade})
    entries = cat.get('entries', [])
    if a.show:
        for e in entries:
            if a.show in ('all', e.get('id')):
                show(e)
    for w in warnings:
        print('warning:', w)
    for x in errors:
        print('error:', x)
    games = sum(e.get('kind') == 'game' for e in entries)
    print(f'{len(entries)} entries ({games} games), {len(warnings)} warnings, {len(errors)} errors')
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
