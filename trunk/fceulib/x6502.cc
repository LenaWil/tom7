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

#include <string.h>
#include "types.h"
#include "x6502.h"
#include "fceu.h"
#include "sound.h"

#include "tracing.h"

// XXX get rid of this -tom7
#define _A reg_A
#define _X reg_X
#define _Y reg_Y
#define _S reg_S
#define _P reg_P
#define _PI reg_PI

#define N_FLAG 0x80
#define V_FLAG 0x40
#define U_FLAG 0x20
#define B_FLAG 0x10
#define D_FLAG 0x08
#define I_FLAG 0x04
#define Z_FLAG 0x02
#define C_FLAG 0x01

X6502 X;

#define ADDCYC(x)            \
  {                          \
    int __x = x;             \
    this->tcount += __x;     \
    this->count -= __x * 48; \
    timestamp += __x;        \
  }

static inline void WrRAM(unsigned int A, uint8 V) {
  RAM[A] = V;
}

uint8 X6502::DMR(uint32 A) {
  ADDCYC(1);
  return (DB = ARead[A](A));
}

void X6502::DMW(uint32 A, uint8 V) {
  ADDCYC(1);
  BWrite[A](A, V);
}

#define PUSH(V)              \
  {                          \
    uint8 VTMP = V;          \
    WrRAM(0x100 + _S, VTMP); \
    _S--;                    \
  }

#define POP() RdRAM(0x100 + (++_S))

// I think this stands for "zero and negative" table, which has the
// zero and negative cpu flag set for each possible byte. The
// information content is pretty low, and we might consider replacing
// the ZN/ZNT macros with something that computes from the byte itself
// (for example, the N flag is actually 0x80 which is the same bit as
// what's tested to populate the table, so flags |= (b & 0x80)).
// Anyway, I inlined the values rather than establishing them when the
// emulator starts up, mostly for thread safety sake. -tom7
static constexpr uint8 ZNTable[256] = {
    Z_FLAG, 0,      0,      0,      0,      0,      0,      0,      0,
    0,      0,      0,      0,      0,      0,      0,      0,      0,
    0,      0,      0,      0,      0,      0,      0,      0,      0,
    0,      0,      0,      0,      0,      0,      0,      0,      0,
    0,      0,      0,      0,      0,      0,      0,      0,      0,
    0,      0,      0,      0,      0,      0,      0,      0,      0,
    0,      0,      0,      0,      0,      0,      0,      0,      0,
    0,      0,      0,      0,      0,      0,      0,      0,      0,
    0,      0,      0,      0,      0,      0,      0,      0,      0,
    0,      0,      0,      0,      0,      0,      0,      0,      0,
    0,      0,      0,      0,      0,      0,      0,      0,      0,
    0,      0,      0,      0,      0,      0,      0,      0,      0,
    0,      0,      0,      0,      0,      0,      0,      0,      0,
    0,      0,      0,      0,      0,      0,      0,      0,      0,
    0,      0,      N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG,
    N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG,
    N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG,
    N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG,
    N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG,
    N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG,
    N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG,
    N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG,
    N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG,
    N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG,
    N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG,
    N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG,
    N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG,
    N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG, N_FLAG,
    N_FLAG, N_FLAG, N_FLAG, N_FLAG,
};
/* Some of these operations will only make sense if you know what the flag
   constants are. */

#define X_ZN(zort)          \
  _P &= ~(Z_FLAG | N_FLAG); \
  _P |= ZNTable[zort]
#define X_ZNT(zort) _P |= ZNTable[zort]

#define JR(cond)                    \
  {                                 \
    if (cond) {                     \
      uint32 tmp;                   \
      int32 disp;                   \
      disp = (int8)RdMem(reg_PC);   \
      reg_PC++;                     \
      ADDCYC(1);                    \
      tmp = reg_PC;                 \
      reg_PC += disp;               \
      if ((tmp ^ reg_PC) & 0x100) { \
        ADDCYC(1);                  \
      }                             \
    } else {                        \
      reg_PC++;                     \
    }                               \
  }

#define LDA \
  _A = x;   \
  X_ZN(_A)
#define LDX \
  _X = x;   \
  X_ZN(_X)
#define LDY \
  _Y = x;   \
  X_ZN(_Y)

/*  All of the freaky arithmetic operations. */
#define AND \
  _A &= x;  \
  X_ZN(_A)
#define BIT                          \
  _P &= ~(Z_FLAG | V_FLAG | N_FLAG); \
  _P |= ZNTable[x & _A] & Z_FLAG;    \
  _P |= x & (V_FLAG | N_FLAG)
#define EOR \
  _A ^= x;  \
  X_ZN(_A)
#define ORA \
  _A |= x;  \
  X_ZN(_A)

