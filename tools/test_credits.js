'use strict';
// test_credits.js - checks credits and START of the adapted games in tools/arcade_sim.js
//
//   node tools/test_credits.js space_invaders breakout ...   (no names: every game of games/)
//
// Every game is assembled again with a listing (vasm, path in vasm.path or VASM) to find the
// addresses of TITLE, NEW_GAME (or SELECT) and NPL or CPU_ON (players, 2-player games). Checks:
//   coins:  START without credits does nothing; one coin = one credit; P2 START needs 2 credits;
//           P1 START with a credit starts and takes it; at most 9 credits
//   free play, Arcade BIOS without credits, miniVIC (BUTTON 1 / BUTTON 2) start the game
//   game over: with nobody at the controls (button 1 every 2 s) the game goes back to TITLE by itself
// The title screens go to dev/shots/<game>_*.png when the folder dev/ exists.
// GAME_OVER_MIN = minutes of play allowed for the game over (default 12; Warlords needs about 20).

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { ArcadeSim } = require('./arcade_sim');
const { MiniVIC } = require('./minivic');

const ROOT = path.join(__dirname, '..');
const START = 0x80, B1 = 0x10, B2 = 0x20;
const GAME_OVER_FRAMES = 60 * 60 * (+process.env.GAME_OVER_MIN || 12);   // minutes of play without anybody
// games that never end while nobody moves (Robert: no enemies on the first round): a hop every 2 s too
const IDLE_MOVE = { robert: 0x02 };

function vasmPath() {
  if (process.env.VASM) return process.env.VASM;
  return fs.readFileSync(path.join(ROOT, 'vasm.path'), 'utf8').split(/\r?\n/)[0].trim();
}

function build(name) {
  const tmp = fs.mkdtempSync(path.join(require('os').tmpdir(), 'arc-'));
  const bin = path.join(tmp, name + '.bin'), lst = path.join(tmp, name + '.lst');
  execFileSync(vasmPath(), ['-Fbin', '-dotdir', '-c02', '-quiet', '-o', bin, '-L', lst, name + '.asm'],
    { cwd: path.join(ROOT, 'games'), stdio: ['ignore', 'ignore', 'inherit'] });
  const sym = {};
  const text = fs.readFileSync(lst, 'latin1');
  const part = text.slice(text.indexOf('Symbols by name:'), text.indexOf('Symbols by value:'));
  for (const m of part.matchAll(/^(\w+)\s+\w:([0-9A-F]+)/gm)) sym[m[1]] = parseInt(m[2], 16);
  const data = fs.readFileSync(bin);
  fs.rmSync(tmp, { recursive: true, force: true });
  return { data, sym };
}

// the simulator, with a watch on the addresses: hit[name] = frame of the first visit after reset()
function watch(m, sym) {
  const names = ['TITLE', 'NEW_GAME', 'SELECT'].filter(n => sym[n] !== undefined);
  const at = new Map(names.map(n => [sym[n], n]));
  m.hit = {};
  const orig = m.trySd.bind(m);
  m.trySd = () => {
    const n = at.get(m.cpu.pc);
    if (n && m.hit[n] === undefined) m.hit[n] = m.frame;
    return orig();
  };
  return m;
}

