/// \file
/// \brief Implements core debugging facilities

#include <stdlib.h>
#include <string.h>

#include "types.h"
#include "x6502.h"
#include "fceu.h"
#include "cart.h"
#include "ines.h"
#include "debug.h"
#include "driver.h"
#include "ppu.h"

#include "x6502abbrev.h"


//watchpoint stuffs
#define WP_E       0x01  //watchpoint, enable
#define WP_W       0x02  //watchpoint, write
#define WP_R       0x04  //watchpoint, read
#define WP_X       0x08  //watchpoint, execute
#define WP_F       0x10  //watchpoint, forbid

#define BT_C       0x00  //break type, cpu mem
#define BT_P       0x20  //break type, ppu mem
#define BT_S       0x40  //break type, sprite mem

#define BREAK_TYPE_STEP -1
#define BREAK_TYPE_BADOP -2
#define BREAK_TYPE_CYCLES_EXCEED -3
#define BREAK_TYPE_INSTRUCTIONS_EXCEED -4

#define TYPE_NO 0
#define TYPE_REG 1
#define TYPE_FLAG 2
#define TYPE_NUM 3
#define TYPE_ADDR 4
#define TYPE_BANK 5

#define OP_NO 0
#define OP_EQ 1
#define OP_NE 2
#define OP_GE 3
#define OP_LE 4
#define OP_G 5
#define OP_L 6
#define OP_PLUS 7
#define OP_MINUS 8
#define OP_MULT 9
#define OP_DIV 10
#define OP_OR 11
#define OP_AND 12

extern uint8 *vnapage[4],*VPage[8];
extern uint8 PPU[4],PALRAM[0x20],SPRAM[0x100],VRAMBuffer,PPUGenLatch,XOffset;
extern uint32 RefreshAddr;

extern int numWPs;

//mbg merge 7/18/06 turned into sane c++
struct Condition
{
	Condition* lhs;
	Condition* rhs;

	unsigned int type1;
	unsigned int value1;

	unsigned int op;

	unsigned int type2;
	unsigned int value2;
};

struct watchpointinfo {
	uint16 address;
	uint16 endaddress;
	uint8 flags;
	Condition* cond;
	char* condText;
	char* desc;
};

///encapsulates the operational state of the debugger core
class DebuggerState {
public:
	///indicates whether the debugger is stepping through a single instruction
	bool step;
	///indicates whether the debugger is stepping out of a function call
	bool stepout;
	///indicates whether the debugger is running one line
	bool runline;
	///target timestamp for runline to stop at
	uint64 runline_end_time;
	///indicates whether the debugger should break on bad opcodes
	bool badopbreak;
	///counts the nest level of the call stack while stepping out
	int jsrcount;

	///resets the debugger state to an empty, non-debugging state
	void reset() {
		numWPs = 0;
		step = false;
		stepout = false;
		jsrcount = 0;
	}
};

int vblankScanLines = 0;	//Used to calculate scanlines 240-261 (vblank)
int vblankPixel = 0;		//Used to calculate the pixels in vblank

//opbrktype is used to grab the breakpoint type that each instruction will cause.
//WP_X is not used because ALL opcodes will have the execute bit set.
static const uint8 opbrktype[256] = {
	      /*0,    1, 2, 3,    4,    5,         6, 7, 8,    9, A, B,    C,    D,         E, F*/
/*0x00*/	0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0, 0,    0, 0, 0,    0, WP_R, WP_R|WP_W, 0,
/*0x10*/	0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0, 0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0,
/*0x20*/	0, WP_R, 0, 0, WP_R, WP_R, WP_R|WP_W, 0, 0,    0, 0, 0, WP_R, WP_R, WP_R|WP_W, 0,
/*0x30*/	0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0, 0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0,
/*0x40*/	0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0, 0,    0, 0, 0,    0, WP_R, WP_R|WP_W, 0,
/*0x50*/	0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0, 0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0,
/*0x60*/	0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0, 0,    0, 0, 0, WP_R, WP_R, WP_R|WP_W, 0,
/*0x70*/	0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0, 0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0,
/*0x80*/	0, WP_W, 0, 0, WP_W, WP_W,      WP_W, 0, 0,    0, 0, 0, WP_W, WP_W,      WP_W, 0,
/*0x90*/	0, WP_W, 0, 0, WP_W, WP_W,      WP_W, 0, 0, WP_W, 0, 0,    0, WP_W,         0, 0,
/*0xA0*/	0, WP_R, 0, 0, WP_R, WP_R,      WP_R, 0, 0,    0, 0, 0, WP_R, WP_R,      WP_R, 0,
/*0xB0*/	0, WP_R, 0, 0, WP_R, WP_R,      WP_R, 0, 0, WP_R, 0, 0, WP_R, WP_R,      WP_R, 0,
/*0xC0*/	0, WP_R, 0, 0, WP_R, WP_R, WP_R|WP_W, 0, 0,    0, 0, 0, WP_R, WP_R, WP_R|WP_W, 0,
/*0xD0*/	0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0, 0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0,
/*0xE0*/	0, WP_R, 0, 0, WP_R, WP_R, WP_R|WP_W, 0, 0,    0, 0, 0, WP_R, WP_R, WP_R|WP_W, 0,
/*0xF0*/	0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0, 0, WP_R, 0, 0,    0, WP_R, WP_R|WP_W, 0
};

