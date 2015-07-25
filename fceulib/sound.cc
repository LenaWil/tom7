/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
 */

#include <stdlib.h>
#include <stdio.h>

#include <string.h>

#include "types.h"
#include "x6502.h"

#include "fceu.h"
#include "sound.h"
#include "filter.h"
#include "state.h"
#include "fsettings.h"

static constexpr int RectDuties[4] = {1, 2, 4, 6};

static constexpr uint8 lengthtable[0x20] = {
    10, 254, 20, 2,  40, 4,  80, 6,  160, 8,  60, 10, 14, 12, 26, 14,
    12, 16,  24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30};

static constexpr uint32 NoiseFreqTableNTSC[0x10] = {
    4, 8, 16, 32, 64, 96, 128, 160,
    202, 254, 380, 508, 762, 1016, 2034, 4068};

static constexpr uint32 NoiseFreqTablePAL[0x10] = {
    4, 7, 14, 30, 60, 88, 118, 148,
    188, 236, 354, 472, 708, 944, 1890, 3778};

static constexpr uint32 NTSCDMCTable[0x10] = {
    428, 380, 340, 320, 286, 254, 226, 214,
    190, 160, 142, 128, 106, 84,  72,  54};

/* Previous values for PAL DMC was value - 1, I am not certain if this
   is if FCEU handled PAL differently or not, the NTSC values are
   right, so I am assuming that the current value is handled the same
   way NTSC is handled. */
static constexpr uint32 PALDMCTable[0x10] = {
    398, 354, 316, 298, 276, 236, 210, 198,
    176, 148, 132, 118, 98, 78, 66, 50};

// $4010        -        Frequency
// $4011        -        Actual data outputted
// $4012        -        Address register: $c000 + V*64
// $4013        -        Size register:  Size in bytes = (V+1)*64

void Sound::LoadDMCPeriod(uint8 V) {
  if (fc->fceu->PAL)
    DMCPeriod = PALDMCTable[V];
  else
    DMCPeriod = NTSCDMCTable[V];
}

void Sound::PrepDPCM() {
  DMCAddress = 0x4000 + (DMCAddressLatch << 6);
  DMCSize = (DMCSizeLatch << 4) + 1;
}

/* Instantaneous? Maybe the new freq value is being calculated all of
   the time... */

int Sound::CheckFreq(uint32 cf, uint8 sr) {
  if (!(sr & 0x8)) {
    const uint32 mod = cf >> (sr & 7);
    if ((mod + cf) & 0x800) return 0;
  }
  return 1;
}

void Sound::SQReload(int x, uint8 V) {
  if (EnabledChannels & (1 << x)) {
    if (x)
      (this->*DoSQ2)();
    else
      (this->*DoSQ1)();
    lengthcount[x] = lengthtable[(V >> 3) & 0x1f];
  }

  sweepon[x] = PSG[(x << 2) | 1] & 0x80;
  curfreq[x] = PSG[(x << 2) | 0x2] | ((V & 7) << 8);
  SweepCount[x] = ((PSG[(x << 2) | 0x1] >> 4) & 7) + 1;

  RectDutyCount[x] = 7;
  EnvUnits[x].reloaddec = 1;
  // reloadfreq[x]=1;
}

static DECLFW(Write_PSG) {
  return fc->sound->Write_PSG_Direct(DECLFW_FORWARD);
}

void Sound::Write_PSG_Direct(DECLFW_ARGS) {
  A &= 0x1F;
  switch (A) {
    case 0x0:
      (this->*DoSQ1)();
      EnvUnits[0].Mode = (V & 0x30) >> 4;
      EnvUnits[0].Speed = (V & 0xF);
      break;
    case 0x1: sweepon[0] = V & 0x80; break;
    case 0x2:
      (this->*DoSQ1)();
      curfreq[0] &= 0xFF00;
      curfreq[0] |= V;
      break;
    case 0x3: SQReload(0, V); break;
    case 0x4:
      (this->*DoSQ2)();
      EnvUnits[1].Mode = (V & 0x30) >> 4;
      EnvUnits[1].Speed = (V & 0xF);
      break;
    case 0x5: sweepon[1] = V & 0x80; break;
    case 0x6:
      (this->*DoSQ2)();
      curfreq[1] &= 0xFF00;
      curfreq[1] |= V;
      break;
    case 0x7: SQReload(1, V); break;
    case 0xa: (this->*DoTriangle)(); break;
    case 0xb:
      (this->*DoTriangle)();
      if (EnabledChannels & 0x4) lengthcount[2] = lengthtable[(V >> 3) & 0x1f];
      TriMode = 1;  // Load mode
      break;
    case 0xC:
      (this->*DoNoise)();
      EnvUnits[2].Mode = (V & 0x30) >> 4;
      EnvUnits[2].Speed = (V & 0xF);
      break;
    case 0xE: (this->*DoNoise)(); break;
    case 0xF:
      (this->*DoNoise)();
      if (EnabledChannels & 0x8) lengthcount[3] = lengthtable[(V >> 3) & 0x1f];
      EnvUnits[2].reloaddec = 1;
      break;
    case 0x10:
      (this->*DoPCM)();
      LoadDMCPeriod(V & 0xF);

      if (SIRQStat & 0x80) {
        if (!(V & 0x80)) {
          fc->X->IRQEnd(FCEU_IQDPCM);
          SIRQStat &= ~0x80;
        } else {
          fc->X->IRQBegin(FCEU_IQDPCM);
        }
      }
      break;
  }
  PSG[A] = V;
}

