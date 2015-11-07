#include "problem-twoplayer.h"

#include <map>

#include "../fceulib/simplefm2.h"
#include "markov-controller.h"
#include "weighted-objectives.h"
#include "learnfun.h"


// XXX for contra to enter konami code.
// should be derived from input.
static constexpr int WARMUP_FRAMES = 800;

using TPP = TwoPlayerProblem;
using Worker = TPP::Worker;

TPP::Input Worker::RandomInput(ArcFour *rc) {
  MutexLock ml(&mutex);
  const uint8 p1 = tpp->markov1->RandomNext(Player1(previous), rc);
  const uint8 p2 = tpp->markov2->RandomNext(Player2(previous), rc);
  return MakeInput(p1, p2);
}

TPP::TwoPlayerProblem(const map<string, string> &config) {
  game = GetDefault(config, "game", "");
  const string movie = GetDefault(config, "movie", "");
  original_inputs = SimpleFM2::ReadInputs2P(movie);
  CHECK(original_inputs.size() > WARMUP_FRAMES);

  // Throwaway emulator instance for warmup, training.
  printf("Warmup.\n");
  unique_ptr<Emulator> emu(Emulator::Create(game));
  Input last_input = MakeInput(0, 0);
  for (int i = 0; i < WARMUP_FRAMES; i++) {
    emu->Step(original_inputs[i].first, original_inputs[i].second);
    last_input = MakeInput(original_inputs[i].first,
			   original_inputs[i].second);
  }

  // Save start state for each worker.
  start_state = {emu->SaveUncompressed(), last_input};

  printf("Get memories.\n");
  // Now build inputs and memories for learning.
  vector<uint8> player1, player2;
  vector<vector<uint8>> memories;
  memories.reserve(original_inputs.size() - WARMUP_FRAMES);
  for (int i = WARMUP_FRAMES; i < original_inputs.size(); i++) {
    const auto &p = original_inputs[i];
    player1.push_back(p.first);
    player2.push_back(p.second);
    emu->Step(p.first, p.second);
    memories.push_back(emu->GetMemory());
  }
  printf("Build markov controllers.\n");
  markov1.reset(new MarkovController(player1));
  markov2.reset(new MarkovController(player1));  
  
  // XXX learnfun here.
  Learnfun learnfun{memories};
  objectives.reset(learnfun.MakeWeighted());
}

Worker *TPP::CreateWorker() {
  CHECK(this);
  Worker *w = new Worker(this);
  w->emu.reset(Emulator::Create(game));
  CHECK(w->emu.get() != nullptr);
  w->ClearStatus();
  return w;
}

void Worker::Init() {
  // n.b., restore takes lock
  Restore(tpp->start_state);
}

void Worker::Visualize(vector<uint8> *argb) {
  MutexLock ml(&mutex);
  CHECK(argb->size() == 4 * 256 * 256);
  emu->GetImageARGB(argb);
  vector<uint8> xxx = emu->GetMemory();
  for (int i = 0; i < xxx.size(); i++) {
    (*argb)[i * 4 + 0] = xxx[i];
    (*argb)[i * 4 + 1] = xxx[i];
    (*argb)[i * 4 + 2] = xxx[i];
    (*argb)[i * 4 + 3] = 0xFF;
  }
}
