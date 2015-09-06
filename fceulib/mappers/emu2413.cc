/***********************************************************************************

  emu2413.c -- YM2413 emulator written by Mitsutaka Okazaki 2001

  2001 01-08 : Version 0.10 -- 1st version.
  2001 01-15 : Version 0.20 -- semi-public version.
  2001 01-16 : Version 0.30 -- 1st public version.
  2001 01-17 : Version 0.31 -- Fixed bassdrum problem.
             : Version 0.32 -- LPF implemented.
  2001 01-18 : Version 0.33 -- Fixed the drum problem, refine the mix-down
method.
                            -- Fixed the LFO bug.
  2001 01-24 : Version 0.35 -- Fixed the drum problem,
                               support undocumented EG behavior.
  2001 02-02 : Version 0.38 -- Improved the performance.
                               Fixed the hi-hat and cymbal model.
                               Fixed the default percussive datas.
                               Noise reduction.
                               Fixed the feedback problem.
  2001 03-03 : Version 0.39 -- Fixed some drum bugs.
                               Improved the performance.
  2001 03-04 : Version 0.40 -- Improved the feedback.
                               Change the default table size.
                               Clock and Rate can be changed during play.
  2001 06-24 : Version 0.50 -- Improved the hi-hat and the cymbal tone.
                               Added VRC7 patch (OPLL_reset_patch is changed).
                               Fixed OPLL_reset() bug.
                               Added OPLL_setMask, OPLL_getMask and
OPLL_toggleMask.
                               Added OPLL_writeIO.
  2001 09-28 : Version 0.51 -- Removed the noise table.
  2002 01-28 : Version 0.52 -- Added Stereo mode.
  2002 02-07 : Version 0.53 -- Fixed some drum bugs.
  2002 02-20 : Version 0.54 -- Added the best quality mode.
  2002 03-02 : Version 0.55 -- Removed OPLL_init & OPLL_close.
  2002 05-30 : Version 0.60 -- Fixed HH&CYM generator and all voice datas.

  2004 01-24 : Modified by xodnizel to remove code not needed for the VRC7,
among other things.

  References:
    fmopl.c        -- 1999,2000 written by Tatsuyuki Satoh (MAME development).
    fmopl.c(fixed) -- (C) 2002 Jarek Burczynski.
    s_opl.c        -- 2001 written by Mamiya (NEZplug development).
    fmgen.cpp      -- 1999,2000 written by cisc.
    fmpac.ill      -- 2000 created by NARUTO.
    MSX-Datapack
    YMU757 data sheet
    YM2143 data sheet

**************************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "emu2413.h"

/* Mask */
#define OPLL_MASK_CH(x) (1 << (x))

#define PI 3.14159265358979323846

static constexpr uint8 default_inst[15][8] = {
    /* VRC7 instruments, January 17, 2004 update -Xodnizel */
    {0x03, 0x21, 0x04, 0x06, 0x8D, 0xF2, 0x42, 0x17},
    {0x13, 0x41, 0x05, 0x0E, 0x99, 0x96, 0x63, 0x12},
    {0x31, 0x11, 0x10, 0x0A, 0xF0, 0x9C, 0x32, 0x02},
    {0x21, 0x61, 0x1D, 0x07, 0x9F, 0x64, 0x20, 0x27},
    {0x22, 0x21, 0x1E, 0x06, 0xF0, 0x76, 0x08, 0x28},
    {0x02, 0x01, 0x06, 0x00, 0xF0, 0xF2, 0x03, 0x95},
    {0x21, 0x61, 0x1C, 0x07, 0x82, 0x81, 0x16, 0x07},
    {0x23, 0x21, 0x1A, 0x17, 0xEF, 0x82, 0x25, 0x15},
    {0x25, 0x11, 0x1F, 0x00, 0x86, 0x41, 0x20, 0x11},
    {0x85, 0x01, 0x1F, 0x0F, 0xE4, 0xA2, 0x11, 0x12},
    {0x07, 0xC1, 0x2B, 0x45, 0xB4, 0xF1, 0x24, 0xF4},
    {0x61, 0x23, 0x11, 0x06, 0x96, 0x96, 0x13, 0x16},
    {0x01, 0x02, 0xD3, 0x05, 0x82, 0xA2, 0x31, 0x51},
    {0x61, 0x22, 0x0D, 0x02, 0xC3, 0x7F, 0x24, 0x05},
    {0x21, 0x62, 0x0E, 0x00, 0xA1, 0xA0, 0x44, 0x17},
};

