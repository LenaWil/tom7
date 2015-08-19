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

#include "fc.h"

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
  explicit INes(FC *fc);
  ~INes();

  // Returns true on success.
  bool iNESLoad(const char *name, FceuFile *fp, int OverwriteVidMode);
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
  struct OldCartiface;
  
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
  bool MapperInit();
  void CheckHInfo();

  FC *fc = nullptr;
};

// These are allowed to be accessed by mappers. -tom7
#ifdef INESPRIV

/* This order is necessary */
#define WRAM    (fceulib__.fceu->GameMemBlock)
#define sizeofWRAM    8192

#define MapperExRAM   (fceulib__.fceu->GameMemBlock+sizeofWRAM)
#define sizeofMapperExRAM  32768
/* for the MMC5 code to work properly.  It might be fixed later... */

#define CHRRAM  (fceulib__.fceu->GameMemBlock+sizeofWRAM+sizeofMapperExRAM)
#define sizeofCHRRAM 8192

#define ExtraNTARAM   (fceulib__.fceu->GameMemBlock+sizeofWRAM+sizeofMapperExRAM+sizeofCHRRAM)
#define sizeofExtraNTARAM 2048

#define PRGBankList    (ExtraNTARAM+sizeofExtraNTARAM)

#define mapbyte1       (PRGBankList+4)
#define mapbyte2       (mapbyte1+8)
#define mapbyte3       (mapbyte2+8)
#define mapbyte4       (mapbyte3+8)

#endif  // INESPRIV

// TODO: Maybe should be members of INes.
void VRAM_BANK1(FC *fc, uint32 A, uint8 V);
void VRAM_BANK4(FC *fc, uint32 A,uint32 V);

void VROM_BANK1(FC *fc, uint32 A,uint32 V);
void VROM_BANK2(FC *fc, uint32 A,uint32 V);
void VROM_BANK4(FC *fc, uint32 A, uint32 V);
void VROM_BANK8(FC *fc, uint32 V);
void ROM_BANK8(FC *fc, uint32 A, uint32 V);
void ROM_BANK16(FC *fc, uint32 A, uint32 V);
void ROM_BANK32(FC *fc, uint32 V);

// This list is pretty weird, I guess part of some transition
// to the capital-i Init methods. Many of these are not even
// defined anywhere. If there's a space after // then I was
// the one who commented it out -tom7.

#if 0
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
#endif

// The new mappers.

// Datalatch.
CartInterface *Mapper8_Init(FC *fc, CartInfo *info);
CartInterface *Mapper11_Init(FC *fc, CartInfo *info);
CartInterface *Mapper144_Init(FC *fc, CartInfo *info);
CartInterface *Mapper36_Init(FC *fc, CartInfo *info);
CartInterface *Mapper38_Init(FC *fc, CartInfo *info);
CartInterface *Mapper140_Init(FC *fc, CartInfo *info);
CartInterface *Mapper70_Init(FC *fc, CartInfo *info);
CartInterface *Mapper78_Init(FC *fc, CartInfo *info);
CartInterface *Mapper86_Init(FC *fc, CartInfo *info);
CartInterface *Mapper87_Init(FC *fc, CartInfo *info);
CartInterface *Mapper89_Init(FC *fc, CartInfo *info);
CartInterface *Mapper94_Init(FC *fc, CartInfo *info);
CartInterface *Mapper97_Init(FC *fc, CartInfo *info);
CartInterface *Mapper101_Init(FC *fc, CartInfo *info);
CartInterface *Mapper107_Init(FC *fc, CartInfo *info);
CartInterface *Mapper113_Init(FC *fc, CartInfo *info);
CartInterface *Mapper152_Init(FC *fc, CartInfo *info);
CartInterface *Mapper180_Init(FC *fc, CartInfo *info);
CartInterface *Mapper184_Init(FC *fc, CartInfo *info);
CartInterface *Mapper203_Init(FC *fc, CartInfo *info);
CartInterface *Mapper240_Init(FC *fc, CartInfo *info);
CartInterface *Mapper241_Init(FC *fc, CartInfo *info);

