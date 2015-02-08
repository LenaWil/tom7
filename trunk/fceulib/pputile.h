
template<bool PPUT_MMC5SP, bool PPUT_HOOK, bool PPUT_MMC5SP>
void PPUTile() {
  uint8 *C; 
  register uint8 cc;
  uint32 vadr;

  // Was conditional on !PPUT_MMC5SP, but I assume compiler will have
  // no trouble with unused vars.
  uint8 zz;       

  // XXX delete
  // Note: This is unused with the defines that are set for me.
  // I guess PPUT_MMC5CHR1 must be true? Suppressing the warning
  // in any case. -tom7
  (void)zz;

  uint8 xs,ys;
  if (PPUT_MMC5SP) {
    xs=X1;
    ys=((scanline>>3)+MMC5HackSPScroll)&0x1F;
    if(ys>=0x1E) ys-=0x1E;
  }
	
  if(X1>=2) {
    uint8 *S=PALRAM;
    uint32 pixdata;

    pixdata = ppulut1[(pshift[0]>>(8-XOffset))&0xFF] | 
              ppulut2[(pshift[1]>>(8-XOffset))&0xFF];

    pixdata |= ppulut3[XOffset|(atlatch<<3)];
    // printf("%02x ",ppulut3[XOffset|(atlatch<<3)]);

    P[0]=S[pixdata&0xF];
    pixdata>>=4;
    P[1]=S[pixdata&0xF];
    pixdata>>=4;
    P[2]=S[pixdata&0xF];
    pixdata>>=4;
    P[3]=S[pixdata&0xF];
    pixdata>>=4;
    P[4]=S[pixdata&0xF];
    pixdata>>=4;
    P[5]=S[pixdata&0xF];
    pixdata>>=4;
    P[6]=S[pixdata&0xF];
    pixdata>>=4;
    P[7]=S[pixdata&0xF];
    P+=8;
  }

  if (PPUT_MMC5SP) {
    vadr = (MMC5HackExNTARAMPtr[xs|(ys<<5)]<<4)+(vofs&7);
  } else {
    zz = refreshaddr_local&0x1F;
    C = vnapage[(refreshaddr_local>>10)&3];
    /* Fetch name table byte. */
    vadr = (C[refreshaddr_local&0x3ff]<<4)+vofs;
  }

  if (PPUT_HOOK) {
    PPU_hook(0x2000|(refreshaddr_local&0xfff));
  }

  if (PPUT_MMC5SP) {
    cc=MMC5HackExNTARAMPtr[0x3c0+(xs>>2)+((ys&0x1C)<<1)];
    cc=((cc >> ((xs&2) + ((ys&0x2)<<1))) &3);
  } else {
    if (PPUT_MMC5CHR1) {
      cc=(MMC5HackExNTARAMPtr[refreshaddr_local & 0x3ff] & 0xC0)>>6;
    } else {
      cc=C[0x3c0+(zz>>2)+((refreshaddr_local&0x380)>>4)];  /* Fetch attribute table byte. */
      cc=((cc >> ((zz&2) + ((refreshaddr_local&0x40)>>4))) &3);
    }
  }

atlatch>>=2;
atlatch|=cc<<2;  
       
pshift[0]<<=8;
pshift[1]<<=8;

#ifdef PPUT_MMC5SP
	C = MMC5HackVROMPTR+vadr;
	C += ((MMC5HackSPPage & 0x3f & MMC5HackVROMMask) << 12);
#else
	#ifdef PPUT_MMC5CHR1
		C = MMC5HackVROMPTR;
		C += (((MMC5HackExNTARAMPtr[refreshaddr_local & 0x3ff]) & 0x3f & 
			MMC5HackVROMMask) << 12) + (vadr & 0xfff);
		C += (MMC50x5130&0x3)<<18; //11-jun-2009 for kuja_killer
	#elif defined(PPUT_MMC5)
		C=MMC5BGVRAMADR(vadr);
	#else
		C = VRAMADR(vadr);
	#endif
#endif

#ifdef PPUT_HOOK
	PPU_hook(vadr);
#endif

pshift[0]|=C[0];
pshift[1]|=C[8];

if((refreshaddr_local&0x1f)==0x1f)
	refreshaddr_local^=0x41F;
else
	refreshaddr_local++;

#ifdef PPUT_HOOK
	PPU_hook(0x2000|(refreshaddr_local&0xfff));
#endif

