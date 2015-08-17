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
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

/* TODO:  Battery backup file saving, mirror force    */
/* **INCOMPLETE**             */
/* Override stuff: CHR RAM instead of CHR ROM,   mirroring. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "types.h"
#include "fceu.h"
#include "cart.h"
#include "unif.h"
#include "ines.h"
#include "utils/endian.h"
#include "utils/memory.h"
#include "utils/md5.h"
#include "state.h"
#include "file.h"
#include "input.h"
#include "driver.h"
#include "boards/boards.h"

namespace {
struct BMAPPING {
  const char *const name;
  CartInterface *(*const init)(FC *, CartInfo *);
  const int flags;
};

struct BFMAPPING {
  const char *const name;
  int (Unif::*const init)(FceuFile *fp);
};
}

Unif::Unif(FC *fc) : fc(fc) {}

static int FixRomSize(uint32 size, uint32 minimum) {
  uint32 x = 1;

  if (size < minimum) return minimum;
  while (x < size) x <<= 1;
  return x;
}

void Unif::FreeUNIF() {
  free(UNIFchrrama);
  UNIFchrrama = nullptr;

  free(boardname);
  boardname = nullptr;

  for (int x = 0; x < 32; x++) {
    free(malloced[x]);
    malloced[x] = nullptr;
  }

  delete fc->fceu->cartiface;
  fc->fceu->cartiface = nullptr;
}

void Unif::ResetUNIF() {
  for (int x = 0; x < 32; x++) malloced[x] = 0;
  vramo = 0;
  boardname = nullptr;
  mirrortodo = 0;
  memset(&UNIFCart, 0, sizeof(UNIFCart));
  delete fc->fceu->cartiface;
  fc->fceu->cartiface = nullptr;
  UNIFchrrama = nullptr;
}

void Unif::MooMirroring() {
  if (mirrortodo < 0x4) {
    fc->cart->SetupCartMirroring(mirrortodo, 1, 0);
  } else if (mirrortodo == 0x4) {
    fc->cart->SetupCartMirroring(4, 1, exntar);
    fc->state->AddExState(exntar, 2048, 0, "EXNR");
  } else {
    fc->cart->SetupCartMirroring(0, 0, 0);
  }
}

int Unif::DoMirroring(FceuFile *fp) {
  const uint8 t = FCEU_fgetc(fp);
  mirrortodo = t;

  static constexpr const char *const stuffo[] = {
      "Horizontal",
      "Vertical",
      "$2000",
      "$2400",
      "\"Four-screen\"",
      "Controlled by Mapper Hardware"
  };
  if (t < 6) FCEU_printf(" Name/Attribute Table Mirroring: %s\n", stuffo[t]);
  return 1;
}

// Note: This used to fill in the unused name field in GameInfo, but
// now all it does is print it out. -tom7
int Unif::NAME(FceuFile *fp) {
  char namebuf[100];
  int index;
  int t;

  FCEU_printf(" Name: ");
  index = 0;

  while ((t = FCEU_fgetc(fp)) > 0)
    if (index < 99) namebuf[index++] = t;

  namebuf[index] = 0;
  FCEU_printf("%s\n", namebuf);

  return 1;
}

int Unif::DINF(FceuFile *fp) {
  char name[100], method[100];
  uint8 d, m;
  uint16 y;
  int t;

  if (FCEU_fread(name, 1, 100, fp) != 100) return 0;
  if ((t = FCEU_fgetc(fp)) == EOF) return 0;
  d = t;
  if ((t = FCEU_fgetc(fp)) == EOF) return 0;
  m = t;
  if ((t = FCEU_fgetc(fp)) == EOF) return 0;
  y = t;
  if ((t = FCEU_fgetc(fp)) == EOF) return 0;
  y |= t << 8;
  if (FCEU_fread(method, 1, 100, fp) != 100) return 0;
  name[99] = method[99] = 0;
  FCEU_printf(" Dumped by: %s\n", name);
  FCEU_printf(" Dumped with: %s\n", method);

  static constexpr const char *const months[] = {
      "January", "February", "March",     "April",   "May",      "June",
      "July",    "August",   "September", "October", "November", "December"};
  FCEU_printf(" Dumped on: %s %d, %d\n", months[(m - 1) % 12], d, y);
  return 1;
}

int Unif::CTRL(FceuFile *fp) {
  int t = FCEU_fgetc(fp);

  if (t == EOF) return 0;
  /* The information stored in this byte isn't very helpful, but it's
     better than nothing...maybe.
  */

  if (t & 1)
    fc->fceu->GameInfo->input[0] = fc->fceu->GameInfo->input[1] = SI_GAMEPAD;
  else
    fc->fceu->GameInfo->input[0] = fc->fceu->GameInfo->input[1] = SI_NONE;

  if (t & 2) fc->fceu->GameInfo->input[1] = SI_ZAPPER;
  // else if (t&0x10) fc->fceu->GameInfo->input[1]=SI_POWERPAD;

  return 1;
}