static DECLFW(Write_DMCRegs) {
  return fc->sound->Write_DMCRegs_Direct(DECLFW_FORWARD);
}

void Sound::Write_DMCRegs_Direct(DECLFW_ARGS) {
  A &= 0xF;

  switch (A) {
  case 0x00:
    (this->*DoPCM)();
    LoadDMCPeriod(V & 0xF);

    if (SIRQStat & 0x80) {
      if (!(V & 0x80)) {
	fc->X->IRQEnd(FCEU_IQDPCM);
	SIRQStat &= ~0x80;
      } else {
	fc->X->IRQBegin(FCEU_IQDPCM);
      }
    }
    DMCFormat = V;
    break;
  case 0x01:
    (this->*DoPCM)();
    RawDALatch = V & 0x7F;
    break;
  case 0x02: DMCAddressLatch = V; break;
  case 0x03: DMCSizeLatch = V; break;
  }
}

static DECLFW(StatusWrite) {
  return fc->sound->StatusWrite_Direct(DECLFW_FORWARD);
}

void Sound::StatusWrite_Direct(DECLFW_ARGS) {
  (this->*DoSQ1)();
  (this->*DoSQ2)();
  (this->*DoTriangle)();
  (this->*DoNoise)();
  (this->*DoPCM)();
  /* Force length counters to 0. */
  for (int x = 0; x < 4; x++)
    if (!(V & (1 << x))) lengthcount[x] = 0;

  if (V & 0x10) {
    if (!DMCSize) PrepDPCM();
  } else {
    DMCSize = 0;
  }
  SIRQStat &= ~0x80;
  fc->X->IRQEnd(FCEU_IQDPCM);
  EnabledChannels = V & 0x1F;
}

static DECLFR(StatusRead) {
  return fc->sound->StatusRead_Direct(DECLFR_FORWARD);
}

DECLFR_RET Sound::StatusRead_Direct(DECLFR_ARGS) {
  uint8 ret = SIRQStat;

  for (int x = 0; x < 4; x++) ret |= lengthcount[x] ? (1 << x) : 0;
  if (DMCSize) ret |= 0x10;

  SIRQStat &= ~0x40;
  fc->X->IRQEnd(FCEU_IQFCOUNT);
  return ret;
}

void Sound::FrameSoundStuff(int V) {
  (this->*DoSQ1)();
  (this->*DoSQ2)();
  (this->*DoNoise)();
  (this->*DoTriangle)();

  /* Envelope decay, linear counter, length counter, freq sweep */
  if (!(V & 1)) {
    if (!(PSG[8] & 0x80))
      if (lengthcount[2] > 0) lengthcount[2]--;

    /* Make sure loop flag is not set. */
    if (!(PSG[0xC] & 0x20))
      if (lengthcount[3] > 0) lengthcount[3]--;

    for (int P = 0; P < 2; P++) {
      /* Make sure loop flag is not set. */
      if (!(PSG[P << 2] & 0x20))
        if (lengthcount[P] > 0) lengthcount[P]--;

      /* Frequency Sweep Code Here */
      /* xxxx 0000 */
      /* xxxx = hz.  120/(x+1)*/
      if (sweepon[P]) {
        int32 mod = 0;

        if (SweepCount[P] > 0) SweepCount[P]--;
        if (SweepCount[P] <= 0) {
          SweepCount[P] = ((PSG[(P << 2) + 0x1] >> 4) & 7) + 1;  //+1;
          if (PSG[(P << 2) + 0x1] & 0x8) {
            mod -= (P ^ 1) + ((curfreq[P]) >> (PSG[(P << 2) + 0x1] & 7));
            if (curfreq[P] &&
                (PSG[(P << 2) + 0x1] & 7) /* && sweepon[P]&0x80*/) {
              curfreq[P] += mod;
            }
          } else {
            mod = curfreq[P] >> (PSG[(P << 2) + 0x1] & 7);
            if ((mod + curfreq[P]) & 0x800) {
              sweepon[P] = 0;
              curfreq[P] = 0;
            } else {
              if (curfreq[P] &&
                  (PSG[(P << 2) + 0x1] & 7) /* && sweepon[P]&0x80*/) {
                curfreq[P] += mod;
              }
            }
          }
        }
      } else {
        /* Sweeping is disabled: */
        // curfreq[P]&=0xFF00;
        // curfreq[P]|=PSG[(P<<2)|0x2]; //|((PSG[(P<<2)|3]&7)<<8);
      }
    }
  }

  /* Now do envelope decay + linear counter. */

  if (TriMode)  // In load mode?
    TriCount = PSG[0x8] & 0x7F;
  else if (TriCount)
    TriCount--;

  if (!(PSG[0x8] & 0x80)) TriMode = 0;

  for (int P = 0; P < 3; P++) {
    if (EnvUnits[P].reloaddec) {
      EnvUnits[P].decvolume = 0xF;
      EnvUnits[P].DecCountTo1 = EnvUnits[P].Speed + 1;
      EnvUnits[P].reloaddec = 0;
      continue;
    }

    if (EnvUnits[P].DecCountTo1 > 0) EnvUnits[P].DecCountTo1--;
    if (EnvUnits[P].DecCountTo1 == 0) {
      EnvUnits[P].DecCountTo1 = EnvUnits[P].Speed + 1;
      if (EnvUnits[P].decvolume || (EnvUnits[P].Mode & 0x2)) {
        EnvUnits[P].decvolume--;
        EnvUnits[P].decvolume &= 0xF;
      }
    }
  }
}