// Returns the value of a given type or register

int getValue(int type)
{
	switch (type)
	{
		case 'A': return _A;
		case 'X': return _X;
		case 'Y': return _Y;
		case 'N': return _P & N_FLAG ? 1 : 0;
		case 'V': return _P & V_FLAG ? 1 : 0;
		case 'U': return _P & U_FLAG ? 1 : 0;
		case 'B': return _P & B_FLAG ? 1 : 0;
		case 'D': return _P & D_FLAG ? 1 : 0;
		case 'I': return _P & I_FLAG ? 1 : 0;
		case 'Z': return _P & Z_FLAG ? 1 : 0;
		case 'C': return _P & C_FLAG ? 1 : 0;
		case 'P': return _PC;
	}

	return 0;
}

int GetPRGAddress(int A){
	int result;
	if((A < 0x8000) || (A > 0xFFFF))return -1;
	result = &Page[A>>11][A]-PRGptr[0];
	if((result > (int)PRGsize[0]) || (result < 0))return -1;
	else return result;
}

static int GetNesFileAddress(int A){
	int result;
	if((A < 0x8000) || (A > 0xFFFF))return -1;
	result = &Page[A>>11][A]-PRGptr[0];
	if((result > (int)(PRGsize[0])) || (result < 0))return -1;
	else return result+16; //16 bytes for the header remember
}

/**
* Returns the bank for a given offset.
* Technically speaking this function does not calculate the actual bank
* where the offset resides but the 0x4000 bytes large chunk of the ROM of the offset.
*
* @param offs The offset
* @return The bank of that offset or -1 if the offset is not part of the ROM.
**/
static int getBank(int offs)
{
	//NSF data is easy to overflow the return on.
	//Anything over FFFFF will kill it.

	//GetNesFileAddress doesn't work well with Unif files
	int addr = GetNesFileAddress(offs)-16;

	return addr != -1 ? addr / 0x4000 : -1;
}

static uint8 GetMem(uint16 A) {
	if ((A >= 0x2000) && (A < 0x4000)) {
		switch (A&7) {
			case 0: return PPU[0];
			case 1: return PPU[1];
			case 2: return PPU[2]|(PPUGenLatch&0x1F);
			case 3: return PPU[3];
			case 4: return SPRAM[PPU[3]];
			case 5: return XOffset;
			case 6: return RefreshAddr&0xFF;
			case 7: return VRAMBuffer;
		}
	} else if ((A >= 0x4000) && (A < 0x5000)) return 0xFF;	// AnS: changed the range, so MMC5 ExRAM can be watched in the Hexeditor
	if (GameInfo) return ARead[A](A);					 //adelikat: 11/17/09: Prevent crash if this is called with no game loaded.
	else return 0;
}

//---------------------

// Evaluates a condition
int evaluate(Condition* c)
{
	int f = 0;

	int value1, value2;

	if (c->lhs)
	{
		value1 = evaluate(c->lhs);
	}
	else
	{
		switch(c->type1)
		{
			case TYPE_ADDR: // This is intended to not break, and use the TYPE_NUM code
			case TYPE_NUM: value1 = c->value1; break;
			default: value1 = getValue(c->value1); break;
		}
	}

	switch(c->type1)
	{
		case TYPE_ADDR: value1 = GetMem(value1); break;
		case TYPE_BANK: value1 = getBank(_PC); break;
	}

	f = value1;

	if (c->op)
	{
		if (c->rhs)
		{
			value2 = evaluate(c->rhs);
		}
		else
		{
			switch(c->type2)
			{
				case TYPE_ADDR: // This is intended to not break, and use the TYPE_NUM code
				case TYPE_NUM: value2 = c->value2; break;
				default: value2 = getValue(c->type2); break;
			}
		}

	switch(c->type2)
	{
		case TYPE_ADDR: value2 = GetMem(value2); break;
		case TYPE_BANK: value2 = getBank(_PC); break;
	}

		switch (c->op)
		{
			case OP_EQ: f = value1 == value2; break;
			case OP_NE: f = value1 != value2; break;
			case OP_GE: f = value1 >= value2; break;
			case OP_LE: f = value1 <= value2; break;
			case OP_G: f = value1 > value2; break;
			case OP_L: f = value1 < value2; break;
			case OP_MULT: f = value1 * value2; break;
			case OP_DIV: f = value1 / value2; break;
			case OP_PLUS: f = value1 + value2; break;
			case OP_MINUS: f = value1 - value2; break;
			case OP_OR: f = value1 || value2; break;
			case OP_AND: f = value1 && value2; break;
		}
	}

	return f;
}