/* Phase increment counter */
#define DP_BITS 18
#define DP_WIDTH (1 << DP_BITS)
#define DP_BASE_BITS (DP_BITS - PG_BITS)

/* Dynamic range of sustine level */
#define SL_STEP 3.0
#define SL_BITS 4
#define SL_MUTE (1 << SL_BITS)

#define EG2DB(d) ((d) * (int32)(EG_STEP / DB_STEP))
#define TL2EG(d) ((d) * (int32)(TL_STEP / EG_STEP))
#define SL2EG(d) ((d) * (int32)(SL_STEP / EG_STEP))

#define DB_POS(x) (uint32)((x) / DB_STEP)
#define DB_NEG(x) (uint32)(DB_MUTE + DB_MUTE + (x) / DB_STEP)

/* Bits for liner value */
#define DB2LIN_AMP_BITS 11
#define SLOT_AMP_BITS (DB2LIN_AMP_BITS)

/* Bits for envelope phase incremental counter */
#define EG_DP_BITS 22
#define EG_DP_WIDTH (1 << EG_DP_BITS)

/* PM table is calcurated by PM_AMP * pow(2,PM_DEPTH*sin(x)/1200) */
#define PM_AMP_BITS 8
#define PM_AMP (1 << PM_AMP_BITS)

/* PM speed(Hz) and depth(cent) */
#define PM_SPEED 6.4
#define PM_DEPTH 13.75

/* AM speed(Hz) and depth(dB) */
#define AM_SPEED 3.7
//#define AM_DEPTH 4.8
#define AM_DEPTH 2.4

/* Cut the lower b bit(s) off. */
#define HIGHBITS(c, b) ((c) >> (b))

/* Leave the lower b bit(s). */
#define LOWBITS(c, b) ((c) & ((1 << (b)) - 1))

/* Expand x which is s bits to d bits. */
#define EXPAND_BITS(x, s, d) ((x) << ((d) - (s)))

/* Expand x which is s bits to d bits and fill expanded bits '1' */
#define EXPAND_BITS_X(x, s, d) (((x) << ((d) - (s))) | ((1 << ((d) - (s))) - 1))

/* Adjust envelope speed which depends on sampling rate. */
#define rate_adjust(x)                                        \
  (rate == 49716 ? x : (uint32)((double)(x)*clk / 72 / rate + \
                                0.5)) /* added 0.5 to round the value*/

#define MOD(o, x) (&(o)->slot[(x) << 1])
#define CAR(o, x) (&(o)->slot[((x) << 1) | 1])

#define BIT(s, b) (((s) >> (b)) & 1)


/* Definition of envelope mode */
enum { SETTLE, ATTACK, DECAY, SUSHOLD, SUSTINE, RELEASE, FINISH };

/***************************************************

                  Create tables

****************************************************/
inline static int32 Min(int32 i, int32 j) {
  if (i < j)
    return i;
  else
    return j;
}

/* Table for AR to LogCurve. */
void EMU2413::makeAdjustTable() {
  AR_ADJUST_TABLE[0] = (1 << EG_BITS);
  for (int32 i = 1; i < 128; i++)
    AR_ADJUST_TABLE[i] = (uint16)((double)(1 << EG_BITS) - 1 -
                                  (1 << EG_BITS) * log(i) / log(128));
}

/* Table for dB(0 -- (1<<DB_BITS)-1) to Liner(0 -- DB2LIN_AMP_WIDTH) */
void EMU2413::makeDB2LinTable() {
  for (int32 i = 0; i < DB_MUTE + DB_MUTE; i++) {
    DB2LIN_TABLE[i] = (int16)((double)((1 << DB2LIN_AMP_BITS) - 1) *
                              pow(10, -(double)i * DB_STEP / 20));
    if (i >= DB_MUTE) DB2LIN_TABLE[i] = 0;
    DB2LIN_TABLE[i + DB_MUTE + DB_MUTE] = (int16)(-DB2LIN_TABLE[i]);
  }
}

/* Liner(+0.0 - +1.0) to dB((1<<DB_BITS) - 1 -- 0) */
int32 EMU2413::lin2db(double d) {
  if (d == 0)
    return (DB_MUTE - 1);
  else
    return Min(-(int32)(20.0 * log10(d) / DB_STEP), DB_MUTE - 1); /* 0 -- 127 */
}