void Sound::FrameSoundUpdate() {
  // Linear counter:  Bit 0-6 of $4008
  // Length counter:  Bit 4-7 of $4003, $4007, $400b, $400f

  if (!fcnt && !(IRQFrameMode & 0x3)) {
    SIRQStat |= 0x40;
    fc->X->IRQBegin(FCEU_IQFCOUNT);
  }

  if (fcnt == 3) {
    if (IRQFrameMode & 0x2) fhcnt += fhinc;
  }
  FrameSoundStuff(fcnt);
  fcnt = (fcnt + 1) & 3;
}

void Sound::Tester() {
  if (DMCBitCount == 0) {
    if (!DMCHaveDMA) {
      DMCHaveSample = 0;
    } else {
      DMCHaveSample = 1;
      DMCShift = DMCDMABuf;
      DMCHaveDMA = 0;
    }
  }
}

void Sound::DMCDMA() {
  if (DMCSize && !DMCHaveDMA) {
    fc->X->DMR(0x8000 + DMCAddress);
    fc->X->DMR(0x8000 + DMCAddress);
    fc->X->DMR(0x8000 + DMCAddress);
    DMCDMABuf = fc->X->DMR(0x8000 + DMCAddress);
    DMCHaveDMA = 1;
    DMCAddress = (DMCAddress + 1) & 0x7fff;
    DMCSize--;
    if (!DMCSize) {
      if (DMCFormat & 0x40) {
        PrepDPCM();
      } else {
        SIRQStat |= 0x80;
        if (DMCFormat & 0x80) fc->X->IRQBegin(FCEU_IQDPCM);
      }
    }
  }
}

void Sound::FCEU_SoundCPUHook(int cycles) {
  fhcnt -= cycles * 48;
  if (fhcnt <= 0) {
    FrameSoundUpdate();
    fhcnt += fhinc;
  }

  DMCDMA();
  DMCacc -= cycles;

  while (DMCacc <= 0) {
    if (DMCHaveSample) {
      uint8 bah = RawDALatch;
      int t = ((DMCShift & 1) << 2) - 2;

      /* Unbelievably ugly hack */
      if (FCEUS_SNDRATE) {
        soundtsoffs += DMCacc;
        (this->*DoPCM)();
        soundtsoffs -= DMCacc;
      }
      RawDALatch += t;
      if (RawDALatch & 0x80) RawDALatch = bah;
    }

    DMCacc += DMCPeriod;
    DMCBitCount = (DMCBitCount + 1) & 7;
    DMCShift >>= 1;
    Tester();
  }
}

void Sound::RDoPCM() {
  for (uint32 V = ChannelBC[4]; V < SoundTS(); V++) {
    // TODO get rid of floating calculations to binary. set log volume scaling.
    WaveHi[V] += (((RawDALatch << 16) / 256) * FCEUS_PCMVOLUME) & (~0xFFFF);
  }
  ChannelBC[4] = SoundTS();
}

