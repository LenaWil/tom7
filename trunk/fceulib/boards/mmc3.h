
#ifndef __MMC3_H
#define __MMC3_H

#include "cart.h"

struct MMC3 : public CartInterface {

  uint8 MMC3_cmd = 0;
  uint8 mmc3opts = 0;
  uint8 A000B = 0;
  uint8 A001B = 0;
  uint8 DRegBuf[8] = {};

  static void MMC3_CMDWrite(DECLFW_ARGS);
  static void MMC3_IRQWrite(DECLFW_ARGS);

  virtual void PWrap(uint32 A, uint8 V);
  virtual void CWrap(uint32 A, uint8 V);
  virtual void MWrap(uint8 V);

  void Close() override;
  void Reset() override;
  void Power() override;

  MMC3(FC *fc, CartInfo *info, int prg, int chr, int wram, int battery);
  // was:
  // void GenMMC3_Init(CartInfo *info, int prg, int chr, int wram, int battery);

 protected:
  void FixMMC3PRG(int V);
  void FixMMC3CHR(int V);

  DECLFW_RET MMC3_CMDWrite_Direct(DECLFW_ARGS);
  DECLFW_RET MMC3_IRQWrite_Direct(DECLFW_ARGS);
  
  int isRevB = 1;
  
  uint8 *MMC3_WRAM = nullptr;

private:
  vector<SFORMAT> MMC3_StateRegs;

  DECLFW_RET MBWRAMMMC6(DECLFW_ARGS);
  DECLFR_RET MAWRAMMMC6(DECLFR_ARGS);

  void GenMMC3Restore(FC *fc, int version);
  
  void ClockMMC3Counter();
  
  uint8 *CHRRAM = nullptr;
  uint32 CHRRAMSize = 0;

  uint8 irq_count = 0, irq_latch = 0, irq_a = 0;
  uint8 irq_reload = 0;

  int wrams = 0;
};

#endif