function testGame(name) {
  const { data, sym } = build(name);
  const src = fs.readFileSync(path.join(ROOT, 'games', name + '.asm'), 'latin1');
  const maxp = +(src.match(/LDA #\$0([12])\s*\r?\n\s*JSR ARC_INIT/) || [0, 1])[1];
  const shots = fs.existsSync(path.join(ROOT, 'dev')) ? path.join(ROOT, 'dev', 'shots') : null;
  if (shots) fs.mkdirSync(shots, { recursive: true });
  const run = (m, n) => { for (let i = 0; i < n; i++) m.runFrame(); };
  const press = (m, p, bits) => { m.joy[p] |= bits; run(m, 6); m.joy[p] &= ~bits; run(m, 6); };
  const coin = (m, p) => { m.coin[p] = true; run(m, 3); m.coin[p] = false; run(m, 3); };
  const shot = (m, n) => shots && fs.writeFileSync(path.join(shots, `${name}_${n}.png`), m.vdp.png(2));
  const started = m => m.hit.NEW_GAME !== undefined || m.hit.SELECT !== undefined;
  // players: NPL, or CPU_ON (1 = one player against the computer) in the duel games
  const players = m => sym.NPL !== undefined ? m.mem[sym.NPL] : (m.mem[sym.CPU_ON] ? 1 : 2);
  const fails = [];
  const check = (c, t) => { if (!c) fails.push(t); };
  const TITLE_WAIT = 400;                         // intro tunes: the title must be ready by then

  // coins
  let m = watch(new ArcadeSim(data), sym);
  run(m, TITLE_WAIT); shot(m, 'coin0');
  press(m, 0, START); run(m, 30);
  check(!started(m), 'P1 START without credits starts');
  coin(m, 0); run(m, 30); shot(m, 'coin1');
  check(m.credits === 1, 'one coin is not one credit');
  if (maxp === 2) {
    press(m, 1, START); run(m, 30);
    check(!started(m) && m.credits === 1, 'P2 START with 1 credit starts');
    coin(m, 1); run(m, 30); shot(m, 'coin2');
    press(m, 1, START); run(m, 60);
    check(started(m) && m.credits === 0 && players(m) === 2, 'P2 START with 2 credits: no 2-player game');
  } else {
    press(m, 0, START); run(m, 60);
    check(started(m) && m.credits === 0, 'P1 START with 1 credit: no game');
  }
  for (let i = 0; i < 12; i++) coin(m, 0);
  check(m.credits === 9, 'more than 9 credits');

  // one player with a credit (2-player games)
  if (maxp === 2) {
    m = watch(new ArcadeSim(data), sym);
    run(m, TITLE_WAIT); coin(m, 0); press(m, 0, START); run(m, 60);
    check(started(m) && m.credits === 0 && players(m) === 1, 'P1 START with 1 credit: no 1-player game');
  }
  // game over of that 1-player game: nobody at the controls (the computer wins the duels)
  m.hit.TITLE = undefined;
  let f = 0;
  while (m.hit.TITLE === undefined && f < GAME_OVER_FRAMES) {
    m.joy[0] = m.joy[1] = f % 120 < 4 ? B1 : f % 120 < 8 ? (IDLE_MOVE[name] || 0) : 0;   // button 1 every 2 s: games that wait for a serve
    m.runFrame(); f++;
  }
  m.joy[0] = m.joy[1] = 0;
  check(m.hit.TITLE !== undefined, `no way back to the title in ${GAME_OVER_FRAMES / 3600} minutes`);
  run(m, 300); shot(m, 'after');
  // free play
  m = watch(new ArcadeSim(data, { free: true }), sym);
  run(m, TITLE_WAIT); shot(m, 'free');
  press(m, maxp === 2 ? 1 : 0, START); run(m, 60);
  check(started(m) && (maxp === 1 || players(m) === 2), 'free play: START does not start');
  // Arcade BIOS without credits
  m = watch(new ArcadeSim(data, { credits: false }), sym);
  run(m, TITLE_WAIT);
  press(m, 0, START); run(m, 60);
  check(started(m), 'BIOS without credits: START does not start');
  // miniVIC
  m = watch(new MiniVIC(data), sym);
  run(m, TITLE_WAIT); shot(m, 'minivic');
  press(m, 0, maxp === 2 ? B2 : B1); run(m, 60);
  check(started(m) && (maxp === 1 || players(m) === 2), 'miniVIC: the buttons do not start');

  const end = 0x0FD0 + data.length;
  console.log(`${fails.length ? 'FAIL' : 'OK  '} ${name.padEnd(18)} ${maxp}P  code to $${end.toString(16).toUpperCase()}` +
    `  game over -> title in ${(f / 60).toFixed(0)} s` + (fails.length ? '\n       ' + fails.join('\n       ') : ''));
  return fails.length === 0;
}

const names = process.argv.slice(2);
const list = names.length ? names : fs.readdirSync(path.join(ROOT, 'games')).filter(f => f.endsWith('.asm')).map(f => f.slice(0, -4));
let ok = true;
for (const n of list) ok = testGame(n) && ok;
process.exit(ok ? 0 : 1);