int Unif::TVCI(FceuFile *fp) {
  int t;
  if ((t = FCEU_fgetc(fp)) == EOF) return 0;
  if (t <= 2) {
    static constexpr const char *const stuffo[3] = {"NTSC", "PAL",
                                                    "NTSC and PAL"};
    if (t == 0) {
      fc->fceu->GameInfo->vidsys = GIV_NTSC;
      fc->fceu->FCEUI_SetVidSystem(0);
    } else if (t == 1) {
      fc->fceu->GameInfo->vidsys = GIV_PAL;
      fc->fceu->FCEUI_SetVidSystem(1);
    }
    FCEU_printf(" TV Standard Compatibility: %s\n", stuffo[t]);
  }
  return 1;
}

int Unif::EnableBattery(FceuFile *fp) {
  FCEU_printf(" Battery-backed.\n");
  if (FCEU_fgetc(fp) == EOF) return 0;
  UNIFCart.battery = 1;
  return 1;
}

int Unif::LoadPRG(FceuFile *fp) {
  int z = uchead.ID[3] - '0';

  if (z < 0 || z > 15) return 0;
  FCEU_printf(" PRG ROM %d size: %d", z, (int)uchead.info);
  if (malloced[z]) free(malloced[z]);
  int t = FixRomSize(uchead.info, 2048);
  if (!(malloced[z] = (uint8 *)FCEU_malloc(t))) return 0;
  mallocedsizes[z] = t;
  memset(malloced[z] + uchead.info, 0xFF, t - uchead.info);
  if (FCEU_fread(malloced[z], 1, uchead.info, fp) != uchead.info) {
    FCEU_printf("Read Error!\n");
    return 0;
  } else {
    FCEU_printf("\n");
  }

  fc->cart->SetupCartPRGMapping(z, malloced[z], t, 0);
  return 1;
}

int Unif::SetBoardName(FceuFile *fp) {
  if (!(boardname = (uint8 *)FCEU_malloc(uchead.info + 1))) return 0;
  FCEU_fread(boardname, 1, uchead.info, fp);
  boardname[uchead.info] = 0;
  FCEU_printf(" Board name: %s\n", boardname);
  sboardname = boardname;
  if (!memcmp(boardname, "NES-", 4) || !memcmp(boardname, "UNL-", 4) ||
      !memcmp(boardname, "HVC-", 4) || !memcmp(boardname, "BTL-", 4) ||
      !memcmp(boardname, "BMC-", 4)) {
    sboardname += 4;
  }
  return 1;
}

int Unif::LoadCHR(FceuFile *fp) {
  int z = uchead.ID[3] - '0';
  if (z < 0 || z > 15) return 0;
  FCEU_printf(" CHR ROM %d size: %d", z, (int)uchead.info);
  if (malloced[16 + z]) free(malloced[16 + z]);
  int t = FixRomSize(uchead.info, 8192);
  if (!(malloced[16 + z] = (uint8 *)FCEU_malloc(t))) return 0;
  mallocedsizes[16 + z] = t;
  memset(malloced[16 + z] + uchead.info, 0xFF, t - uchead.info);
  if (FCEU_fread(malloced[16 + z], 1, uchead.info, fp) != uchead.info) {
    FCEU_printf("Read Error!\n");
    return 0;
  } else {
    FCEU_printf("\n");
  }

  fc->cart->SetupCartCHRMapping(z, malloced[16 + z], t, 0);
  return 1;
}

#define BMCFLAG_FORCE4 1
#define BMCFLAG_16KCHRR 2
#define BMCFLAG_32KCHRR 4
#define BMCFLAG_EXPCHRR 8

