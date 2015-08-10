/* FCE Ultra - NES/Famicom Emulator
*
* Copyright notice for this file:
*  Copyright (C) 1998 BERO
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "types.h"
#include "x6502.h"
#include "fceu.h"
#include "cart.h"
#include "ppu.h"

#define INESPRIV
#include "ines.h"
#include "unif.h"
#include "state.h"
#include "file.h"
#include "utils/memory.h"
#include "utils/crc32.h"
#include "utils/md5.h"
#include "utils/xstring.h"
#include "vsuni.h"
#include "driver.h"
#include "boards/boards.h"

#include "tracing.h"

#define ARRAY_SIZE(a) (sizeof(a)/sizeof(a[0]))

INes::INes(FC *fc) : fc(fc) {}

INes::~INes() {
  // Lots more needs to be deleted here :(
}

/*  MapperReset() is called when the NES is reset(with the reset button).
Mapperxxx_init is called when the NES has been powered on.
*/

void INes::CleanupHeader(INes::Header *head) {
  if (!memcmp((char *)(head)+0x7,"DiskDude",8)) {
    memset((char *)(head)+0x7,0,0x9);
  }

  if (!memcmp((char *)(head)+0x7,"demiforce",9)) {
    memset((char *)(head)+0x7,0,0x9);
  }

  if (!memcmp((char *)(head)+0xA,"Ni03",4)) {
    if (!memcmp((char *)(head)+0x7,"Dis",3))
      memset((char *)(head)+0x7,0,0x9);
    else
      memset((char *)(head)+0xA,0,0x6);
  }
}

DECLFR_RET INes::TrainerRead_Direct(DECLFR_ARGS) {
  return trainerdata[A&0x1FF];
}

static DECLFR(TrainerRead) {
  return fc->ines->TrainerRead_Direct(DECLFR_FORWARD);
}

void INes::iNES_ExecPower() {
  if (CHRRAMSize != -1)
    FCEU_InitMemory(VROM, CHRRAMSize);

  fc->fceu->cartiface->Power();

  if (trainerdata) {
    for (int x=0;x<512;x++) {
      fc->X->DMW(0x7000+x,trainerdata[x]);
      if (fc->X->DMR(0x7000+x)!=trainerdata[x]) {
	fc->fceu->SetReadHandler(0x7000,0x71FF,TrainerRead);
	break;
      }
    }
  }
}

void INes::iNESGI(GI h) {
  switch (h) {
  case GI_RESETSAVE:
    fc->cart->FCEU_ClearGameSave(&iNESCart);
    break;

  case GI_RESETM2:
    if (MapperReset)
      MapperReset();
    fc->fceu->cartiface->Reset();
    break;

  case GI_POWER:
    iNES_ExecPower();

    break;

  case GI_CLOSE:
    fc->cart->FCEU_SaveGameSave(&iNESCart);

    fc->fceu->cartiface->Close();
    free(ROM);
    ROM = nullptr;
    free(VROM);
    VROM = nullptr;

    if (MapClose) MapClose();
    free(trainerdata);
    trainerdata = nullptr;
    break;
  }
}

namespace {
struct CRCMATCH {
  const uint32 crc;
  const char *const name;
};

struct INPSEL {
  const uint32 crc32;
  const ESI input1;
  const ESI input2;
  const ESIFC inputfc;
};
}

