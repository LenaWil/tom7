
#include "audio-engine.h"

// These are static.
SDL_mutex *AudioEngine::mutex = nullptr;
int64 AudioEngine::cursor = 0ULL;
bool AudioEngine::playing = false;
SampleLayer *AudioEngine::song = nullptr;

void AudioEngine::Init() {
  mutex = SDL_CreateMutex();
  CHECK(mutex);

  // new samplelayer...
}

