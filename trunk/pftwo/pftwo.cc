#include <vector>
#include <string>
#include <set>
#include <memory>

#include <cstdio>
#include <cstdlib>

#include "pftwo.h"

#include "../fceulib/emulator.h"
#include "../fceulib/simplefm2.h"
#include "../cc-lib/sdl/sdlutil.h"
#include "../cc-lib/util.h"
#include "../cc-lib/arcfour.h"
#include "../cc-lib/textsvg.h"
#include "../cc-lib/stb_image.h"
#include "../cc-lib/sdl/chars.h"
#include "../cc-lib/sdl/font.h"


#include "atom7ic.h"

#include "motifs.h"
#include "weighted-objectives.h"

#include "SDL.h"

#include "problem-twoplayer.h"

#define WIDTH 1920
#define HEIGHT 1080

// "Functor"
using Problem = TwoPlayerProblem;
using Worker = Problem::Worker;

struct PF2;
struct WorkThread;
struct UIThread;

std::mutex print_mutex;
#define Printf(fmt, ...) do {			\
    MutexLock Printf_ml(&print_mutex);		\
    printf(fmt, ##__VA_ARGS__);			\
  } while (0)

// TODO(twm): use shared_mutex when available
static bool should_die = false;
static mutex should_die_m;

// assumes ARGB, surfaces exactly the same size, etc.
static void CopyARGB(const vector<uint8> &argb, SDL_Surface *surface) {
  // int bpp = surface->format->BytesPerPixel;
  Uint8 * p = (Uint8 *)surface->pixels;
  memcpy(p, argb.data(), surface->w * surface->h * 4);
}

static void BlitARGB(const vector<uint8> &argb, int w, int h,
		     int x, int y, SDL_Surface *surface) {
  for (int i = 0; i < h; i++) {
    int yy = y + i;
    Uint8 *p = (Uint8 *)surface->pixels +
      (surface->w * 4 * yy) + x * 4;
    memcpy(p, argb.data() + (i * w * 4), w * 4);
  }
}

static inline constexpr uint8 Mix4(uint8 v1, uint8 v2, uint8 v3, uint8 v4) {
  return (uint8)(((uint32)v1 + (uint32)v2 + (uint32)v3 + (uint32)v4) >> 2);
}

static void HalveARGB(const vector<uint8> &argb, int width, int height,
		      SDL_Surface *surface) {
  // PERF
  const int halfwidth = width >> 1;
  const int halfheight = height >> 1;
  vector<uint8> argb_half;
  argb_half.resize(halfwidth * halfheight * 4);
  for (int y = 0; y < halfheight; y++) {
    for (int x = 0; x < halfwidth; x++) {
      #define PIXEL(i) \
	argb_half[(y * halfwidth + x) * 4 + (i)] =	\
	  Mix4(argb[(y * 2 * width + x * 2) * 4 + (i)], \
	       argb[(y * 2 * width + x * 2 + 1) * 4 + (i)], \
	       argb[((y * 2 + 1) * width + x * 2) * 4 + (i)],	\
	       argb[((y * 2 + 1) * width + x * 2 + 1) * 4 + (i)])
      PIXEL(0);
      PIXEL(1);
      PIXEL(2);
      PIXEL(3);
    }
  }
  CopyARGB(argb_half, surface);
}

struct PF2 {
  std::unique_ptr<WeightedObjectives> objectives;
  std::unique_ptr<Motifs> motifs;

  // Should not be modified after initialization.
  std::unique_ptr<Problem> problem;

  // Approximately one per CPU. Created at startup and lives
  // until should_die becomes true. Pointers owned by PF2.
  vector<WorkThread *> workers;
  int num_workers = 0;

  UIThread *ui_thread = nullptr;
  
  PF2() {
    map<string, string> config = Util::ReadFileToMap("config.txt");
    if (config.empty()) {
      fprintf(stderr, "Missing config.txt.\n");
      abort();
    }

    string game = config["game"];
    const string moviename = config["movie"];
    CHECK(!game.empty());
    CHECK(!moviename.empty());

    // XXX: Note, contra was only trained on 1P inputs.
    objectives.reset(WeightedObjectives::LoadFromFile(game + ".objectives"));
    CHECK(objectives.get());
    fprintf(stderr, "Loaded %d objective functions\n", (int)objectives->Size());

    motifs.reset(Motifs::LoadFromFile(game + ".motifs"));
    CHECK(motifs);

    num_workers = atoi(config["workers"].c_str());
    if (num_workers <= 0) {
      fprintf(stderr, "Warning: In config, 'workers' should be set >0.\n");
      num_workers = 1;
    }

    problem.reset(new Problem);
  }

  void StartThreads();
  void DestroyThreads();
  
  void Play() {
    // Doesn't return until UI thread exits.
    StartThreads();
    
    DestroyThreads();
    
#if 0
      SDL_Delay(1000.0 / 60.0);
      
      emu->StepFull(inputa, inputb);

      if (frame % 1 == 0) {
	vector<uint8> image = emu->GetImageARGB();
	CopyARGB(image, surf);
	HalveARGB(image, 256, 256, surfhalf);
	
	sdlutil::clearsurface(screen, 0x00000000);

	// Draw pixels to screen...
	sdlutil::blitall(surf, screen, 0, 0);
	sdlutil::blitall(surfhalf, screen, 260, 0);
	
	SDL_Flip(screen);
      }
    }
    #endif
  }
};

