#ifndef _DEBUG_H_
#define _DEBUG_H_

#include "git.h"
#include "types.h"

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

extern int GetPRGAddress(int A);

//---------CDLogger
// void LogCDVectors(int which);
static constexpr bool debug_loggingCD = false;
void LogCDData(uint8 *opcode, uint16 A, int size);
extern volatile int codecount, datacount, undefinedcount;
extern unsigned char *cdloggerdata;

// extern int debug_loggingCD;
// static INLINE void FCEUI_SetLoggingCD(int val) { debug_loggingCD = val; }
// static INLINE int FCEUI_GetLoggingCD() { return debug_loggingCD; }
//-------

//--------debugger
extern int iaPC;
extern uint32 iapoffset; //mbg merge 7/18/06 changed from int
void DebugCycle();
//-------------

//internal variables that debuggers will want access to
extern uint8 *vnapage[4],*VPage[8];
extern uint8 PPU[4],PALRAM[0x20],SPRAM[0x100],VRAMBuffer,PPUGenLatch,XOffset;
extern uint32 RefreshAddr;

extern int numWPs;

///retrieves the core's DebuggerState
// DebuggerState &FCEUI_Debugger();

//#define CPU_BREAKPOINT 1
//#define PPU_BREAKPOINT 2
//#define SPRITE_BREAKPOINT 4
//#define READ_BREAKPOINT 8
//#define WRITE_BREAKPOINT 16
//#define EXECUTE_BREAKPOINT 32

#endif
