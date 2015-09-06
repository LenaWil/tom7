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
  // This is now MapInterface::StateRestore
  // void (*MapStateRestore)(int version) = nullptr;
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

// I think that this gross stuff is because the old style mappers
// (_init in mappers/*) get some flat data block to work with,
// which is saved and copied for them, and they work by indexing
// into its parts with macros. I made them take an FC object and
// prefixed them all with GMB_.

/* This order is necessary */
#define GMB_WRAM(fc)    ((fc)->fceu->GameMemBlock)
#define sizeofWRAM    8192

#define GMB_MapperExRAM(fc)   ((fc)->fceu->GameMemBlock + sizeofWRAM)
#define sizeofMapperExRAM  32768
/* for the MMC5 code to work properly.  It might be fixed later... */

#define GMB_CHRRAM(fc)  ((fc)->fceu->GameMemBlock+sizeofWRAM+sizeofMapperExRAM)
#define sizeofCHRRAM 8192

#define GMB_ExtraNTARAM(fc)   ((fc)->fceu->GameMemBlock+sizeofWRAM+sizeofMapperExRAM+sizeofCHRRAM)
#define sizeofExtraNTARAM 2048

#define GMB_PRGBankList(fc)    (GMB_ExtraNTARAM(fc) + sizeofExtraNTARAM)

#define GMB_mapbyte1(fc)       (GMB_PRGBankList(fc) + 4)
#define GMB_mapbyte2(fc)       (GMB_mapbyte1(fc) + 8)
#define GMB_mapbyte3(fc)       (GMB_mapbyte2(fc) + 8)
#define GMB_mapbyte4(fc)       (GMB_mapbyte3(fc) + 8)

#endif  // INESPRIV

// TODO: Maybe should be members of INes.
void VRAM_BANK1(FC *fc, uint32 A, uint8 V);
void VRAM_BANK4(FC *fc, uint32 A, uint32 V);

void VROM_BANK1(FC *fc, uint32 A, uint32 V);
void VROM_BANK2(FC *fc, uint32 A, uint32 V);
void VROM_BANK4(FC *fc, uint32 A, uint32 V);
void VROM_BANK8(FC *fc, uint32 V);
void ROM_BANK8(FC *fc, uint32 A, uint32 V);
void ROM_BANK16(FC *fc, uint32 A, uint32 V);
void ROM_BANK32(FC *fc, uint32 V);

// This list is pretty weird, I guess part of some transition
// to the capital-i Init methods. Many of these are not even
// defined anywhere. If there's a space after // then I was
// the one who commented it out -tom7.