/* Sin Table */
void EMU2413::makeSinTable() {
  int32 i;

  for (i = 0; i < PG_WIDTH / 4; i++) {
    fullsintable[i] = (uint32)lin2db(sin(2.0 * PI * i / PG_WIDTH));
  }

  for (i = 0; i < PG_WIDTH / 4; i++) {
    fullsintable[PG_WIDTH / 2 - 1 - i] = fullsintable[i];
  }

  for (i = 0; i < PG_WIDTH / 2; i++) {
    fullsintable[PG_WIDTH / 2 + i] =
        (uint32)(DB_MUTE + DB_MUTE + fullsintable[i]);
  }

  for (i = 0; i < PG_WIDTH / 2; i++) halfsintable[i] = fullsintable[i];
  for (i = PG_WIDTH / 2; i < PG_WIDTH; i++) halfsintable[i] = fullsintable[0];
}

/* Table for Pitch Modulator */
void EMU2413::makePmTable() {
  int32 i;

  for (i = 0; i < PM_PG_WIDTH; i++)
    pmtable[i] = (int32)(
        (double)PM_AMP *
        pow(2, (double)PM_DEPTH * sin(2.0 * PI * i / PM_PG_WIDTH) / 1200));
}

/* Table for Amp Modulator */
void EMU2413::makeAmTable() {
  int32 i;

  for (i = 0; i < AM_PG_WIDTH; i++)
    amtable[i] = (int32)((double)AM_DEPTH / 2 / DB_STEP *
                         (1.0 + sin(2.0 * PI * i / PM_PG_WIDTH)));
}

/* Phase increment counter table */
void EMU2413::makeDphaseTable() {
  static constexpr uint32 mltable[16] =
    {1,      1 * 2,  2 * 2,  3 * 2, 4 * 2,  5 * 2,
     6 * 2,  7 * 2,  8 * 2,  9 * 2, 10 * 2, 10 * 2,
     12 * 2, 12 * 2, 15 * 2, 15 * 2};

  for (uint32 fnum = 0; fnum < 512; fnum++)
    for (uint32 block = 0; block < 8; block++)
      for (uint32 ML = 0; ML < 16; ML++)
        dphaseTable[fnum][block][ML] =
            rate_adjust(((fnum * mltable[ML]) << block) >> (20 - DP_BITS));
}

static constexpr double dB2(double x) {
  return x * 2.0;
}

void EMU2413::makeTllTable() {
  // #define dB2(x) ((x) * 2)

  static constexpr double kltable[16] = {
      dB2(0.000),  dB2(9.000),  dB2(12.000), dB2(13.875),
      dB2(15.000), dB2(16.125), dB2(16.875), dB2(17.625),
      dB2(18.000), dB2(18.750), dB2(19.125), dB2(19.500),
      dB2(19.875), dB2(20.250), dB2(20.625), dB2(21.000)};

  for (int32 fnum = 0; fnum < 16; fnum++) {
    for (int32 block = 0; block < 8; block++) {
      for (int32 TL = 0; TL < 64; TL++) {
        for (int32 KL = 0; KL < 4; KL++) {
          if (KL == 0) {
            tllTable[fnum][block][TL][KL] = TL2EG(TL);
          } else {
            int32 tmp = (int32)(kltable[fnum] - dB2(3.000) * (7 - block));
            if (tmp <= 0)
              tllTable[fnum][block][TL][KL] = TL2EG(TL);
            else
              tllTable[fnum][block][TL][KL] =
                  (uint32)((tmp >> (3 - KL)) / EG_STEP) + TL2EG(TL);
          }
        }
      }
    }
  }
}

/* Rate Table for Attack */
void EMU2413::makeDphaseARTable() {
  for (int32 AR = 0; AR < 16; AR++)
    for (int32 Rks = 0; Rks < 16; Rks++) {
      int32 RM = AR + (Rks >> 2);
      int32 RL = Rks & 3;
      if (RM > 15) RM = 15;
      switch (AR) {
        case 0: dphaseARTable[AR][Rks] = 0; break;
        case 15: dphaseARTable[AR][Rks] = 0; /*EG_DP_WIDTH;*/ break;
        default:
          dphaseARTable[AR][Rks] = rate_adjust((3 * (RL + 4) << (RM + 1)));
          break;
      }
    }
}