static void SetInput(uint32 gamecrc, FCEUGI *gi) {
  static constexpr struct INPSEL const input_sel[] = {
    {0x29de87af, SI_GAMEPAD, SI_GAMEPAD, SIFC_FTRAINERB }, // Aerobics Studio
    {0xd89e5a67, SI_UNSET, SI_UNSET, SIFC_ARKANOID }, // Arkanoid (J)
    {0x0f141525, SI_UNSET, SI_UNSET, SIFC_ARKANOID }, // Arkanoid 2(J)
    {0x32fb0583, SI_UNSET, SI_ARKANOID, SIFC_NONE }, // Arkanoid(NES)
    {0x60ad090a, SI_GAMEPAD, SI_GAMEPAD, SIFC_FTRAINERA }, // Athletic World
    {0x48ca0ee1, SI_GAMEPAD, SI_GAMEPAD, SIFC_BWORLD }, // Barcode World
    {0x4318a2f8, SI_UNSET, SI_ZAPPER, SIFC_NONE }, // Barker Bill's Trick Shooting
    {0x6cca1c1f, SI_GAMEPAD, SI_GAMEPAD, SIFC_FTRAINERB }, // Dai Undoukai
    {0x24598791, SI_UNSET, SI_ZAPPER, SIFC_NONE }, // Duck Hunt
    {0xd5d6eac4, SI_UNSET, SI_UNSET, SIFC_SUBORKB }, // Edu (As)
    {0xe9a7fe9e, SI_UNSET, SI_MOUSE, SIFC_NONE }, // Educational Computer 2000
    {0x8f7b1669, SI_UNSET, SI_UNSET, SIFC_SUBORKB }, // FP BASIC 3.3 by maxzhou88
    {0xf7606810, SI_UNSET, SI_UNSET, SIFC_FKB }, // Family BASIC 2.0A
    {0x895037bc, SI_UNSET, SI_UNSET, SIFC_FKB }, // Family BASIC 2.1a
    {0xb2530afc, SI_UNSET, SI_UNSET, SIFC_FKB }, // Family BASIC 3.0
    {0xea90f3e2, SI_GAMEPAD, SI_GAMEPAD, SIFC_FTRAINERB }, // Family Trainer: Running Stadium
    {0xbba58be5, SI_GAMEPAD, SI_GAMEPAD, SIFC_FTRAINERB }, // Family Trainer: Manhattan Police
    {0x3e58a87e, SI_UNSET, SI_ZAPPER, SIFC_NONE }, // Freedom Force
    {0xd9f45be9, SI_GAMEPAD, SI_GAMEPAD, SIFC_QUIZKING }, // Gimme a Break ...
    {0x1545bd13, SI_GAMEPAD, SI_GAMEPAD, SIFC_QUIZKING }, // Gimme a Break ... 2
    {0x4e959173, SI_UNSET, SI_ZAPPER, SIFC_NONE }, // Gotcha! - The Sport!
    {0xbeb8ab01, SI_UNSET, SI_ZAPPER, SIFC_NONE }, // Gumshoe
    {0xff24d794, SI_UNSET, SI_ZAPPER, SIFC_NONE }, // Hogan's Alley
    {0x21f85681, SI_GAMEPAD, SI_GAMEPAD, SIFC_HYPERSHOT }, // Hyper Olympic (Gentei Ban)
    {0x980be936, SI_GAMEPAD, SI_GAMEPAD, SIFC_HYPERSHOT }, // Hyper Olympic
    {0x915a53a7, SI_GAMEPAD, SI_GAMEPAD, SIFC_HYPERSHOT }, // Hyper Sports
    {0x9fae4d46, SI_GAMEPAD, SI_GAMEPAD, SIFC_MAHJONG }, // Ide Yousuke Meijin no Jissen Mahjong
    // Ide Yousuke Meijin no Jissen Mahjong 2
    {0x7b44fb2a, SI_GAMEPAD, SI_GAMEPAD, SIFC_MAHJONG },
    {0x2f128512, SI_GAMEPAD, SI_GAMEPAD, SIFC_FTRAINERA }, // Jogging Race
    {0xbb33196f, SI_UNSET, SI_UNSET, SIFC_FKB }, // Keyboard Transformer
    {0x8587ee00, SI_UNSET, SI_UNSET, SIFC_FKB }, // Keyboard Transformer
    {0x543ab532, SI_UNSET, SI_UNSET, SIFC_SUBORKB }, // LIKO Color Lines
    {0x368c19a8, SI_UNSET, SI_UNSET, SIFC_SUBORKB }, // LIKO Study Cartridge
    {0x5ee6008e, SI_UNSET, SI_ZAPPER, SIFC_NONE }, // Mechanized Attack
    {0x370ceb65, SI_GAMEPAD, SI_GAMEPAD, SIFC_FTRAINERB }, // Meiro Dai Sakusen
    {0x3a1694f9, SI_GAMEPAD, SI_GAMEPAD, SIFC_4PLAYER }, // Nekketsu Kakutou Densetsu
    {0x9d048ea4, SI_GAMEPAD, SI_GAMEPAD, SIFC_OEKAKIDS }, // Oeka Kids
    {0x2a6559a1, SI_UNSET, SI_ZAPPER, SIFC_NONE }, // Operation Wolf (J)
    {0xedc3662b, SI_UNSET, SI_ZAPPER, SIFC_NONE }, // Operation Wolf
    {0x912989dc, SI_UNSET, SI_UNSET, SIFC_FKB }, // Playbox BASIC
    {0x9044550e, SI_GAMEPAD, SI_GAMEPAD, SIFC_FTRAINERA }, // Rairai Kyonshizu
    {0xea90f3e2, SI_GAMEPAD, SI_GAMEPAD, SIFC_FTRAINERB }, // Running Stadium
    {0x851eb9be, SI_GAMEPAD, SI_ZAPPER, SIFC_NONE }, // Shooting Range
    {0x6435c095, SI_GAMEPAD, SI_POWERPADB, SIFC_UNSET }, // Short Order/Eggsplode
    {0xc043a8df, SI_UNSET, SI_MOUSE, SIFC_NONE }, // Shu Qi Yu - Shu Xue Xiao Zhuan Yuan (Ch)
    {0x2cf5db05, SI_UNSET, SI_MOUSE, SIFC_NONE }, // Shu Qi Yu - Zhi Li Xiao Zhuan Yuan (Ch)
    {0xad9c63e2, SI_GAMEPAD, SI_UNSET, SIFC_SHADOW }, // Space Shadow
    {0x61d86167, SI_GAMEPAD, SI_POWERPADB, SIFC_UNSET }, // Street Cop
    {0xabb2f974, SI_UNSET, SI_UNSET, SIFC_SUBORKB }, // Study and Game 32-in-1
    {0x41ef9ac4, SI_UNSET, SI_UNSET, SIFC_SUBORKB }, // Subor
    {0x8b265862, SI_UNSET, SI_UNSET, SIFC_SUBORKB }, // Subor
    {0x82f1fb96, SI_UNSET, SI_UNSET, SIFC_SUBORKB }, // Subor 1.0 Russian
    // Super Mogura Tataki!! - Pokkun Moguraa
    {0x9f8f200a, SI_GAMEPAD, SI_GAMEPAD, SIFC_FTRAINERA }, 
    {0xd74b2719, SI_GAMEPAD, SI_POWERPADB, SIFC_UNSET }, // Super Team Games
    {0x74bea652, SI_GAMEPAD, SI_ZAPPER, SIFC_NONE }, // Supergun 3-in-1
    {0x5e073a1b, SI_UNSET, SI_UNSET, SIFC_SUBORKB }, // Supor English (Chinese)
    {0x589b6b0d, SI_UNSET, SI_UNSET, SIFC_SUBORKB }, // SuporV20
    {0x41401c6d, SI_UNSET, SI_UNSET, SIFC_SUBORKB }, // SuporV40
    {0x23d17f5e, SI_GAMEPAD, SI_ZAPPER, SIFC_NONE }, // The Lone Ranger
    {0xc3c0811d, SI_GAMEPAD, SI_GAMEPAD, SIFC_OEKAKIDS }, // The two "Oeka Kids" games
    {0xde8fd935, SI_UNSET, SI_ZAPPER, SIFC_NONE }, // To the Earth
    {0x47232739, SI_GAMEPAD, SI_GAMEPAD, SIFC_TOPRIDER }, // Top Rider
    {0x8a12a7d9, SI_GAMEPAD, SI_GAMEPAD, SIFC_FTRAINERB }, // Totsugeki Fuuun Takeshi Jou
    {0xb8b9aca3, SI_UNSET, SI_ZAPPER, SIFC_NONE }, // Wild Gunman
    {0x5112dc21, SI_UNSET, SI_ZAPPER, SIFC_NONE }, // Wild Gunman
    {0xaf4010ea, SI_GAMEPAD, SI_POWERPADB, SIFC_UNSET }, // World Class Track Meet
    {0x00000000, SI_UNSET, SI_UNSET, SIFC_UNSET }
  };

  for (int x = 0;
       input_sel[x].input1 >= 0 || input_sel[x].input2 >= 0 || input_sel[x].inputfc >= 0;
       x++) {
    if (input_sel[x].crc32 == gamecrc) {
      gi->input[0] = input_sel[x].input1;
      gi->input[1] = input_sel[x].input2;
      gi->inputfc = input_sel[x].inputfc;
      break;
    }
  }
}

#define INESB_INCOMPLETE  1
#define INESB_CORRUPT     2
#define INESB_HACKED      4

namespace {
struct BADINF {
  const uint64 md5partial;
  const char *const name;
  const uint32 type;
};
}

static constexpr BADINF const BadROMImages[] = {
  { 0xecf78d8a13a030a6LL, "Ai Sensei no Oshiete", INESB_HACKED },
  { 0x4712856d3e12f21fLL, "Akumajou Densetsu", INESB_HACKED },
  { 0x10f90ba5bd55c22eLL, "Alien Syndrome", INESB_HACKED },
  { 0x0d69ab3ad28ad1c2LL, "Banana", INESB_INCOMPLETE },
  { 0x85d2c348a161cdbfLL, "Bio Senshi Dan", INESB_HACKED },
  { 0x18fdb7c16aa8cb5cLL, "Bucky O'Hare", INESB_CORRUPT },
  { 0xe27c48302108d11bLL, "Chibi Maruko Chan", INESB_HACKED },
  { 0x9d1f505c6ba507bfLL, "Contra", INESB_HACKED },
  { 0x60936436d3ea0ab6LL, "Crisis Force", INESB_HACKED },
  { 0xcf31097ddbb03c5dLL, "Crystalis (Prototype)", INESB_CORRUPT },
  { 0x92080a8ce94200eaLL, "Digital Devil Story II", INESB_HACKED },
  { 0x6c2a2f95c2fe4b6eLL, "Dragon Ball", INESB_HACKED },
  { 0x767aaff62963c58fLL, "Dragon Ball", INESB_HACKED },
  { 0x97f133d8bc1c28dbLL, "Dragon Ball", INESB_HACKED },
  { 0x500b267abb323005LL, "Dragon Warrior 4", INESB_CORRUPT },
  { 0x02bdcf375704784bLL, "Erika to Satoru no Yume Bouken", INESB_HACKED },
  { 0xd4fea9d2633b9186LL, "Famista 91", INESB_HACKED },
  { 0xfdf8c812839b61f0LL, "Famista 92", INESB_HACKED },
  { 0xb5bb1d0fb47d0850LL, "Famista 93", INESB_HACKED },
  { 0x30471e773f7cdc89LL, "Famista 94", INESB_HACKED },
  { 0x76c5c44ffb4a0bd7LL, "Fantasy Zone", INESB_HACKED },
  { 0xb470bfb90e2b1049LL, "Fire Emblem Gaiden", INESB_HACKED },
  { 0x27da2b0c500dc346LL, "Fire Emblem", INESB_HACKED },
  { 0x23214fe456fba2ceLL, "Ganbare Goemon 2", INESB_HACKED },
  { 0xbf8b22524e8329d9LL, "Ganbare Goemon Gaiden", INESB_HACKED },
  { 0xa97041c3da0134e3LL, "Gegege no Kitarou 2", INESB_INCOMPLETE },
  { 0x805db49a86db5449LL, "Goonies", INESB_HACKED },
  { 0xc5abdaa65ac49b6bLL, "Gradius 2", INESB_HACKED },
  { 0x04afae4ad480c11cLL, "Gradius 2", INESB_HACKED },
  { 0x9b4bad37b5498992LL, "Gradius 2", INESB_HACKED },
  { 0xb068d4ac10ef848eLL, "Highway Star", INESB_HACKED },
  { 0xbf5175271e5019c3LL, "Kaiketsu Yanchamaru 3", INESB_HACKED },
  { 0xfb4b508a236bbba3LL, "Salamander", INESB_HACKED },
  { 0x1895afc6eef26c7dLL, "Super Mario Bros.", INESB_HACKED },
  { 0x3716c4bebf885344LL, "Super Mario Bros.", INESB_HACKED },
  { 0xfffda4407d80885aLL, "Sweet Home", INESB_CORRUPT },
  { 0x103fc85d978b861bLL, "Sweet Home", INESB_CORRUPT },
  { 0x7979dc51da86f19fLL, "110-in-1", INESB_CORRUPT },
  { 0x001c0bb9c358252aLL, "110-in-1", INESB_CORRUPT },
  { 0, 0, 0 }
};