// TODO PERF: Was inlined before; called only with constant 0 or 1.
/* This has the correct phase.  Don't mess with it. */
// Int x decides if this is Square Wave 1 or 2
void Sound::RDoSQ(int x) {
  int32 V;
  int32 amp, ampx;
  int32 rthresh;
  int32 *D;
  int32 currdc;
  int32 cf;
  int32 rc;

  if (curfreq[x] < 8 || curfreq[x] > 0x7ff) goto endit;
  if (!CheckFreq(curfreq[x], PSG[(x << 2) | 0x1])) goto endit;
  if (!lengthcount[x]) goto endit;

  if (EnvUnits[x].Mode & 0x1) {
    amp = EnvUnits[x].Speed;
  } else {
    // Set the volume of the Square Wave.
    amp = EnvUnits[x].decvolume;
  }

  // Modify Square wave volume based on channel volume modifiers
  // adelikat: Note: the formula x = x * y /100 does not yield exact
  // results, but is "close enough" and avoids the need for using
  // double vales or implicit cohersion which are slower (we need
  // speed here)
  // TODO OPTIMIZE ME!
  ampx = x ? FCEUS_SQUARE2VOLUME : FCEUS_SQUARE1VOLUME;
  // CaH4e3: fixed - setting up maximum volume for square2 caused
  // complete mute square2 channel
  if (ampx != 256) amp = (amp * ampx) / 256;

  amp <<= 24;

  rthresh = RectDuties[(PSG[(x << 2)] & 0xC0) >> 6];

  D = &WaveHi[ChannelBC[x]];
  V = SoundTS() - ChannelBC[x];

  currdc = RectDutyCount[x];
  cf = (curfreq[x] + 1) * 2;
  rc = wlcount[x];

  while (V > 0) {
    if (currdc < rthresh) *D += amp;
    rc--;
    if (!rc) {
      rc = cf;
      currdc = (currdc + 1) & 7;
    }
    V--;
    D++;
  }

  RectDutyCount[x] = currdc;
  wlcount[x] = rc;

endit:
  ChannelBC[x] = SoundTS();
}

void Sound::RDoSQ1() {
  RDoSQ(0);
}

void Sound::RDoSQ2() {
  RDoSQ(1);
}

void Sound::RDoSQLQ() {
  int32 start, end;
  int32 V;
  int32 amp[2], ampx;
  int32 rthresh[2];
  int32 freq[2];
  int32 inie[2];

  int32 ttable[2][8];
  int32 totalout;

  start = ChannelBC[0];
  end = (SoundTS() << 16) / soundtsinc;
  if (end <= start) return;
  ChannelBC[0] = end;

  for (int x = 0; x < 2; x++) {
    inie[x] = nesincsize;
    if (curfreq[x] < 8 || curfreq[x] > 0x7ff) inie[x] = 0;
    if (!CheckFreq(curfreq[x], PSG[(x << 2) | 0x1])) inie[x] = 0;
    if (!lengthcount[x]) inie[x] = 0;

    if (EnvUnits[x].Mode & 0x1)
      amp[x] = EnvUnits[x].Speed;
    else
      amp[x] = EnvUnits[x].decvolume;

    // Modify Square wave volume based on channel volume modifiers
    // adelikat: Note: the formulat x = x * y /100 does not yield exact
    // results, but is "close enough" and avoids the need for using
    // double vales or implicit cohersion which are slower (we need
    // speed here) TODO OPTIMIZE ME!
    ampx = x ? FCEUS_SQUARE1VOLUME : FCEUS_SQUARE2VOLUME;
    // CaH4e3: fixed - setting up maximum volume for square2 caused
    // complete mute square2 channel
    if (ampx != 256) amp[x] = (amp[x] * ampx) / 256;

    if (!inie[x]) amp[x] = 0; /* Correct? Buzzing in MM2, others otherwise... */

    rthresh[x] = RectDuties[(PSG[x * 4] & 0xC0) >> 6];

    for (int y = 0; y < 8; y++) {
      if (y < rthresh[x])
        ttable[x][y] = amp[x];
      else
        ttable[x][y] = 0;
    }
    freq[x] = (curfreq[x] + 1) << 1;
    freq[x] <<= 17;
  }

  totalout =
	 wlookup1[ttable[0][RectDutyCount[0]] + ttable[1][RectDutyCount[1]]];

  if (!inie[0] && !inie[1]) {
    for (V = start; V < end; V++) Wave[V >> 4] += totalout;
  } else {
    for (V = start; V < end; V++) {

      Wave[V >> 4] += totalout;  // tmpamp;

      sqacc[0] -= inie[0];
      sqacc[1] -= inie[1];

      if (sqacc[0] <= 0) {
        do {
          sqacc[0] += freq[0];
          RectDutyCount[0] = (RectDutyCount[0] + 1) & 7;
        } while (sqacc[0] <= 0);
        totalout =
            wlookup1[ttable[0][RectDutyCount[0]] + ttable[1][RectDutyCount[1]]];
      }

      if (sqacc[1] <= 0) {
        do {
          sqacc[1] += freq[1];
          RectDutyCount[1] = (RectDutyCount[1] + 1) & 7;
        } while (sqacc[1] <= 0);
        totalout =
            wlookup1[ttable[0][RectDutyCount[0]] + ttable[1][RectDutyCount[1]]];
      }
    }
  }
}

