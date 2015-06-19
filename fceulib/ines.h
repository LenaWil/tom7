/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 1998 Bero
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

#ifndef _INES_H_
#define _INES_H_

#include <stdlib.h>
#include <string.h>
#include <map>
#include "fceu.h"

// This is the iNES ROM image format (probably actually NES 2.0), the
// most popular one.
//
// http://wiki.nesdev.com/w/index.php/INES

struct FceuFile;
struct INesTMasterRomInfo {
  uint64 md5lower;
  const char* params;
};

struct INes {
  INes();

  int iNESLoad(const char *name, FceuFile *fp, int OverwriteVidMode);
  void iNESStateRestore(int version);

  void ClearMasterRomInfoParams() {
    MasterRomInfoParams.clear();
  }

  const std::string *MasterRomInfoParam(const std::string &key) {
    auto it = MasterRomInfoParams.find(key);
    if (it == MasterRomInfoParams.end())
      return nullptr;
    else return &it->second;
  }

  DECLFR_RET TrainerRead_Direct(DECLFR_ARGS);

  // INESPRV
  void (*MapStateRestore)(int version) = nullptr;
  void (*MapperReset)() = nullptr;
  void onemir(uint8 V);
  void MIRROR_SET2(uint8 V);
  void MIRROR_SET(uint8 V);

  uint8 iNESIRQa = 0;
  uint8 iNESMirroring = 0;
  int32 iNESIRQCount = 0;
  int32 iNESIRQLatch = 0;
  uint16 iNESCHRBankList[8] = {0};
  uint32 VROM_size = 0;
  uint32 ROM_size = 0;

  uint8 *ROM = nullptr;
  uint8 *VROM = nullptr;

 private:

  struct Header {
    char ID[4]; /*NES^Z*/
    uint8 ROM_size;
    uint8 VROM_size;
    uint8 ROM_type;
    uint8 ROM_type2;
    uint8 reserve[8];
  };

  Header head;
  void CleanupHeader(Header *h);
  
  uint8 *trainerdata = nullptr;

  int mapper_number = 0;
  CartInfo iNESCart = {};
  int CHRRAMSize = -1;
  uint32 iNESGameCRC32 = 0;
  
  const INesTMasterRomInfo *MasterRomInfo = nullptr;
  std::map<std::string, std::string> MasterRomInfoParams;

  void (*MapClose)() = nullptr;

  void NONE_init();

  int NewiNES_Init(int num);
  void iNESPower();
  void iNES_ExecPower();
  void iNESGI(GI h);
  void MapperInit();
  void CheckHInfo();
};

extern INes fceulib__ines;

// These are allowed to be accessed by mappers. -tom7
#ifdef INESPRIV

/* This order is necessary */
#define WRAM    (GameMemBlock)
#define sizeofWRAM    8192

#define MapperExRAM   (GameMemBlock+sizeofWRAM)
#define sizeofMapperExRAM  32768
/* for the MMC5 code to work properly.  It might be fixed later... */

#define CHRRAM  (GameMemBlock+sizeofWRAM+sizeofMapperExRAM)
#define sizeofCHRRAM 8192

#define ExtraNTARAM   (GameMemBlock+sizeofWRAM+sizeofMapperExRAM+sizeofCHRRAM)
#define sizeofExtraNTARAM 2048

#define PRGBankList    (ExtraNTARAM+sizeofExtraNTARAM)

#define mapbyte1       (PRGBankList+4)
#define mapbyte2       (mapbyte1+8)
#define mapbyte3       (mapbyte2+8)
#define mapbyte4       (mapbyte3+8)

#endif  // INESPRIV

void VRAM_BANK1(uint32 A, uint8 V);
void VRAM_BANK4(uint32 A,uint32 V);

void VROM_BANK1(uint32 A,uint32 V);
void VROM_BANK2(uint32 A,uint32 V);
void VROM_BANK4(uint32 A, uint32 V);
void VROM_BANK8(uint32 V);
void ROM_BANK8(uint32 A, uint32 V);
void ROM_BANK16(uint32 A, uint32 V);
void ROM_BANK32(uint32 V);