static void CheckBad(uint64 md5partial) {
  for (int x = 0; BadROMImages[x].name; x++) {
    if (BadROMImages[x].md5partial == md5partial) {
      FCEU_PrintError("The copy game you have loaded, \"%s\", "
		      "is bad, and will not work properly in FCEUX.",
		      BadROMImages[x].name);
      return;
    }
  }
}

namespace {
struct CHINF {
  uint32 crc32;
  int32 mapper;
  int32 mirror;
  // This used to be here but was unintialized and appears to be unused.
  // I can only imagine it makes a difference if someone is casting these
  // to some other type, but then uninitialized strings ..? -tom7
  // const char *const params;
};
}

struct INes::OldCartiface : public CartInterface {
  using CartInterface::CartInterface;
  virtual void Power() {
    return fc->ines->iNESPower();
  }
};

// Returns true on success.
bool INes::MapperInit() {
  if (!NewiNES_Init(mapper_number)) {
    printf("Ugh! I disabled old cartiface interface -tom7.\n");
    return false;
    
    fc->fceu->cartiface = new OldCartiface(fc);
    if (head.ROM_type & 2) {
      TRACEF("Set savegame %d", head.ROM_type);
      iNESCart.SaveGame[0] = WRAM;
      iNESCart.SaveGameLen[0] = 8192;
    }
  }

  return true;
}

static constexpr INesTMasterRomInfo const sMasterRomInfo[] = {
  { 0x62b51b108a01d2beLL, "bonus=0" }, //4-in-1 (FK23C8021)[p1][!].nes
  { 0x8bb48490d8d22711LL, "bonus=0" }, //4-in-1 (FK23C8033)[p1][!].nes
  { 0xc75888d7b48cd378LL, "bonus=0" }, //4-in-1 (FK23C8043)[p1][!].nes
  { 0xf81a376fa54fdd69LL, "bonus=0" }, //4-in-1 (FK23Cxxxx, S-0210A PCB)[p1][!].nes
  { 0xa37eb9163e001a46LL, "bonus=0" }, //4-in-1 (FK23C8026) [p1][!].nes
  { 0xde5ce25860233f7eLL, "bonus=0" }, //4-in-1 (FK23C8045) [p1][!].nes
  { 0x5b3aa4cdc484a088LL, "bonus=0" }, //4-in-1 (FK23C8056) [p1][!].nes
  { 0x9342bf9bae1c798aLL, "bonus=0" }, //4-in-1 (FK23C8079) [p1][!].nes
  //Cybernoid - The Fighting Machine (U)[!].nes -- needs bus conflict emulation
  { 0x164eea6097a1e313LL, "busc=1" }, 
};

void INes::CheckHInfo() {
  /* ROM images that have the battery-backed bit set in the header that really
     don't have battery-backed RAM is not that big of a problem, so I'll
     treat this differently by only listing games that should have 
     battery-backed RAM.

     Lower 64 bits of the MD5 hash.
  */

  static constexpr uint64 const savie[] = {
    0x498c10dc463cfe95LL,  /* Battle Fleet */
    0x6917ffcaca2d8466LL,  /* Famista '90 */

    0xd63dcc68c2b20adcLL,    /* Final Fantasy J */
    0x012df596e2b31174LL,    /* Final Fantasy 1+2 */
    0xf6b359a720549ecdLL,    /* Final Fantasy 2 */
    0x5a30da1d9b4af35dLL,    /* Final Fantasy 3 */

    0x2ee3417ba8b69706LL,  /* Hydlide 3*/

    0xebbce5a54cf3ecc0LL,  /* Justbreed */

    0x6a858da551ba239eLL,  /* Kaijuu Monogatari */
    0xa40666740b7d22feLL,  /* Mindseeker */

    0x77b811b2760104b9LL,    /* Mouryou Senki Madara */

    0x11b69122efe86e8cLL,  /* RPG Jinsei Game */

    0xa70b495314f4d075LL,  /* Ys 3 */


    0xc04361e499748382LL,  /* AD&D Heroes of the Lance */
    0xb72ee2337ced5792LL,  /* AD&D Hillsfar */
    0x2b7103b7a27bd72fLL,  /* AD&D Pool of Radiance */

    0x854d7947a3177f57LL,    /* Crystalis */

    0xb0bcc02c843c1b79LL,  /* DW */
    0x4a1f5336b86851b6LL,  /* DW */

    0x2dcf3a98c7937c22LL,  /* DW 2 */
    0x733026b6b72f2470LL,  /* Dw 3 */
    0x98e55e09dfcc7533LL,  /* DW 4*/
    0x8da46db592a1fcf4LL,  /* Faria */
    0x91a6846d3202e3d6LL,  /* Final Fantasy */
    0xedba17a2c4608d20LL,  /* ""    */

    0x94b9484862a26cbaLL,    /* Legend of Zelda */
    0x04a31647de80fdabLL,    /*      ""      */

    0x9aa1dc16c05e7de5LL,    /* Startropics */
    0x1b084107d0878bd0LL,    /* Startropics 2*/

    0x836c0ff4f3e06e45LL,    /* Zelda 2 */

    0x82000965f04a71bbLL,    /* Mirai Shinwa Jarvas */

    0      /* Abandon all hope if the game has 0 in the lower 
	      64-bits of its MD5 hash */
  };

  static constexpr struct CHINF const ines_correct[] = {
#include "ines-correct.h"
  };
  uint64 partialmd5 = 0ULL;

  for (int x=0;x<8;x++) {
    partialmd5 |= (uint64)iNESCart.MD5[15 - x] << (x * 8);
    //printf("%16llx\n",partialmd5);
  }
  CheckBad(partialmd5);

  MasterRomInfo = nullptr;
  for (int i = 0; i < ARRAY_SIZE(sMasterRomInfo); i++) {
    const INesTMasterRomInfo &info = sMasterRomInfo[i];
    if (info.md5lower != partialmd5)
      continue;

    MasterRomInfo = &info;
    if (!info.params) break;

    std::vector<std::string> toks = tokenize_str(info.params,",");
    for (int j=0;j<(int)toks.size();j++) {
      std::vector<std::string> parts = tokenize_str(toks[j],"=");
      MasterRomInfoParams[parts[0]] = parts[1];
    }
    break;
  }

  int tofix = 0;
  int x = 0;

  do {
    if (ines_correct[x].crc32==iNESGameCRC32) {
      if (ines_correct[x].mapper>=0) {
	if (ines_correct[x].mapper&0x800 && VROM_size) {
	  VROM_size=0;
	  free(VROM);
	  VROM = nullptr;
	  tofix|=8;
	}
	if (mapper_number!=(ines_correct[x].mapper&0xFF)) {
	  tofix|=1;
	  mapper_number=ines_correct[x].mapper&0xFF;
	}
      }
      if (ines_correct[x].mirror>=0) {
	if (ines_correct[x].mirror==8) {
	  /* Anything but hard-wired(four screen). */
	  if (iNESMirroring==2) {
	    tofix|=2;
	    iNESMirroring=0;
	  }
	} else if (iNESMirroring!=ines_correct[x].mirror) {
	  if (iNESMirroring!=(ines_correct[x].mirror&~4))
	    if ((ines_correct[x].mirror&~4)<=2) {
	      /* Don't complain if one-screen mirroring
		 needs to be set (the iNES header can't
		 hold this information).
	      */
	      tofix|=2;
	    }
	  iNESMirroring=ines_correct[x].mirror;
	}
      }
      break;
    }
    x++;
  } while (ines_correct[x].mirror>=0 || ines_correct[x].mapper>=0);

  for (int x = 0; savie[x] != 0; x++) {
    if (savie[x] == partialmd5) {
      if (!(head.ROM_type&2)) {
	tofix|=4;
	head.ROM_type|=2;
      }
    }
  }

  /* Games that use these iNES mappers tend to have the four-screen bit set
     when it should not be.
  */
  if ((mapper_number==118 || 
       mapper_number==24 || 
       mapper_number==26) && (iNESMirroring==2)) {
    iNESMirroring=0;
    tofix|=2;
  }

  /* Four-screen mirroring implicitly set. */
  if (mapper_number == 99)
    iNESMirroring = 2;

  if (tofix) {
    char gigastr[768];
    strcpy(gigastr,"The iNES header contains incorrect information.  "
	   "For now, the information will be corrected in RAM.  ");
    if (tofix & 1)
      sprintf(gigastr+strlen(gigastr),
	      "The mapper number should be set to %d.  ",mapper_number);
    if (tofix & 2) {
      static constexpr const char *const mstr[3] = 
	{"Horizontal", "Vertical", "Four-screen"};
      sprintf(gigastr+strlen(gigastr),
	      "Mirroring should be set to \"%s\".  ",mstr[iNESMirroring&3]);
    }
    if (tofix&4)
      strcat(gigastr, "The battery-backed bit should be set.  ");
    if (tofix&8)
      strcat(gigastr, "This game should not have any CHR ROM.  ");
    strcat(gigastr,"\n");
    FCEU_printf("%s", gigastr);
  }
}