int condition(watchpointinfo* wp)
{
	return wp->cond == 0 || evaluate(wp->cond);
}


//---------------------

volatile int codecount, datacount, undefinedcount;

//-----------debugger stuff

static watchpointinfo watchpoint[65]; //64 watchpoints, + 1 reserved for step over
int iaPC;
uint32 iapoffset; //mbg merge 7/18/06 changed from int
int u; //deleteme
int skipdebug; //deleteme
int numWPs;

// for CPU cycles and Instructions counters
unsigned long int total_cycles_base = 0;
unsigned long int delta_cycles_base = 0;
bool break_on_cycles = false;
unsigned long int break_cycles_limit = 0;
unsigned long int total_instructions = 0;
unsigned long int delta_instructions = 0;
bool break_on_instructions = false;
unsigned long int break_instructions_limit = 0;

static DebuggerState dbgstate;

void ResetDebugStatisticsCounters()
{
	total_cycles_base = delta_cycles_base = timestampbase + timestamp;
	total_instructions = delta_instructions = 0;
}
void ResetDebugStatisticsDeltaCounters()
{
	delta_cycles_base = timestampbase + timestamp;
	delta_instructions = 0;
}
void IncrementInstructionsCounters()
{
	total_instructions++;
	delta_instructions++;
}

void BreakHit(int bp_num, bool force = false)
{
	if(!force) {

		//check to see whether we fall in any forbid zone
		for (int i = 0; i < numWPs; i++) {
			watchpointinfo& wp = watchpoint[i];
			if(!(wp.flags & WP_F) || !(wp.flags & WP_E))
				continue;

			if (condition(&wp))
			{
				if (wp.endaddress) {
					if( (wp.address <= _PC) && (wp.endaddress >= _PC) )
						return;	//forbid
				} else {
					if(wp.address == _PC)
						return; //forbid
				}
			}
		}
	}

	FCEUI_SetEmulationPaused(1); //mbg merge 7/19/06 changed to use EmulationPaused()

#ifdef WIN32
	FCEUD_DebugBreakpoint(bp_num);
#endif
}

uint8 StackAddrBackup = X.S;
uint16 StackNextIgnorePC = 0xFFFF;

