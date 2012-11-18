/* Searches for solutions to Karate Kid. */

#include <unistd.h>
#include <sys/types.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

#include "tasbot.h"

#include "fceu/utils/md5.h"
#include "config.h"
#include "fceu/driver.h"
#include "fceu/drivers/common/args.h"
#include "fceu/state.h"
#include "basis-util.h"
#include "emulator.h"
#include "fceu/fceu.h"
#include "fceu/types.h"
#include "simplefm2.h"

/* Represents a node in the state graph.

   == Quotienting ==

   This can actually be a quotient of the "real" state graph, if we
   can identify parts of the state that don't matter (i.e., if some
   location in memory stores the cursor in the music, but that cursor
   is never branched on except to change the music, then we might
   ignore it for the purpose of state equality). This is risky
   business because the search algorithm assumes these states are
   interchangeable.

   For Karate Kid I am using the contents of RAM with certain ranges
   blocked out. For example, address 0x036E always contains the input
   byte for that frame. We need to ignore this in equality tests or
   else it will appear that every frame has 2^buttons distinct
   successors just because of the byte in memory that we control. In
   reality, many buttons are ignored on many frames (for example,
   jumping when in the air or punching while punching). In fact, this
   could automate the otherwise external knowledge that the Select
   button does nothing in this game.

   (P.S. I think that's the right thing to do from an efficiency
    standpoint, but these states might converge anyway because the
    states with equivalent inputs (in game logic) should also have
    equivalent (or equal) successors. But we may still increase
    efficiency by a constant factor of 2^inputs, which is obviously
    worth the minor complexity.)

   == Replay ==

   Compressed save states are about 1.8kb after doing some tricks
   (though I think this can be reduced further by ignoring some
   output-only parts; see emulator.cc). We could only store about
   35 million of them, max. Therefore, they are optional in
   most nodes. If the savestate is not present, we back up
   the graph to the most recent predecessor that has a savestate,
   then replay the inputs in order to load this node. This trades
   off time for space.


*/
struct Node : public Heapable {
  // If NULL, then this is the root state. It MUST have
  // saved state.
  Node *prev;
  // Optional new-ly allocated savestate, owned by this node.
  // It can be cleared at any time, unless prev is NULL.
  vector<uint8> *savestate;

  // The input issued to get from the previous state
  // to this state. Meaningless if this is the root node.
  uint8 input;

  // Best known distance to the root. If location (inherited
  // from Heapable) is -1, then this is the final distance.
  uint16 distance;

  // We have to be able to compute a priority for each node; this will
  // be some function of the distance and the heuristic. It usually
  // won't be possible to come up with an admissible heuristic because
  // there are so many unpredictable things about how the game proceeds.
  uint32 heuristic;
};

static void DoFun(int frameskip) {
  uint8 *gfx;
  int32 *sound;
  int32 ssize;
  static int opause = 0;

  // fprintf(stderr, "In DoFun..\n");

  // Limited ability to skip video and sound.
  #define SKIP_VIDEO_AND_SOUND 2

  // Emulate a single frame.
  FCEUI_Emulate(NULL, &sound, &ssize, SKIP_VIDEO_AND_SOUND);

  // This was the only useful thing from Update. It's called multiple
  // times; I don't know why.
  // --- update input! --

  uint8 v = RAM[0x0009];
  uint8 s = RAM[0x000B];  // Should be 77.
  uint32 loc = (RAM[0x0080] << 24) |
    (RAM[0x0081] << 16) |
    (RAM[0x0082] << 8) |
    (RAM[0x0083]);
  // fprintf(stderr, "%02x %02x\n", v, s);
}