static constexpr BMAPPING bmap[] = {
#if 0
    {"11160", BMC11160_Init, 0},
    {"12-IN-1", BMC12IN1_Init, 0},
    {"13in1JY110", BMC13in1JY110_Init, 0},
    {"190in1", BMC190in1_Init, 0},
#endif
    {"22211", UNL22211_Init, 0},
    {"3D-BLOCK", UNL3DBlock_Init, 0},
    {"411120-C", BMC411120C_Init, 0},
#if 0
    {"42in1ResetSwitch", Mapper226_Init, 0},
    {"43272", UNL43272_Init, 0},
    {"603-5052", UNL6035052_Init, 0},
    {"64in1NoRepeat", BMC64in1nr_Init, 0},
    {"70in1", BMC70in1_Init, 0},
    {"70in1B", BMC70in1B_Init, 0},
    {"810544-C-A1", BMC810544CA1_Init, 0},
    {"8157", UNL8157_Init, 0},
    {"8237", UNL8237_Init, 0},
    {"8237A", UNL8237A_Init, 0},
    {"830118C", BMC830118C_Init, 0},
    {"A65AS", BMCA65AS_Init, 0},
    {"AC08", AC08_Init, 0},
    {"ANROM", ANROM_Init, 0},
    {"AX5705", UNLAX5705_Init, 0},
    {"BB", UNLBB_Init, 0},
    {"BS-5", BMCBS5_Init, 0},
    {"CC-21", UNLCC21_Init, 0},
    {"CITYFIGHT", UNLCITYFIGHT_Init, 0},
    {"CNROM", CNROM_Init, 0},
    {"CPROM", CPROM_Init, BMCFLAG_16KCHRR},
    {"D1038", BMCD1038_Init, 0},
    {"DANCE", UNLOneBus_Init, 0},  // redundant
    {"DANCE2000", UNLD2000_Init, 0},
    {"DREAMTECH01", DreamTech01_Init, 0},
    {"EDU2000", UNLEDU2000_Init, 0},
    {"EKROM", EKROM_Init, 0},
    {"ELROM", ELROM_Init, 0},
    {"ETROM", ETROM_Init, 0},
    {"EWROM", EWROM_Init, 0},
    {"FK23C", BMCFK23C_Init, BMCFLAG_EXPCHRR},
    {"FK23CA", BMCFK23CA_Init, BMCFLAG_EXPCHRR},
    {"FS304", UNLFS304_Init, 0},
    {"G-146", BMCG146_Init, 0},
    {"GK-192", BMCGK192_Init, 0},
    {"GS-2004", BMCGS2004_Init, 0},
#endif
    {"GS-2013", BMCGS2013_Init, 0},
#if 0
    {"Ghostbusters63in1", BMCGhostbusters63in1_Init, 0},
#endif
    {"H2288", UNLH2288_Init, 0},
    {"HKROM", HKROM_Init, 0},
    {"KOF97", UNLKOF97_Init, 0},
    {"KONAMI-QTAI", Mapper190_Init, 0},
#if 0
    {"KS7012", UNLKS7012_Init, 0},
    {"KS7013B", UNLKS7013B_Init, 0},
    {"KS7017", UNLKS7017_Init, 0},
    {"KS7030", UNLKS7030_Init, 0},
    {"KS7031", UNLKS7031_Init, 0},
    {"KS7032", UNLKS7032_Init, 0},
    {"KS7037", UNLKS7037_Init, 0},
    {"KS7057", UNLKS7057_Init, 0},
    {"LE05", LE05_Init, 0},
    {"LH10", LH10_Init, 0},
    {"LH32", LH32_Init, 0},
    {"LH53", LH53_Init, 0},
    {"MARIO1-MALEE2", MALEE_Init, 0},
    {"MHROM", MHROM_Init, 0},
    {"N625092", UNLN625092_Init, 0},
    {"NROM", NROM_Init, 0},
    {"NROM-128", NROM_Init, 0},
    {"NROM-256", NROM_Init, 0},
    {"NTBROM", Mapper68_Init, 0},
    {"NTD-03", BMCNTD03_Init, 0},
    {"NovelDiamond9999999in1", Novel_Init, 0},
    {"OneBus", UNLOneBus_Init, 0},
    {"PEC-586", UNLPEC586Init, 0},
    {"RROM", NROM_Init, 0},
    {"RROM-128", NROM_Init, 0},
    {"SA-002", TCU02_Init, 0},
    {"SA-0036", SA0036_Init, 0},
    {"SA-0037", SA0037_Init, 0},
    {"SA-009", SA009_Init, 0},
    {"SA-016-1M", SA0161M_Init, 0},
    {"SA-72007", SA72007_Init, 0},
    {"SA-72008", SA72008_Init, 0},
    {"SA-9602B", SA9602B_Init, BMCFLAG_32KCHRR},
    {"SA-NROM", TCA01_Init, 0},
#endif
    // MMC1
    {"SAROM", SAROM_Init, 0},
    {"SBROM", SBROM_Init, 0},
    {"SCROM", SCROM_Init, 0},
    {"SEROM", SEROM_Init, 0},
    {"SGROM", SGROM_Init, 0},
    {"SKROM", SKROM_Init, 0},
    {"SNROM", SNROM_Init, 0},
    {"SOROM", SOROM_Init, 0},
    {"SL1ROM", SL1ROM_Init, 0},
    {"SLROM", SLROM_Init, 0},

#if 0
    {"SC-127", UNLSC127_Init, 0},
    {"SHERO", UNLSHeroes_Init, 0},
    {"SL12", UNLSL12_Init, 0},
    {"SL1632", UNLSL1632_Init, 0},
    {"SMB2J", UNLSMB2J_Init, 0},
    {"SSS-NROM-256", SSSNROM_Init, 0},
    {"SUNSOFT_UNROM", SUNSOFT_UNROM_Init, 0},
    {"Sachen-74LS374N", S74LS374N_Init, 0},
    {"Sachen-74LS374NA", S74LS374NA_Init, 0},  // seems to be custom mapper
    {"Sachen-8259A", S8259A_Init, 0},
    {"Sachen-8259B", S8259B_Init, 0},
    {"Sachen-8259C", S8259C_Init, 0},
    {"Sachen-8259D", S8259D_Init, 0},
    {"Super24in1SC03", Super24_Init, 0},
    {"SuperHIK8in1", Mapper45_Init, 0},
    {"Supervision16in1", Supervision16_Init, 0},
    {"T-227-1", BMCT2271_Init, 0},
    {"T-230", UNLT230_Init, 0},
    {"T-262", BMCT262_Init, 0},
#endif
    {"TBROM", TBROM_Init, 0},
#if 0
    {"TC-U01-1.5M", TCU01_Init, 0},
    {"TEK90", Mapper90_Init, 0},
    {"TEROM", TEROM_Init, 0},
    {"TF1201", UNLTF1201_Init, 0},
#endif
    {"TFROM", TFROM_Init, 0},
    {"TGROM", TGROM_Init, 0},
    {"TKROM", TKROM_Init, 0},
    {"TKSROM", TKSROM_Init, 0},
    {"TLROM", TLROM_Init, 0},
    {"TLSROM", TLSROM_Init, 0},
    {"TQROM", TQROM_Init, 0},
#if 0
    {"TR1ROM", TFROM_Init, BMCFLAG_FORCE4},
#endif
    {"TSROM", TSROM_Init, 0},
#if 0
    {"TVROM", TLROM_Init, BMCFLAG_FORCE4},
    {"Transformer", Transformer_Init, 0},
    {"UNROM", UNROM_Init, 0},
    {"UOROM", UNROM_Init, 0},
    {"VRC7", UNLVRC7_Init, 0},
    {"YOKO", UNLYOKO_Init, 0},
#endif
    {0, 0, 0}};