///fires a breakpoint
static void breakpoint(uint8 *opcode, uint16 A, int size) {
	int i, j;
	uint8 brk_type;
	uint8 stackop=0;
	uint8 stackopstartaddr,stackopendaddr;

	if (break_on_cycles && (timestampbase + timestamp - total_cycles_base > break_cycles_limit))
		BreakHit(BREAK_TYPE_CYCLES_EXCEED, true);
	if (break_on_instructions && (total_instructions > break_instructions_limit))
		BreakHit(BREAK_TYPE_INSTRUCTIONS_EXCEED, true);

	//if the current instruction is bad, and we are breaking on bad opcodes, then hit the breakpoint
	if(dbgstate.badopbreak && (size == 0))
		BreakHit(BREAK_TYPE_BADOP, true);

	//if we're stepping out, track the nest level
	if (dbgstate.stepout) {
		if (opcode[0] == 0x20) dbgstate.jsrcount++;
		else if (opcode[0] == 0x60) {
			if (dbgstate.jsrcount)
				dbgstate.jsrcount--;
			else {
				dbgstate.stepout = false;
				dbgstate.step = true;
				return;
			}
		}
	}

	//if we're stepping, then we'll always want to break
	if (dbgstate.step) {
		dbgstate.step = false;
		BreakHit(BREAK_TYPE_STEP, true);
		return;
	}

	//if we're running for a scanline, we want to check if we've hit the cycle limit
	if (dbgstate.runline) {
		uint64 ts = timestampbase;
		ts+=timestamp;
		int diff = dbgstate.runline_end_time-ts;
		if (diff<=0)
		{
			dbgstate.runline=false;
			BreakHit(BREAK_TYPE_STEP, true);
			return;
		}
	}

	//check the step over address and break if we've hit it
	if ((watchpoint[64].address == _PC) && (watchpoint[64].flags)) {
		watchpoint[64].address = 0;
		watchpoint[64].flags = 0;
		BreakHit(BREAK_TYPE_STEP, true);
		return;
	}

	brk_type = opbrktype[opcode[0]] | WP_X;

	switch (opcode[0]) {
		//Push Ops
		case 0x08: //Fall to next
		case 0x48: stackopstartaddr=stackopendaddr=X.S-1; stackop=WP_W; StackAddrBackup = X.S; StackNextIgnorePC=_PC+1; break;
		//Pull Ops
		case 0x28: //Fall to next
		case 0x68: stackopstartaddr=stackopendaddr=X.S+1; stackop=WP_R; StackAddrBackup = X.S; StackNextIgnorePC=_PC+1; break;
		//JSR (Includes return address - 1)
		case 0x20: stackopstartaddr=stackopendaddr=X.S-1; stackop=WP_W; StackAddrBackup = X.S; StackNextIgnorePC=(opcode[1]|opcode[2]<<8); break;
		//RTI (Includes processor status, and exact return address)
		case 0x40: 
		  stackopstartaddr=X.S+1;
		  stackopendaddr=X.S+3;
		  stackop=WP_R;
		  StackAddrBackup = X.S; 
		  StackNextIgnorePC=(GetMem((X.S+2)|0x0100)|GetMem((X.S+3)|0x0100)<<8);
		  break;
		//RTS (Includes return address - 1)
		case 0x60: stackopstartaddr=X.S+1; stackopendaddr=X.S+2; stackop=WP_R; StackAddrBackup = X.S; StackNextIgnorePC=(GetMem(stackopstartaddr|0x0100)|GetMem(stackopendaddr|0x0100)<<8)+1; break;
	}

	for (i = 0; i < numWPs; i++)
	{
// ################################## Start of SP CODE ###########################
		if ((watchpoint[i].flags & WP_E) && condition(&watchpoint[i]))
		{
// ################################## End of SP CODE ###########################
			if (watchpoint[i].flags & BT_P)
			{
				// PPU Mem breaks
				if ((watchpoint[i].flags & brk_type) && ((A >= 0x2000) && (A < 0x4000)) && ((A&7) == 7))
				{
					if (watchpoint[i].endaddress)
					{
						if ((watchpoint[i].address <= RefreshAddr) && (watchpoint[i].endaddress >= RefreshAddr))
							BreakHit(i);
					} else
					{
						if (watchpoint[i].address == RefreshAddr)
							BreakHit(i);
					}
				}
			} else if (watchpoint[i].flags & BT_S)
			{
				// Sprite Mem breaks
				if ((watchpoint[i].flags & brk_type) && ((A >= 0x2000) && (A < 0x4000)) && ((A&7) == 4))
				{
					if (watchpoint[i].endaddress)
					{
						if ((watchpoint[i].address <= PPU[3]) && (watchpoint[i].endaddress >= PPU[3]))
							BreakHit(i);
					} else
					{
						if (watchpoint[i].address == PPU[3])
						BreakHit(i);
					}
				} else if ((watchpoint[i].flags & WP_W) && (A == 0x4014))
				{
					// Sprite DMA! :P
					BreakHit(i);
				}
			} else
			{
				// CPU mem breaks
				if ((watchpoint[i].flags & brk_type))
				{
					if (watchpoint[i].endaddress)
					{
						if (((watchpoint[i].flags & (WP_R | WP_W)) && (watchpoint[i].address <= A) && (watchpoint[i].endaddress >= A)) ||
							((watchpoint[i].flags & WP_X) && (watchpoint[i].address <= _PC) && (watchpoint[i].endaddress >= _PC)))
							BreakHit(i);
					} else
					{
						if (((watchpoint[i].flags & (WP_R | WP_W)) && (watchpoint[i].address == A)) ||
							((watchpoint[i].flags & WP_X) && (watchpoint[i].address == _PC)))
							BreakHit(i);
					}
				} else
				{
					// brk_type independant coding
					if (stackop > 0)
					{
						// Announced stack mem breaks
						// PHA, PLA, PHP, and PLP affect the stack data.
						// TXS and TSX only deal with the pointer.
						if (watchpoint[i].flags & stackop)
						{
							for (j = (stackopstartaddr|0x0100); j <= (stackopendaddr|0x0100); j++)
							{
								if (watchpoint[i].endaddress)
								{
									if ((watchpoint[i].address <= j) && (watchpoint[i].endaddress >= j))
										BreakHit(i);
								} else
								{
									if (watchpoint[i].address == j)
										BreakHit(i);
								}
							}
						}
					}
					if (StackNextIgnorePC == _PC)
					{
						// Used to make it ignore the unannounced stack code one time
						StackNextIgnorePC = 0xFFFF;
					} else
					{
						if ((X.S < StackAddrBackup) && (stackop==0))
						{
							// Unannounced stack mem breaks
							// Pushes to stack
							if (watchpoint[i].flags & WP_W)
							{
								for (j = (X.S|0x0100); j < (StackAddrBackup|0x0100); j++)
								{
									if (watchpoint[i].endaddress)
									{
										if ((watchpoint[i].address <= j) && (watchpoint[i].endaddress >= j))
											BreakHit(i);
									} else
									{
										if (watchpoint[i].address == j)
											BreakHit(i);
									}
								}
							}
						} else if ((StackAddrBackup < X.S) && (stackop==0))
						{
							// Pulls from stack
							if (watchpoint[i].flags & WP_R)
							{
								for (j = (StackAddrBackup|0x0100); j < (X.S|0x0100); j++)
								{
									if (watchpoint[i].endaddress)
									{
										if ((watchpoint[i].address <= j) && (watchpoint[i].endaddress >= j))
											BreakHit(i);
									} else
									{
										if (watchpoint[i].address == j)
											BreakHit(i);
									}
								}
							}
						}
					}

				}
			}
// ################################## Start of SP CODE ###########################
		}
// ################################## End of SP CODE ###########################
	}

	//Update the stack address with the current one, now that changes have registered.
	StackAddrBackup = X.S;
}
//bbit edited: this is the end of the inserted code