/* Rate Table for Decay and Release */
void EMU2413::makeDphaseDRTable() {
  for (int32 DR = 0; DR < 16; DR++)
    for (int32 Rks = 0; Rks < 16; Rks++) {
      int32 RM = DR + (Rks >> 2);
      int32 RL = Rks & 3;
      if (RM > 15) RM = 15;
      switch (DR) {
        case 0: dphaseDRTable[DR][Rks] = 0; break;
        default:
          dphaseDRTable[DR][Rks] = rate_adjust((RL + 4) << (RM - 1));
          break;
      }
    }
}

void EMU2413::makeRksTable() {
  for (int32 fnum8 = 0; fnum8 < 2; fnum8++)
    for (int32 block = 0; block < 8; block++)
      for (int32 KR = 0; KR < 2; KR++) {
        if (KR != 0)
          rksTable[fnum8][block][KR] = (block << 1) + fnum8;
        else
          rksTable[fnum8][block][KR] = block >> 1;
      }
}

/************************************************************

                      Calc Parameters

************************************************************/

uint32 EMU2413::calc_eg_dphase(OPLL_SLOT *slot) {
  switch (slot->eg_mode) {
    case ATTACK: return dphaseARTable[slot->patch.AR][slot->rks];

    case DECAY: return dphaseDRTable[slot->patch.DR][slot->rks];

    case SUSHOLD: return 0;

    case SUSTINE: return dphaseDRTable[slot->patch.RR][slot->rks];

    case RELEASE:
      if (slot->sustine)
        return dphaseDRTable[5][slot->rks];
      else if (slot->patch.EG)
        return dphaseDRTable[slot->patch.RR][slot->rks];
      else
        return dphaseDRTable[7][slot->rks];

    case FINISH: return 0;

    default: return 0;
  }
}

/*************************************************************

                    OPLL internal interfaces

*************************************************************/

#define UPDATE_PG(S) \
  (S)->dphase = dphaseTable[(S)->fnum][(S)->block][(S)->patch.ML]
#define UPDATE_TLL(S)                                                       \
  (((S)->type == 0) ?                                                       \
       ((S)->tll = tllTable[((S)->fnum) >>                                  \
                            5][(S)->block][(S)->patch.TL][(S)->patch.KL]) : \
       ((S)->tll = tllTable[((S)->fnum) >>                                  \
                            5][(S)->block][(S)->volume][(S)->patch.KL]))
#define UPDATE_RKS(S) \
  (S)->rks = rksTable[((S)->fnum) >> 8][(S)->block][(S)->patch.KR]
#define UPDATE_WF(S) (S)->sintbl = waveform[(S)->patch.WF]
#define UPDATE_EG(S) (S)->eg_dphase = calc_eg_dphase(S)
#define UPDATE_ALL(S) \
  UPDATE_PG(S);       \
  UPDATE_TLL(S);      \
  UPDATE_RKS(S);      \
  UPDATE_WF(S);       \
  UPDATE_EG(S) /* EG should be updated last. */

/* Slot key on  */
void EMU2413::slotOn(OPLL_SLOT *slot) {
  slot->eg_mode = ATTACK;
  slot->eg_phase = 0;
  slot->phase = 0;
}

/* Slot key off */
void EMU2413::slotOff(OPLL_SLOT *slot) {
  if (slot->eg_mode == ATTACK)
    slot->eg_phase = EXPAND_BITS(
        AR_ADJUST_TABLE[HIGHBITS(slot->eg_phase, EG_DP_BITS - EG_BITS)],
        EG_BITS, EG_DP_BITS);
  slot->eg_mode = RELEASE;
}

/* Channel key on */
void EMU2413::keyOn(OPLL *opll, int32 i) {
  if (!opll->slot_on_flag[i * 2]) slotOn(MOD(opll, i));
  if (!opll->slot_on_flag[i * 2 + 1]) slotOn(CAR(opll, i));
  opll->key_status[i] = 1;
}

/* Channel key off */
void EMU2413::keyOff(OPLL *opll, int32 i) {
  if (opll->slot_on_flag[i * 2 + 1]) slotOff(CAR(opll, i));
  opll->key_status[i] = 0;
}

/* Set sustine parameter */
void EMU2413::setSustine(OPLL *opll, int32 c, int32 sustine) {
  CAR(opll, c)->sustine = sustine;
  if (MOD(opll, c)->type) MOD(opll, c)->sustine = sustine;
}

/* Volume : 6bit ( Volume register << 2 ) */
void EMU2413::setVolume(OPLL *opll, int32 c, int32 volume) {
  CAR(opll, c)->volume = volume;
}