namespace {
struct BoardMapping {
  const char *const name;
  const int number;
  CartInterface *(* const init)(FC *, CartInfo *);
};
}

static constexpr BoardMapping const board_map[] = {
  {"NROM", 0, NROM_Init},
  {"MMC1", 1, Mapper1_Init},
  {"UNROM", 2, UNROM_Init},
  {"CNROM", 3, CNROM_Init},
  {"MMC3", 4, Mapper4_Init},
#if 0
  {"MMC5", 5, Mapper5_Init},
 // {"", 6, Mapper6_Init},
#endif
  {"ANROM", 7, ANROM_Init},
#if 0
  {"", 8, Mapper8_Init}, // Nogaems, it's worthless
  // {"", 9, Mapper9_Init},
  // {"", 10, Mapper10_Init},
  {"Color Dreams", 11, Mapper11_Init},
#endif
  {"", 12, Mapper12_Init},
  {"CPROM", 13, CPROM_Init},
#if 0
  // {"", 14, Mapper14_Init},
  {"100-in-1", 15, Mapper15_Init},
  {"Bandai", 16, Mapper16_Init},
  {"", 17, Mapper17_Init},
  {"", 18, Mapper18_Init},
  {"Namcot 106", 19, Mapper19_Init},
  // {"", 20, Mapper20_Init},
  {"Konami VRC2/VRC4", 21, Mapper21_Init},
  {"Konami VRC2/VRC4", 22, Mapper22_Init},
  {"Konami VRC2/VRC4", 23, Mapper23_Init},
  // {"", 24, Mapper24_Init},
  {"Konami VRC2/VRC4", 25, Mapper25_Init},
  // {"", 26, Mapper26_Init},
  // {"", 27, Mapper27_Init}, // Deprecated, dupe for VRC2/VRC4 mapper
  {"INL-ROM", 28, Mapper28_Init},
  // {"", 29, Mapper29_Init},
  // {"", 30, Mapper30_Init},
  // {"", 31, Mapper31_Init},
  {"IREM G-101", 32, Mapper32_Init},
  {"TC0190FMC/TC0350FMR", 33, Mapper33_Init},
  {"", 34, Mapper34_Init},
  {"Wario Land 2", 35, UNLSC127_Init},
  {"TXC Policeman", 36, Mapper36_Init},
#endif
  {"", 37, Mapper37_Init},
#if 0
  {"Bit Corp.", 38, Mapper38_Init}, // Crime Busters
  // {"", 39, Mapper39_Init},
  // {"", 40, Mapper40_Init},
  // {"", 41, Mapper41_Init},
  // {"", 42, Mapper42_Init},
  {"", 43, Mapper43_Init},
#endif
  {"", 44, Mapper44_Init},
#if 0
  {"", 45, Mapper45_Init},
  // {"", 46, Mapper46_Init},
  {"", 47, Mapper47_Init},
  {"TAITO TCxxx", 48, Mapper48_Init},
  {"", 49, Mapper49_Init},
  // {"", 50, Mapper50_Init},
  // {"", 51, Mapper51_Init},
  {"", 52, Mapper52_Init},
  // {"", 53, Mapper53_Init}, // iNES version of complex UNIF board, can't emulate properly as iNES
  // {"", 54, Mapper54_Init},
  // {"", 55, Mapper55_Init},
  // {"", 56, Mapper56_Init},
  {"", 57, Mapper57_Init},
  {"", 58, BMCGK192_Init},
  {"", 59, Mapper59_Init}, // Check this out
  {"", 60, BMCD1038_Init},
  // {"", 61, Mapper61_Init},
  // {"", 62, Mapper62_Init},
  // {"", 63, Mapper63_Init},
  // {"", 64, Mapper64_Init},
  // {"", 65, Mapper65_Init},
#endif
  {"MHOM", 66, MHROM_Init},
#if 0
  // {"", 67, Mapper67_Init},
  {"Sunsoft Mapper #4", 68, Mapper68_Init},
  // {"", 69, Mapper69_Init},
  {"", 70, Mapper70_Init},
  // {"", 71, Mapper71_Init},
  // {"", 72, Mapper72_Init},
  // {"", 73, Mapper73_Init},
  {"", 74, Mapper74_Init},
  // {"", 75, Mapper75_Init},
  // {"", 76, Mapper76_Init},
  // {"", 77, Mapper77_Init},
  {"Irem 74HC161/32", 78, Mapper78_Init},
  // {"", 79, Mapper79_Init},
  // {"", 80, Mapper80_Init},
  // {"", 81, Mapper81_Init},
  {"", 82, Mapper82_Init},
  {"", 83, Mapper83_Init},
  // {"", 84, Mapper84_Init},
  // {"", 85, Mapper85_Init},
  {"", 86, Mapper86_Init},
  {"", 87, Mapper87_Init},
  {"", 88, Mapper88_Init},
  {"", 89, Mapper89_Init},
  {"", 90, Mapper90_Init},
  {"", 91, Mapper91_Init},
  {"", 92, Mapper92_Init},
#endif
  {"Sunsoft UNROM", 93, SUNSOFT_UNROM_Init},
#if 0
  {"", 94, Mapper94_Init},
  {"", 95, Mapper95_Init},
  {"", 96, Mapper96_Init},
  {"", 97, Mapper97_Init},
  // {"", 98, Mapper98_Init},
  {"", 99, Mapper99_Init},
  // {"", 100, Mapper100_Init},
  {"", 101, Mapper101_Init},
  // {"", 102, Mapper102_Init},
  {"", 103, Mapper103_Init},
  // {"", 104, Mapper104_Init},
  {"", 105, Mapper105_Init},
  {"", 106, Mapper106_Init},
  {"", 107, Mapper107_Init},
  {"", 108, Mapper108_Init},
  // {"", 109, Mapper109_Init},
  // {"", 110, Mapper110_Init},
  // {"", 111, Mapper111_Init},
  {"", 112, Mapper112_Init},
  {"", 113, Mapper113_Init},
  {"", 114, Mapper114_Init},
  {"", 115, Mapper115_Init},
  {"", 116, UNLSL12_Init},
  {"", 117, Mapper117_Init},
  {"TSKROM", 118, TKSROM_Init},
  {"", 119, Mapper119_Init},
  {"", 120, Mapper120_Init},
  {"", 121, Mapper121_Init},
  // {"", 122, Mapper122_Init},
  {"UNLH2288", 123, UNLH2288_Init},
  // {"", 124, Mapper124_Init},
  {"", 125, LH32_Init},
  // {"", 126, Mapper126_Init},
  // {"", 127, Mapper127_Init},
  // {"", 128, Mapper128_Init},
  // {"", 129, Mapper129_Init},
  // {"", 130, Mapper130_Init},
  // {"", 131, Mapper131_Init},
  {"UNL22211", 132, UNL22211_Init},
  {"SA72008", 133, SA72008_Init},
  {"", 134, Mapper134_Init},
  // {"", 135, Mapper135_Init},
  {"TCU02", 136, TCU02_Init},
  {"S8259D", 137, S8259D_Init},
  {"S8259B", 138, S8259B_Init},
  {"S8259C", 139, S8259C_Init},
  {"", 140, Mapper140_Init},
  {"S8259A", 141, S8259A_Init},
  {"UNLKS7032", 142, UNLKS7032_Init},
  {"TCA01", 143, TCA01_Init},
  {"", 144, Mapper144_Init},
  {"SA72007", 145, SA72007_Init},
  {"SA0161M", 146, SA0161M_Init},
  {"TCU01", 147, TCU01_Init},
  {"SA0037", 148, SA0037_Init},
  {"SA0036", 149, SA0036_Init},
  {"S74LS374N", 150, S74LS374N_Init},
  {"", 151, Mapper151_Init},
  {"", 152, Mapper152_Init},
  {"", 153, Mapper153_Init},
  {"", 154, Mapper154_Init},
  {"", 155, Mapper155_Init},
  {"", 156, Mapper156_Init},
  {"", 157, Mapper157_Init},
  // {"", 158, Mapper158_Init},
  // {"", 159, Mapper159_Init},
  {"SA009", 160, SA009_Init},
  // {"", 161, Mapper161_Init},
  {"", 162, UNLFS304_Init},
  {"", 163, Mapper163_Init},
  {"", 164, Mapper164_Init},
  {"", 165, Mapper165_Init},
  // {"", 166, Mapper166_Init},
  // {"", 167, Mapper167_Init},
  {"", 168, Mapper168_Init},
  // {"", 169, Mapper169_Init},
  {"", 170, Mapper170_Init},
  {"", 171, Mapper171_Init},
  {"", 172, Mapper172_Init},
  {"", 173, Mapper173_Init},
  // {"", 174, Mapper174_Init},
  {"", 175, Mapper175_Init},
  {"BMCFK23C", 176, BMCFK23C_Init}, //zero 26-may-2012 - well, i have some WXN junk games that use 176 for instance ????. i dont know what game uses this BMCFK23C as mapper 176. we'll have to make a note when we find it.
  {"", 177, Mapper177_Init},
  {"", 178, Mapper178_Init},
  // {"", 179, Mapper179_Init},
  {"", 180, Mapper180_Init},
  {"", 181, Mapper181_Init},
  // {"", 182, Mapper182_Init}, // Deprecated, dupe
  {"", 183, Mapper183_Init},
  {"", 184, Mapper184_Init},
  {"", 185, Mapper185_Init},
  {"", 186, Mapper186_Init},
  {"", 187, Mapper187_Init},
  {"", 188, Mapper188_Init},
  {"", 189, Mapper189_Init},
  // {"", 190, Mapper190_Init},
  {"", 191, Mapper191_Init},
  {"", 192, Mapper192_Init},
  {"", 193, Mapper193_Init},
  {"", 194, Mapper194_Init},
  {"", 195, Mapper195_Init},
  {"", 196, Mapper196_Init},
  {"", 197, Mapper197_Init},
  {"", 198, Mapper198_Init},
  {"", 199, Mapper199_Init},
  {"", 200, Mapper200_Init},
  {"", 201, Mapper201_Init},
  {"", 202, Mapper202_Init},
  {"", 203, Mapper203_Init},
  {"", 204, Mapper204_Init},
  {"", 205, Mapper205_Init},
  {"DEIROM", 206, DEIROM_Init},
  // {"", 207, Mapper207_Init},
  {"", 208, Mapper208_Init},
  {"", 209, Mapper209_Init},
  {"", 210, Mapper210_Init},
  {"", 211, Mapper211_Init},
  {"", 212, Mapper212_Init},
  {"", 213, Mapper213_Init},
  {"", 214, Mapper214_Init},
  {"", 215, UNL8237_Init},
  {"", 216, Mapper216_Init},
  {"", 217, Mapper217_Init}, // Redefined to a new Discrete BMC mapper
  // {"", 218, Mapper218_Init},
  {"UNLA9746", 219, UNLA9746_Init},
  {"Debug Mapper", 220, UNLKS7057_Init},
  {"UNLN625092", 221, UNLN625092_Init},
  {"", 222, Mapper222_Init},
  // {"", 223, Mapper223_Init},
  // {"", 224, Mapper224_Init},
  {"", 225, Mapper225_Init},
  {"BMC 22+20-in-1", 226, Mapper226_Init},
  {"", 227, Mapper227_Init},
  {"", 228, Mapper228_Init},
  {"", 229, Mapper229_Init},
  {"BMC 22-in-1+Contra", 230, Mapper230_Init},
  {"", 231, Mapper231_Init},
  {"BMC QUATTRO", 232, Mapper232_Init},
  {"BMC 22+20-in-1 RST", 233, Mapper233_Init},
  {"BMC MAXI", 234, Mapper234_Init},
  {"", 235, Mapper235_Init},
  // {"", 236, Mapper236_Init},
  // {"", 237, Mapper237_Init},
  {"UNL6035052", 238, UNL6035052_Init},
  // {"", 239, Mapper239_Init},
  {"", 240, Mapper240_Init},
  {"", 241, Mapper241_Init},
  {"", 242, Mapper242_Init},
  {"S74LS374NA", 243, S74LS374NA_Init},
  {"DECATHLON", 244, Mapper244_Init},
  {"", 245, Mapper245_Init},
  {"FONG SHEN BANG", 246, Mapper246_Init},
  // {"", 247, Mapper247_Init},
  // {"", 248, Mapper248_Init},
  {"", 249, Mapper249_Init},
  {"", 250, Mapper250_Init},
  // {"", 251, Mapper251_Init}, // No good dumps for this mapper, use UNIF version
  {"SAN GUO ZHI PIRATE", 252, Mapper252_Init},
  {"DRAGON BALL PIRATE", 253, Mapper253_Init},
  {"", 254, Mapper254_Init},
  // {"", 255, Mapper255_Init}, // No good dumps for this mapper
#endif
  {"", 0, nullptr},
};

