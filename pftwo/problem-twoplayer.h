#ifndef __PROBLEM_TWOPLAYER_H
#define __PROBLEM_TWOPLAYER_H

#include "pftwo.h"

#include <mutex>
#include <atomic>

#include "markov-controller.h"
#include "../fceulib/emulator.h"
#include "weighted-objectives.h"

struct TwoPlayerProblem {
  // Player 1 and Player 2 controllers.
  using Input = uint16;

  static inline uint8 Player1(Input i) { return (i >> 8) & 255; }
  static inline uint8 Player2(Input i) { return i & 255; }
  static inline Input MakeInput(uint8 p1, uint8 p2) {
    return ((uint16)p1 << 8) | (uint16)p2;
  }
  
  // Save state; these are portable between workers.
  struct State {
    vector<uint8> save;
    // PERF This is actually part of save.
    vector<uint8> mem;
    Input prev;
  };

  // An individual instance of the emulator that can be used to
  // execute steps. We create one of these per thread.
  struct Worker {
    explicit Worker(TwoPlayerProblem *parent) : tpp(parent) {}
    // Same game is loaded as parent Problem.
    unique_ptr<Emulator> emu;
    // Previous input.
    Input previous;
    
    // Sample a random input; may depend on the current state (for
    // example, in Markov models). Doesn't execute the input.
    Input RandomInput(ArcFour *rc);

    // Called in the worker thread before anything else, but
    // the worker's state must be valid before this point.
    void Init();
    
    State Save() {
      MutexLock ml(&mutex);
      return {emu->SaveUncompressed(), emu->GetMemory(), previous};
    }

    void Restore(const State &state) {
      MutexLock ml(&mutex);
      emu->LoadUncompressed(state.save);
      // (Doesn't actually need the memory to restore.)
      previous = state.prev;
    }
    void Exec(Input input) {
      MutexLock ml(&mutex);
      emu->Step(Player1(input), Player2(input));
      IncrementNESFrames(1);
      previous = input;
    }

    void Observe();
    
    // XXX: This interface pretty much only works for grabbing a
    // single NES frame right now.
    void Visualize(vector<uint8> *argb256x256);
    
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
    inline void IncrementNESFrames(int d) {
      nes_frames.fetch_add(d, std::memory_order_relaxed);
    }
    
    // Current operation. Should point to a string literal;
    // other code may hang on to references.
    std::atomic<const char *> status{nullptr};
    // Fraction complete.
    std::atomic<int> numer{0}, denom{0};
    // For benchmarking, the total number of NES frames (or
    // equivalent) executed by this worker. This isn't
    // all the program does, but it is the main bottleneck,
    // so we want to make sure we aren't stalling them.
    std::atomic<int> nes_frames{0};
    
    const TwoPlayerProblem *tpp = nullptr;

    // Lock emulator etc.
    std::mutex mutex;
  };

  // Commits observations.
  void Commit() {
    printf("In problem commit.\n");
    CHECK(observations.get());
    observations->Commit();
  }
  // Score in [0, 1]. Should be stable in-between calls to
  // Commit.
  double Score(const State &state) {
    return observations->GetWeightedValue(state.mem);
  }
  
  // Must be thread safe and leave Worker in a valid state.
  Worker *CreateWorker();

  TwoPlayerProblem(const map<string, string> &config);
 
  string game;
  vector<pair<uint8, uint8>> original_inputs;
  unique_ptr<MarkovController> markov1, markov2;
  // After warmup inputs.
  State start_state;
  // For play after warmup.
  unique_ptr<WeightedObjectives> objectives;
  unique_ptr<Observations> observations;
};


#endif
