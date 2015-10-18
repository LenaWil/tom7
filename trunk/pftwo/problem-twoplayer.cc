#include "problem-twoplayer.h"

#include "../fceulib/simplefm2.h"
#include "markov-controller.h"

using TPP = TwoPlayerProblem;
using Worker = TPP::Worker;

TPP::Input Worker::RandomInput(ArcFour *rc) {
  MutexLock ml(&mutex);
  const uint8 p1 = tpp->markov1->RandomNext(Player1(previous), rc);
  const uint8 p2 = tpp->markov2->RandomNext(Player2(previous), rc);
  return MakeInput(p1, p2);
}

// XXX should take config text?
TPP::TwoPlayerProblem() {
  original_inputs = SimpleFM2::ReadInputs2P("contra2p.fm2");

  vector<uint8> player1, player2;
  for (const auto &p : original_inputs) {
    player1.push_back(p.first);
    player2.push_back(p.second);
  }
  markov1.reset(new MarkovController(player1));
  markov2.reset(new MarkovController(player1));  
  
  warmup_inputs = original_inputs;
  CHECK_GT(warmup_inputs.size(), 800);
  warmup_inputs.resize(800);
}

Worker *TPP::CreateWorker() {
  CHECK(this);
  Worker *w = new Worker(this);
  w->emu.reset(Emulator::Create("contra.nes"));
  CHECK(w->emu.get() != nullptr);
  w->ClearStatus();
  return w;
}

void Worker::Init() {
  MutexLock ml(&mutex);
  SetStatus("Warm up");
  SetDenom(tpp->warmup_inputs.size());
  for (int i = 0; i < tpp->warmup_inputs.size(); i++) {
    emu->Step(tpp->warmup_inputs[i].first, tpp->warmup_inputs[i].second);
    SetNumer(i);
  }
  ClearStatus();
}

void Worker::Visualize(vector<uint8> *argb) {
  MutexLock ml(&mutex);
  CHECK(argb->size() == 4 * 256 * 256);
  emu->GetImageARGB(argb);
}