// this is for games that is not the a power of 2
// mapper based for now...
// not really accurate but this works since games
// that are not in the power of 2 tends to come
// in obscure mappers themselves which supports such
// size
static constexpr int const not_power2[] = {
  228
};

// moved from utils/general -tom7
static uint32 uppow2(uint32 n) {
  for (int x = 31; x >= 0; x--) {
    if (n&(1<<x)) {
      if ((1<<x)!=n) {
	return 1<<(x+1);
      }
      break;
    }
  }
  return n;
}

bool INes::iNESLoad(const char *name, FceuFile *fp, int OverwriteVidMode) {
  struct md5_context md5;

  if (FCEU_fread(&head,1,16,fp)!=16)
    return false;

  if (memcmp(&head,"NES\x1a",4))
    return false;

  CleanupHeader(&head);

  memset(&iNESCart, 0, sizeof(iNESCart));
  delete fc->fceu->cartiface;
  fc->fceu->cartiface = nullptr;
  
  mapper_number = head.ROM_type >> 4;
  mapper_number |= (head.ROM_type2 & 0xF0);
  iNESMirroring = head.ROM_type & 1;

  //  int ROM_size=0;
  if (!head.ROM_size) {
    //   FCEU_PrintError("No PRG ROM!");
    //   return(0);
    ROM_size = 256;
    //head.ROM_size++;
  } else {
    ROM_size = uppow2(head.ROM_size);
  }

  //    ROM_size = head.ROM_size;
  VROM_size = head.VROM_size;

  int round = true;
  for (int i = 0; i != sizeof(not_power2)/sizeof(not_power2[0]); ++i) {
    //for games not to the power of 2, so we just read enough
    //prg rom from it, but we have to keep ROM_size to the power of 2
    //since PRGCartMapping wants ROM_size to be to the power of 2
    //so instead if not to power of 2, we just use head.ROM_size when
    //we use FCEU_read
    if (not_power2[i] == mapper_number) {
      round = false;
      break;
    }
  }

  if (VROM_size)
    VROM_size=uppow2(VROM_size);


  if (head.ROM_type&8) iNESMirroring=2;

  if ((ROM = (uint8 *)FCEU_malloc(ROM_size<<14)) == nullptr) return 0;
  memset(ROM,0xFF,ROM_size<<14);

  if (VROM_size) {
    if ((VROM = (uint8 *)FCEU_malloc(VROM_size<<13)) == nullptr) {
      free(ROM);
      ROM = nullptr;
      return false;
    }
    memset(VROM,0xFF,VROM_size<<13);
  }

  /* Trainer */
  if (head.ROM_type & 4) {
    trainerdata = (uint8 *)FCEU_gmalloc(512);
    FCEU_fread(trainerdata,512,1,fp);
  }

  fc->cart->ResetCartMapping();
  fc->state->ResetExState(nullptr, nullptr);

  fc->cart->SetupCartPRGMapping(0,ROM,ROM_size*0x4000,0);
  // SetupCartPRGMapping(1,WRAM,8192,1);

  FCEU_fread(ROM,0x4000,(round) ? ROM_size : head.ROM_size,fp);

  if (VROM_size)
    FCEU_fread(VROM,0x2000,head.VROM_size,fp);

  md5_starts(&md5);
  md5_update(&md5,ROM,ROM_size<<14);

  iNESGameCRC32=CalcCRC32(0,ROM,ROM_size<<14);

  if (VROM_size) {
    iNESGameCRC32=CalcCRC32(iNESGameCRC32,VROM,VROM_size<<13);
    md5_update(&md5,VROM,VROM_size<<13);
  }
  md5_finish(&md5,iNESCart.MD5);
  memcpy(&fc->fceu->GameInfo->MD5,&iNESCart.MD5,sizeof(iNESCart.MD5));

  iNESCart.CRC32 = iNESGameCRC32;

  FCEU_printf(" PRG ROM:  %3d x 16KiB\n"
	      " CHR ROM:  %3d x  8KiB\n"
	      " ROM CRC32:  0x%08lx\n",
	      (round) ? ROM_size : head.ROM_size, head.VROM_size,iNESGameCRC32);

  FCEU_printf(" ROM MD5:  0x");
  for (int x = 0; x < 16; x++)
    FCEU_printf("%02x",iNESCart.MD5[x]);
  FCEU_printf("\n");

  const char* mappername = "Not Listed";

  for (int mappertest = 0;
       mappertest < (sizeof board_map / sizeof board_map[0]) - 1; 
       mappertest++) {
    if (board_map[mappertest].number == mapper_number) {
      mappername = board_map[mappertest].name;
      break;
    }
  }

  FCEU_printf(" Mapper #:  %d\n Mapper name: %s\n Mirroring: %s\n",
	      mapper_number, mappername, 
	      iNESMirroring == 2 ? "None (Four-screen)" :
	      iNESMirroring ? "Vertical" : "Horizontal");

  FCEU_printf(" Battery-backed: %s\n", (head.ROM_type&2)?"Yes":"No");
  FCEU_printf(" Trained: %s\n", (head.ROM_type&4)?"Yes":"No");
  // (head.ROM_type&8) = iNESMirroring: None(Four-screen)

  SetInput(iNESGameCRC32, fc->fceu->GameInfo);
  CheckHInfo();
  {
    uint64 partialmd5 = 0ULL;

    for (int x = 0; x < 8; x++) {
      partialmd5 |= (uint64)iNESCart.MD5[7-x] << (x * 8);
    }

    fc->vsuni->FCEU_VSUniCheck(partialmd5, &mapper_number, &iNESMirroring);
  }
  /* Must remain here because above functions might change value of
     VROM_size and free(VROM).
  */
  if (VROM_size)
    fc->cart->SetupCartCHRMapping(0,VROM,VROM_size*0x2000,0);

  if (iNESMirroring == 2)
    fc->cart->SetupCartMirroring(4,1,ExtraNTARAM);
  else if (iNESMirroring >= 0x10)
    fc->cart->SetupCartMirroring(2+(iNESMirroring&1),1,0);
  else
    fc->cart->SetupCartMirroring(iNESMirroring&1,(iNESMirroring&4)>>2,0);

  iNESCart.battery=(head.ROM_type&2)?1:0;
  iNESCart.mirror=iNESMirroring;

  fc->fceu->GameInfo->mappernum = mapper_number;
  if (!MapperInit()) {
    // XXX tom7 added this possibility during the mapper rewrite,
    // so that I could run comprehensive tests on the covered
    // mappers at least. It probably doesn't clean up enough?
    return false;
  }
  
  fc->cart->FCEU_LoadGameSave(&iNESCart);
  TRACEA(WRAM, 8192);

  // Extract Filename only. Should account for Windows/Unix this way.
  if (strrchr(name, '/')) {
    name = strrchr(name, '/') + 1;
  } else if (strrchr(name, '\\')) {
    name = strrchr(name, '\\') + 1;
  }

  fc->fceu->GameInterface = [](FC *fc, GI h) {
    // fprintf(stderr, "ines GameInterface %d\n", (int)h);
    return fc->ines->iNESGI(h);
  };
  FCEU_printf("\n");

  // since apparently the iNES format doesn't store this information,
  // guess if the settings should be PAL or NTSC from the ROM name
  // TODO: MD5 check against a list of all known PAL games instead?
  if (OverwriteVidMode) {
    if (strstr(name,"(E)") || strstr(name,"(e)")
	|| strstr(name,"(Europe)") || strstr(name,"(PAL)")
	|| strstr(name,"(F)") || strstr(name,"(f)")
	|| strstr(name,"(G)") || strstr(name,"(g)")
	|| strstr(name,"(I)") || strstr(name,"(i)")) {
      fc->fceu->FCEUI_SetVidSystem(1);
    } else {
      fc->fceu->FCEUI_SetVidSystem(0);
    }
  }

  return true;
}