struct WorkThread {
  WorkThread(PF2 *pftwo, int id) : pftwo(pftwo), id(id),
				   rc(StringPrintf("worker_%d", id)),
				   worker(pftwo->problem->CreateWorker()),
				   th{&WorkThread::Run, this} {}

  void Run() {
    worker->Init();
    worker->SetDenom(500000);
    for (int i = 0; i < 500000; i++) {
      worker->SetNumer(i);
      worker->SetStatus("Random inputs");

      Problem::Input input = worker->RandomInput(&rc);
      worker->Exec(input);
      
      if (ReadWithLock(&should_die_m, &should_die)) {
	worker->SetStatus("Die");
	return;
      }
    }
  }

  // Expects that should_die is true or will become true.
  ~WorkThread() {
    Printf("Worker %d shutting down...\n", id);
    th.join();
    Printf("Worker %d done.\n", id);
  }

  Worker *GetWorker() const { return worker; }
  
private:
  PF2 *pftwo = nullptr;
  const int id = 0;
  // Distinct private stream.
  ArcFour rc;
  Problem::Worker *worker = nullptr;
  std::thread th;
};

// Note: This is really the main thread.
struct UIThread {
  UIThread(PF2 *pftwo) : pftwo(pftwo) {}

  void Loop() {
    SDL_Surface *surf = sdlutil::makesurface(256, 256, true);
    SDL_Surface *surfhalf = sdlutil::makesurface(128, 128, true);
    (void)frame;
    (void)surf;
    (void)surfhalf;

    const int num_workers = pftwo->workers.size();
    vector<vector<uint8>> screenshots;
    screenshots.resize(num_workers);
    for (auto &v : screenshots) v.resize(256 * 256 * 4);

    const int64 start = time(nullptr);
    
    for (;;) {
      frame++;
      SDL_Event event;
      SDL_PollEvent(&event);
      switch (event.type) {
      case SDL_QUIT:
	return;
      case SDL_KEYDOWN:
	switch (event.key.keysym.sym) {
	  
	case SDLK_ESCAPE:
	  return;
	default:;
	}
	break;
      default:;
      }
      
      SDL_Delay(1000.0 / 60.0);

      sdlutil::clearsurface(screen, 0x33333333);
      /*
      sdlutil::clearsurface(screen,
			    (frame * 0xDEADBEEF));
      */

      font->draw(10, 10, StringPrintf("This is frame %d!", frame));

      int64 total_steps = 0ll;
      for (int i = 0; i < pftwo->workers.size(); i++) {
	const Worker *w = pftwo->workers[i]->GetWorker();
	int numer = w->numer.load(std::memory_order_relaxed);
	font->draw(256 * 6 + 10, 40 + FONTHEIGHT * i,
		   StringPrintf("[%d] %d/%d %s",
				i,
				numer,
				w->denom.load(std::memory_order_relaxed),
				w->status.load(std::memory_order_relaxed)));
	total_steps += numer;
      }

      // Update all screenshots.
      for (int i = 0; i < num_workers; i++) {
	Worker *w = pftwo->workers[i]->GetWorker();
	w->Visualize(&screenshots[i]);
      }

      for (int i = 0; i < num_workers; i++) {
	int x = i % 6;
	int y = i / 6;
	BlitARGB(screenshots[i], 256, 256,
		 x * 256, y * 256 + 20, screen);
      }
      
      const int64 now = time(nullptr);
      double sec = (now - start);
      font->draw(10, HEIGHT - FONTHEIGHT,
		 StringPrintf("%lld NES frames in %.0f sec = %.2f NES FPS",
			      total_steps, sec,
			      total_steps / sec));
      
      SDL_Flip(screen);
    }
    
  }
  
  void Run() {
    screen = sdlutil::makescreen(WIDTH, HEIGHT);
    CHECK(screen);

    font = Font::create(screen,
			"font.png",
			FONTCHARS,
			FONTWIDTH, FONTHEIGHT, FONTSTYLES, 1, 3);
    CHECK(font != nullptr) << "Couldn't load font.";

    
    Loop();
    Printf("UI shutdown.\n");
    WriteWithLock(&should_die_m, &should_die, true);
  }

  ~UIThread() {
    // XXX free screen
    delete font;
  }
  
 private:
  static constexpr int FONTWIDTH = 9;
  static constexpr int FONTHEIGHT = 16;

  Font *font = nullptr;

  PF2 *pftwo = nullptr;
  SDL_Surface *screen = nullptr;
  int64 frame = 0LL;
};

void PF2::StartThreads() {
  CHECK(workers.empty());
  CHECK(num_workers > 0);
  workers.reserve(num_workers);
  for (int i = 0; i < num_workers; i++) {
    workers.push_back(new WorkThread(this, i));
  }

  ui_thread = new UIThread(this);
  ui_thread->Run();
}

void PF2::DestroyThreads() {
  delete ui_thread;
  ui_thread = nullptr;
  for (WorkThread *wt : workers)
    delete wt;
  workers.clear();
}

/**
 * The main loop for the SDL.
 */
int main(int argc, char *argv[]) {
  fprintf(stderr, "Init SDL\n");

  /* Initialize SDL and network, if we're using it. */
  CHECK(SDL_Init(SDL_INIT_VIDEO) >= 0);
  fprintf(stderr, "SDL initialized OK.\n");

  {
    PF2 pftwo;
    pftwo.Play();
  }

  SDL_Quit();
  return 0;
}