// MapInterface *Mapper0_init(FC *fc);
// MapInterface *Mapper1_init(FC *fc);
//MapInterface *Mapper2_init(FC *fc);
//MapInterface *Mapper3_init(FC *fc);
MapInterface *Mapper6_init(FC *fc);
//MapInterface *Mapper7_init(FC *fc);
//MapInterface *Mapper8_init(FC *fc);
MapInterface *Mapper9_init(FC *fc);
MapInterface *Mapper10_init(FC *fc);
//MapInterface *Mapper11_init(FC *fc);
MapInterface *Mapper12_init(FC *fc);
//MapInterface *Mapper13_init(FC *fc);
MapInterface *Mapper14_init(FC *fc);
//MapInterface *Mapper15_init(FC *fc);
//MapInterface *Mapper16_init(FC *fc);
//MapInterface *Mapper17_init(FC *fc);
//MapInterface *Mapper18_init(FC *fc);
MapInterface *Mapper19_init(FC *fc);
MapInterface *Mapper20_init(FC *fc);
//MapInterface *Mapper21_init(FC *fc);
//MapInterface *Mapper22_init(FC *fc);
//MapInterface *Mapper23_init(FC *fc);
MapInterface *Mapper24_init(FC *fc);
//MapInterface *Mapper25_init(FC *fc);
MapInterface *Mapper26_init(FC *fc);
//MapInterface *Mapper27_init(FC *fc);
MapInterface *Mapper28_init(FC *fc);
// MapInterface *Mapper29_init(FC *fc);
// MapInterface *Mapper30_init(FC *fc);
// MapInterface *Mapper31_init(FC *fc);
//MapInterface *Mapper32_init(FC *fc);
//MapInterface *Mapper33_init(FC *fc);
//MapInterface *Mapper34_init(FC *fc);
// MapInterface *Mapper35_init(FC *fc);
// MapInterface *Mapper36_init(FC *fc);
//MapInterface *Mapper37_init(FC *fc);
//MapInterface *Mapper38_init(FC *fc);
//MapInterface *Mapper39_init(FC *fc);
MapInterface *Mapper40_init(FC *fc);
MapInterface *Mapper41_init(FC *fc);
MapInterface *Mapper42_init(FC *fc);
//MapInterface *Mapper43_init(FC *fc);
MapInterface *Mapper44_init(FC *fc);
MapInterface *Mapper45_init(FC *fc);
MapInterface *Mapper46_init(FC *fc);
MapInterface *Mapper47_init(FC *fc);
//MapInterface *Mapper48_init(FC *fc);
MapInterface *Mapper49_init(FC *fc);
MapInterface *Mapper50_init(FC *fc);
MapInterface *Mapper51_init(FC *fc);
MapInterface *Mapper53_init(FC *fc);
MapInterface *Mapper54_init(FC *fc);
MapInterface *Mapper55_init(FC *fc);
MapInterface *Mapper56_init(FC *fc);
//MapInterface *Mapper59_init(FC *fc);
MapInterface *Mapper60_init(FC *fc);
MapInterface *Mapper61_init(FC *fc);
MapInterface *Mapper62_init(FC *fc);
MapInterface *Mapper63_init(FC *fc);
MapInterface *Mapper64_init(FC *fc);
MapInterface *Mapper65_init(FC *fc);
//MapInterface *Mapper66_init(FC *fc);
MapInterface *Mapper67_init(FC *fc);
//MapInterface *Mapper68_init(FC *fc);
MapInterface *Mapper69_init(FC *fc);
//MapInterface *Mapper70_init(FC *fc);
MapInterface *Mapper71_init(FC *fc);
MapInterface *Mapper72_init(FC *fc);
MapInterface *Mapper73_init(FC *fc);
MapInterface *Mapper74_init(FC *fc);
MapInterface *Mapper75_init(FC *fc);
MapInterface *Mapper76_init(FC *fc);
MapInterface *Mapper77_init(FC *fc);
//MapInterface *Mapper78_init(FC *fc);
MapInterface *Mapper79_init(FC *fc);
MapInterface *Mapper80_init(FC *fc);
MapInterface *Mapper81_init(FC *fc);
//MapInterface *Mapper82_init(FC *fc);
MapInterface *Mapper83_init(FC *fc);
MapInterface *Mapper84_init(FC *fc);
MapInterface *Mapper85_init(FC *fc);
//MapInterface *Mapper86_init(FC *fc);
//MapInterface *Mapper87_init(FC *fc);
MapInterface *Mapper88_init(FC *fc);
//MapInterface *Mapper89_init(FC *fc);
//MapInterface *Mapper91_init(FC *fc);
//MapInterface *Mapper92_init(FC *fc);
//MapInterface *Mapper93_init(FC *fc);
//MapInterface *Mapper94_init(FC *fc);
//MapInterface *Mapper96_init(FC *fc);
//MapInterface *Mapper97_init(FC *fc);
MapInterface *Mapper98_init(FC *fc);
//MapInterface *Mapper99_init(FC *fc);
MapInterface *Mapper100_init(FC *fc);
//MapInterface *Mapper101_init(FC *fc);
//MapInterface *Mapper103_init(FC *fc);
MapInterface *Mapper104_init(FC *fc);
//MapInterface *Mapper106_init(FC *fc);
//MapInterface *Mapper107_init(FC *fc);
//MapInterface *Mapper108_init(FC *fc);
MapInterface *Mapper109_init(FC *fc);
MapInterface *Mapper110_init(FC *fc);
//MapInterface *Mapper111_init(FC *fc);
//MapInterface *Mapper113_init(FC *fc);
MapInterface *Mapper115_init(FC *fc);
//MapInterface *Mapper116_init(FC *fc);
//MapInterface *Mapper117_init(FC *fc);
//MapInterface *Mapper120_init(FC *fc);
//MapInterface *Mapper121_init(FC *fc);
MapInterface *Mapper122_init(FC *fc);
MapInterface *Mapper123_init(FC *fc);
MapInterface *Mapper124_init(FC *fc);
MapInterface *Mapper126_init(FC *fc);
MapInterface *Mapper127_init(FC *fc);
MapInterface *Mapper128_init(FC *fc);
MapInterface *Mapper129_init(FC *fc);
MapInterface *Mapper130_init(FC *fc);
MapInterface *Mapper131_init(FC *fc);
MapInterface *Mapper132_init(FC *fc);
//MapInterface *Mapper134_init(FC *fc);
MapInterface *Mapper135_init(FC *fc);
MapInterface *Mapper136_init(FC *fc);
MapInterface *Mapper137_init(FC *fc);
MapInterface *Mapper139_init(FC *fc);
//MapInterface *Mapper140_init(FC *fc);
MapInterface *Mapper141_init(FC *fc);
//MapInterface *Mapper142_init(FC *fc);
MapInterface *Mapper143_init(FC *fc);
//MapInterface *Mapper144_init(FC *fc);
MapInterface *Mapper150_init(FC *fc);
//MapInterface *Mapper151_init(FC *fc);
//MapInterface *Mapper152_init(FC *fc);
//MapInterface *Mapper153_init(FC *fc);
MapInterface *Mapper154_init(FC *fc);
//MapInterface *Mapper156_init(FC *fc);
//MapInterface *Mapper157_init(FC *fc);
//MapInterface *Mapper158_init(FC *fc);
//MapInterface *Mapper159_init(FC *fc);
MapInterface *Mapper160_init(FC *fc);
MapInterface *Mapper161_init(FC *fc);
MapInterface *Mapper162_init(FC *fc);
// subor.cc
MapInterface *Mapper166_init(FC *fc);
MapInterface *Mapper167_init(FC *fc);
MapInterface *Mapper168_init(FC *fc);
//MapInterface *Mapper169_init(FC *fc);
MapInterface *Mapper170_init(FC *fc);
//MapInterface *Mapper171_init(FC *fc);
//MapInterface *Mapper172_init(FC *fc);
//MapInterface *Mapper173_init(FC *fc);
MapInterface *Mapper174_init(FC *fc);
MapInterface *Mapper175_init(FC *fc);
MapInterface *Mapper176_init(FC *fc);
//MapInterface *Mapper177_init(FC *fc);
//MapInterface *Mapper178_init(FC *fc);
//MapInterface *Mapper179_init(FC *fc);
MapInterface *Mapper180_init(FC *fc);
//MapInterface *Mapper181_init(FC *fc);
//MapInterface *Mapper184_init(FC *fc);
//MapInterface *Mapper185_init(FC *fc);
//MapInterface *Mapper189_init(FC *fc);
//MapInterface *Mapper192_init(FC *fc);
//MapInterface *Mapper193_init(FC *fc);
//MapInterface *Mapper194_init(FC *fc);
//MapInterface *Mapper195_init(FC *fc);
//MapInterface *Mapper196_init(FC *fc);
//MapInterface *Mapper197_init(FC *fc);
//MapInterface *Mapper198_init(FC *fc);
MapInterface *Mapper199_init(FC *fc);
//MapInterface *Mapper200_init(FC *fc);
//MapInterface *Mapper201_init(FC *fc);
//MapInterface *Mapper202_init(FC *fc);
//MapInterface *Mapper203_init(FC *fc);
//MapInterface *Mapper204_init(FC *fc);
MapInterface *Mapper207_init(FC *fc);
//MapInterface *Mapper211_init(FC *fc);
//MapInterface *Mapper212_init(FC *fc);
//MapInterface *Mapper213_init(FC *fc);
//MapInterface *Mapper214_init(FC *fc);
//MapInterface *Mapper218_init(FC *fc);
MapInterface *Mapper219_init(FC *fc);
//MapInterface *Mapper220_init(FC *fc);
MapInterface *Mapper221_init(FC *fc);
//MapInterface *Mapper222_init(FC *fc);
MapInterface *Mapper223_init(FC *fc);
MapInterface *Mapper224_init(FC *fc);
//MapInterface *Mapper225_init(FC *fc);
//MapInterface *Mapper226_init(FC *fc);
//MapInterface *Mapper227_init(FC *fc);
//MapInterface *Mapper228_init(FC *fc);
//MapInterface *Mapper229_init(FC *fc);
//MapInterface *Mapper230_init(FC *fc);
//MapInterface *Mapper231_init(FC *fc);
//MapInterface *Mapper232_init(FC *fc);
//MapInterface *Mapper233_init(FC *fc);
//MapInterface *Mapper234_init(FC *fc);
//MapInterface *Mapper235_init(FC *fc);
MapInterface *Mapper236_init(FC *fc);
MapInterface *Mapper237_init(FC *fc);
MapInterface *Mapper238_init(FC *fc);
MapInterface *Mapper239_init(FC *fc);
MapInterface *Mapper240_init(FC *fc);
//MapInterface *Mapper241_init(FC *fc);
//MapInterface *Mapper242_init(FC *fc);
//MapInterface *Mapper244_init(FC *fc);
MapInterface *Mapper245_init(FC *fc);
//MapInterface *Mapper246_init(FC *fc);
MapInterface *Mapper247_init(FC *fc);
MapInterface *Mapper249_init(FC *fc);
MapInterface *Mapper251_init(FC *fc);
//MapInterface *Mapper252_init(FC *fc);
//MapInterface *Mapper253_init(FC *fc);
//MapInterface *Mapper255_init(FC *fc);