void Sound::RDoTriangle() {
  int32 tcout;

  tcout = (tristep & 0xF);
  if (!(tristep & 0x10)) tcout ^= 0xF;
  tcout = (tcout * 3) << 16;

  if (!lengthcount[2] || !TriCount) {
    int32 cout = (tcout / 256 * FCEUS_TRIANGLEVOLUME) & (~0xFFFF);
    for (uint32 V = ChannelBC[2]; V < SoundTS(); V++) WaveHi[V] += cout;
  } else {
    for (uint32 V = ChannelBC[2]; V < SoundTS(); V++) {
      // Modify volume based on channel volume modifiers
      WaveHi[V] += (tcout / 256 * FCEUS_TRIANGLEVOLUME) &
                   (~0xFFFF);  // TODO OPTIMIZE ME!
      wlcount[2]--;
      if (!wlcount[2]) {
        wlcount[2] = (PSG[0xa] | ((PSG[0xb] & 7) << 8)) + 1;
        tristep++;
        tcout = (tristep & 0xF);
        if (!(tristep & 0x10)) tcout ^= 0xF;
        tcout = (tcout * 3) << 16;
      }
    }
  }

  ChannelBC[2] = SoundTS();
}

void Sound::RDoTriangleNoisePCMLQ() {
  int32 start, end;
  int32 freq[2];
  int32 inie[2];
  uint32 amptab[2];
  uint32 noiseout;
  int nshift;

  int32 totalout;

  start = ChannelBC[2];
  end = (SoundTS() << 16) / soundtsinc;
  if (end <= start) return;
  ChannelBC[2] = end;

  inie[0] = inie[1] = nesincsize;

  freq[0] = (((PSG[0xa] | ((PSG[0xb] & 7) << 8)) + 1));

  if (!lengthcount[2] || !TriCount || freq[0] <= 4) inie[0] = 0;

  freq[0] <<= 17;
  if (EnvUnits[2].Mode & 0x1)
    amptab[0] = EnvUnits[2].Speed;
  else
    amptab[0] = EnvUnits[2].decvolume;

  // Modify Square wave volume based on channel volume modifiers
  // adelikat: Note: the formula x = x * y /100 does not yield exact
  // results, but is "close enough" and avoids the need for using
  // double vales or implicit cohersion which are slower (we need speed
  // here)
  // TODO OPTIMIZE ME!
  if (FCEUS_TRIANGLEVOLUME != 256)
    amptab[0] = (amptab[0] * FCEUS_TRIANGLEVOLUME) / 256;

  amptab[1] = 0;
  amptab[0] <<= 1;

  if (!lengthcount[3])
    amptab[0] = inie[1] = 0; /* Quick hack speedup, set inie[1] to 0 */

  noiseout = amptab[(nreg >> 0xe) & 1];

  if (PSG[0xE] & 0x80)
    nshift = 8;
  else
    nshift = 13;

  totalout = wlookup2[triangle_noise_tcout + noiseout + RawDALatch];

  if (inie[0] && inie[1]) {
    for (int32 V = start; V < end; V++) {
      Wave[V >> 4] += totalout;

      triangle_noise_triacc -= inie[0];
      triangle_noise_noiseacc -= inie[1];

      if (triangle_noise_triacc <= 0) {
        do {
          triangle_noise_triacc += freq[0];  // t;
          tristep = (tristep + 1) & 0x1F;
        } while (triangle_noise_triacc <= 0);
        triangle_noise_tcout = (tristep & 0xF);
        if (!(tristep & 0x10)) triangle_noise_tcout ^= 0xF;
        triangle_noise_tcout *= 3;
        totalout = wlookup2[triangle_noise_tcout + noiseout + RawDALatch];
      }

      if (triangle_noise_noiseacc <= 0) {
        do {
          // used to added <<(16+2) when the noise table
          // values were half.
          if (fc->fceu->PAL)
            triangle_noise_noiseacc += NoiseFreqTablePAL[PSG[0xE] & 0xF]
                                       << (16 + 1);
          else
            triangle_noise_noiseacc += NoiseFreqTableNTSC[PSG[0xE] & 0xF]
                                       << (16 + 1);
          nreg = (nreg << 1) + (((nreg >> nshift) ^ (nreg >> 14)) & 1);
          nreg &= 0x7fff;
          noiseout = amptab[(nreg >> 0xe) & 1];
        } while (triangle_noise_noiseacc <= 0);
        totalout = wlookup2[triangle_noise_tcout + noiseout + RawDALatch];
      } /* triangle_noise_noiseacc<=0 */
    } /* for (V=... */
  } else if (inie[0]) {
    for (int32 V = start; V < end; V++) {
      Wave[V >> 4] += totalout;

      triangle_noise_triacc -= inie[0];

      if (triangle_noise_triacc <= 0) {
        do {
          triangle_noise_triacc += freq[0];  // t;
          tristep = (tristep + 1) & 0x1F;
        } while (triangle_noise_triacc <= 0);
        triangle_noise_tcout = (tristep & 0xF);
        if (!(tristep & 0x10)) triangle_noise_tcout ^= 0xF;
        triangle_noise_tcout *= 3;
        totalout = wlookup2[triangle_noise_tcout + noiseout + RawDALatch];
      }
    }
  } else if (inie[1]) {
    for (int32 V = start; V < end; V++) {
      Wave[V >> 4] += totalout;
      triangle_noise_noiseacc -= inie[1];
      if (triangle_noise_noiseacc <= 0) {
        do {
          // used to be added <<(16+2) when the noise table
          // values were half.
          if (fc->fceu->PAL)
            triangle_noise_noiseacc += NoiseFreqTablePAL[PSG[0xE] & 0xF]
                                       << (16 + 1);
          else
            triangle_noise_noiseacc += NoiseFreqTableNTSC[PSG[0xE] & 0xF]
                                       << (16 + 1);
          nreg = (nreg << 1) + (((nreg >> nshift) ^ (nreg >> 14)) & 1);
          nreg &= 0x7fff;
          noiseout = amptab[(nreg >> 0xe) & 1];
        } while (triangle_noise_noiseacc <= 0);
        totalout = wlookup2[triangle_noise_tcout + noiseout + RawDALatch];
      } /* triangle_noise_noiseacc<=0 */
    }
  } else {
    for (int32 V = start; V < end; V++) {
      Wave[V >> 4] += totalout;
    }
  }
}

