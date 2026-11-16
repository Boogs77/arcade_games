'use strict';
// arcade_sim.js - the minimal emulator of tools/minivic.js as an Arcade6502 cabinet
//
// Adds what the games of this repository need from the Arcade BIOS:
//   $FD80 JT_ARC_INPUTS      A = P1, X = P2 (8 bits, 1 = pressed), Y = bit 0 COIN 1, bit 1 COIN 2
//   $FD83 JT_ARC_SILENCE     does nothing (no audio here)
//   $FD86 JT_ARC_CREDITS     A = credits (0-9), C = 1 free play
//   $FD89 JT_ARC_USE_CREDIT  A = credits to take: C = 0 taken (free play: nothing taken), C = 1 not enough
// The credits are counted like the BIOS will: at every NMI a COIN that was not pressed at the
// previous NMI gives one credit, up to 9 (opts.credits = false: an Arcade BIOS without credits).
// Inputs: sim.joy[0] / sim.joy[1] (bits of ARC_JOY), sim.coin[0] / sim.coin[1] (true = pressed).

const { MiniVIC } = require('./minivic');

const C = 0x01;

class ArcadeSim extends MiniVIC {
  constructor(bin, opts = {}) {
    super(bin, 0x0FD0, 0x1000, opts);
    this.free = !!opts.free;
    this.credits = opts.startCredits || 0;
    this.coin = [false, false];
    this.prevCoin = [false, false];
    this.lastNmi = false;
    this.nmiCount = 0;
    const entries = opts.credits === false ? [0xFD80, 0xFD83] : [0xFD80, 0xFD83, 0xFD86, 0xFD89];
    for (const a of entries) this.mem.set([0x4C, a & 0xFF, a >> 8], a);
    this.arcEntries = new Set(entries);
  }
  checkNmi() {
    const irq = this.vdp.irq();
    if (irq && !this.lastNmi) {                    // the NMI of the BIOS samples the coins
      this.nmiCount++;
      for (let i = 0; i < 2; i++) {
        if (this.coin[i] && !this.prevCoin[i] && this.credits < 9) this.credits++;
        this.prevCoin[i] = this.coin[i];
      }
    }
    this.lastNmi = irq;
    super.checkNmi();
  }
  trySd() {
    const cpu = this.cpu, pc = cpu.pc;
    if (!this.arcEntries.has(pc)) return super.trySd();
    if (pc === 0xFD80) {
      cpu.a = this.joy[0] & 0xFF; cpu.x = this.joy[1] & 0xFF;
      cpu.y = (this.coin[0] ? 1 : 0) | (this.coin[1] ? 2 : 0);
    } else if (pc === 0xFD86) {
      cpu.a = this.credits; cpu.flag(C, this.free);
    } else if (pc === 0xFD89) {
      const n = cpu.a;
      if (this.free) cpu.flag(C, false);
      else if (this.credits >= n) { this.credits -= n; cpu.flag(C, false); }
      else cpu.flag(C, true);
    }
    cpu.pc = ((cpu.pull() | (cpu.pull() << 8)) + 1) & 0xFFFF;
    cpu.cycles += 60;
    return true;
  }
}

module.exports = { ArcadeSim };
