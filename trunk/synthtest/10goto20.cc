
#include "10goto20.h"
#include "audio-engine.h"

#include "bleep-bloop-sample-layer.h"

#include "jdksmidi/world.h"
#include "jdksmidi/track.h"
#include "jdksmidi/multitrack.h"
#include "jdksmidi/filereadmultitrack.h"
#include "jdksmidi/fileread.h"
#include "jdksmidi/fileshow.h"

#define STARTW 800
#define STARTH 600

static SampleLayer *layer;

int64 ttt = 0LL;

// XXX dithering, etc.
static Sint16 DoubleTo16(double d) {
  if (d > 1.0) return 32767;
  // signed 16-bit int goes to -32768, but we never use
  // this sample value; symmetric amplitudes seem like
  // the right thing?
  else if (d < -1.0) return -32767;
  else return (Sint16)(d * 32767.0);
}

void Audio(void *userdata, Uint8 *stream_bytes, int num_bytes) {
  Sint16 *stream = (Sint16*) stream_bytes;
  int samples = num_bytes / sizeof (Sint16);

  // Two channels.
  for (int i = 0; i < samples; i += 2) {
    Sample s = layer->SampleAt(ttt);
    stream[i] = DoubleTo16(s.left);
    stream[i + 1] = DoubleTo16(s.right);
    ttt++;
  }
}

int waste(void *unused) {
  int x = 0;
  for(;;) {
    x *= 0xBEEF;
    x ^= 0xDEAD;
    if (x & 1) {
      x <<= 1;
    } else {
      x >>= 1;
    }
  }
  
  return -1;
}

namespace {
using namespace jdksmidi;
void DumpMIDITimedBigMessage ( const MIDITimedBigMessage *msg ) {
  if ( msg ) {
    char msgbuf[1024];
    fprintf ( stdout, "%8ld : %s\n", msg->GetTime(), msg->MsgToText ( msgbuf ) );
    
    if ( msg->IsSystemExclusive() ) {
      fprintf ( stdout, "\tSYSEX length: %d\n", msg->GetSysEx()->GetLength() );
    }
  }
}

void DumpMIDITrack ( MIDITrack *t ) {
  MIDITimedBigMessage *msg;
  
  for ( int i = 0; i < t->GetNumEvents(); ++i ) {
    msg = t->GetEventAddress ( i );
    DumpMIDITimedBigMessage ( msg );
  }
}

void DumpAllTracks ( MIDIMultiTrack *mlt ) {
  for ( int i = 0; i < mlt->GetNumTracks(); ++i ) {
    if ( mlt->GetTrack ( i )->GetNumEvents() > 0 ) {
      fprintf ( stdout, "DUMP OF TRACK #%2d:\n", i );
      DumpMIDITrack ( mlt->GetTrack ( i ) );
      fprintf ( stdout, "\n" );
    }
  }
}
  
void DumpMIDIMultiTrack ( MIDIMultiTrack *mlt ) {
  fprintf(stderr, "Dump midi...\n");
  MIDIMultiTrackIterator i ( mlt );
  const MIDITimedBigMessage *msg;
  i.GoToTime ( 0 );

  do {
    int trk_num;

    if ( i.GetCurEvent ( &trk_num, &msg ) ) {
      fprintf ( stdout, "#%2d - ", trk_num );
      DumpMIDITimedBigMessage ( msg );
    }
  }
  while ( i.GoToNextEvent() );
}

} // namespace

int main (int argc, char **argv) {

  if (SDL_Init (SDL_INIT_AUDIO | SDL_INIT_VIDEO | SDL_INIT_TIMER) < 0) {
    fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
    abort();
  }

//FILE * ctt = fopen("CON", "w" );
//freopen( "CON", "w", stdout );
//freopen( "CON", "w", stderr );

  fprintf(stderr, "10 GOTO 20\n");

  layer = BleepBloopSampleLayer::Create();
  CHECK(layer);

  {
    jdksmidi::MIDIFileReadStreamFile rs("sensations.mid");
    jdksmidi::MIDIMultiTrack tracks;
    jdksmidi::MIDIFileReadMultiTrack track_loader(&tracks);
    jdksmidi::MIDIFileRead reader(&rs, &track_loader);
    reader.Parse();
    DumpMIDIMultiTrack(&tracks);
  }

  SDL_EnableUNICODE(1);
  SDL_Surface *screen = sdlutil::makescreen(STARTW, STARTH);
  sdlutil::clearsurface(screen, 1234567);
  SDL_Flip(screen);

  SDL_AudioSpec spec, obtained;
  spec.freq = SAMPLINGRATE;
  spec.samples = 2048;
  spec.channels = 2;
  spec.callback = &Audio;
  spec.userdata = 0;
  spec.format = AUDIO_S16SYS;
  SDL_OpenAudio(&spec, &obtained);

  fprintf(stderr, "hey. %d %d\n", obtained.freq, obtained.samples);

  SDL_PauseAudio(0);

  SDL_Thread *t1 = SDL_CreateThread(waste, 0);
  SDL_Thread *t2 = SDL_CreateThread(waste, 0);
  SDL_Thread *t3 = SDL_CreateThread(waste, 0);
  SDL_Thread *t4 = SDL_CreateThread(waste, 0);
  SDL_Thread *t5 = SDL_CreateThread(waste, 0);
  SDL_Thread *t6 = SDL_CreateThread(waste, 0);

  while(1) {
    SDL_Event e;
    /* event loop */
    while (SDL_PollEvent(&e)) {
      switch(e.type) {
      case SDL_QUIT:
	return 0;

      case SDL_KEYDOWN: {
	int key = e.key.keysym.sym;
	switch(key) {
	case SDLK_ESCAPE:
	  return 0;
	default:;
	}
      }
	
      default:;
      }
    }

    SDL_Delay(0);
  }


// fclose(ctt);
  return 0;
}