int Unif::LoadUNIFChunks(FceuFile *fp) {
  static constexpr BFMAPPING bfunc[] = {
      {"CTRL", &Unif::CTRL},
      {"TVCI", &Unif::TVCI},
      {"BATR", &Unif::EnableBattery},
      {"MIRR", &Unif::DoMirroring},
      {"PRG", &Unif::LoadPRG},
      {"CHR", &Unif::LoadCHR},
      {"NAME", &Unif::NAME},
      {"MAPR", &Unif::SetBoardName},
      {"DINF", &Unif::DINF},
      {0, nullptr}
  };

  for (;;) {
    int t = FCEU_fread(&uchead, 1, 4, fp);
    if (t < 4) {
      if (t > 0) {
        return 0;
      }
      return 1;
    }
    if (!(FCEU_read32le(&uchead.info, fp))) return 0;
    t = 0;
    // printf("Funky: %s\n",((uint8 *)&uchead));
    for (int x = 0; bfunc[x].name; x++) {
      if (!memcmp(&uchead, bfunc[x].name, strlen(bfunc[x].name))) {
        auto fn = bfunc[x].init;
        if (!(this->*fn)(fp)) return 0;
        t = 1;
        break;
      }
    }
    if (!t) {
      if (FCEU_fseek(fp, uchead.info, SEEK_CUR) < 0) {
        return 0;
      }
    }
  }
}