// Probably can kill NSF code? -tom7
// void NSFMMC5_Init();
// void NSFAY_Init();
// // n106
// void NSFN106_Init(FC *fc, CartInfo *info);
// void Mapper19_ESI(); // (now private -tom7)

// void NSFVRC7_Init();

// The new mappers.

// mmc1
CartInterface *Mapper171_Init(FC *fc, CartInfo *info);
CartInterface *Mapper155_Init(FC *fc, CartInfo *info);
CartInterface *Mapper105_Init(FC *fc, CartInfo *info);
CartInterface *Mapper1_Init(FC *fc, CartInfo *info);

// datalatch
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

// mmc3
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
CartInterface *Mapper245_Init(FC *fc, CartInfo *);
CartInterface *Mapper249_Init(FC *fc, CartInfo *);
CartInterface *Mapper250_Init(FC *fc, CartInfo *);
CartInterface *Mapper254_Init(FC *fc, CartInfo *);

// mmc5
CartInterface *Mapper5_Init(FC *fc, CartInfo *);

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

// 95
CartInterface *Mapper95_Init(FC *fc, CartInfo *);

// 17
CartInterface *Mapper17_Init(FC *fc, CartInfo *);

// 170
CartInterface *Mapper170_Init(FC *fc, CartInfo *);