#define ADC                                                      \
  {                                                              \
    uint32 l = _A + x + (_P & 1);                                \
    _P &= ~(Z_FLAG | C_FLAG | N_FLAG | V_FLAG);                  \
    _P |= ((((_A ^ x) & 0x80) ^ 0x80) & ((_A ^ l) & 0x80)) >> 1; \
    _P |= (l >> 8) & C_FLAG;                                     \
    _A = l;                                                      \
    X_ZNT(_A);                                                   \
  }

#define SBC                                     \
  {                                             \
    uint32 l = _A - x - ((_P & 1) ^ 1);         \
    _P &= ~(Z_FLAG | C_FLAG | N_FLAG | V_FLAG); \
    _P |= ((_A ^ l) & (_A ^ x) & 0x80) >> 1;    \
    _P |= ((l >> 8) & C_FLAG) ^ C_FLAG;         \
    _A = l;                                     \
    X_ZNT(_A);                                  \
  }

#define CMPL(a1, a2)                    \
  {                                     \
    uint32 t = a1 - a2;                 \
    X_ZN(t & 0xFF);                     \
    _P &= ~C_FLAG;                      \
    _P |= ((t >> 8) & C_FLAG) ^ C_FLAG; \
  }

/* Special undocumented operation.  Very similar to CMP. */
#define AXS                             \
  {                                     \
    uint32 t = (_A & _X) - x;           \
    X_ZN(t & 0xFF);                     \
    _P &= ~C_FLAG;                      \
    _P |= ((t >> 8) & C_FLAG) ^ C_FLAG; \
    _X = t;                             \
  }

#define CMP CMPL(_A, x)
#define CPX CMPL(_X, x)
#define CPY CMPL(_Y, x)

/* The following operations modify the byte being worked on. */
#define DEC \
  x--;      \
  X_ZN(x)
#define INC \
  x++;      \
  X_ZN(x)

#define ASL      \
  _P &= ~C_FLAG; \
  _P |= x >> 7;  \
  x <<= 1;       \
  X_ZN(x)
#define LSR                          \
  _P &= ~(C_FLAG | N_FLAG | Z_FLAG); \
  _P |= x & 1;                       \
  x >>= 1;                           \
  X_ZNT(x)

/* For undocumented instructions, maybe for other things later... */
#define LSRA                         \
  _P &= ~(C_FLAG | N_FLAG | Z_FLAG); \
  _P |= _A & 1;                      \
  _A >>= 1;                          \
  X_ZNT(_A)

#define ROL                            \
  {                                    \
    uint8 l = x >> 7;                  \
    x <<= 1;                           \
    x |= _P & C_FLAG;                  \
    _P &= ~(Z_FLAG | N_FLAG | C_FLAG); \
    _P |= l;                           \
    X_ZNT(x);                          \
  }
#define ROR                            \
  {                                    \
    uint8 l = x & 1;                   \
    x >>= 1;                           \
    x |= (_P & C_FLAG) << 7;           \
    _P &= ~(Z_FLAG | N_FLAG | C_FLAG); \
    _P |= l;                           \
    X_ZNT(x);                          \
  }

/* Icky icky thing for some undocumented instructions.  Can easily be
   broken if names of local variables are changed.
*/

/* Absolute */
#define GetAB(target)             \
  {                               \
    target = RdMem(reg_PC);       \
    reg_PC++;                     \
    target |= RdMem(reg_PC) << 8; \
    reg_PC++;                     \
  }

/* Absolute Indexed(for reads) */
#define GetABIRD(target, i)       \
  {                               \
    unsigned int tmp;             \
    GetAB(tmp);                   \
    target = tmp;                 \
    target += i;                  \
    if ((target ^ tmp) & 0x100) { \
      target &= 0xFFFF;           \
      RdMem(target ^ 0x100);      \
      ADDCYC(1);                  \
    }                             \
  }

/* Absolute Indexed(for writes and rmws) */
#define GetABIWR(target, i)                   \
  {                                           \
    unsigned int rt;                          \
    GetAB(rt);                                \
    target = rt;                              \
    target += i;                              \
    target &= 0xFFFF;                         \
    RdMem((target & 0x00FF) | (rt & 0xFF00)); \
  }

/* Zero Page */
#define GetZP(target)       \
  {                         \
    target = RdMem(reg_PC); \
    reg_PC++;               \
  }

/* Zero Page Indexed */
#define GetZPI(target, i)       \
  {                             \
    target = i + RdMem(reg_PC); \
    reg_PC++;                   \
  }

/* Indexed Indirect */
#define GetIX(target)          \
  {                            \
    uint8 tmp;                 \
    tmp = RdMem(reg_PC);       \
    reg_PC++;                  \
    tmp += _X;                 \
    target = RdRAM(tmp);       \
    tmp++;                     \
    target |= RdRAM(tmp) << 8; \
  }