/* Set F-Number ( fnum : 9bit ) */
void EMU2413::setFnumber(OPLL *opll, int32 c, int32 fnum) {
  CAR(opll, c)->fnum = fnum;
  MOD(opll, c)->fnum = fnum;
}

/* Set Block data (block : 3bit ) */
void EMU2413::setBlock(OPLL *opll, int32 c, int32 block) {
  CAR(opll, c)->block = block;
  MOD(opll, c)->block = block;
}

void EMU2413::update_key_status(OPLL *opll) {
  for (int ch = 0; ch < 6; ch++)
    opll->slot_on_flag[ch * 2] = opll->slot_on_flag[ch * 2 + 1] =
        (opll->HiFreq[ch]) & 0x10;
}

/***********************************************************

                      Initializing

***********************************************************/

void EMU2413::OPLL_SLOT_reset(OPLL_SLOT *slot, int type) {
  slot->type = type;
  slot->sintbl = waveform[0];
  slot->phase = 0;
  slot->dphase = 0;
  slot->output[0] = 0;
  slot->output[1] = 0;
  slot->feedback = 0;
  slot->eg_mode = SETTLE;
  slot->eg_phase = EG_DP_WIDTH;
  slot->eg_dphase = 0;
  slot->rks = 0;
  slot->tll = 0;
  slot->sustine = 0;
  slot->fnum = 0;
  slot->block = 0;
  slot->volume = 0;
  slot->pgout = 0;
  slot->egout = 0;
}

void EMU2413::internal_refresh() {
  makeDphaseTable();
  makeDphaseARTable();
  makeDphaseDRTable();
  pm_dphase = (uint32)rate_adjust(PM_SPEED * PM_DP_WIDTH / (clk / 72));
  am_dphase = (uint32)rate_adjust(AM_SPEED * AM_DP_WIDTH / (clk / 72));
}

void EMU2413::maketables(uint32 c, uint32 r) {
  if (c != clk) {
    clk = c;
    makePmTable();
    makeAmTable();
    makeDB2LinTable();
    makeAdjustTable();
    makeTllTable();
    makeRksTable();
    makeSinTable();
    // makeDefaultPatch ();
  }

  if (r != rate) {
    rate = r;
    internal_refresh();
  }
}

OPLL *EMU2413::OPLL_new(uint32 clk, uint32 rate) {
  OPLL *opll;

  maketables(clk, rate);

  opll = (OPLL *)calloc(sizeof(OPLL), 1);
  if (opll == nullptr) return nullptr;

  opll->mask = 0;

  OPLL_reset(opll);

  return opll;
}

void EMU2413::OPLL_delete(OPLL *opll) {
  free(opll);
}

/* Reset whole of OPLL except patch datas. */
void EMU2413::OPLL_reset(OPLL *opll) {
  if (!opll) return;

  opll->adr = 0;
  opll->out = 0;

  opll->pm_phase = 0;
  opll->am_phase = 0;

  opll->mask = 0;

  for (int32 i = 0; i < 12; i++)
    OPLL_SLOT_reset(&opll->slot[i], i % 2);

  for (int32 i = 0; i < 6; i++) {
    opll->key_status[i] = 0;
    // setPatch (opll, i, 0);
  }

  for (int32 i = 0; i < 0x40; i++)
    OPLL_writeReg(opll, i, 0);

  opll->realstep = (uint32)((1 << 31) / rate);
  opll->opllstep = (uint32)((1 << 31) / (clk / 72));
  opll->oplltime = 0;
}

/* Force Refresh (When external program changes some parameters). */
void EMU2413::OPLL_forceRefresh(OPLL *opll) {
  if (opll == nullptr) return;

  for (int32 i = 0; i < 12; i++) {
    UPDATE_PG(&opll->slot[i]);
    UPDATE_RKS(&opll->slot[i]);
    UPDATE_TLL(&opll->slot[i]);
    UPDATE_WF(&opll->slot[i]);
    UPDATE_EG(&opll->slot[i]);
  }
}

void EMU2413::OPLL_set_rate(OPLL *opll, uint32 r) {
  if (opll->quality)
    rate = 49716;
  else
    rate = r;
  internal_refresh();
  rate = r;
}