void Sound::RDoNoise() {
  int32 outo;
  uint32 amptab[2];

  if (EnvUnits[2].Mode & 0x1)
    amptab[0] = EnvUnits[2].Speed;
  else
    amptab[0] = EnvUnits[2].decvolume;

  // Modfiy Noise channel volume based on channel volume setting
  // adelikat: Note: the formulat x = x * y /100 does not yield exact
  // results, but is "close enough" and avoids the need for using
  // double vales or implicit cohersion which are slower (we need
  // speed here)
  // TODO OPTIMIZE ME!
  if (FCEUS_NOISEVOLUME != 256)
    amptab[0] = (amptab[0] * FCEUS_NOISEVOLUME) / 256;
  amptab[0] <<= 16;
  amptab[1] = 0;

  amptab[0] <<= 1;

  outo = amptab[(nreg >> 0xe) & 1];

  if (!lengthcount[3]) {
    outo = amptab[0] = 0;
  }

  if (PSG[0xE] & 0x80) {
    // "short" noise
    for (uint32 V = ChannelBC[3]; V < SoundTS(); V++) {
      WaveHi[V] += outo;
      wlcount[3]--;
      if (!wlcount[3]) {
        uint8 feedback;
        if (fc->fceu->PAL)
          wlcount[3] = NoiseFreqTablePAL[PSG[0xE] & 0xF];
        else
          wlcount[3] = NoiseFreqTableNTSC[PSG[0xE] & 0xF];
        feedback = ((nreg >> 8) & 1) ^ ((nreg >> 14) & 1);
        nreg = (nreg << 1) + feedback;
        nreg &= 0x7fff;
        outo = amptab[(nreg >> 0xe) & 1];
      }
    }
  } else {
    for (uint32 V = ChannelBC[3]; V < SoundTS(); V++) {
      WaveHi[V] += outo;
      wlcount[3]--;
      if (!wlcount[3]) {
        uint8 feedback;
        if (fc->fceu->PAL)
          wlcount[3] = NoiseFreqTablePAL[PSG[0xE] & 0xF];
        else
          wlcount[3] = NoiseFreqTableNTSC[PSG[0xE] & 0xF];
        feedback = ((nreg >> 13) & 1) ^ ((nreg >> 14) & 1);
        nreg = (nreg << 1) + feedback;
        nreg &= 0x7fff;
        outo = amptab[(nreg >> 0xe) & 1];
      }
    }
  }
  ChannelBC[3] = SoundTS();
}

static DECLFW(Write_IRQFM) {
  return fc->sound->Write_IRQFM_Direct(DECLFW_FORWARD);
}

void Sound::Write_IRQFM_Direct(DECLFW_ARGS) {
  V = (V & 0xC0) >> 6;
  fcnt = 0;
  if (V & 0x2) FrameSoundUpdate();
  fcnt = 1;
  fhcnt = fhinc;
  fc->X->IRQEnd(FCEU_IQFCOUNT);
  SIRQStat &= ~0x40;
  IRQFrameMode = V;
}

void Sound::SetNESSoundMap() {
  fc->fceu->SetWriteHandler(0x4000, 0x400F, Write_PSG);
  fc->fceu->SetWriteHandler(0x4010, 0x4013, Write_DMCRegs);
  fc->fceu->SetWriteHandler(0x4017, 0x4017, Write_IRQFM);

  fc->fceu->SetWriteHandler(0x4015, 0x4015, StatusWrite);
  fc->fceu->SetReadHandler(0x4015, 0x4015, StatusRead);
}

