#include "problem-twoplayer.h"

#include "../fceulib/simplefm2.h"

using TPP = TwoPlayerProblem;

using Worker = TPP::Worker;

// XXX should take config text?
TwoPlayerProblem::TwoPlayerProblem() {
  warmup_inputs = SimpleFM2::ReadInputs2P("contra2p.fm2");
  CHECK_GT(warmup_inputs.size(), 800);
  warmup_inputs.resize(800);
}

Worker *TPP::CreateWorker() {
  Worker *w = new Worker;
  w->emu.reset(Emulator::Create("contra.nes"));
  CHECK(w->emu.get() != nullptr);

  w->status = "Warm up";
  w->denom = warmup_inputs.size();
  for (int i = 0; i < warmup_inputs.size(); i++) {
    w->emu->Step(warmup_inputs[i].first, warmup_inputs[i].second);
    w->numer = i;
  }
  w->ClearStatus();

  return w;
}
