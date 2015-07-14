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

#include "mapinc.h"

static uint8 cmd, dip;
static uint8 latch[8];

static void S74LS374MSync(uint8 mirr) {
  switch (mirr & 3) {
    case 0: fceulib__.cart->setmirror(MI_V); break;
    case 1: fceulib__.cart->setmirror(MI_H); break;
    case 2: fceulib__.cart->setmirrorw(0, 1, 1, 1); break;
    case 3: fceulib__.cart->setmirror(MI_0); break;
  }
}

static void S74LS374NSynco() {
  fceulib__.cart->setprg32(0x8000, latch[0]);
  fceulib__.cart->setchr8(latch[1] | latch[3] | latch[4]);
  S74LS374MSync(latch[2]);
}

static DECLFW(S74LS374NWrite) {
  A &= 0x4101;
  if (A == 0x4100)
    cmd = V & 7;
  else {
    switch (cmd) {
      case 2:
        latch[0] = V & 1;
        latch[3] = (V & 1) << 3;
        break;
      case 4: latch[4] = (V & 1) << 2; break;
      case 5: latch[0] = V & 7; break;
      case 6: latch[1] = V & 3; break;
      case 7: latch[2] = V >> 1; break;
    }
    S74LS374NSynco();
  }
}

static DECLFR(S74LS374NRead) {
  uint8 ret;
  if ((A & 0x4100) == 0x4100)
    //	  ret=(fceulib__.X->DB&0xC0)|((~cmd)&0x3F);
    ret = ((~cmd) & 0x3F) ^ dip;
  else
    ret = fceulib__.X->DB;
  return ret;
}

static void S74LS374NPower() {
  dip = 0;
  latch[0] = latch[1] = latch[2] = latch[3] = latch[4] = 0;
  S74LS374NSynco();
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x4100, 0x7FFF, S74LS374NWrite);
  fceulib__.fceu->SetReadHandler(0x4100, 0x5fff, S74LS374NRead);
}

static void S74LS374NReset() {
  dip ^= 1;
  latch[0] = latch[1] = latch[2] = latch[3] = latch[4] = 0;
  S74LS374NSynco();
}

static void S74LS374NRestore(int version) {
  S74LS374NSynco();
}

void S74LS374N_Init(CartInfo *info) {
  info->Power = S74LS374NPower;
  info->Reset = S74LS374NReset;
  fceulib__.fceu->GameStateRestore = S74LS374NRestore;
  fceulib__.state->AddExState(latch, 5, 0, "LATC");
  fceulib__.state->AddExState(&cmd, 1, 0, "CMD");
  fceulib__.state->AddExState(&dip, 1, 0, "DIP");
}

static void S74LS374NASynco() {
  fceulib__.cart->setprg32(0x8000, latch[0]);
  fceulib__.cart->setchr8(latch[1]);
  S74LS374MSync(latch[2]);
}

static DECLFW(S74LS374NAWrite) {
  A &= 0x4101;
  if (A == 0x4100)
    cmd = V & 7;
  else {
    switch (cmd) {
      case 0:
        latch[0] = 0;
        latch[1] = 3;
        break;
      case 2: latch[3] = (V & 1) << 3; break;
      case 4: latch[1] = (latch[1] & 6) | (V & 3); break;
      case 5: latch[0] = V & 1; break;
      case 6: latch[1] = (latch[1] & 1) | latch[3] | ((V & 3) << 1); break;
      case 7: latch[2] = V & 1; break;
    }
    S74LS374NASynco();
  }
}

static void S74LS374NAPower() {
  latch[0] = latch[2] = latch[3] = latch[4] = 0;
  latch[1] = 3;
  S74LS374NASynco();
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x4100, 0x7FFF, S74LS374NAWrite);
}

void S74LS374NA_Init(CartInfo *info) {
  info->Power = S74LS374NAPower;
  fceulib__.fceu->GameStateRestore = S74LS374NRestore;
  fceulib__.state->AddExState(latch, 5, 0, "LATC");
  fceulib__.state->AddExState(&cmd, 1, 0, "CMD");
}