// Get the hashcode for the current state. This is based just on RAM.
// XXX should include registers too, right?
static uint64 GetHashCode() {
  uint64 a = 0xDEADBEEFCAFEBABEULL,
    b = 0xDULL,
    c = 0xFFFF000073731919ULL;
  for (int i = 0; i < 0x800; i++) {
    do { uint64 t = a; a = b; b = c; c = t; } while(0);
    switch (i) {
    // Bytes that are ignored...
    case 0x036E: // Contains the input byte for that frame. Ignore.

      break;
    default:
      a += (RAM[i] * 31337);
      b ^= 0xB00BFACEFULL;
      c *= 0x1234567ULL;
      c = (c >> 17) | (c << (64 - 17));
      a ^= c;
    }
  }
  return a + b + c;
}

// Magic "game location" address.
// See addresses.txt
static uint32 GetLoc() {
  return (RAM[0x0080] << 24) |
    (RAM[0x0081] << 16) |
    (RAM[0x0082] << 8) |
    (RAM[0x0083]);
}

// Determine if this state should be avoided
// completely. For example, if we die or enter
// some optional bonus stage.
static bool IsBad() {

  // Number of lives
  // n.b. this would allow me to get an extra
  // life and then die. Maybe this should be
  // IsBadTransition and compare to the
  // last state?
  if (RAM[0x07D6] < 3) {
    return true;
  }

  uint32 loc = GetLoc();

  if (loc == 65536) {
    // Don't allow taking damage during
    // tournament.
    if (RAM[0x0085] < 0xF) {
      return true;
    }
  }
}

// Return true if we've won.
// For now this is just killing the
// dude in the first battle.
static bool IsWon() {
  // Magic "game location" address.
  uint32 loc = GetLoc();

  if (loc == 65536) {
    return RAM[0x008B] == 0;
  }

  fprintf(stderr, "Exited karate battle? %u\n", loc);
  abort();
  return false;
}

// This must return an unsigned number 0-0xFFFFFFFF
// where larger numbers are closer to the end of
// the game.
static uint32 GetHeuristic() {
  // Magic "game location" address.
  uint32 loc = GetLoc();

  // Plan for later: First nybble is the phase
  // (battle 1-3, level 3-9, etc.), remainder
  // is some scaled value for that phase.

  if (loc == 65536) {
    // XXX need something to tell us which battle
    // number this is.

    // Start screen and battles.

    // More damage is better.
    uint8 damage = 0xFF - (uint8)RAM[0x008B];
    return (damage << 16) |
      // x coordinate
      (uint8)RAM[0x0502];
    // XXX y coordinate?
  } else {
    fprintf(stderr, "Exited karate battle? %u\n", loc);
    abort();
  }

  return 0;
}

// Initialized at startup.
static vector<uint8> *basis = NULL;

static Node *MakeNode(Node *prev, uint8 input) {
  Node *n = new Node;
  n->prev = prev;
  // PERF Shouldn't need to initialize this?
  n->location = -1;

  n->distance = (prev == NULL) ? 0 : (prev->distance + 1);
  // Note, ignored if prev == NULL.
  n->input = input;

  // XXX decide whether to make savestate, like by
  // tracing backwards or computing parity of distance
  // or whatever.
  n->savestate = new vector<uint8>;
  Emulator::SaveEx(n->savestate, basis);

  n->heuristic = GetHeuristic();
}

/**
 * The main loop for the SDL.
 */
int main(int argc, char *argv[]) {
  fprintf(stderr, "Nodes are %d bytes\n", sizeof(Node));

  Emulator::Initialize("karate.nes");

  vector<uint8> inputs = SimpleFM2::ReadInputs("karate.fm2");
  basis = new vector<uint8>;
  *basis = BasisUtil::LoadOrComputeBasis(inputs, 4935, "karate.basis");

  // Fast-forward to gameplay.
  // There are 98 frames before the initial battle begins.
  for (int i = 0; i < 98; i++) {
    Emulator::Step(inputs[i]);
  }

  hash_map<uint64, Node *> nodes;

  Node *start = MakeNode(NULL, 0x0);
  nodes[GetHashCode()] = start;

  Heap<uint64, Node> queue;


  Emulator::Shutdown();

  // exit the infrastructure
  FCEUI_Kill();
  return 0;
}