// This list is pretty weird, I guess part of some transition
// to the capital-i Init methods. Many of these are not even
// defined anywhere. If there's a space after // then I was
// the one who commented it out -tom7.

// void Mapper0_init();
// void Mapper1_init();
//void Mapper2_init();
//void Mapper3_init();
void Mapper6_init();
//void Mapper7_init();
//void Mapper8_init();
void Mapper9_init();
void Mapper10_init();
//void Mapper11_init();
void Mapper12_init();
//void Mapper13_init();
void Mapper14_init();
//void Mapper15_init();
//void Mapper16_init();
//void Mapper17_init();
//void Mapper18_init();
void Mapper19_init();
void Mapper20_init();
//void Mapper21_init();
//void Mapper22_init();
//void Mapper23_init();
void Mapper24_init();
//void Mapper25_init();
void Mapper26_init();
//void Mapper27_init();
void Mapper28_init();
// void Mapper29_init();
// void Mapper30_init();
// void Mapper31_init();
//void Mapper32_init();
//void Mapper33_init();
//void Mapper34_init();
// void Mapper35_init();
// void Mapper36_init();
//void Mapper37_init();
//void Mapper38_init();
//void Mapper39_init();
void Mapper40_init();
void Mapper41_init();
void Mapper42_init();
//void Mapper43_init();
void Mapper44_init();
void Mapper45_init();
void Mapper46_init();
void Mapper47_init();
//void Mapper48_init();
void Mapper49_init();
void Mapper50_init();
void Mapper51_init();
void Mapper53_init();
void Mapper54_init();
void Mapper55_init();
void Mapper56_init();
//void Mapper59_init();
void Mapper60_init();
void Mapper61_init();
void Mapper62_init();
void Mapper63_init();
void Mapper64_init();
void Mapper65_init();
//void Mapper66_init();
void Mapper67_init();
//void Mapper68_init();
void Mapper69_init();
//void Mapper70_init();
void Mapper71_init();
void Mapper72_init();
void Mapper73_init();
void Mapper74_init();
void Mapper75_init();
void Mapper76_init();
void Mapper77_init();
//void Mapper78_init();
void Mapper79_init();
void Mapper80_init();
void Mapper81_init();
//void Mapper82_init();
void Mapper83_init();
void Mapper84_init();
void Mapper85_init();
//void Mapper86_init();
//void Mapper87_init();
void Mapper88_init();
//void Mapper89_init();
//void Mapper91_init();
//void Mapper92_init();
//void Mapper93_init();
//void Mapper94_init();
//void Mapper96_init();
//void Mapper97_init();
void Mapper98_init();
//void Mapper99_init();
void Mapper100_init();
//void Mapper101_init();
//void Mapper103_init();
void Mapper104_init();
//void Mapper106_init();
//void Mapper107_init();
//void Mapper108_init();
void Mapper109_init();
void Mapper110_init();
//void Mapper111_init();
//void Mapper113_init();
void Mapper115_init();
//void Mapper116_init();
//void Mapper117_init();
//void Mapper120_init();
//void Mapper121_init();
void Mapper122_init();
void Mapper123_init();
void Mapper124_init();
void Mapper126_init();
void Mapper127_init();
void Mapper128_init();
void Mapper129_init();
void Mapper130_init();
void Mapper131_init();
void Mapper132_init();
//void Mapper134_init();
void Mapper135_init();
void Mapper136_init();
void Mapper137_init();
void Mapper139_init();
//void Mapper140_init();
void Mapper141_init();
//void Mapper142_init();
void Mapper143_init();
//void Mapper144_init();
void Mapper150_init();
//void Mapper151_init();
//void Mapper152_init();
//void Mapper153_init();
void Mapper154_init();
//void Mapper156_init();
//void Mapper157_init();
//void Mapper158_init();
//void Mapper159_init();
void Mapper160_init();
void Mapper161_init();
void Mapper162_init();
void Mapper166_init();
void Mapper167_init();
void Mapper168_init();
//void Mapper169_init();
void Mapper170_init();
//void Mapper171_init();
//void Mapper172_init();
//void Mapper173_init();
void Mapper174_init();
void Mapper175_init();
void Mapper176_init();
//void Mapper177_init();
//void Mapper178_init();
//void Mapper179_init();
void Mapper180_init();
//void Mapper181_init();
//void Mapper184_init();
//void Mapper185_init();
//void Mapper189_init();
//void Mapper192_init();
//void Mapper193_init();
//void Mapper194_init();
//void Mapper195_init();
//void Mapper196_init();
//void Mapper197_init();
//void Mapper198_init();
void Mapper199_init();
//void Mapper200_init();
//void Mapper201_init();
//void Mapper202_init();
//void Mapper203_init();
//void Mapper204_init();
void Mapper207_init();
//void Mapper211_init();
//void Mapper212_init();
//void Mapper213_init();
//void Mapper214_init();
//void Mapper218_init();
void Mapper219_init();
//void Mapper220_init();
void Mapper221_init();
//void Mapper222_init();
void Mapper223_init();
void Mapper224_init();
//void Mapper225_init();
//void Mapper226_init();
//void Mapper227_init();
//void Mapper228_init();
//void Mapper229_init();
//void Mapper230_init();
//void Mapper231_init();
//void Mapper232_init();
//void Mapper233_init();
//void Mapper234_init();
//void Mapper235_init();
void Mapper236_init();
void Mapper237_init();
void Mapper238_init();
void Mapper239_init();
void Mapper240_init();
//void Mapper241_init();
//void Mapper242_init();
//void Mapper244_init();
void Mapper245_init();
//void Mapper246_init();
void Mapper247_init();
void Mapper249_init();
void Mapper251_init();
//void Mapper252_init();
//void Mapper253_init();
//void Mapper255_init();