// 175
CartInterface *Mapper175_Init(FC *fc, CartInfo *);

// 96
CartInterface *Mapper96_Init(FC *fc, CartInfo *);

// 176 - dead?
CartInterface *Mapper176_Init(FC *fc, CartInfo *);

// 99
CartInterface *Mapper99_Init(FC *fc, CartInfo *);

// 177
CartInterface *Mapper177_Init(FC *fc, CartInfo *);

// 178
CartInterface *Mapper178_Init(FC *fc, CartInfo *);

// 18
CartInterface *Mapper18_Init(FC *fc, CartInfo *);

// addrlatch
CartInterface *Mapper59_Init(FC *fc, CartInfo *);
CartInterface *Mapper92_Init(FC *fc, CartInfo *);
CartInterface *Mapper200_Init(FC *fc, CartInfo *);
CartInterface *Mapper201_Init(FC *fc, CartInfo *);
CartInterface *Mapper202_Init(FC *fc, CartInfo *);
CartInterface *Mapper204_Init(FC *fc, CartInfo *);
CartInterface *Mapper212_Init(FC *fc, CartInfo *);
CartInterface *Mapper213_Init(FC *fc, CartInfo *);
CartInterface *Mapper214_Init(FC *fc, CartInfo *);
CartInterface *Mapper227_Init(FC *fc, CartInfo *);
CartInterface *Mapper229_Init(FC *fc, CartInfo *);
CartInterface *Mapper231_Init(FC *fc, CartInfo *);
CartInterface *Mapper217_Init(FC *fc, CartInfo *);
CartInterface *Mapper242_Init(FC *fc, CartInfo *);