int debug_tracing;

void DebugCycle()
{
  fprintf(stderr, "Debugging shouldn't be on... -tom7.");
  abort();

	uint8 opcode[3] = {0};
	uint16 A = 0;
	int size;

#ifdef WIN32
	// since this function is called once for every instruction, we can use it for keeping statistics
	IncrementInstructionsCounters();
#endif

	if (scanline == 240)
	{
		vblankScanLines = (PAL?int((double)timestamp / ((double)341 / (double)3.2)):timestamp / 114);	//114 approximates the number of timestamps per scanline during vblank.  Approx 2508. NTSC: (341 / 3.0) PAL: (341 / 3.2). Uses (3.? * cpu_cycles) / 341.0, and assumes 1 cpu cycle.
		if (vblankScanLines) vblankPixel = 341 / vblankScanLines;	//341 pixels per scanline
		//FCEUI_printf("vbPixel = %d",vblankPixel);					     //Debug
		//FCEUI_printf("ts: %d line: %d\n", timestamp, vblankScanLines); //Debug
	}
	else
		vblankScanLines = 0;

	opcode[0] = GetMem(_PC);
	size = opsize[opcode[0]];
	switch (size)
	{
		case 2:
			opcode[1] = GetMem(_PC + 1);
			break;
		case 3:
			opcode[1] = GetMem(_PC + 1);
			opcode[2] = GetMem(_PC + 2);
			break;
	}

	switch (optype[opcode[0]])
	{
		case 0: break;
		case 1:
			A = (opcode[1] + _X) & 0xFF;
			A = GetMem(A) | (GetMem(A + 1) << 8);
			break;
		case 2: A = opcode[1]; break;
		case 3: A = opcode[1] | (opcode[2] << 8); break;
		case 4: A = (GetMem(opcode[1]) | (GetMem(opcode[1]+1) << 8)) + _Y; break;
		case 5: A = opcode[1] + _X; break;
		case 6: A = (opcode[1] | (opcode[2] << 8)) + _Y; break;
		case 7: A = (opcode[1] | (opcode[2] << 8)) + _X; break;
		case 8: A = opcode[1] + _Y; break;
	}

	if (numWPs || dbgstate.step || dbgstate.runline || dbgstate.stepout || watchpoint[64].flags || dbgstate.badopbreak || break_on_cycles || break_on_instructions)
		breakpoint(opcode, A, size);

#ifdef WIN32
	//This needs to be windows only or else the linux build system will fail since logging is declared in a
	//windows source file
	FCEUD_TraceInstruction(opcode, size);
#endif

}