/*********************************************************

                 Generate wave data

*********************************************************/
/* Convert Amp(0 to EG_HEIGHT) to Phase(0 to 2PI). */
#if (SLOT_AMP_BITS - PG_BITS) > 0
#define wave2_2pi(e) ((e) >> (SLOT_AMP_BITS - PG_BITS))
#else
#define wave2_2pi(e) ((e) << (PG_BITS - SLOT_AMP_BITS))
#endif

/* Convert Amp(0 to EG_HEIGHT) to Phase(0 to 4PI). */
#if (SLOT_AMP_BITS - PG_BITS - 1) == 0
#define wave2_4pi(e) (e)
#elif(SLOT_AMP_BITS - PG_BITS - 1) > 0
#define wave2_4pi(e) ((e) >> (SLOT_AMP_BITS - PG_BITS - 1))
#else
#define wave2_4pi(e) ((e) << (1 + PG_BITS - SLOT_AMP_BITS))
#endif

/* Convert Amp(0 to EG_HEIGHT) to Phase(0 to 8PI). */
#if (SLOT_AMP_BITS - PG_BITS - 2) == 0
#define wave2_8pi(e) (e)
#elif(SLOT_AMP_BITS - PG_BITS - 2) > 0
#define wave2_8pi(e) ((e) >> (SLOT_AMP_BITS - PG_BITS - 2))
#else
#define wave2_8pi(e) ((e) << (2 + PG_BITS - SLOT_AMP_BITS))
#endif

/* Update AM, PM unit */
void EMU2413::update_ampm(OPLL *opll) {
  opll->pm_phase = (opll->pm_phase + pm_dphase) & (PM_DP_WIDTH - 1);
  opll->am_phase = (opll->am_phase + am_dphase) & (AM_DP_WIDTH - 1);
  opll->lfo_am = amtable[HIGHBITS(opll->am_phase, AM_DP_BITS - AM_PG_BITS)];
  opll->lfo_pm = pmtable[HIGHBITS(opll->pm_phase, PM_DP_BITS - PM_PG_BITS)];
}

/* PG */
void EMU2413::calc_phase(OPLL_SLOT *slot, int32 lfo) {
  if (slot->patch.PM)
    slot->phase += (slot->dphase * lfo) >> PM_AMP_BITS;
  else
    slot->phase += slot->dphase;

  slot->phase &= (DP_WIDTH - 1);

  slot->pgout = HIGHBITS(slot->phase, DP_BASE_BITS);
}

#define S2E(x) (SL2EG((int32)(x / SL_STEP)) << (EG_DP_BITS - EG_BITS))

/* EG */
void EMU2413::calc_envelope(OPLL_SLOT *slot, int32 lfo) {
  static constexpr uint32 SL[16] =
    {S2E(0.0),  S2E(3.0),  S2E(6.0),  S2E(9.0),
     S2E(12.0), S2E(15.0), S2E(18.0), S2E(21.0),
     S2E(24.0), S2E(27.0), S2E(30.0), S2E(33.0),
     S2E(36.0), S2E(39.0), S2E(42.0), S2E(48.0)};

  uint32 egout;

  switch (slot->eg_mode) {
    case ATTACK:
      egout = AR_ADJUST_TABLE[HIGHBITS(slot->eg_phase, EG_DP_BITS - EG_BITS)];
      slot->eg_phase += slot->eg_dphase;
      if ((EG_DP_WIDTH & slot->eg_phase) || (slot->patch.AR == 15)) {
        egout = 0;
        slot->eg_phase = 0;
        slot->eg_mode = DECAY;
        UPDATE_EG(slot);
      }
      break;

    case DECAY:
      egout = HIGHBITS(slot->eg_phase, EG_DP_BITS - EG_BITS);
      slot->eg_phase += slot->eg_dphase;
      if (slot->eg_phase >= SL[slot->patch.SL]) {
        if (slot->patch.EG) {
          slot->eg_phase = SL[slot->patch.SL];
          slot->eg_mode = SUSHOLD;
          UPDATE_EG(slot);
        } else {
          slot->eg_phase = SL[slot->patch.SL];
          slot->eg_mode = SUSTINE;
          UPDATE_EG(slot);
        }
      }
      break;

    case SUSHOLD:
      egout = HIGHBITS(slot->eg_phase, EG_DP_BITS - EG_BITS);
      if (slot->patch.EG == 0) {
        slot->eg_mode = SUSTINE;
        UPDATE_EG(slot);
      }
      break;

    case SUSTINE:
    case RELEASE:
      egout = HIGHBITS(slot->eg_phase, EG_DP_BITS - EG_BITS);
      slot->eg_phase += slot->eg_dphase;
      if (egout >= (1 << EG_BITS)) {
        slot->eg_mode = FINISH;
        egout = (1 << EG_BITS) - 1;
      }
      break;

    case FINISH: egout = (1 << EG_BITS) - 1; break;

    default: egout = (1 << EG_BITS) - 1; break;
  }

  if (slot->patch.AM)
    egout = EG2DB(egout + slot->tll) + lfo;
  else
    egout = EG2DB(egout + slot->tll);

  if (egout >= DB_MUTE) egout = DB_MUTE - 1;

  slot->egout = egout;
}