static int type;
static void S8259Synco() {
  fceulib__.cart->setprg32(0x8000, latch[5] & 7);

  if (!fceulib__.unif->UNIFchrrama) {
    // No CHR RAM?  Then BS'ing is ok.
    for (int x = 0; x < 4; x++) {
      int bank;
      if (latch[7] & 1)
        bank = (latch[0] & 0x7) | ((latch[4] & 7) << 3);
      else
        bank = (latch[x] & 0x7) | ((latch[4] & 7) << 3);
      switch (type) {
        case 00:
          bank = (bank << 1) | (x & 1);
          fceulib__.cart->setchr2(0x800 * x, bank);
          break;
        case 01: fceulib__.cart->setchr2(0x800 * x, bank); break;
        case 02:
          bank = (bank << 2) | (x & 3);
          fceulib__.cart->setchr2(0x800 * x, bank);
          break;
        case 03:
          bank = latch[x] & 7;
          switch (x & 3) {
            case 01: bank |= (latch[4] & 1) << 4; break;
            case 02: bank |= (latch[4] & 2) << 3; break;
            case 03:
              bank |= ((latch[4] & 4) << 2) | ((latch[6] & 1) << 3);
              break;
          }
          fceulib__.cart->setchr1(0x400 * x, bank);
          fceulib__.cart->setchr4(0x1000, ~0);
          break;
      }
    }
  }
  if (!(latch[7] & 1))
    S74LS374MSync(latch[7] >> 1);
  else
    fceulib__.cart->setmirror(MI_V);
}

static DECLFW(S8259Write) {
  A &= 0x4101;
  if (A == 0x4100)
    cmd = V;
  else {
    latch[cmd & 7] = V;
    S8259Synco();
  }
}

static void S8259Reset() {
  cmd = 0;

  for (int x = 0; x < 8; x++) latch[x] = 0;
  fceulib__.cart->setchr8(0);

  S8259Synco();
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x4100, 0x7FFF, S8259Write);
}

static void S8259Restore(int version) {
  S8259Synco();
}

void S8259A_Init(CartInfo *info)  // Kevin's Horton 141 mapper
{
  info->Power = S8259Reset;
  fceulib__.fceu->GameStateRestore = S8259Restore;
  fceulib__.state->AddExState(latch, 8, 0, "LATC");
  fceulib__.state->AddExState(&cmd, 1, 0, "CMD");
  type = 0;
}

void S8259B_Init(CartInfo *info)  // Kevin's Horton 138 mapper
{
  info->Power = S8259Reset;
  fceulib__.fceu->GameStateRestore = S8259Restore;
  fceulib__.state->AddExState(latch, 8, 0, "LATC");
  fceulib__.state->AddExState(&cmd, 1, 0, "CMD");
  type = 1;
}

void S8259C_Init(CartInfo *info)  // Kevin's Horton 139 mapper
{
  info->Power = S8259Reset;
  fceulib__.fceu->GameStateRestore = S8259Restore;
  fceulib__.state->AddExState(latch, 8, 0, "LATC");
  fceulib__.state->AddExState(&cmd, 1, 0, "CMD");
  type = 2;
}

void S8259D_Init(CartInfo *info)  // Kevin's Horton 137 mapper
{
  info->Power = S8259Reset;
  fceulib__.fceu->GameStateRestore = S8259Restore;
  fceulib__.state->AddExState(latch, 8, 0, "LATC");
  fceulib__.state->AddExState(&cmd, 1, 0, "CMD");
  type = 3;
}

static void (*WSync)();

static DECLFW(SAWrite) {
  if (A & 0x100) {
    latch[0] = V;
    WSync();
  }
}

static void SAPower() {
  latch[0] = 0;
  WSync();
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x4100, 0x5FFF, SAWrite);
}

static void SARestore(int version) {
  WSync();
}

static DECLFW(SADWrite) {
  latch[0] = V;
  WSync();
}

static void SADPower() {
  latch[0] = 0;
  WSync();
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x8000, 0xFFFF, SADWrite);
}

static void SA0161MSynco() {
  fceulib__.cart->setprg32(0x8000, (latch[0] >> 3) & 1);
  fceulib__.cart->setchr8(latch[0] & 7);
}

static void SA72007Synco() {
  fceulib__.cart->setprg32(0x8000, 0);
  fceulib__.cart->setchr8(latch[0] >> 7);
}

static void SA009Synco() {
  fceulib__.cart->setprg32(0x8000, 0);
  fceulib__.cart->setchr8(latch[0] & 1);
}

static void SA72008Synco() {
  fceulib__.cart->setprg32(0x8000, (latch[0] >> 2) & 1);
  fceulib__.cart->setchr8(latch[0] & 3);
}