/* Indirect Indexed(for reads) */
#define GetIYRD(target)          \
  {                              \
    unsigned int rt;             \
    uint8 tmp;                   \
    tmp = RdMem(reg_PC);         \
    reg_PC++;                    \
    rt = RdRAM(tmp);             \
    tmp++;                       \
    rt |= RdRAM(tmp) << 8;       \
    target = rt;                 \
    target += _Y;                \
    if ((target ^ rt) & 0x100) { \
      target &= 0xFFFF;          \
      RdMem(target ^ 0x100);     \
      ADDCYC(1);                 \
    }                            \
  }

/* Indirect Indexed(for writes and rmws) */
#define GetIYWR(target)                       \
  {                                           \
    unsigned int rt;                          \
    uint8 tmp;                                \
    tmp = RdMem(reg_PC);                      \
    reg_PC++;                                 \
    rt = RdRAM(tmp);                          \
    tmp++;                                    \
    rt |= RdRAM(tmp) << 8;                    \
    target = rt;                              \
    target += _Y;                             \
    target &= 0xFFFF;                         \
    RdMem((target & 0x00FF) | (rt & 0xFF00)); \
  }

/* Now come the macros to wrap up all of the above stuff addressing
   mode functions and operation macros. Note that operation macros
   will always operate(redundant redundant) on the variable "x".
*/

#define RMW_A(op) \
  {               \
    uint8 x = _A; \
    op;           \
    _A = x;       \
    break;        \
  }
#define RMW_AB(op)   \
  {                  \
    unsigned int AA; \
    uint8 x;         \
    GetAB(AA);       \
    x = RdMem(AA);   \
    WrMem(AA, x);    \
    op;              \
    WrMem(AA, x);    \
    break;           \
  }
#define RMW_ABI(reg, op) \
  {                      \
    unsigned int AA;     \
    uint8 x;             \
    GetABIWR(AA, reg);   \
    x = RdMem(AA);       \
    WrMem(AA, x);        \
    op;                  \
    WrMem(AA, x);        \
    break;               \
  }
#define RMW_ABX(op) RMW_ABI(_X, op)
#define RMW_ABY(op) RMW_ABI(_Y, op)
#define RMW_IX(op)   \
  {                  \
    unsigned int AA; \
    uint8 x;         \
    GetIX(AA);       \
    x = RdMem(AA);   \
    WrMem(AA, x);    \
    op;              \
    WrMem(AA, x);    \
    break;           \
  }
#define RMW_IY(op)   \
  {                  \
    unsigned int AA; \
    uint8 x;         \
    GetIYWR(AA);     \
    x = RdMem(AA);   \
    WrMem(AA, x);    \
    op;              \
    WrMem(AA, x);    \
    break;           \
  }
#define RMW_ZP(op) \
  {                \
    uint8 AA;      \
    uint8 x;       \
    GetZP(AA);     \
    x = RdRAM(AA); \
    op;            \
    WrRAM(AA, x);  \
    break;         \
  }
#define RMW_ZPX(op) \
  {                 \
    uint8 AA;       \
    uint8 x;        \
    GetZPI(AA, _X); \
    x = RdRAM(AA);  \
    op;             \
    WrRAM(AA, x);   \
    break;          \
  }

#define LD_IM(op)      \
  {                    \
    uint8 x;           \
    x = RdMem(reg_PC); \
    TRACEN(x);         \
    reg_PC++;          \
    op;                \
    break;             \
  }
#define LD_ZP(op)  \
  {                \
    uint8 AA;      \
    uint8 x;       \
    GetZP(AA);     \
    x = RdRAM(AA); \
    op;            \
    break;         \
  }
#define LD_ZPX(op)  \
  {                 \
    uint8 AA;       \
    uint8 x;        \
    GetZPI(AA, _X); \
    x = RdRAM(AA);  \
    op;             \
    break;          \
  }
#define LD_ZPY(op)  \
  {                 \
    uint8 AA;       \
    uint8 x;        \
    GetZPI(AA, _Y); \
    x = RdRAM(AA);  \
    op;             \
    break;          \
  }
#define LD_AB(op)                     \
  {                                   \
    unsigned int AA;                  \
    uint8 x;                          \
    GetAB(AA);                        \
    TRACEN(AA);                       \
    x = RdMem(AA);                    \
    TRACEF("Read %d -> %02x", AA, x); \
    (void) x;                         \
    op;                               \
    break;                            \
  }
#define LD_ABI(reg, op) \
  {                     \
    unsigned int AA;    \
    uint8 x;            \
    GetABIRD(AA, reg);  \
    x = RdMem(AA);      \
    (void) x;           \
    op;                 \
    break;              \
  }