/* CARRIOR */
int32 EMU2413::calc_slot_car(OPLL_SLOT *slot, int32 fm) {
  slot->output[1] = slot->output[0];

  if (slot->egout >= (DB_MUTE - 1)) {
    slot->output[0] = 0;
  } else {
    slot->output[0] = DB2LIN_TABLE[slot->sintbl[(slot->pgout + wave2_8pi(fm)) &
                                                (PG_WIDTH - 1)] +
                                   slot->egout];
  }

  return (slot->output[1] + slot->output[0]) >> 1;
}

/* MODULATOR */
int32 EMU2413::calc_slot_mod(OPLL_SLOT *slot) {
  slot->output[1] = slot->output[0];

  if (slot->egout >= (DB_MUTE - 1)) {
    slot->output[0] = 0;
  } else if (slot->patch.FB != 0) {
    int32 fm = wave2_4pi(slot->feedback) >> (7 - slot->patch.FB);
    slot->output[0] =
        DB2LIN_TABLE[slot->sintbl[(slot->pgout + fm) & (PG_WIDTH - 1)] +
                     slot->egout];
  } else {
    slot->output[0] = DB2LIN_TABLE[slot->sintbl[slot->pgout] + slot->egout];
  }

  slot->feedback = (slot->output[1] + slot->output[0]) >> 1;

  return slot->feedback;
}

int16 EMU2413::calc(OPLL *opll) {
  int32 inst = 0, out = 0;
  update_ampm(opll);

  for (int32 i = 0; i < 12; i++) {
    calc_phase(&opll->slot[i], opll->lfo_pm);
    calc_envelope(&opll->slot[i], opll->lfo_am);
  }

  for (int32 i = 0; i < 6; i++)
    if (!(opll->mask & OPLL_MASK_CH(i)) && (CAR(opll, i)->eg_mode != FINISH))
      inst += calc_slot_car(CAR(opll, i), calc_slot_mod(MOD(opll, i)));

  out = inst;
  return (int16)out;
}

void EMU2413::OPLL_FillBuffer(OPLL *opll, int32 *buf, int32 len, int shift) {
  while (len > 0) {
    *buf += (calc(opll) + 32768) << shift;
    buf++;
    len--;
  }
}

/****************************************************

                       I/O Ctrl

*****************************************************/

void EMU2413::setInstrument(OPLL *opll, uint32 i, uint32 inst) {
  const uint8 *src;
  OPLL_PATCH *modp, *carp;

  opll->patch_number[i] = inst;

  if (inst)
    src = default_inst[inst - 1];
  else
    src = opll->CustInst;

  modp = &MOD(opll, i)->patch;
  carp = &CAR(opll, i)->patch;

  modp->AM = (src[0] >> 7) & 1;
  modp->PM = (src[0] >> 6) & 1;
  modp->EG = (src[0] >> 5) & 1;
  modp->KR = (src[0] >> 4) & 1;
  modp->ML = (src[0] & 0xF);

  carp->AM = (src[1] >> 7) & 1;
  carp->PM = (src[1] >> 6) & 1;
  carp->EG = (src[1] >> 5) & 1;
  carp->KR = (src[1] >> 4) & 1;
  carp->ML = (src[1] & 0xF);

  modp->KL = (src[2] >> 6) & 3;
  modp->TL = (src[2] & 0x3F);

  carp->KL = (src[3] >> 6) & 3;
  carp->WF = (src[3] >> 4) & 1;

  modp->WF = (src[3] >> 3) & 1;

  modp->FB = (src[3]) & 7;

  modp->AR = (src[4] >> 4) & 0xF;
  modp->DR = (src[4] & 0xF);

  carp->AR = (src[5] >> 4) & 0xF;
  carp->DR = (src[5] & 0xF);

  modp->SL = (src[6] >> 4) & 0xF;
  modp->RR = (src[6] & 0xF);

  carp->SL = (src[7] >> 4) & 0xF;
  carp->RR = (src[7] & 0xF);
}