// 185
CartInterface *Mapper181_Init(FC *fc, CartInfo *);
CartInterface *Mapper185_Init(FC *fc, CartInfo *);

// 186
CartInterface *Mapper186_Init(FC *fc, CartInfo *);

// 187
CartInterface *Mapper187_Init(FC *fc, CartInfo *);

// 193
CartInterface *Mapper193_Init(FC *fc, CartInfo *);

// bmc42in1r
CartInterface *Mapper226_Init(FC *fc, CartInfo *);
CartInterface *Mapper233_Init(FC *fc, CartInfo *);

// 208
CartInterface *Mapper208_Init(FC *fc, CartInfo *);

// 222
CartInterface *Mapper222_Init(FC *fc, CartInfo *);

// bonza
CartInterface *Mapper216_Init(FC *fc, CartInfo *);

// 225
CartInterface *Mapper225_Init(FC *fc, CartInfo *);

// 228
CartInterface *Mapper228_Init(FC *fc, CartInfo *);

// 230
CartInterface *Mapper230_Init(FC *fc, CartInfo *);

// n106
CartInterface *Mapper19_Init(FC *fc, CartInfo *);
CartInterface *Mapper210_Init(FC *fc, CartInfo *);

// 232
CartInterface *Mapper232_Init(FC *fc, CartInfo *);

// 234
CartInterface *Mapper234_Init(FC *fc, CartInfo *);

// 235
CartInterface *Mapper235_Init(FC *fc, CartInfo *);

// 244
CartInterface *Mapper244_Init(FC *fc, CartInfo *);

// bandai
CartInterface *Mapper16_Init(FC *fc, CartInfo *);
CartInterface *Mapper153_Init(FC *fc, CartInfo *);
CartInterface *Mapper157_Init(FC *fc, CartInfo *);

// 246
CartInterface *Mapper246_Init(FC *fc, CartInfo *);

// 252
CartInterface *Mapper252_Init(FC *fc, CartInfo *);

// vrc2and4
CartInterface *Mapper21_Init(FC *fc, CartInfo *);
CartInterface *Mapper22_Init(FC *fc, CartInfo *);
CartInterface *Mapper23_Init(FC *fc, CartInfo *);
CartInterface *Mapper25_Init(FC *fc, CartInfo *);

// 253
CartInterface *Mapper253_Init(FC *fc, CartInfo *);

// 28
CartInterface *Mapper28_Init(FC *fc, CartInfo *);

// yoko
CartInterface *Mapper83_Init(FC *fc, CartInfo *);

// 91
CartInterface *Mapper91_Init(FC *fc, CartInfo *);

// 183
CartInterface *Mapper183_Init(FC *fc, CartInfo *);

// 189
CartInterface *Mapper189_Init(FC *fc, CartInfo *);

// 199
CartInterface *Mapper199_Init(FC *fc, CartInfo *);

// ? nonexistent? -tom7

// CartInterface *Mapper93_Init(FC *fc, CartInfo *);
// CartInterface *Mapper125_Init(FC *fc, CartInfo *);
// CartInterface *Mapper220_Init(FC *fc, CartInfo *);
// CartInterface *Mapper236_Init(FC *fc, CartInfo *);
// CartInterface *Mapper237_Init(FC *fc, CartInfo *);

#endif