int Sound::FlushEmulateSound() {
  int32 end, left;

  if (!fc->X->timestamp) return 0;

  if (!FCEUS_SNDRATE) {
    left = 0;
    end = 0;
    goto nosoundo;
  }

  (this->*DoSQ1)();
  (this->*DoSQ2)();
  (this->*DoTriangle)();
  (this->*DoNoise)();
  (this->*DoPCM)();

  if (FCEUS_SOUNDQ >= 1) {
    int32 *tmpo = &WaveHi[soundtsoffs];

    if (GameExpSound.HiFill) GameExpSound.HiFill(fc);

    for (int x = fc->X->timestamp; x; x--) {
      uint32 b = *tmpo;
      *tmpo = (b & 65535) + wlookup2[(b >> 16) & 255] + wlookup1[b >> 24];
      tmpo++;
    }
    end = fc->filter->NeoFilterSound(WaveHi, WaveFinal, SoundTS(), &left);

    memmove(WaveHi, WaveHi + SoundTS() - left, left * sizeof(uint32));
    memset(WaveHi + left, 0, sizeof(WaveHi) - left * sizeof(uint32));

    if (GameExpSound.HiSync) GameExpSound.HiSync(fc, left);
    for (int x = 0; x < 5; x++) ChannelBC[x] = left;
  } else {
    end = (SoundTS() << 16) / soundtsinc;
    if (GameExpSound.Fill) GameExpSound.Fill(fc, end & 0xF);

    fc->filter->SexyFilter(Wave, WaveFinal, end >> 4);

    // if (FCEUS_LOWPASS)
    // SexyFilter2(WaveFinal,end>>4);
    if (end & 0xF) Wave[0] = Wave[(end >> 4)];
    Wave[end >> 4] = 0;
  }
nosoundo:

  if (FCEUS_SOUNDQ >= 1) {
    soundtsoffs = left;
  } else {
    for (int x = 0; x < 5; x++) ChannelBC[x] = end & 0xF;
    soundtsoffs = (soundtsinc * (end & 0xF)) >> 16;
    end >>= 4;
  }
  sound_buffer_length = end;

  // FCEU_WriteWaveData(WaveFinal, end); /* This function will just return
  // if sound recording is off. */
  return end;
}

int Sound::GetSoundBuffer(int32 **w) {
  *w = WaveFinal;
  return sound_buffer_length;
}

/* FIXME: Find out what sound registers get reset on reset. I know
   $4001/$4005 don't, due to that whole MegaMan 2 Game Genie thing. */
void Sound::FCEUSND_Reset() {
  IRQFrameMode = 0x0;
  fhcnt = fhinc;
  fcnt = 0;
  nreg = 1;

  for (int x = 0; x < 2; x++) {
    wlcount[x] = 2048;
    if (nesincsize)  // lq mode
      sqacc[x] = ((uint32)2048 << 17) / nesincsize;
    else
      sqacc[x] = 1;
    sweepon[x] = 0;
    curfreq[x] = 0;
  }

  wlcount[2] = 1;  // 2048;
  wlcount[3] = 2048;

  DMCHaveDMA = DMCHaveSample = 0;
  SIRQStat = 0x00;

  RawDALatch = 0x00;
  TriCount = 0;
  TriMode = 0;
  tristep = 0;
  EnabledChannels = 0;
  for (int x = 0; x < 4; x++) lengthcount[x] = 0;

  DMCAddressLatch = 0;
  DMCSizeLatch = 0;
  DMCFormat = 0;
  DMCAddress = 0;
  DMCSize = 0;
  DMCShift = 0;

  // There was some craziness here to work around a bug where these two
  // weren't reset. Since we don't have any legacy savestates to load, we'll
  // just reset them "like we should have done in the first place." -tom7
  DMCacc = 1;
  DMCBitCount = 0;
}

void Sound::FCEUSND_Power() {
  SetNESSoundMap();
  memset(PSG, 0x00, sizeof(PSG));
  FCEUSND_Reset();

  memset(Wave, 0, sizeof(Wave));
  memset(WaveHi, 0, sizeof(WaveHi));
  memset(&EnvUnits, 0, sizeof(EnvUnits));

  for (int x = 0; x < 5; x++) ChannelBC[x] = 0;
  soundtsoffs = 0;
  LoadDMCPeriod(DMCFormat & 0xF);
}

