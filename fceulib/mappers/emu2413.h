#ifndef _EMU2413_H_
#define _EMU2413_H_

#include "../types.h"

/* voice data */
typedef struct {
  uint32 TL, FB, EG, ML, AR, DR, SL, RR, KR, KL, AM, PM, WF;
} OPLL_PATCH;

/* slot */
typedef struct {
  OPLL_PATCH patch;

  int32 type; /* 0 : modulator 1 : carrier */

  /* OUTPUT */
  int32 feedback;
  int32 output[2]; /* Output value of slot */

  /* for Phase Generator (PG) */
  uint16 *sintbl; /* Wavetable */
  uint32 phase; /* Phase */
  uint32 dphase; /* Phase increment amount */
  uint32 pgout; /* output */

  /* for Envelope Generator (EG) */
  int32 fnum; /* F-Number */
  int32 block; /* Block */
  int32 volume; /* Current volume */
  int32 sustine; /* Sustine 1 = ON, 0 = OFF */
  uint32 tll; /* Total Level + Key scale level*/
  uint32 rks; /* Key scale offset (Rks) */
  int32 eg_mode; /* Current state */
  uint32 eg_phase; /* Phase */
  uint32 eg_dphase; /* Phase increment amount */
  uint32 egout; /* output */
} OPLL_SLOT;

/* opll */
typedef struct {
  uint32 adr;
  int32 out;

  uint32 realstep;
  uint32 oplltime;
  uint32 opllstep;
  int32 prev, next;

  /* Register */
  uint8 LowFreq[6];
  uint8 HiFreq[6];
  uint8 InstVol[6];

  uint8 CustInst[8];

  int32 slot_on_flag[6 * 2];

  /* Pitch Modulator */
  uint32 pm_phase;
  int32 lfo_pm;

  /* Amp Modulator */
  int32 am_phase;
  int32 lfo_am;

  uint32 quality;

  /* Channel Data */
  int32 patch_number[6];
  int32 key_status[6];

  /* Slot */
  OPLL_SLOT slot[6 * 2];

  uint32 mask;
} OPLL;

/* Size of Sintable ( 8 -- 18 can be used. 9 recommended.)*/
#define PG_BITS 9
#define PG_WIDTH (1 << PG_BITS)
/* Bits for Pitch and Amp modulator */
#define PM_PG_BITS 8
#define PM_PG_WIDTH (1 << PM_PG_BITS)
#define PM_DP_BITS 16
#define PM_DP_WIDTH (1 << PM_DP_BITS)
#define AM_PG_BITS 8
#define AM_PG_WIDTH (1 << AM_PG_BITS)
#define AM_DP_BITS 16
#define AM_DP_WIDTH (1 << AM_DP_BITS)

/* Dynamic range (Accuracy of sin table) */
#define DB_BITS 8
#define DB_STEP (48.0 / (1 << DB_BITS))
#define DB_MUTE (1 << DB_BITS)

/* Dynamic range of envelope */
#define EG_STEP 0.375
#define EG_BITS 7
#define EG_MUTE (1 << EG_BITS)

/* Dynamic range of total level */
#define TL_STEP 0.75
#define TL_BITS 6
#define TL_MUTE (1 << TL_BITS)

struct EMU2413 {
  
  /* Create Object */
  OPLL *OPLL_new(uint32 clk, uint32 rate);
  void OPLL_delete(OPLL *);

  /* Setup */
  void OPLL_reset(OPLL *);
  void OPLL_set_rate(OPLL *opll, uint32 r);
  // void OPLL_set_quality(OPLL *opll, uint32 q);

  /* Port/Register access */
  // void OPLL_writeIO(OPLL *, uint32 reg, uint32 val);
  void OPLL_writeReg(OPLL *, uint32 reg, uint32 val);

  /* Misc */
  void OPLL_forceRefresh(OPLL *);

  void OPLL_FillBuffer(OPLL *opll, int32 *buf, int32 len, int shift);

private:
  void makeAdjustTable();
  void makeDB2LinTable();
  int32 lin2db(double d);
  void makeSinTable();
  void makePmTable();
  void makeAmTable();
  void makeDphaseTable();
  void makeRksTable();
  void makeTllTable();
  void makeDphaseARTable();
  void makeDphaseDRTable();
  uint32 calc_eg_dphase(OPLL_SLOT *slot);
  void slotOn(OPLL_SLOT *slot);
  void slotOff(OPLL_SLOT *slot);
  void keyOn(OPLL *opll, int32 i);
  void keyOff(OPLL *opll, int32 i);
  void setSustine(OPLL *opll, int32 c, int32 sustine);
  void setVolume(OPLL *opll, int32 c, int32 volume);
  void setFnumber(OPLL *opll, int32 c, int32 fnum);
  void setBlock(OPLL *opll, int32 c, int32 block);
  void update_key_status(OPLL *opll);
  void OPLL_SLOT_reset(OPLL_SLOT *slot, int type);
  void internal_refresh();
  void maketables(uint32 c, uint32 r);
  void setInstrument(OPLL *opll, uint32 i, uint32 inst);
  int16 calc(OPLL *opll);
  int32 calc_slot_mod(OPLL_SLOT *slot);
  void update_ampm(OPLL *opll);
  void calc_phase(OPLL_SLOT *slot, int32 lfo);
  void calc_envelope(OPLL_SLOT *slot, int32 lfo);
  int32 calc_slot_car(OPLL_SLOT *slot, int32 fm);
  
  /* Input clock */
  uint32 clk = 844451141;
  /* Sampling rate */
  uint32 rate = 3354932;

  /* WaveTable for each envelope amp */
  uint16 fullsintable[PG_WIDTH] = {};
  uint16 halfsintable[PG_WIDTH] = {};

  uint16 *waveform[2] = {fullsintable, halfsintable};

  /* LFO Table */
  int32 pmtable[PM_PG_WIDTH] = {};
  int32 amtable[AM_PG_WIDTH] = {};

  /* Phase delta for LFO */
  uint32 pm_dphase = 0;
  uint32 am_dphase = 0;

  /* dB to Liner table */
  int16 DB2LIN_TABLE[(DB_MUTE + DB_MUTE) * 2] = {};

  /* Liner to Log curve conversion table (for Attack rate). */
  uint16 AR_ADJUST_TABLE[1 << EG_BITS] = {};

  /* Phase incr table for Attack */
  uint32 dphaseARTable[16][16] = {};
  /* Phase incr table for Decay and Release */
  uint32 dphaseDRTable[16][16] = {};

  /* KSL + TL Table */
  uint32 tllTable[16][8][1 << TL_BITS][4] = {};
  int32 rksTable[2][8][2] = {};

  /* Phase incr table for PG */
  uint32 dphaseTable[512][8][16] = {};
};
  
#endif
