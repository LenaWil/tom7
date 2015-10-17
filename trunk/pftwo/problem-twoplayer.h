#ifndef __PROBLEM_TWOPLAYER_H
#define __PROBLEM_TWOPLAYER_H

#include "pftwo.h"

#include <mutex>
#include <atomic>

#include "markov-controller.h"
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

    // Get a random input; may depend on the current state
    // (for example, in Markov models).
    Input RandomInput(ArcFour *rc) {
      
    }

    State Save() {
      return emu->SaveUncompressed();
    }
    
    void Restore(const State &state) {
      emu->LoadUncompressed(state);
    }
    void Exec(Input input) {
      emu->Step(Player1(input), Player2(input));
    }

    void ClearStatus() {
      SetStatus(nullptr);
      SetNumer(0);
      SetDenom(0);
    }
    inline void SetStatus(const char *s) {
      status.store(s, std::memory_order_relaxed);
    }
    inline void SetNumer(int n) {
      numer.store(n, std::memory_order_relaxed);
    }
    inline void SetDenom(int d) {
      denom.store(d, std::memory_order_relaxed);
    }
    
    // Current operation. Should point to a string literal;
    // other code may hang on to references.
    std::atomic<const char *> status{nullptr};
    // Fraction complete.
    std::atomic<int> numer{0}, denom{0};
  };

  // Must be thread safe.
  Worker *CreateWorker();

  TwoPlayerProblem();

  vector<pair<uint8, uint8>> original_inputs;
  unique_ptr<MarkovController> markov1, markov2;
  vector<pair<uint8, uint8>> warmup_inputs;
};


#endif