void VRAM_BANK1(FC *fc, uint32 A, uint8 V) {
  V&=7;
  fc->ppu->PPUCHRRAM|=(1<<(A>>10));
  fc->ines->iNESCHRBankList[(A)>>10]=V;
  fc->cart->VPage[(A)>>10]=&CHRRAM[V<<10]-(A);
}

void VRAM_BANK4(FC *fc, uint32 A, uint32 V) {
  V&=1;
  fc->ppu->PPUCHRRAM|=(0xF<<(A>>10));
  fc->ines->iNESCHRBankList[(A)>>10]=(V<<2);
  fc->ines->iNESCHRBankList[((A)>>10)+1]=(V<<2)+1;
  fc->ines->iNESCHRBankList[((A)>>10)+2]=(V<<2)+2;
  fc->ines->iNESCHRBankList[((A)>>10)+3]=(V<<2)+3;
  fc->cart->VPage[(A)>>10]=&CHRRAM[V<<10]-(A);
}

void VROM_BANK1(FC *fc, uint32 A,uint32 V) {
  fc->cart->setchr1(A,V);
  fc->ines->iNESCHRBankList[(A)>>10]=V;
}

void VROM_BANK2(FC *fc, uint32 A,uint32 V) {
  fc->cart->setchr2(A,V);
  fc->ines->iNESCHRBankList[(A)>>10]=(V<<1);
  fc->ines->iNESCHRBankList[((A)>>10)+1]=(V<<1)+1;
}