#define LD_ABX(op) LD_ABI(_X, op)
#define LD_ABY(op) LD_ABI(_Y, op)
#define LD_IX(op)    \
  {                  \
    unsigned int AA; \
    uint8 x;         \
    GetIX(AA);       \
    x = RdMem(AA);   \
    op;              \
    break;           \
  }
#define LD_IY(op)    \
  {                  \
    unsigned int AA; \
    uint8 x;         \
    GetIYRD(AA);     \
    x = RdMem(AA);   \
    op;              \
    break;           \
  }

#define ST_ZP(r)  \
  {               \
    uint8 AA;     \
    GetZP(AA);    \
    WrRAM(AA, r); \
    break;        \
  }
#define ST_ZPX(r)   \
  {                 \
    uint8 AA;       \
    GetZPI(AA, _X); \
    WrRAM(AA, r);   \
    break;          \
  }
#define ST_ZPY(r)   \
  {                 \
    uint8 AA;       \
    GetZPI(AA, _Y); \
    WrRAM(AA, r);   \
    break;          \
  }
#define ST_AB(r)     \
  {                  \
    unsigned int AA; \
    GetAB(AA);       \
    WrMem(AA, r);    \
    break;           \
  }
#define ST_ABI(reg, r) \
  {                    \
    unsigned int AA;   \
    GetABIWR(AA, reg); \
    WrMem(AA, r);      \
    break;             \
  }
#define ST_ABX(r) ST_ABI(_X, r)
#define ST_ABY(r) ST_ABI(_Y, r)
#define ST_IX(r)     \
  {                  \
    unsigned int AA; \
    GetIX(AA);       \
    WrMem(AA, r);    \
    break;           \
  }
#define ST_IY(r)     \
  {                  \
    unsigned int AA; \
    GetIYWR(AA);     \
    WrMem(AA, r);    \
    break;           \
  }

static constexpr uint8 CycTable[256] = {
    /*0x00*/ 7, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 4, 4, 6, 6,
    /*0x10*/ 2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    /*0x20*/ 6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 4, 4, 6, 6,
    /*0x30*/ 2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    /*0x40*/ 6, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 3, 4, 6, 6,
    /*0x50*/ 2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    /*0x60*/ 6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 5, 4, 6, 6,
    /*0x70*/ 2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    /*0x80*/ 2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4,
    /*0x90*/ 2, 6, 2, 6, 4, 4, 4, 4, 2, 5, 2, 5, 5, 5, 5, 5,
    /*0xA0*/ 2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4,
    /*0xB0*/ 2, 5, 2, 5, 4, 4, 4, 4, 2, 4, 2, 4, 4, 4, 4, 4,
    /*0xC0*/ 2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6,
    /*0xD0*/ 2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    /*0xE0*/ 2, 6, 3, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6,
    /*0xF0*/ 2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
};

void X6502::IRQBegin(int w) {
  TRACEF("IRQBegin %d", w);
  IRQlow |= w;
}

void X6502::IRQEnd(int w) {
  TRACEF("IRQEnd %d", w);
  IRQlow &= ~w;
}

void X6502::TriggerNMI() {
  TRACEFUN();
  IRQlow |= FCEU_IQNMI;
}

void X6502::TriggerNMI2() {
  TRACEFUN();
  IRQlow |= FCEU_IQNMI2;
}

void X6502::Reset() {
  TRACEFUN();
  IRQlow = FCEU_IQRESET;
}

/**
* Initializes the 6502 CPU
**/
void X6502::Init() {
  // Initialize the CPU structure
  memset((void *)this, 0, sizeof(X6502));

// Now initialized statically. -tom7
#if 0
  for(int i = 0; i < sizeof(ZNTable); i++) {
    if (!i) {
      ZNTable[i] = Z_FLAG;
    } else if ( i & 0x80 ) {
      ZNTable[i] = N_FLAG;
    } else {
      ZNTable[i] = 0;
    }
  }
#endif
}

void X6502::Power() {
  count = tcount = IRQlow = reg_PC = _A = _X = _Y = _P = _PI = DB = jammed = 0;
  _S = 0xFD;
  timestamp = 0;
  Reset();
}

#define TRACE_MACHINEFMT \
  "X: %d %04x %02x %02x %02x %02x %02x %02x / %02x %u %02x"
#define TRACE_MACHINEARGS \
  count, reg_PC, _A, _X, _Y, _S, _P, _PI, jammed, IRQlow, DB