// Probably can kill NSF code? -tom7
void NSFVRC6_Init();
void NSFMMC5_Init();
void NSFAY_Init();
void NSFN106_Init();
void NSFVRC7_Init();

void Mapper19_ESI();

// These are presumably the new mappers. 
void Mapper1_Init(CartInfo *);
void Mapper4_Init(CartInfo *);
void Mapper5_Init(CartInfo *);
void Mapper8_Init(CartInfo *);
void Mapper11_Init(CartInfo *);
void Mapper12_Init(CartInfo *);
void Mapper15_Init(CartInfo *);
void Mapper16_Init(CartInfo *);
void Mapper17_Init(CartInfo *);
void Mapper18_Init(CartInfo *);
void Mapper19_Init(CartInfo *);
void Mapper21_Init(CartInfo *);
void Mapper22_Init(CartInfo *);
void Mapper23_Init(CartInfo *);
void Mapper25_Init(CartInfo *);
void Mapper28_Init(CartInfo *);
void Mapper32_Init(CartInfo *);
void Mapper33_Init(CartInfo *);
void Mapper34_Init(CartInfo *);
void Mapper36_Init(CartInfo *);
void Mapper37_Init(CartInfo *);
void Mapper38_Init(CartInfo *);
void Mapper43_Init(CartInfo *);
void Mapper44_Init(CartInfo *);
void Mapper45_Init(CartInfo *);
void Mapper47_Init(CartInfo *);
void Mapper48_Init(CartInfo *);
void Mapper49_Init(CartInfo *);
void Mapper52_Init(CartInfo *);
void Mapper57_Init(CartInfo *);
void Mapper59_Init(CartInfo *);
void Mapper68_Init(CartInfo *);
void Mapper70_Init(CartInfo *);
void Mapper74_Init(CartInfo *);
void Mapper78_Init(CartInfo *);
void Mapper82_Init(CartInfo *);
void Mapper83_Init(CartInfo *);
void Mapper86_Init(CartInfo *);
void Mapper87_Init(CartInfo *);
void Mapper88_Init(CartInfo *);
void Mapper89_Init(CartInfo *);
void Mapper90_Init(CartInfo *);
void Mapper91_Init(CartInfo *);
void Mapper92_Init(CartInfo *);
void Mapper93_Init(CartInfo *);
void Mapper94_Init(CartInfo *);
void Mapper95_Init(CartInfo *);
void Mapper96_Init(CartInfo *);
void Mapper97_Init(CartInfo *);
void Mapper99_Init(CartInfo *);
void Mapper101_Init(CartInfo *);
void Mapper103_Init(CartInfo *);
void Mapper105_Init(CartInfo *);
void Mapper106_Init(CartInfo *);
void Mapper107_Init(CartInfo *);
void Mapper108_Init(CartInfo *);
void Mapper112_Init(CartInfo *);
void Mapper113_Init(CartInfo *);
void Mapper114_Init(CartInfo *);
void Mapper115_Init(CartInfo *);
void Mapper117_Init(CartInfo *);
void Mapper119_Init(CartInfo *);
void Mapper120_Init(CartInfo *);
void Mapper121_Init(CartInfo *);
void Mapper125_Init(CartInfo *);
void Mapper134_Init(CartInfo *);
void Mapper140_Init(CartInfo *);
void Mapper144_Init(CartInfo *);
void Mapper151_Init(CartInfo *);
void Mapper152_Init(CartInfo *);
void Mapper153_Init(CartInfo *);
void Mapper154_Init(CartInfo *);
void Mapper155_Init(CartInfo *);
void Mapper156_Init(CartInfo *);
void Mapper157_Init(CartInfo *);
void Mapper163_Init(CartInfo *);
void Mapper164_Init(CartInfo *);
void Mapper165_Init(CartInfo *);
void Mapper168_Init(CartInfo *);
void Mapper170_Init(CartInfo *);
void Mapper171_Init(CartInfo *);
void Mapper172_Init(CartInfo *);
void Mapper173_Init(CartInfo *);
void Mapper175_Init(CartInfo *);
void Mapper177_Init(CartInfo *);
void Mapper178_Init(CartInfo *);
void Mapper180_Init(CartInfo *);
void Mapper181_Init(CartInfo *);
void Mapper183_Init(CartInfo *);
void Mapper184_Init(CartInfo *);
void Mapper185_Init(CartInfo *);
void Mapper186_Init(CartInfo *);
void Mapper187_Init(CartInfo *);
void Mapper188_Init(CartInfo *);
void Mapper189_Init(CartInfo *);
void Mapper191_Init(CartInfo *);
void Mapper192_Init(CartInfo *);
void Mapper193_Init(CartInfo *);
void Mapper194_Init(CartInfo *);
void Mapper195_Init(CartInfo *);
void Mapper196_Init(CartInfo *);
void Mapper197_Init(CartInfo *);
void Mapper198_Init(CartInfo *);
void Mapper199_Init(CartInfo *);
void Mapper200_Init(CartInfo *);
void Mapper201_Init(CartInfo *);
void Mapper202_Init(CartInfo *);
void Mapper203_Init(CartInfo *);
void Mapper205_Init(CartInfo *);
void Mapper204_Init(CartInfo *);
void Mapper208_Init(CartInfo *);
void Mapper209_Init(CartInfo *);
void Mapper210_Init(CartInfo *);
void Mapper211_Init(CartInfo *);
void Mapper212_Init(CartInfo *);
void Mapper213_Init(CartInfo *);
void Mapper214_Init(CartInfo *);
void Mapper216_Init(CartInfo *);
void Mapper217_Init(CartInfo *);
void Mapper220_Init(CartInfo *);
void Mapper222_Init(CartInfo *);
void Mapper225_Init(CartInfo *);
void Mapper226_Init(CartInfo *);
void Mapper227_Init(CartInfo *);
void Mapper228_Init(CartInfo *);
void Mapper229_Init(CartInfo *);
void Mapper230_Init(CartInfo *);
void Mapper231_Init(CartInfo *);
void Mapper232_Init(CartInfo *);
void Mapper233_Init(CartInfo *);
void Mapper234_Init(CartInfo *);
void Mapper235_Init(CartInfo *);
void Mapper236_Init(CartInfo *);
void Mapper237_Init(CartInfo *);
void Mapper240_Init(CartInfo *);
void Mapper241_Init(CartInfo *);
void Mapper242_Init(CartInfo *);
void Mapper244_Init(CartInfo *);
void Mapper245_Init(CartInfo *);
void Mapper246_Init(CartInfo *);
void Mapper249_Init(CartInfo *);
void Mapper250_Init(CartInfo *);
void Mapper252_Init(CartInfo *);
void Mapper253_Init(CartInfo *);
void Mapper254_Init(CartInfo *);

#endif
