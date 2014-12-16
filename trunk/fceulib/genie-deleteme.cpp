static DECLFR(GenieRead)
{
	return GENIEROM[A&4095];
}

static DECLFW(GenieWrite)
{
	switch(A)
	{
	case 0x800c:
	case 0x8008:
	case 0x8004:genieval[((A-4)&0xF)>>2]=V;break;

	case 0x800b:
	case 0x8007:
	case 0x8003:geniech[((A-3)&0xF)>>2]=V;break;

	case 0x800a:
	case 0x8006:
	case 0x8002:genieaddr[((A-2)&0xF)>>2]&=0xFF00;genieaddr[((A-2)&0xF)>>2]|=V;break;

	case 0x8009:
	case 0x8005:
	case 0x8001:genieaddr[((A-1)&0xF)>>2]&=0xFF;genieaddr[((A-1)&0xF)>>2]|=(V|0x80)<<8;break;

	case 0x8000:if(!V)
					FixGenieMap();
				else
				{
					modcon=V^0xFF;
					if(V==0x71)
						modcon=0;
				}
				break;
	}
}

static readfunc GenieBackup[3];

static DECLFR(GenieFix1)
{
	uint8 r=GenieBackup[0](A);

	if((modcon>>1)&1)    // No check
		return genieval[0];
	else if(r==geniech[0])
		return genieval[0];

	return r;
}

static DECLFR(GenieFix2)
{
	uint8 r=GenieBackup[1](A);

	if((modcon>>2)&1)        // No check
		return genieval[1];
	else if(r==geniech[1])
		return genieval[1];

	return r;
}

static DECLFR(GenieFix3)
{
	uint8 r=GenieBackup[2](A);

	if((modcon>>3)&1)        // No check
		return genieval[2];
	else if(r==geniech[2])
		return genieval[2];

	return r;
}


void FixGenieMap(void)
{
	int x;

	geniestage=2;

	for(x=0;x<8;x++)
		VPage[x]=VPageG[x];

	VPageR=VPage;
	FlushGenieRW();
	//printf("Rightyo\n");
	for(x=0;x<3;x++)
		if((modcon>>(4+x))&1)
		{
			readfunc tmp[3]={GenieFix1,GenieFix2,GenieFix3};
			GenieBackup[x]=GetReadHandler(genieaddr[x]);
			SetReadHandler(genieaddr[x],genieaddr[x],tmp[x]);
		}
}


