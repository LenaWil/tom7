#ifndef __BOARDS_H
#define __BOARDS_H

struct CartInfo;
struct FC;
struct CartInterface;

#if 0
CartInterface *AC08_Init(FC *fc, CartInfo *info);
CartInterface *ANROM_Init(FC *fc, CartInfo *info);
CartInterface *BMC12IN1_Init(FC *fc, CartInfo *info);
CartInterface *BMC13in1JY110_Init(FC *fc, CartInfo *info);
CartInterface *BMC190in1_Init(FC *fc, CartInfo *info);
CartInterface *BMC64in1nr_Init(FC *fc, CartInfo *info);
CartInterface *BMC70in1B_Init(FC *fc, CartInfo *info);
CartInterface *BMC70in1_Init(FC *fc, CartInfo *info);
CartInterface *BMC810544CA1_Init(FC *fc, CartInfo *info);
CartInterface *BMC830118C_Init(FC *fc, CartInfo *info);
CartInterface *BMCBS5_Init(FC *fc, CartInfo *info);
CartInterface *BMCD1038_Init(FC *fc, CartInfo *info);
CartInterface *BMCFK23CA_Init(FC *fc, CartInfo *info);
CartInterface *BMCFK23C_Init(FC *fc, CartInfo *info);
CartInterface *BMCG146_Init(FC *fc, CartInfo *info);
CartInterface *BMCGK192_Init(FC *fc, CartInfo *info);
CartInterface *BMCGS2004_Init(FC *fc, CartInfo *info);
CartInterface *BMCGhostbusters63in1_Init(FC *fc, CartInfo *info);
CartInterface *BMCNTD03_Init(FC *fc, CartInfo *info);
CartInterface *BMCT2271_Init(FC *fc, CartInfo *info);
CartInterface *BMCT262_Init(FC *fc, CartInfo *info);
CartInterface *DEIROM_Init(FC *fc, CartInfo *info);
CartInterface *DreamTech01_Init(FC *fc, CartInfo *info);
CartInterface *EKROM_Init(FC *fc, CartInfo *info);
CartInterface *ELROM_Init(FC *fc, CartInfo *info);
CartInterface *ETROM_Init(FC *fc, CartInfo *info);
CartInterface *EWROM_Init(FC *fc, CartInfo *info);
CartInterface *GNROM_Init(FC *fc, CartInfo *info);
CartInterface *LE05_Init(FC *fc, CartInfo *info);
CartInterface *LH10_Init(FC *fc, CartInfo *info);
CartInterface *LH32_Init(FC *fc, CartInfo *info);
CartInterface *LH53_Init(FC *fc, CartInfo *info);
CartInterface *MALEE_Init(FC *fc, CartInfo *info);
CartInterface *Novel_Init(FC *fc, CartInfo *info);
CartInterface *S74LS374NA_Init(FC *fc, CartInfo *info);
CartInterface *S74LS374N_Init(FC *fc, CartInfo *info);
CartInterface *S8259A_Init(FC *fc, CartInfo *info);
CartInterface *S8259B_Init(FC *fc, CartInfo *info);
CartInterface *S8259C_Init(FC *fc, CartInfo *info);
CartInterface *S8259D_Init(FC *fc, CartInfo *info);
CartInterface *SA0036_Init(FC *fc, CartInfo *info);
CartInterface *SA0037_Init(FC *fc, CartInfo *info);
CartInterface *SA009_Init(FC *fc, CartInfo *info);
CartInterface *SA0161M_Init(FC *fc, CartInfo *info);
CartInterface *SA72007_Init(FC *fc, CartInfo *info);
CartInterface *SA72008_Init(FC *fc, CartInfo *info);
CartInterface *SA9602B_Init(FC *fc, CartInfo *info);
#endif

// konami-qtai
CartInterface *Mapper190_Init(FC *fc, CartInfo *info);

// 411120-c
CartInterface *BMC411120C_Init(FC *fc, CartInfo *info);

// gs-2013
CartInterface *BMCGS2013_Init(FC *fc, CartInfo *info);

// Datalatch
CartInterface *NROM_Init(FC *fc, CartInfo *info);
CartInterface *UNROM_Init(FC *fc, CartInfo *info);
CartInterface *CNROM_Init(FC *fc, CartInfo *info);
CartInterface *ANROM_Init(FC *fc, CartInfo *info);
CartInterface *CPROM_Init(FC *fc, CartInfo *info);
CartInterface *MHROM_Init(FC *fc, CartInfo *info);
CartInterface *SUNSOFT_UNROM_Init(FC *fc, CartInfo *info);
CartInterface *BMCA65AS_Init(FC *fc, CartInfo *info);
CartInterface *BMC11160_Init(FC *fc, CartInfo *info);