void VROM_BANK4(FC *fc, uint32 A, uint32 V) {
  fc->cart->setchr4(A,V);
  fc->ines->iNESCHRBankList[(A)>>10]=(V<<2);
  fc->ines->iNESCHRBankList[((A)>>10)+1]=(V<<2)+1;
  fc->ines->iNESCHRBankList[((A)>>10)+2]=(V<<2)+2;
  fc->ines->iNESCHRBankList[((A)>>10)+3]=(V<<2)+3;
}

void VROM_BANK8(FC *fc, uint32 V) {
  fc->cart->setchr8(V);
  fc->ines->iNESCHRBankList[0]=(V<<3);
  fc->ines->iNESCHRBankList[1]=(V<<3)+1;
  fc->ines->iNESCHRBankList[2]=(V<<3)+2;
  fc->ines->iNESCHRBankList[3]=(V<<3)+3;
  fc->ines->iNESCHRBankList[4]=(V<<3)+4;
  fc->ines->iNESCHRBankList[5]=(V<<3)+5;
  fc->ines->iNESCHRBankList[6]=(V<<3)+6;
  fc->ines->iNESCHRBankList[7]=(V<<3)+7;
}

void ROM_BANK8(FC *fc, uint32 A, uint32 V) {
  fc->cart->setprg8(A,V);
  if (A>=0x8000)
    PRGBankList[((A-0x8000)>>13)]=V;
}

void ROM_BANK16(FC *fc, uint32 A, uint32 V) {
  fc->cart->setprg16(A,V);
  if (A>=0x8000) {
    PRGBankList[((A-0x8000)>>13)]=V<<1;
    PRGBankList[((A-0x8000)>>13)+1]=(V<<1)+1;
  }
}

void ROM_BANK32(FC *fc, uint32 V) {
  fc->cart->setprg32(0x8000,V);
  PRGBankList[0]=V<<2;
  PRGBankList[1]=(V<<2)+1;
  PRGBankList[2]=(V<<2)+2;
  PRGBankList[3]=(V<<2)+3;
}

void INes::onemir(uint8 V) {
  if (iNESMirroring==2) return;
  if (V>1)
    V=1;
  iNESMirroring=0x10|V;
  fc->cart->setmirror(MI_0+V);
}

void INes::MIRROR_SET2(uint8 V) {
  if (iNESMirroring==2) return;
  iNESMirroring=V;
  fc->cart->setmirror(V);
}

void INes::MIRROR_SET(uint8 V) {
  if (iNESMirroring==2) return;
  V^=1;
  iNESMirroring=V;
  fc->cart->setmirror(V);
}

void INes::NONE_init() {
  ROM_BANK16(fc, 0x8000,0);
  ROM_BANK16(fc, 0xC000,~0);

  if (VROM_size)
    VROM_BANK8(fc, 0);
  else
    fc->cart->setvram8(CHRRAM);
}

static constexpr void (* const MapInitTab[256])() = {
#if 0
  0,
  0,
  0, //Mapper2_init,
  0, //Mapper3_init,
  0,
  0,
  Mapper6_init,
  0, //Mapper7_init,
  0, //Mapper8_init,
  Mapper9_init,
  Mapper10_init,
  0, //Mapper11_init,
  0,
  0, //Mapper13_init,
  0,
  0, //Mapper15_init,
  0, //Mapper16_init,
  0, //Mapper17_init,
  0, //Mapper18_init,
  0,
  0,
  0, //Mapper21_init,
  0, //Mapper22_init,
  0, //Mapper23_init,
  Mapper24_init,
  0, //Mapper25_init,
  Mapper26_init,
  0, //Mapper27_init,
  0,
  0,
  0,
  0,
  0, //Mapper32_init,
  0, //Mapper33_init,
  0, //Mapper34_init,
  0,
  0,
  0,
  0,
  0,
  Mapper40_init,
  Mapper41_init,
  Mapper42_init,
  0, //Mapper43_init,
  0,
  0,
  Mapper46_init,
  0,
  0, //Mapper48_init,
  0,
  Mapper50_init,
  Mapper51_init,
  0,
  0,
  0,
  0,
  0,
  0, //Mapper57_init,
  0, //Mapper58_init,
  0, //Mapper59_init,
  0, //Mapper60_init,
  Mapper61_init,
  Mapper62_init,
  0,
  Mapper64_init,
  Mapper65_init,
  0, //Mapper66_init,
  Mapper67_init,
  0, //Mapper68_init,
  Mapper69_init,
  0, //Mapper70_init,
  Mapper71_init,
  Mapper72_init,
  Mapper73_init,
  0,
  Mapper75_init,
  Mapper76_init,
  Mapper77_init,
  0, //Mapper78_init,
  Mapper79_init,
  Mapper80_init,
  0,
  0, //Mapper82_init,
  0, //Mapper83_init,
  0,
  Mapper85_init,
  0, //Mapper86_init,
  0, //Mapper87_init,
  0, //Mapper88_init,
  0, //Mapper89_init,
  0,
  0, //Mapper91_init,
  0, //Mapper92_init,
  0, //Mapper93_init,
  0, //Mapper94_init,
  0,
  0, //Mapper96_init,
  0, //Mapper97_init,
  0,
  0, //Mapper99_init,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0, //Mapper107_init,
  0,
  0,
  0,
  0,
  0,
  0, //Mapper113_init,
  0,
  0,
  0, //Mapper116_init,
  0, //Mapper117_init,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0, //Mapper140_init,
  0,
  0,
  0,
  0, //Mapper144_init,
  0,
  0,
  0,
  0,
  0,
  0,
  0, //Mapper151_init,
  0, //Mapper152_init,
  0, //Mapper153_init,
  0, //Mapper154_init,
  0,
  0, //Mapper156_init,
  0, //Mapper157_init,
  0, //Mapper158_init, removed
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  Mapper166_init,
  Mapper167_init,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0, //Mapper180_init,
  0,
  0,
  0,
  0, //Mapper184_init,
  0, //Mapper185_init,
  0,
  0,
  0,
  0, //Mapper189_init,
  0,
  0, //Mapper191_init,
  0,
  0, //Mapper193_init,
  0,
  0,
  0,
  0,
  0,
  0,
  0, //Mapper200_init,
  0, //Mapper201_init,
  0, //Mapper202_init,
  0, //Mapper203_init,
  0, //Mapper204_init,
  0,
  0,
  Mapper207_init,
  0,
  0,
  0,
  0, //Mapper211_init,
  0, //Mapper212_init,
  0, //Mapper213_init,
  0, //Mapper214_init,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0, //Mapper225_init,
  0, //Mapper226_init,
  0, //Mapper227_init,
  0, //Mapper228_init,
  0, //Mapper229_init,
  0, //Mapper230_init,
  0, //Mapper231_init,
  0, //Mapper232_init,
  0,
  0, //Mapper234_init,
  0, //Mapper235_init,
  0,
  0,
  0,
  0,
  0, //Mapper240_init,
  0, //Mapper241_init,
  0, //Mapper242_init,
  0,
  0, //Mapper244_init,
  0,
  0, //Mapper246_init,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0, //Mapper255_init
#endif
};

