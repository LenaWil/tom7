
#include "pixeltest.h"

#define PIXELSIZE 4

// In game pixels.
#define WIDTH 320
#define HEIGHT 200


int counter = 0;

// XXX locking?
static void FillScreen2x(SDL_Surface *surf) {
  static int r = 0x50, g = 0x80, b = 0xFE, a = 0xFF, f = 0xFFFFFF;
  // printf("RGB %d %d %d\n", R, G, B);
  CHECK(surf->format->BytesPerPixel == 4);

  for (int y = 0; y < HEIGHT; y++) {
    for (int x = 0; x < WIDTH; x++) {
      f = (f * 67) & 0xFFFFFFFF;
      f = f * 156;
      f += x;
      f = f & 0xFFFFFF;

      r *= 25;
      r += (x + counter / 32);
      g++;
      g *= (y + counter);
      b *= 31337;
      b += f;
      f = r ^ g;

      // PERF?
      Uint32 color = SDL_MapRGB(surf->format, r, g, b);
      Uint32 *pixels = (Uint32 *)surf->pixels;

      // pixel offset of top-left corner of megapixel
      int o = (y * PIXELSIZE * (WIDTH * PIXELSIZE) + x * PIXELSIZE);
      pixels[o] = color;
      #if PIXELSIZE > 1
      pixels[o + 1] = color;
      pixels[o + (WIDTH * PIXELSIZE)] = color;
      pixels[o + (WIDTH * PIXELSIZE) + 1] = color;
      #endif
      #if PIXELSIZE > 2
      // right column
      pixels[o + 2] = color;
      pixels[o + (WIDTH * PIXELSIZE) + 2] = color;
      pixels[o + (WIDTH * PIXELSIZE) * 2 + 2] = color;
      // bottom row
      pixels[o + (WIDTH * PIXELSIZE) * 2] = color;
      pixels[o + (WIDTH * PIXELSIZE) * 2 + 1] = color;
      #endif
      #if PIXELSIZE > 3
      // right column
      pixels[o + 3] = color;
      pixels[o + (WIDTH * PIXELSIZE) + 3] = color;
      pixels[o + (WIDTH * PIXELSIZE) * 2 + 3] = color;
      pixels[o + (WIDTH * PIXELSIZE) * 3 + 3] = color;
      // bottom row
      pixels[o + (WIDTH * PIXELSIZE) * 3] = color;
      pixels[o + (WIDTH * PIXELSIZE) * 3 + 1] = color;
      pixels[o + (WIDTH * PIXELSIZE) * 3 + 2] = color;
      #endif
      #if PIXELSIZE > 4
      # error Only pixel size 1, 2, 3, 4 are supported.
      #endif
    }
  }
}

int main (int argc, char **argv) {

  if (SDL_Init (SDL_INIT_AUDIO | SDL_INIT_VIDEO | SDL_INIT_TIMER) < 0) {
    fprintf(stderr, "Unable to init SDL: %s\n", SDL_GetError());
    abort();
  }

  fprintf(stderr, "PIXEL TEST\n");

  //  MidiMusicLayer *midi = MidiMusicLayer::Create("sensations.mid");
  //   CHECK(midi);
// XXX use it...

  SDL_EnableUNICODE(1);
  SDL_Surface *screen = sdlutil::makescreen(WIDTH * PIXELSIZE, HEIGHT * PIXELSIZE);
  sdlutil::clearsurface(screen, 1234567);
  SDL_Flip(screen);

  uint64 starttime = time(NULL);

#if 0
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
#endif

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

    FillScreen2x(screen);
    counter++;
    if (counter % 1000 == 0) {
      uint64 now = time(NULL);
      fprintf(stderr, "%d (%.2f fps)\n",
	      counter, counter / (double)(now - starttime));
    }
    SDL_Flip(screen);

    // SDL_Delay(0);
  }

  return 0;
}