// MMC1
CartInterface *SAROM_Init(FC *fc, CartInfo *info);
CartInterface *SBROM_Init(FC *fc, CartInfo *info);
CartInterface *SCROM_Init(FC *fc, CartInfo *info);
CartInterface *SEROM_Init(FC *fc, CartInfo *info);
CartInterface *SGROM_Init(FC *fc, CartInfo *info);
CartInterface *SKROM_Init(FC *fc, CartInfo *info);
CartInterface *SLROM_Init(FC *fc, CartInfo *info);
CartInterface *SL1ROM_Init(FC *fc, CartInfo *info);
// SL2ROM? SFROM? SHROM?
CartInterface *SNROM_Init(FC *fc, CartInfo *info);
CartInterface *SOROM_Init(FC *fc, CartInfo *info);

// MMC3
CartInterface *TBROM_Init(FC *fc, CartInfo *info);
CartInterface *TEROM_Init(FC *fc, CartInfo *info);
CartInterface *TFROM_Init(FC *fc, CartInfo *info);
CartInterface *TGROM_Init(FC *fc, CartInfo *info);
CartInterface *TKROM_Init(FC *fc, CartInfo *info);
CartInterface *TKSROM_Init(FC *fc, CartInfo *info);
CartInterface *TLROM_Init(FC *fc, CartInfo *info);
CartInterface *TLSROM_Init(FC *fc, CartInfo *info);
CartInterface *TQROM_Init(FC *fc, CartInfo *info);
CartInterface *TSROM_Init(FC *fc, CartInfo *info);
CartInterface *HKROM_Init(FC *fc, CartInfo *info);

// 01-222
CartInterface *UNL22211_Init(FC *fc, CartInfo *info);

// h2288
CartInterface *UNLH2288_Init(FC *fc, CartInfo *info);

// 3d-block
CartInterface *UNL3DBlock_Init(FC *fc, CartInfo *info);

// kof97
CartInterface *UNLKOF97_Init(FC *fc, CartInfo *info);

// 116
CartInterface *UNLSL12_Init(FC *fc, CartInfo *info);

#if 0
CartInterface *SSSNROM_Init(FC *fc, CartInfo *info);
CartInterface *Super24_Init(FC *fc, CartInfo *info);
CartInterface *Supervision16_Init(FC *fc, CartInfo *info);
CartInterface *TCA01_Init(FC *fc, CartInfo *info);
CartInterface *TCU01_Init(FC *fc, CartInfo *info);
CartInterface *TCU02_Init(FC *fc, CartInfo *info);
CartInterface *Transformer_Init(FC *fc, CartInfo *info);
CartInterface *UNL43272_Init(FC *fc, CartInfo *info);
CartInterface *UNL6035052_Init(FC *fc, CartInfo *info);
CartInterface *UNL8157_Init(FC *fc, CartInfo *info);
CartInterface *UNL8237A_Init(FC *fc, CartInfo *info);
CartInterface *UNL8237_Init(FC *fc, CartInfo *info);
CartInterface *UNLA9746_Init(FC *fc, CartInfo *info);
CartInterface *UNLAX5705_Init(FC *fc, CartInfo *info);
CartInterface *UNLBB_Init(FC *fc, CartInfo *info);
CartInterface *UNLCC21_Init(FC *fc, CartInfo *info);
CartInterface *UNLCITYFIGHT_Init(FC *fc, CartInfo *info);
CartInterface *UNLD2000_Init(FC *fc, CartInfo *info);
CartInterface *UNLEDU2000_Init(FC *fc, CartInfo *info);
CartInterface *UNLFS304_Init(FC *fc, CartInfo *info);
CartInterface *UNLKS7012_Init(FC *fc, CartInfo *info);
CartInterface *UNLKS7013B_Init(FC *fc, CartInfo *info);
CartInterface *UNLKS7017_Init(FC *fc, CartInfo *info);
CartInterface *UNLKS7030_Init(FC *fc, CartInfo *info);
CartInterface *UNLKS7031_Init(FC *fc, CartInfo *info);
CartInterface *UNLKS7032_Init(FC *fc, CartInfo *info);
CartInterface *UNLKS7037_Init(FC *fc, CartInfo *info);
CartInterface *UNLKS7057_Init(FC *fc, CartInfo *info);
CartInterface *UNLN625092_Init(FC *fc, CartInfo *info);
CartInterface *UNLOneBus_Init(FC *fc, CartInfo *info);
CartInterface *UNLPEC586Init(FC *fc, CartInfo *info);
CartInterface *UNLSC127_Init(FC *fc, CartInfo *info);
CartInterface *UNLSHeroes_Init(FC *fc, CartInfo *info);
CartInterface *UNLSL1632_Init(FC *fc, CartInfo *info);
CartInterface *UNLSMB2J_Init(FC *fc, CartInfo *info);
CartInterface *UNLT230_Init(FC *fc, CartInfo *info);
CartInterface *UNLTF1201_Init(FC *fc, CartInfo *info);
CartInterface *UNLVRC7_Init(FC *fc, CartInfo *info);
CartInterface *UNLYOKO_Init(FC *fc, CartInfo *info);
#endif

#endif