void SA0161M_Init(CartInfo *info) {
  WSync = SA0161MSynco;
  fceulib__.fceu->GameStateRestore = SARestore;
  info->Power = SAPower;
  fceulib__.state->AddExState(&latch[0], 1, 0, "LATC");
}

void SA72007_Init(CartInfo *info) {
  WSync = SA72007Synco;
  fceulib__.fceu->GameStateRestore = SARestore;
  info->Power = SAPower;
  fceulib__.state->AddExState(&latch[0], 1, 0, "LATC");
}

void SA72008_Init(CartInfo *info) {
  WSync = SA72008Synco;
  fceulib__.fceu->GameStateRestore = SARestore;
  info->Power = SAPower;
  fceulib__.state->AddExState(&latch[0], 1, 0, "LATC");
}

void SA009_Init(CartInfo *info) {
  WSync = SA009Synco;
  fceulib__.fceu->GameStateRestore = SARestore;
  info->Power = SAPower;
  fceulib__.state->AddExState(&latch[0], 1, 0, "LATC");
}

void SA0036_Init(CartInfo *info) {
  WSync = SA72007Synco;
  fceulib__.fceu->GameStateRestore = SARestore;
  info->Power = SADPower;
  fceulib__.state->AddExState(&latch[0], 1, 0, "LATC");
}

void SA0037_Init(CartInfo *info) {
  WSync = SA0161MSynco;
  fceulib__.fceu->GameStateRestore = SARestore;
  info->Power = SADPower;
  fceulib__.state->AddExState(&latch[0], 1, 0, "LATC");
}

// -----------------------------------------------

static void TCU01Synco() {
  fceulib__.cart->setprg32(0x8000,
                           ((latch[0] & 0x80) >> 6) | ((latch[0] >> 2) & 1));
  fceulib__.cart->setchr8((latch[0] >> 3) & 0xF);
}

static DECLFW(TCU01Write) {
  if ((A & 0x103) == 0x102) {
    latch[0] = V;
    TCU01Synco();
  }
}

static void TCU01Power() {
  latch[0] = 0;
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetWriteHandler(0x4100, 0xFFFF, TCU01Write);
  TCU01Synco();
}

static void TCU01Restore(int version) {
  TCU01Synco();
}

void TCU01_Init(CartInfo *info) {
  fceulib__.fceu->GameStateRestore = TCU01Restore;
  info->Power = TCU01Power;
  fceulib__.state->AddExState(&latch[0], 1, 0, "LATC");
}

//-----------------------------------------------

static void TCU02Synco() {
  fceulib__.cart->setprg32(0x8000, 0);
  fceulib__.cart->setchr8(latch[0] & 3);
}

static DECLFW(TCU02Write) {
  if ((A & 0x103) == 0x102) {
    latch[0] = V + 3;
    TCU02Synco();
  }
}

static DECLFR(TCU02Read) {
  return (latch[0] & 0x3F) | (fceulib__.X->DB & 0xC0);
}

static void TCU02Power() {
  latch[0] = 0;
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetReadHandler(0x4100, 0x4100, TCU02Read);
  fceulib__.fceu->SetWriteHandler(0x4100, 0xFFFF, TCU02Write);
  TCU02Synco();
}

static void TCU02Restore(int version) {
  TCU02Synco();
}

void TCU02_Init(CartInfo *info) {
  fceulib__.fceu->GameStateRestore = TCU02Restore;
  info->Power = TCU02Power;
  fceulib__.state->AddExState(&latch[0], 1, 0, "LATC");
}

// ---------------------------------------------

static DECLFR(TCA01Read) {
  uint8 ret;
  if ((A & 0x4100) == 0x4100)
    ret = (fceulib__.X->DB & 0xC0) | ((~A) & 0x3F);
  else
    ret = fceulib__.X->DB;
  return ret;
}

static void TCA01Power() {
  fceulib__.cart->setprg16(0x8000, 0);
  fceulib__.cart->setprg16(0xC000, 1);
  fceulib__.cart->setchr8(0);
  fceulib__.fceu->SetReadHandler(0x8000, 0xFFFF, Cart::CartBR);
  fceulib__.fceu->SetReadHandler(0x4100, 0x5FFF, TCA01Read);
}

void TCA01_Init(CartInfo *info) {
  info->Power = TCA01Power;
}
