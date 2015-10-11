#ifndef __PROBLEM_TWOPLAYER_H
#define __PROBLEM_TWOPLAYER_H

#include "pftwo.h"

#include "../fceulib/emulator.h"

struct TwoPlayerProblem {
  // Player 1 and Player 2 controllers.
  using Input = uint16;

  static inline uint8 Player1(Input i) { return (i >> 8) & 255; }
  static inline uint8 Player2(Input i) { return i & 255; }
  
  // Save state; these are portable between workers.
  using State = vector<uint8>;

  // An individual instance of the emulator that can be used to
  // execute steps. We create one of these per thread.
  struct Worker {
    // Same game is loaded as parent Problem.
    unique_ptr<Emulator> emu;

    void Restore(const State &state) {
      emu->LoadUncompressed(state);
    }
    void Exec(Input input) {
      emu->Step(Player1(input), Player2(input));
    }

    void ClearStatus() {
      status = nullptr;
      numer = denom = 0;
    }
    // Current operation. Meant to point to a constant string.
    const char *status = nullptr;
    // Fraction complete.
    int numer = 0, denom = 0;
  };

  Worker *CreateWorker();

  TwoPlayerProblem();


  vector<pair<uint8, uint8>> warmup_inputs;
};


#endif