// MMC3
CartInterface *Mapper4_Init(FC *fc, CartInfo *);
CartInterface *Mapper12_Init(FC *fc, CartInfo *);
CartInterface *Mapper37_Init(FC *fc, CartInfo *);
CartInterface *Mapper44_Init(FC *fc, CartInfo *);
CartInterface *Mapper45_Init(FC *fc, CartInfo *);
CartInterface *Mapper47_Init(FC *fc, CartInfo *);
CartInterface *Mapper49_Init(FC *fc, CartInfo *);
CartInterface *Mapper52_Init(FC *fc, CartInfo *);
CartInterface *Mapper74_Init(FC *fc, CartInfo *);
CartInterface *Mapper114_Init(FC *fc, CartInfo *);
CartInterface *Mapper115_Init(FC *fc, CartInfo *);
CartInterface *Mapper119_Init(FC *fc, CartInfo *);
CartInterface *Mapper134_Init(FC *fc, CartInfo *);
CartInterface *Mapper165_Init(FC *fc, CartInfo *);
CartInterface *Mapper191_Init(FC *fc, CartInfo *);
CartInterface *Mapper192_Init(FC *fc, CartInfo *);
CartInterface *Mapper194_Init(FC *fc, CartInfo *);
CartInterface *Mapper195_Init(FC *fc, CartInfo *);
CartInterface *Mapper196_Init(FC *fc, CartInfo *);
CartInterface *Mapper197_Init(FC *fc, CartInfo *);
CartInterface *Mapper198_Init(FC *fc, CartInfo *);
CartInterface *Mapper205_Init(FC *fc, CartInfo *);
CartInterface *Mapper249_Init(FC *fc, CartInfo *);
CartInterface *Mapper250_Init(FC *fc, CartInfo *);
CartInterface *Mapper254_Init(FC *fc, CartInfo *);

// 01-222
CartInterface *Mapper172_Init(FC *fc, CartInfo *);
CartInterface *Mapper173_Init(FC *fc, CartInfo *);

// 32
CartInterface *Mapper32_Init(FC *fc, CartInfo *);

// 103
CartInterface *Mapper103_Init(FC *fc, CartInfo *);

// 33
CartInterface *Mapper33_Init(FC *fc, CartInfo *);
CartInterface *Mapper48_Init(FC *fc, CartInfo *);

// 106
CartInterface *Mapper106_Init(FC *fc, CartInfo *);

// 34
CartInterface *Mapper34_Init(FC *fc, CartInfo *);

// karaoke
CartInterface *Mapper188_Init(FC *fc, CartInfo *);

// 108
CartInterface *Mapper108_Init(FC *fc, CartInfo *);

// 112
CartInterface *Mapper112_Init(FC *fc, CartInfo *);

// 116
CartInterface *Mapper116_Init(FC *fc, CartInfo *);

// 43
CartInterface *Mapper43_Init(FC *fc, CartInfo *);

// 117
CartInterface *Mapper117_Init(FC *fc, CartInfo *);

// 57
CartInterface *Mapper57_Init(FC *fc, CartInfo *);

// 120
CartInterface *Mapper120_Init(FC *fc, CartInfo *);

// 121
CartInterface *Mapper121_Init(FC *fc, CartInfo *);

// 68
CartInterface *Mapper68_Init(FC *fc, CartInfo *);

// 15
CartInterface *Mapper15_Init(FC *fc, CartInfo *);

// 82
CartInterface *Mapper82_Init(FC *fc, CartInfo *);

// 151
CartInterface *Mapper151_Init(FC *fc, CartInfo *);

// 156
CartInterface *Mapper156_Init(FC *fc, CartInfo *);

// 164
CartInterface *Mapper163_Init(FC *fc, CartInfo *);
CartInterface *Mapper164_Init(FC *fc, CartInfo *);

// 88
CartInterface *Mapper88_Init(FC *fc, CartInfo *);
CartInterface *Mapper154_Init(FC *fc, CartInfo *);

// 168
CartInterface *Mapper168_Init(FC *fc, CartInfo *);

// 90
CartInterface *Mapper90_Init(FC *fc, CartInfo *);
CartInterface *Mapper209_Init(FC *fc, CartInfo *);
CartInterface *Mapper211_Init(FC *fc, CartInfo *);

// 17
CartInterface *Mapper17_Init(FC *fc, CartInfo *);

