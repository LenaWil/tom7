#ifndef __FDS_H
#define __FDS_H

// for GI enum.
#include "fceu.h"
#include "fc.h"

struct FceuFile;

// This is the Famicom Disk System, a fairly exotic but awesome
// expansion for the Famicom.
//
// https://en.wikipedia.org/wiki/Family_Computer_Disk_System

struct FDS {
  explicit FDS(FC *fc);

  void FCEU_FDSInsert();
  void FCEU_FDSSelect();

  int FDSLoad(const char *name, FceuFile *fp);

  void FDSRAMWrite_Direct(DECLFW_ARGS);
  void FDSSWrite_Direct(DECLFW_ARGS);
  void FDSWrite_Direct(DECLFW_ARGS);
  void FDSWaveWrite_Direct(DECLFW_ARGS);

  DECLFR_RET FDSRead4013_Direct(DECLFR_ARGS);
  DECLFR_RET FDSRead4032_Direct(DECLFR_ARGS);
  DECLFR_RET FDSBIOSRead_Direct(DECLFR_ARGS);
  DECLFR_RET FDSRAMRead_Direct(DECLFR_ARGS);
  DECLFR_RET FDSSRead_Direct(DECLFR_ARGS);
  DECLFR_RET FDSWaveRead_Direct(DECLFR_ARGS);

 private:
  uint8 FDSRegs[6] = {0};
  int32 IRQLatch = 0, IRQCount = 0;
  uint8 IRQa = 0;
  
  void HQSync(int32 ts);
    
  void FDSInit();
  void FDSClose();
  void FDSSound(int);
  void FDSSoundReset();
  void FDSSoundStateAdd();
  void FDS_ESI();
  void RenderSound();
  void RenderSoundHQ();

  void FDSFix(int a);
  void FDSStateRestore(int version);
  void FDSGI(GI h);
  
  int32 FDSDoSound();
  void ClockRise();
  void ClockFall();
  void FreeFDSMemory();
  int SubLoad(FceuFile *fp);
  void PreSave();
  void PostSave();
  void DoEnv();
  // XXX not saved? moved from within DoEnv.
  int counto[2] = {0, 0};

  uint8 FDSBIOS[8192] = {0};

  /* Original disk data backup, to help in creating save states. */
  uint8 *diskdatao[8] = {0,0,0,0,0,0,0,0};

  uint8 *diskdata[8] = {0,0,0,0,0,0,0,0};

  int TotalSides = 0; //mbg merge 7/17/06 - unsignedectomy
  uint8 DiskWritten = 0;    /* Set to 1 if disk was written to. */
  uint8 writeskip = 0;
  int32 DiskPtr = 0;
  int32 DiskSeekIRQ = 0;
  uint8 SelectDisk = 0, InDisk = 0;

  int32 FBC = 0;

  struct FdsSound {
    int64 cycles = 0;     // Cycles per PCM sample
    int64 count = 0;    // Cycle counter
    int64 envcount = 0;    // Envelope cycle counter
    uint32 b19shiftreg60 = 0;
    uint32 b24adder66 = 0;
    uint32 b24latch68 = 0;
    uint32 b17latch76 = 0;
    int32 clockcount = 0;  // Counter to divide frequency by 8.
    uint8 b8shiftreg88 = 0;  // Modulation register.
    uint8 amplitude[2] = {0} ;  // Current amplitudes.
    uint8 speedo[2] = {0};
    uint8 mwcount = 0;
    uint8 mwstart = 0;
    uint8 mwave[0x20] = {0};      // Modulation waveform
    uint8 cwave[0x40] = {0};      // Game-defined waveform(carrier)
    uint8 SPSG[0xB] = {0};
  };

  FdsSound fdso;
  // TODO: Not saved?
  int ta = 0;
  // TODO: Not saved?
  uint8 fdsread4013_z = 0;

  FC *fc = nullptr;
};

#endif