void EMU2413::OPLL_writeReg(OPLL *opll, uint32 reg, uint32 data) {
  int32 i, v, ch;

  data = data & 0xff;
  reg = reg & 0x3f;

  switch (reg) {
    case 0x00:
      opll->CustInst[0] = data;
      for (i = 0; i < 6; i++) {
        if (opll->patch_number[i] == 0) {
          setInstrument(opll, i, 0);
          UPDATE_PG(MOD(opll, i));
          UPDATE_RKS(MOD(opll, i));
          UPDATE_EG(MOD(opll, i));
        }
      }
      break;

    case 0x01:
      opll->CustInst[1] = data;
      for (i = 0; i < 6; i++) {
        if (opll->patch_number[i] == 0) {
          setInstrument(opll, i, 0);
          UPDATE_PG(CAR(opll, i));
          UPDATE_RKS(CAR(opll, i));
          UPDATE_EG(CAR(opll, i));
        }
      }
      break;

    case 0x02:
      opll->CustInst[2] = data;
      for (i = 0; i < 6; i++) {
        if (opll->patch_number[i] == 0) {
          setInstrument(opll, i, 0);
          UPDATE_TLL(MOD(opll, i));
        }
      }
      break;

    case 0x03:
      opll->CustInst[3] = data;
      for (i = 0; i < 6; i++) {
        if (opll->patch_number[i] == 0) {
          setInstrument(opll, i, 0);
          UPDATE_WF(MOD(opll, i));
          UPDATE_WF(CAR(opll, i));
        }
      }
      break;

    case 0x04:
      opll->CustInst[4] = data;
      for (i = 0; i < 6; i++) {
        if (opll->patch_number[i] == 0) {
          setInstrument(opll, i, 0);
          UPDATE_EG(MOD(opll, i));
        }
      }
      break;

    case 0x05:
      opll->CustInst[5] = data;
      for (i = 0; i < 6; i++) {
        if (opll->patch_number[i] == 0) {
          setInstrument(opll, i, 0);
          UPDATE_EG(CAR(opll, i));
        }
      }
      break;

    case 0x06:
      opll->CustInst[6] = data;
      for (i = 0; i < 6; i++) {
        if (opll->patch_number[i] == 0) {
          setInstrument(opll, i, 0);
          UPDATE_EG(MOD(opll, i));
        }
      }
      break;

    case 0x07:
      opll->CustInst[7] = data;
      for (i = 0; i < 6; i++) {
        if (opll->patch_number[i] == 0) {
          setInstrument(opll, i, 0);
          UPDATE_EG(CAR(opll, i));
        }
      }
      break;

    case 0x10:
    case 0x11:
    case 0x12:
    case 0x13:
    case 0x14:
    case 0x15:
      ch = reg - 0x10;
      opll->LowFreq[ch] = data;
      setFnumber(opll, ch, data + ((opll->HiFreq[ch] & 1) << 8));
      UPDATE_ALL(MOD(opll, ch));
      UPDATE_ALL(CAR(opll, ch));
      break;

    case 0x20:
    case 0x21:
    case 0x22:
    case 0x23:
    case 0x24:
    case 0x25:
      ch = reg - 0x20;
      opll->HiFreq[ch] = data;

      setFnumber(opll, ch, ((data & 1) << 8) + opll->LowFreq[ch]);
      setBlock(opll, ch, (data >> 1) & 7);
      setSustine(opll, ch, (data >> 5) & 1);
      if (data & 0x10)
        keyOn(opll, ch);
      else
        keyOff(opll, ch);
      UPDATE_ALL(MOD(opll, ch));
      UPDATE_ALL(CAR(opll, ch));
      update_key_status(opll);
      break;

    case 0x30:
    case 0x31:
    case 0x32:
    case 0x33:
    case 0x34:
    case 0x35:
      opll->InstVol[reg - 0x30] = data;
      i = (data >> 4) & 15;
      v = data & 15;
      setInstrument(opll, reg - 0x30, i);
      setVolume(opll, reg - 0x30, v << 2);
      UPDATE_ALL(MOD(opll, reg - 0x30));
      UPDATE_ALL(CAR(opll, reg - 0x30));
      break;

    default:
      break;
  }
}