static DECLFW(BWRAM) {
  WRAM[A-0x6000]=V;
}

static DECLFR(AWRAM) {
  return WRAM[A-0x6000];
}

void INes::iNESStateRestore(int version) {
  if (!mapper_number) return;

  for (int x = 0; x < 4; x++)
    fc->cart->setprg8(0x8000+x*8192,PRGBankList[x]);

  if (VROM_size)
    for (int x = 0; x < 8; x++)
      fc->cart->setchr1(0x400*x,iNESCHRBankList[x]);

#if 0
  switch(iNESMirroring) {
  case 0:fc->cart->setmirror(MI_H);break;
  case 1:fc->cart->setmirror(MI_V);break;
  case 0x12:
  case 0x10:fc->cart->setmirror(MI_0);break;
  case 0x13:
  case 0x11:fc->cart->setmirror(MI_1);break;
  }
#endif
  if (MapStateRestore) MapStateRestore(version);
}

void INes::iNESPower() {
  // This is the old loading code. It's only called if NewiNES_Init
  // fails. Can we do without it? -tom7
  printf("Ugh! Old iNESPower mapper code!\n");
  
  TRACEF("iNESPower %d", mapper_number);
  int type = mapper_number;

  fc->fceu->SetReadHandler(0x8000,0xFFFF,Cart::CartBR);
  fc->fceu->GameStateRestore = [](FC *fc, int v) {
    return fc->ines->iNESStateRestore(v);
  };
  MapClose=0;
  MapperReset=0;
  MapStateRestore = nullptr;

  fc->cart->setprg8r(1,0x6000,0);

  fc->fceu->SetReadHandler(0x6000,0x7FFF,AWRAM);
  fc->fceu->SetWriteHandler(0x6000,0x7FFF,BWRAM);

  /* This statement represents atrocious code.  I need to rewrite
     all of the iNES mapper code... */
  iNESIRQCount=iNESIRQLatch=iNESIRQa=0;
  if (head.ROM_type&2)
    memset(fc->fceu->GameMemBlock+8192,0,GAME_MEM_BLOCK_SIZE-8192);
  else
    memset(fc->fceu->GameMemBlock,0,GAME_MEM_BLOCK_SIZE);

  NONE_init();
  fc->state->ResetExState(nullptr, nullptr);

  if (fc->fceu->GameInfo->type == GIT_VSUNI)
    fc->state->AddExState(fc->vsuni->FCEUVSUNI_STATEINFO(), ~0, 0, 0);

  // Note: This used to save as "WRAM", but this is also used by
  // many mappers. In some situation (I didn't dig in too deeply)
  // the two could get confused, and e.g. Mapper 82 would some
  // memory that was read during destruction. Gave it a unique name.
  // -tom7
  fc->state->AddExState(WRAM, 8192, 0, "iNWR");
  if (type==19 || type==6 || type==69 || type==85 || type==96)
    fc->state->AddExState(MapperExRAM, 32768, 0, "MEXR");
  if ((!VROM_size || type==6 || type==19) && (type!=13 && type!=96))
    fc->state->AddExState(CHRRAM, 8192, 0, "CHRR");
  if (head.ROM_type&8)
    fc->state->AddExState(ExtraNTARAM, 2048, 0, "EXNR");

  /* Exclude some mappers whose emulation code handle save state stuff
     themselves. */
  if (type && type != 13 && type != 96) {
    fc->state->AddExState(mapbyte1, 32, 0, "MPBY");
    fc->state->AddExState(&iNESMirroring, 1, 0, "MIRR");
    // Note that ines.cc also has its own IRQCount; these once had the
    // same key "IRQC" but I renamed them to use different keys. They
    // also conflicted with many boards (e.g. skull.nes exhibits this
    // failure).
    fc->state->AddExState(&iNESIRQCount, 4, 1, "iRQC");
    fc->state->AddExState(&iNESIRQLatch, 4, 1, "IQL1");
    // Similarly with iRQA.
    fc->state->AddExState(&iNESIRQa, 1, 0, "iRQA");
    fc->state->AddExState(PRGBankList, 4, 0, "PBL0");
    for (int x = 0; x < 8; x++) {
      char tak[8];
      sprintf(tak,"CBL%d",x);
      fc->state->AddExState(&iNESCHRBankList[x], 2, 1,tak);
    }
  }

  if (MapInitTab[type]) {
    MapInitTab[type]();
  } else if (type) {
    FCEU_PrintError("iNES mapper #%d is not supported at all.",type);
  }
}

int INes::NewiNES_Init(int num) {
  const BoardMapping *tmp = board_map;
  TRACEF("NewiNES_Init %d", num);

  CHRRAMSize = -1;

  if (fc->fceu->GameInfo->type == GIT_VSUNI)
    fc->state->AddExState(fc->vsuni->FCEUVSUNI_STATEINFO(), ~0, 0, 0);

  while (tmp->init) {
    if (num == tmp->number) {
      // need here for compatibility with UNIF mapper code
      fc->unif->UNIFchrrama = 0;
      if (!VROM_size) {
	if (num==13) {
	  CHRRAMSize=16384;
	} else {
	  CHRRAMSize=8192;
	}
	if ((VROM = (uint8 *)malloc(CHRRAMSize)) == nullptr) return 0;
	FCEU_InitMemory(VROM,CHRRAMSize);

	fc->unif->UNIFchrrama = VROM;
	fc->cart->SetupCartCHRMapping(0,VROM,CHRRAMSize,1);
	fc->state->AddExState(VROM,CHRRAMSize, 0, "CHRR");
      }
      if (head.ROM_type&8)
	fc->state->AddExState(ExtraNTARAM, 2048, 0, "EXNR");
      fc->fceu->cartiface = tmp->init(fc, &iNESCart);
      TRACEF("NewiNES init done.");
      return 1;
    }
    tmp++;
  }
  return 0;
}