int Unif::InitializeBoard() {

  if (!sboardname) return 0;

  for (int x = 0; bmap[x].name; x++) {
    if (!strcmp((char *)sboardname, (char *)bmap[x].name)) {
      if (!malloced[16]) {
        if (bmap[x].flags & BMCFLAG_16KCHRR)
          CHRRAMSize = 16384;
        else if (bmap[x].flags & BMCFLAG_32KCHRR)
          CHRRAMSize = 32768;
        else if (bmap[x].flags & BMCFLAG_EXPCHRR)
          CHRRAMSize = 128 * 1024;
        else
          CHRRAMSize = 8192;
        if ((UNIFchrrama = (uint8 *)FCEU_malloc(CHRRAMSize))) {
          fc->cart->SetupCartCHRMapping(0, UNIFchrrama, CHRRAMSize, 1);
          fc->state->AddExState(UNIFchrrama, CHRRAMSize, 0, "CHRR");
        } else {
          return -1;
        }
      }
      if (bmap[x].flags & BMCFLAG_FORCE4) mirrortodo = 4;
      MooMirroring();
      fc->fceu->cartiface = bmap[x].init(fc, &UNIFCart);
      // bmap[x].init(&UNIFCart);
      return 1;
    }
  }
  FCEU_PrintError("Board type not supported.");
  return 0;
}

void Unif::UNIFGI(GI h) {
  switch (h) {
    case GI_RESETSAVE: fc->cart->FCEU_ClearGameSave(&UNIFCart); break;

    case GI_RESETM2:
      fc->fceu->cartiface->Reset();
      break;
    case GI_POWER:
      fc->fceu->cartiface->Power();
      if (UNIFchrrama) memset(UNIFchrrama, 0, 8192);
      break;
    case GI_CLOSE:
      fc->cart->FCEU_SaveGameSave(&UNIFCart);
      fc->fceu->cartiface->Close();
      FreeUNIF();
      break;
  }
}

int Unif::UNIFLoad(const char *name, FceuFile *fp) {
  FCEU_fseek(fp, 0, SEEK_SET);
  FCEU_fread(&unhead, 1, 4, fp);
  if (memcmp(&unhead, "UNIF", 4)) return 0;

  fc->cart->ResetCartMapping();

  fc->state->ResetExState(nullptr, nullptr);
  ResetUNIF();
  if (!FCEU_read32le(&unhead.info, fp)) goto aborto;
  if (FCEU_fseek(fp, 0x20, SEEK_SET) < 0) goto aborto;
  if (!LoadUNIFChunks(fp)) goto aborto;

  {
    struct md5_context md5;

    md5_starts(&md5);

    for (int x = 0; x < 32; x++) {
      if (malloced[x]) {
        md5_update(&md5, malloced[x], mallocedsizes[x]);
      }
    }
    md5_finish(&md5, UNIFCart.MD5);
    FCEU_printf(" ROM MD5:  0x");
    for (int x = 0; x < 16; x++) FCEU_printf("%02x", UNIFCart.MD5[x]);
    FCEU_printf("\n");
    memcpy(&fc->fceu->GameInfo->MD5, &UNIFCart.MD5, sizeof(UNIFCart.MD5));
  }

  if (!InitializeBoard()) goto aborto;

  fc->cart->FCEU_LoadGameSave(&UNIFCart);

  fc->fceu->GameInterface = [](FC *fc, GI gi) {
    return fc->unif->UNIFGI(gi);
  };
  return 1;

aborto:

  FreeUNIF();
  ResetUNIF();

  return 0;
}