void Sound::SetSoundVariables() {
  fhinc = fc->fceu->PAL ? 16626 : 14915;  // *2 CPU clock rate
  fhinc *= 24;

  if (FCEUS_SNDRATE) {
    wlookup1[0] = 0;
    for (int x = 1; x < 32; x++) {
      wlookup1[x] =
          (double)16 * 16 * 16 * 4 * 95.52 / ((double)8128 / (double)x + 100);
      if (!FCEUS_SOUNDQ) wlookup1[x] >>= 4;
    }
    wlookup2[0] = 0;
    for (int x = 1; x < 203; x++) {
      wlookup2[x] =
          (double)16 * 16 * 16 * 4 * 163.67 / ((double)24329 / (double)x + 100);
      if (!FCEUS_SOUNDQ) wlookup2[x] >>= 4;
    }
    if (FCEUS_SOUNDQ >= 1) {
      DoNoise = &Sound::RDoNoise;
      DoTriangle = &Sound::RDoTriangle;
      DoPCM = &Sound::RDoPCM;
      DoSQ1 = &Sound::RDoSQ1;
      DoSQ2 = &Sound::RDoSQ2;
    } else {
      DoSQ1 = &Sound::RDoSQLQ;
      DoSQ2 = &Sound::RDoSQLQ;
      DoTriangle = &Sound::RDoTriangleNoisePCMLQ;
      DoNoise = &Sound::RDoTriangleNoisePCMLQ;
      DoPCM = &Sound::RDoTriangleNoisePCMLQ;
    }
  } else {
    DoNoise = DoTriangle = DoPCM = DoSQ1 = DoSQ2 = &Sound::Dummyfunc;
    return;
  }

  fc->filter->MakeFilters(FCEUS_SNDRATE);

  if (GameExpSound.RChange) GameExpSound.RChange(fc);

  nesincsize = (int64)(((int64)1 << 17) *
                       (double)(fc->fceu->PAL ? PAL_CPU : NTSC_CPU) /
                       (FCEUS_SNDRATE * 16));
  memset(sqacc, 0, sizeof(sqacc));
  memset(ChannelBC, 0, sizeof(ChannelBC));

  LoadDMCPeriod(DMCFormat & 0xF);  // For changing from PAL to NTSC

  soundtsinc =
      (uint32)((uint64)(fc->fceu->PAL ? (long double)PAL_CPU * 65536 :
			                (long double)NTSC_CPU * 65536) /
               (FCEUS_SNDRATE * 16));
}

void Sound::FCEUI_InitSound() {
  SetSoundVariables();
}

Sound::Sound(FC *fc)
    : stateinfo{{&fhcnt, 4 | FCEUSTATE_RLSB, "FHCN"},
                {&fcnt, 1, "FCNT"},
                {PSG, 0x10, "PSG"},
                {&EnabledChannels, 1, "ENCH"},
                {&IRQFrameMode, 1, "IQFM"},
                {&nreg, 2 | FCEUSTATE_RLSB, "NREG"},
                {&TriMode, 1, "TRIM"},
                {&TriCount, 1, "TRIC"},

                {&EnvUnits[0].Speed, 1, "E0SP"},
                {&EnvUnits[1].Speed, 1, "E1SP"},
                {&EnvUnits[2].Speed, 1, "E2SP"},

                {&EnvUnits[0].Mode, 1, "E0MO"},
                {&EnvUnits[1].Mode, 1, "E1MO"},
                {&EnvUnits[2].Mode, 1, "E2MO"},

                {&EnvUnits[0].DecCountTo1, 1, "E0D1"},
                {&EnvUnits[1].DecCountTo1, 1, "E1D1"},
                {&EnvUnits[2].DecCountTo1, 1, "E2D1"},

                {&EnvUnits[0].decvolume, 1, "E0DV"},
                {&EnvUnits[1].decvolume, 1, "E1DV"},
                {&EnvUnits[2].decvolume, 1, "E2DV"},

                {&lengthcount[0], 4 | FCEUSTATE_RLSB, "LEN0"},
                {&lengthcount[1], 4 | FCEUSTATE_RLSB, "LEN1"},
                {&lengthcount[2], 4 | FCEUSTATE_RLSB, "LEN2"},
                {&lengthcount[3], 4 | FCEUSTATE_RLSB, "LEN3"},
                {sweepon, 2, "SWEE"},
                {&curfreq[0], 4 | FCEUSTATE_RLSB, "CRF1"},
                {&curfreq[1], 4 | FCEUSTATE_RLSB, "CRF2"},
                {SweepCount, 2, "SWCT"},

                {&SIRQStat, 1, "SIRQ"},

                {&DMCacc, 4 | FCEUSTATE_RLSB, "5ACC"},
                {&DMCBitCount, 1, "5BIT"},
                {&DMCAddress, 4 | FCEUSTATE_RLSB, "5ADD"},
                {&DMCSize, 4 | FCEUSTATE_RLSB, "5SIZ"},
                {&DMCShift, 1, "5SHF"},

                {&DMCHaveDMA, 1, "5HVDM"},
                {&DMCHaveSample, 1, "5HVSP"},

                {&DMCSizeLatch, 1, "5SZL"},
                {&DMCAddressLatch, 1, "5ADL"},
                {&DMCFormat, 1, "5FMT"},
                {&RawDALatch, 1, "RWDA"},
		{0}},
      fc(fc) {
          // Constructor, empty.
      };

void Sound::FCEUSND_SaveState() {}

void Sound::FCEUSND_LoadState(int version) {
  LoadDMCPeriod(DMCFormat & 0xF);
  RawDALatch &= 0x7F;
  DMCAddress &= 0x7FFF;
}