// ?
CartInterface *Mapper1_Init(FC *fc, CartInfo *);
CartInterface *Mapper5_Init(FC *fc, CartInfo *);
CartInterface *Mapper16_Init(FC *fc, CartInfo *);
CartInterface *Mapper18_Init(FC *fc, CartInfo *);
CartInterface *Mapper19_Init(FC *fc, CartInfo *);
CartInterface *Mapper21_Init(FC *fc, CartInfo *);
CartInterface *Mapper22_Init(FC *fc, CartInfo *);
CartInterface *Mapper23_Init(FC *fc, CartInfo *);
CartInterface *Mapper25_Init(FC *fc, CartInfo *);
CartInterface *Mapper28_Init(FC *fc, CartInfo *);
CartInterface *Mapper59_Init(FC *fc, CartInfo *);
CartInterface *Mapper83_Init(FC *fc, CartInfo *);
CartInterface *Mapper91_Init(FC *fc, CartInfo *);
CartInterface *Mapper92_Init(FC *fc, CartInfo *);
CartInterface *Mapper93_Init(FC *fc, CartInfo *);
CartInterface *Mapper95_Init(FC *fc, CartInfo *);
CartInterface *Mapper96_Init(FC *fc, CartInfo *);
CartInterface *Mapper99_Init(FC *fc, CartInfo *);
CartInterface *Mapper105_Init(FC *fc, CartInfo *);
CartInterface *Mapper125_Init(FC *fc, CartInfo *);
CartInterface *Mapper153_Init(FC *fc, CartInfo *);
CartInterface *Mapper155_Init(FC *fc, CartInfo *);
CartInterface *Mapper157_Init(FC *fc, CartInfo *);
CartInterface *Mapper170_Init(FC *fc, CartInfo *);
CartInterface *Mapper171_Init(FC *fc, CartInfo *);
CartInterface *Mapper175_Init(FC *fc, CartInfo *);
CartInterface *Mapper177_Init(FC *fc, CartInfo *);
CartInterface *Mapper178_Init(FC *fc, CartInfo *);
CartInterface *Mapper181_Init(FC *fc, CartInfo *);
CartInterface *Mapper183_Init(FC *fc, CartInfo *);
CartInterface *Mapper185_Init(FC *fc, CartInfo *);
CartInterface *Mapper186_Init(FC *fc, CartInfo *);
CartInterface *Mapper187_Init(FC *fc, CartInfo *);
CartInterface *Mapper189_Init(FC *fc, CartInfo *);
CartInterface *Mapper193_Init(FC *fc, CartInfo *);
CartInterface *Mapper199_Init(FC *fc, CartInfo *);
CartInterface *Mapper200_Init(FC *fc, CartInfo *);
CartInterface *Mapper201_Init(FC *fc, CartInfo *);
CartInterface *Mapper202_Init(FC *fc, CartInfo *);
CartInterface *Mapper204_Init(FC *fc, CartInfo *);
CartInterface *Mapper208_Init(FC *fc, CartInfo *);
CartInterface *Mapper210_Init(FC *fc, CartInfo *);
CartInterface *Mapper212_Init(FC *fc, CartInfo *);
CartInterface *Mapper213_Init(FC *fc, CartInfo *);
CartInterface *Mapper214_Init(FC *fc, CartInfo *);
CartInterface *Mapper216_Init(FC *fc, CartInfo *);
CartInterface *Mapper217_Init(FC *fc, CartInfo *);
CartInterface *Mapper220_Init(FC *fc, CartInfo *);
CartInterface *Mapper222_Init(FC *fc, CartInfo *);
CartInterface *Mapper225_Init(FC *fc, CartInfo *);
CartInterface *Mapper226_Init(FC *fc, CartInfo *);
CartInterface *Mapper227_Init(FC *fc, CartInfo *);
CartInterface *Mapper228_Init(FC *fc, CartInfo *);
CartInterface *Mapper229_Init(FC *fc, CartInfo *);
CartInterface *Mapper230_Init(FC *fc, CartInfo *);
CartInterface *Mapper231_Init(FC *fc, CartInfo *);
CartInterface *Mapper232_Init(FC *fc, CartInfo *);
CartInterface *Mapper233_Init(FC *fc, CartInfo *);
CartInterface *Mapper234_Init(FC *fc, CartInfo *);
CartInterface *Mapper235_Init(FC *fc, CartInfo *);
CartInterface *Mapper236_Init(FC *fc, CartInfo *);
CartInterface *Mapper237_Init(FC *fc, CartInfo *);
CartInterface *Mapper242_Init(FC *fc, CartInfo *);
CartInterface *Mapper244_Init(FC *fc, CartInfo *);
CartInterface *Mapper245_Init(FC *fc, CartInfo *);
CartInterface *Mapper246_Init(FC *fc, CartInfo *);
CartInterface *Mapper252_Init(FC *fc, CartInfo *);
CartInterface *Mapper253_Init(FC *fc, CartInfo *);

#endif