void X6502::Run(int32 cycles) {
  // Temporarily disable tracing unless this is the particular cycle
  // we're intereted in.
  // TRACE_SCOPED_STAY_ENABLED_IF(false);
  TRACE_SCOPED_STAY_ENABLED_IF(false);
  TRACEF("x6502_Run(%d) @ %d " TRACE_MACHINEFMT, cycles, timestamp,
         TRACE_MACHINEARGS);
  TRACEA(RAM, 0x800);
  // TRACEA(fceulib__ppu.PPU_values, 4);

  if (PAL) {
    cycles *= 15;  // 15*4=60
  } else {
    cycles *= 16;  // 16*4=64
  }

  count += cycles;

  while (count > 0) {
    int32 temp;

    TRACE_SCOPED_STAY_ENABLED_IF(false);
    TRACEF("while " TRACE_MACHINEFMT, TRACE_MACHINEARGS);
    TRACEA(RAM, 0x800);
    // TRACEA(fceulib__PPU_values, 4);

    if (IRQlow) {
      TRACEF("IRQlow set.");
      if (IRQlow & FCEU_IQRESET) {
        reg_PC = RdMem(0xFFFC);
        reg_PC |= RdMem(0xFFFD) << 8;
        jammed = 0;
        _PI = _P = I_FLAG;
        IRQlow &= ~FCEU_IQRESET;
      } else if (IRQlow & FCEU_IQNMI2) {
        IRQlow &= ~FCEU_IQNMI2;
        IRQlow |= FCEU_IQNMI;
      } else if (IRQlow & FCEU_IQNMI) {
        if (!jammed) {
          ADDCYC(7);
          PUSH(reg_PC >> 8);
          PUSH(reg_PC);
          PUSH((_P & ~B_FLAG) | (U_FLAG));
          _P |= I_FLAG;
          reg_PC = RdMem(0xFFFA);
          reg_PC |= RdMem(0xFFFB) << 8;
          IRQlow &= ~FCEU_IQNMI;
        }
      } else {
        if (!(_PI & I_FLAG) && !jammed) {
          ADDCYC(7);
          PUSH(reg_PC >> 8);
          PUSH(reg_PC);
          PUSH((_P & ~B_FLAG) | (U_FLAG));
          _P |= I_FLAG;
          reg_PC = RdMem(0xFFFE);
          reg_PC |= RdMem(0xFFFF) << 8;
        }
      }
      IRQlow &= ~(FCEU_IQTEMP);
      if (count <= 0) {
        _PI = _P;
        return;
        // Should increase accuracy without a
        // major speed hit.
      }
    }

    _PI = _P;
    const uint8 b1 = RdMem(reg_PC);

    ADDCYC(CycTable[b1]);

    temp = tcount;
    tcount = 0;
    if (MapIRQHook) MapIRQHook(temp);
    fceulib__sound.FCEU_SoundCPUHook(temp);
    reg_PC++;
    TRACEN(b1);
    switch (b1) {
      case 0x00: /* BRK */
        reg_PC++;
        PUSH(reg_PC >> 8);
        PUSH(reg_PC);
        PUSH(_P | U_FLAG | B_FLAG);
        _P |= I_FLAG;
        _PI |= I_FLAG;
        reg_PC = RdMem(0xFFFE);
        reg_PC |= RdMem(0xFFFF) << 8;
        break;

      case 0x40: /* RTI */
        _P = POP();
        /* _PI=_P; This is probably incorrect, so it's commented out. */
        _PI = _P;
        reg_PC = POP();
        reg_PC |= POP() << 8;
        break;

      case 0x60: /* RTS */
        reg_PC = POP();
        reg_PC |= POP() << 8;
        reg_PC++;
        break;

      case 0x48: /* PHA */ PUSH(_A); break;
      case 0x08: /* PHP */ PUSH(_P | U_FLAG | B_FLAG); break;
      case 0x68: /* PLA */
        _A = POP();
        X_ZN(_A);
        break;
      case 0x28: /* PLP */ _P = POP(); break;
      case 0x4C: {
        uint16 ptmp = reg_PC;
        unsigned int npc;

        npc = RdMem(ptmp);
        ptmp++;
        npc |= RdMem(ptmp) << 8;
        reg_PC = npc;
      } break; /* JMP ABSOLUTE */
      case 0x6C: {
        uint32 tmp;
        GetAB(tmp);
        reg_PC = RdMem(tmp);
        reg_PC |= RdMem(((tmp + 1) & 0x00FF) | (tmp & 0xFF00)) << 8;
      } break;
      case 0x20: /* JSR */
      {
        uint8 npc;
        npc = RdMem(reg_PC);
        reg_PC++;
        PUSH(reg_PC >> 8);
        PUSH(reg_PC);
        reg_PC = RdMem(reg_PC) << 8;
        reg_PC |= npc;
      } break;

      case 0xAA: /* TAX */
        _X = _A;
        X_ZN(_A);
        break;

      case 0x8A: /* TXA */
        _A = _X;
        X_ZN(_A);
        break;

      case 0xA8: /* TAY */
        _Y = _A;
        X_ZN(_A);
        break;
      case 0x98: /* TYA */
        _A = _Y;
        X_ZN(_A);
        break;

      case 0xBA: /* TSX */
        _X = _S;
        X_ZN(_X);
        break;
      case 0x9A: /* TXS */ _S = _X; break;

      case 0xCA: /* DEX */
        _X--;
        X_ZN(_X);
        break;
      case 0x88: /* DEY */
        _Y--;
        X_ZN(_Y);
        break;

      case 0xE8: /* INX */
        _X++;
        X_ZN(_X);
        break;
      case 0xC8: /* INY */
        _Y++;
        X_ZN(_Y);
        break;

      case 0x18: /* CLC */ _P &= ~C_FLAG; break;
      case 0xD8: /* CLD */ _P &= ~D_FLAG; break;
      case 0x58: /* CLI */ _P &= ~I_FLAG; break;
      case 0xB8: /* CLV */ _P &= ~V_FLAG; break;

      case 0x38: /* SEC */ _P |= C_FLAG; break;
      case 0xF8: /* SED */ _P |= D_FLAG; break;
      case 0x78: /* SEI */ _P |= I_FLAG; break;

      case 0xEA: /* NOP */ break;

      case 0x0A: RMW_A(ASL);
      case 0x06: RMW_ZP(ASL);
      case 0x16: RMW_ZPX(ASL);
      case 0x0E: RMW_AB(ASL);
      case 0x1E: RMW_ABX(ASL);

      case 0xC6: RMW_ZP(DEC);
      case 0xD6: RMW_ZPX(DEC);
      case 0xCE: RMW_AB(DEC);
      case 0xDE: RMW_ABX(DEC);

      case 0xE6: RMW_ZP(INC);
      case 0xF6: RMW_ZPX(INC);
      case 0xEE: RMW_AB(INC);
      case 0xFE: RMW_ABX(INC);

      case 0x4A: RMW_A(LSR);
      case 0x46: RMW_ZP(LSR);
      case 0x56: RMW_ZPX(LSR);
      case 0x4E: RMW_AB(LSR);
      case 0x5E: RMW_ABX(LSR);

      case 0x2A: RMW_A(ROL);
      case 0x26: RMW_ZP(ROL);
      case 0x36: RMW_ZPX(ROL);
      case 0x2E: RMW_AB(ROL);
      case 0x3E: RMW_ABX(ROL);

      case 0x6A: RMW_A(ROR);
      case 0x66: RMW_ZP(ROR);
      case 0x76: RMW_ZPX(ROR);
      case 0x6E: RMW_AB(ROR);
      case 0x7E: RMW_ABX(ROR);

      case 0x69: LD_IM(ADC);
      case 0x65: LD_ZP(ADC);
      case 0x75: LD_ZPX(ADC);
      case 0x6D: LD_AB(ADC);
      case 0x7D: LD_ABX(ADC);
      case 0x79: LD_ABY(ADC);
      case 0x61: LD_IX(ADC);
      case 0x71: LD_IY(ADC);

      case 0x29: LD_IM(AND);
      case 0x25: LD_ZP(AND);
      case 0x35: LD_ZPX(AND);
      case 0x2D: LD_AB(AND);
      case 0x3D: LD_ABX(AND);
      case 0x39: LD_ABY(AND);
      case 0x21: LD_IX(AND);
      case 0x31: LD_IY(AND);

      case 0x24: LD_ZP(BIT);
      case 0x2C: LD_AB(BIT);

      case 0xC9: LD_IM(CMP);
      case 0xC5: LD_ZP(CMP);
      case 0xD5: LD_ZPX(CMP);
      case 0xCD: LD_AB(CMP);
      case 0xDD: LD_ABX(CMP);
      case 0xD9: LD_ABY(CMP);
      case 0xC1: LD_IX(CMP);
      case 0xD1: LD_IY(CMP);

      case 0xE0: LD_IM(CPX);
      case 0xE4: LD_ZP(CPX);
      case 0xEC: LD_AB(CPX);

      case 0xC0: LD_IM(CPY);
      case 0xC4: LD_ZP(CPY);
      case 0xCC: LD_AB(CPY);

      case 0x49: LD_IM(EOR);
      case 0x45: LD_ZP(EOR);
      case 0x55: LD_ZPX(EOR);
      case 0x4D: LD_AB(EOR);
      case 0x5D: LD_ABX(EOR);
      case 0x59: LD_ABY(EOR);
      case 0x41: LD_IX(EOR);
      case 0x51: LD_IY(EOR);

      case 0xA9: LD_IM(LDA);
      case 0xA5: LD_ZP(LDA);
      case 0xB5: LD_ZPX(LDA);
      case 0xAD: LD_AB(LDA);
      case 0xBD: LD_ABX(LDA);
      case 0xB9: LD_ABY(LDA);
      case 0xA1: LD_IX(LDA);
      case 0xB1: LD_IY(LDA);

      case 0xA2: LD_IM(LDX);
      case 0xA6: LD_ZP(LDX);
      case 0xB6: LD_ZPY(LDX);
      case 0xAE: LD_AB(LDX);
      case 0xBE: LD_ABY(LDX);

      case 0xA0: LD_IM(LDY);
      case 0xA4: LD_ZP(LDY);
      case 0xB4: LD_ZPX(LDY);
      case 0xAC: LD_AB(LDY);
      case 0xBC: LD_ABX(LDY);

      case 0x09: LD_IM(ORA);
      case 0x05: LD_ZP(ORA);
      case 0x15: LD_ZPX(ORA);
      case 0x0D: LD_AB(ORA);
      case 0x1D: LD_ABX(ORA);
      case 0x19: LD_ABY(ORA);
      case 0x01: LD_IX(ORA);
      case 0x11: LD_IY(ORA);

      case 0xEB: /* (undocumented) */
      case 0xE9: LD_IM(SBC);
      case 0xE5: LD_ZP(SBC);
      case 0xF5: LD_ZPX(SBC);
      case 0xED: LD_AB(SBC);
      case 0xFD: LD_ABX(SBC);
      case 0xF9: LD_ABY(SBC);
      case 0xE1: LD_IX(SBC);
      case 0xF1: LD_IY(SBC);

      case 0x85: ST_ZP(_A);
      case 0x95: ST_ZPX(_A);
      case 0x8D: ST_AB(_A);
      case 0x9D: ST_ABX(_A);
      case 0x99: ST_ABY(_A);
      case 0x81: ST_IX(_A);
      case 0x91: ST_IY(_A);

      case 0x86: ST_ZP(_X);
      case 0x96: ST_ZPY(_X);
      case 0x8E: ST_AB(_X);

      case 0x84: ST_ZP(_Y);
      case 0x94: ST_ZPX(_Y);
      case 0x8C:
        ST_AB(_Y);

      /* BCC */
      case 0x90:
        JR(!(_P & C_FLAG));
        break;

      /* BCS */
      case 0xB0:
        JR(_P & C_FLAG);
        break;

      /* BEQ */
      case 0xF0:
        JR(_P & Z_FLAG);
        break;

      /* BNE */
      case 0xD0:
        JR(!(_P & Z_FLAG));
        break;

      /* BMI */
      case 0x30:
        JR(_P & N_FLAG);
        break;

      /* BPL */
      case 0x10:
        JR(!(_P & N_FLAG));
        break;

      /* BVC */
      case 0x50:
        JR(!(_P & V_FLAG));
        break;

      /* BVS */
      case 0x70:
        JR(_P & V_FLAG);
        break;

      // default: printf("Bad %02x at $%04x\n",b1,X.PC);break;
      /* Here comes the undocumented instructions block.  Note that this
     implementation
     may be "wrong".  If so, please tell me.
      */

      /* AAC */
      case 0x2B:
      case 0x0B:
        LD_IM(AND; _P &= ~C_FLAG; _P |= _A >> 7);

      /* AAX */
      case 0x87: ST_ZP(_A & _X);
      case 0x97: ST_ZPY(_A & _X);
      case 0x8F: ST_AB(_A & _X);
      case 0x83:
        ST_IX(_A & _X);

      /* ARR - ARGH, MATEY! */
      case 0x6B: {
        uint8 arrtmp;
        LD_IM(AND; _P &= ~V_FLAG; _P |= (_A ^ (_A >> 1)) & 0x40;
              arrtmp = _A >> 7; _A >>= 1; _A |= (_P & C_FLAG) << 7;
              _P &= ~C_FLAG; _P |= arrtmp; X_ZN(_A));
      }
      /* ASR */
      case 0x4B:
        LD_IM(AND; LSRA);

      /* ATX(OAL) Is this(OR with $EE) correct? Blargg did some test
     and found the constant to be OR with is $FF for NES */
      case 0xAB:
        LD_IM(_A |= 0xFF; AND; _X = _A);

      /* AXS */
      case 0xCB:
        LD_IM(AXS);

      /* DCP */
      case 0xC7: RMW_ZP(DEC; CMP);
      case 0xD7: RMW_ZPX(DEC; CMP);
      case 0xCF: RMW_AB(DEC; CMP);
      case 0xDF: RMW_ABX(DEC; CMP);
      case 0xDB: RMW_ABY(DEC; CMP);
      case 0xC3: RMW_IX(DEC; CMP);
      case 0xD3:
        RMW_IY(DEC; CMP);

      /* ISB */
      case 0xE7: RMW_ZP(INC; SBC);
      case 0xF7: RMW_ZPX(INC; SBC);
      case 0xEF: RMW_AB(INC; SBC);
      case 0xFF: RMW_ABX(INC; SBC);
      case 0xFB: RMW_ABY(INC; SBC);
      case 0xE3: RMW_IX(INC; SBC);
      case 0xF3:
        RMW_IY(INC; SBC);

      /* DOP */

      case 0x04: reg_PC++; break;
      case 0x14: reg_PC++; break;
      case 0x34: reg_PC++; break;
      case 0x44: reg_PC++; break;
      case 0x54: reg_PC++; break;
      case 0x64: reg_PC++; break;
      case 0x74: reg_PC++; break;

      case 0x80: reg_PC++; break;
      case 0x82: reg_PC++; break;
      case 0x89: reg_PC++; break;
      case 0xC2: reg_PC++; break;
      case 0xD4: reg_PC++; break;
      case 0xE2: reg_PC++; break;
      case 0xF4:
        reg_PC++;
        break;

      /* KIL */

      case 0x02:
      case 0x12:
      case 0x22:
      case 0x32:
      case 0x42:
      case 0x52:
      case 0x62:
      case 0x72:
      case 0x92:
      case 0xB2:
      case 0xD2:
      case 0xF2:
        ADDCYC(0xFF);
        jammed = 1;
        reg_PC--;
        break;

      /* LAR */
      case 0xBB:
        RMW_ABY(_S &= x; _A = _X = _S; X_ZN(_X));

      /* LAX */
      case 0xA7: LD_ZP(LDA; LDX);
      case 0xB7: LD_ZPY(LDA; LDX);
      case 0xAF: LD_AB(LDA; LDX);
      case 0xBF: LD_ABY(LDA; LDX);
      case 0xA3: LD_IX(LDA; LDX);
      case 0xB3:
        LD_IY(LDA; LDX);

      /* NOP */
      case 0x1A:
      case 0x3A:
      case 0x5A:
      case 0x7A:
      case 0xDA:
      case 0xFA:
        break;

      /* RLA */
      case 0x27: RMW_ZP(ROL; AND);
      case 0x37: RMW_ZPX(ROL; AND);
      case 0x2F: RMW_AB(ROL; AND);
      case 0x3F: RMW_ABX(ROL; AND);
      case 0x3B: RMW_ABY(ROL; AND);
      case 0x23: RMW_IX(ROL; AND);
      case 0x33:
        RMW_IY(ROL; AND);

      /* RRA */
      case 0x67: RMW_ZP(ROR; ADC);
      case 0x77: RMW_ZPX(ROR; ADC);
      case 0x6F: RMW_AB(ROR; ADC);
      case 0x7F: RMW_ABX(ROR; ADC);
      case 0x7B: RMW_ABY(ROR; ADC);
      case 0x63: RMW_IX(ROR; ADC);
      case 0x73:
        RMW_IY(ROR; ADC);

      /* SLO */
      case 0x07: RMW_ZP(ASL; ORA);
      case 0x17: RMW_ZPX(ASL; ORA);
      case 0x0F: RMW_AB(ASL; ORA);
      case 0x1F: RMW_ABX(ASL; ORA);
      case 0x1B: RMW_ABY(ASL; ORA);
      case 0x03: RMW_IX(ASL; ORA);
      case 0x13:
        RMW_IY(ASL; ORA);

      /* SRE */
      case 0x47: RMW_ZP(LSR; EOR);
      case 0x57: RMW_ZPX(LSR; EOR);
      case 0x4F: RMW_AB(LSR; EOR);
      case 0x5F: RMW_ABX(LSR; EOR);
      case 0x5B: RMW_ABY(LSR; EOR);
      case 0x43: RMW_IX(LSR; EOR);
      case 0x53:
        RMW_IY(LSR; EOR);

      /* AXA - SHA */
      case 0x93: ST_IY(_A & _X & (((AA - _Y) >> 8) + 1));
      case 0x9F:
        ST_ABY(_A & _X & (((AA - _Y) >> 8) + 1));

      /* SYA */
      case 0x9C:
        ST_ABX(_Y & (((AA - _X) >> 8) + 1));

      /* SXA */
      case 0x9E:
        ST_ABY(_X & (((AA - _Y) >> 8) + 1));

      /* XAS */
      case 0x9B:
        _S = _A & _X;
        ST_ABY(_S & (((AA - _Y) >> 8) + 1));

      /* TOP */
      case 0x0C: LD_AB(;);
      case 0x1C:
      case 0x3C:
      case 0x5C:
      case 0x7C:
      case 0xDC:
      case 0xFC:
        LD_ABX(;);

      /* XAA - BIG QUESTION MARK HERE */
      case 0x8B:
        _A |= 0xEE;
        _A &= _X;
        LD_IM(AND);
        // endif
    }
  }
  TRACEF("Exiting X6502_Run normally: " TRACE_MACHINEFMT, TRACE_MACHINEARGS);
  TRACEA(RAM, 0x800);
}
