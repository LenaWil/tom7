#include "problem-twoplayer.h"

#include <map>

#include "../fceulib/simplefm2.h"
#include "n-markov-controller.h"
#include "weighted-objectives.h"
#include "learnfun.h"
#include "../cc-lib/util.h"

// Note NMarkovController::Stats; making this large will often
// make the matrix very sparse.
static constexpr int MARKOV_N = 3;

static_assert(MARKOV_N >= 0 && MARKOV_N <= 8, "allowed range");

// XXX for contra to enter konami code.
// should be derived from input.
static constexpr int WARMUP_FRAMES = 800;

// ??!?
static constexpr int OBSERVATION_SAMPLES = 32768;
// static constexpr int OBSERVATION_SAMPLES = 1024;

using TPP = TwoPlayerProblem;
using Worker = TPP::Worker;

TPP::Input Worker::RandomInput(ArcFour *rc) {
  MutexLock ml(&mutex);
  const uint8 p1 = tpp->markov1->RandomNext(previous1, rc);
  const uint8 p2 = tpp->markov2->RandomNext(previous2, rc);
  return MakeInput(p1, p2);
}

void TPP::SaveSolution(const string &filename_part,
		       const vector<Input> &inputs,
		       const State &state,
		       const string &info) {
  vector<pair<uint8, uint8>> all_inputs;
  for (int i = 0; i < WARMUP_FRAMES; i++) {
    all_inputs.push_back(original_inputs[i]);
  }
  for (const Input &input : inputs) {
    all_inputs.push_back({Player1(input), Player2(input)});
  }
  SimpleFM2::WriteInputs2P(StringPrintf("%s-%s.fm2", game.c_str(),
					filename_part.c_str()),
			   game,
			   // Take from inputs?
			   "base64:WlwvTxyvsfVajcDVrUVQ5Q==",
			   all_inputs);
}


TPP::TwoPlayerProblem(const map<string, string> &config) {
  game = GetDefault(config, "game", "");
  const string movie = GetDefault(config, "movie", "");
  original_inputs = SimpleFM2::ReadInputs2P(movie);
  CHECK(original_inputs.size() > WARMUP_FRAMES);

  // Throwaway emulator instance for warmup, training.
  printf("Warmup.\n");
  unique_ptr<Emulator> emu(Emulator::Create(game));
  for (int i = 0; i < WARMUP_FRAMES; i++) {
    emu->Step(original_inputs[i].first, original_inputs[i].second);
  }

  printf("Get inputs.\n");
  // Now build inputs for training markov.
  vector<uint8> player1, player2;
  for (int i = WARMUP_FRAMES; i < original_inputs.size(); i++) {
    const auto &p = original_inputs[i];
    player1.push_back(p.first);
    player2.push_back(p.second);
  }
  printf("Build markov controllers.\n");
  markov1.reset(new NMarkovController(player1, MARKOV_N));
  markov2.reset(new NMarkovController(player2, MARKOV_N));

  markov1->Stats();
  markov2->Stats();
  
  // Save start state for each worker.
  start_state = {emu->SaveUncompressed(), emu->GetMemory(),
		 0,
		 markov1->HistoryInDomain(),
		 markov2->HistoryInDomain()};
  
  // Now execute inputs to get memories for learnfun.
  printf("Get memories.\n");
  vector<vector<uint8>> memories;
  memories.reserve(original_inputs.size() - WARMUP_FRAMES);
  for (int i = WARMUP_FRAMES; i < original_inputs.size(); i++) {
    const auto &p = original_inputs[i];
    emu->Step(p.first, p.second);
    memories.push_back(emu->GetMemory());
  }
  
  // See if we have cached learnfun results, since it takes some
  // time to run.

  // XXX base this on a fingerprint of ROM, FM2, and any other
  // configuration.
  string cached_objectives = StringPrintf("%s.objectives", game.c_str());
  if (Util::ExistsFile(cached_objectives)) {
    printf("Loading weighted objectives from %s.\n",
	   cached_objectives.c_str());
    objectives.reset(WeightedObjectives::LoadFromFile(cached_objectives));
    printf("There are %d objectives.\n", (int)objectives->Size());
  } else {
    Learnfun learnfun{memories};
    objectives.reset(learnfun.MakeWeighted());
    printf("Saved objectives to %s.\n", cached_objectives.c_str());
    objectives->SaveToFile(cached_objectives);
  }
  CHECK(objectives.get());
  /*
  observations.reset(Observations::
		     SampleObservations(*objectives,
					OBSERVATION_SAMPLES));
  */
  observations.reset(Observations::MixedBaseObservations(*objectives));
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
  #if 0
  vector<uint8> xxx = emu->GetMemory();
  for (int i = 0; i < xxx.size(); i++) {
    (*argb)[i * 4 + 0] = xxx[i];
    (*argb)[i * 4 + 1] = xxx[i];
    (*argb)[i * 4 + 2] = xxx[i];
    (*argb)[i * 4 + 3] = 0xFF;
  }
  #endif
  
  const double s = tpp->observations->GetWeightedValue(emu->GetMemory());
  // printf("%f\n", s);
  for (int y = 250; y < 256; y++) {
    int len = std::min(256, 5 + (int)(256 * s));
    for (int x = 0; x < len; x++) {
      int i = (y * 256 + x) * 4;
      (*argb)[i + 0] = 0x00;
      (*argb)[i + 1] = 0x00;
      (*argb)[i + 2] = 0xFF;
      (*argb)[i + 3] = 0xFF;
    }
  }
}

void Worker::VizText(vector<string> *text) {
  text->push_back(StringPrintf("Depth %d", depth));
  const vector<uint8> mem = emu->GetMemory();

  static constexpr std::initializer_list<int> kLocations = 
    { 48, 100, 101, 820, 821, 50, 51, 2019, 2018, 2021, 2020 };

  for (int i : kLocations) {
    text->push_back(StringPrintf("%d: %d", i, mem[i]));
  }

  text->push_back("--------");
  tpp->observations->VizText(mem, text);
  if (text->size() > 50) {
    text->resize(50);
    text->push_back(" (ahem!) ");
  }
}

void Worker::Observe() {
  // PERF: If we hold the lock, we could just read
  // directly from RAM.
  vector<uint8> mem;
  mem.resize(2048);
  {
    MutexLock ml(&mutex);
    emu->GetMemory(&mem);
  }
  
  tpp->observations->Accumulate(mem);
}
