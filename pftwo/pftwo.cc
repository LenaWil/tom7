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
      #undef PIXEL
    }
  }
  CopyARGB(argb_half, surface);
}

static void BlitARGBHalf(const vector<uint8> &argb, int width, int height,
			 int xpos, int ypos,
			 SDL_Surface *surface) {
  const int halfwidth = width >> 1;
  const int halfheight = height >> 1;
  // argb_half.resize(halfwidth * halfheight * 4);
  for (int y = 0; y < halfheight; y++) {
    int yy = ypos + y;
    Uint8 *p = (Uint8 *)surface->pixels +
      (surface->w * 4 * yy) + xpos * 4;

    for (int x = 0; x < halfwidth; x++) {
      #define PIXEL(i) \
	*p = \
	  Mix4(argb[(y * 2 * width + x * 2) * 4 + (i)], \
	       argb[(y * 2 * width + x * 2 + 1) * 4 + (i)], \
	       argb[((y * 2 + 1) * width + x * 2) * 4 + (i)],	\
	       argb[((y * 2 + 1) * width + x * 2 + 1) * 4 + (i)]); \
	p++
      PIXEL(0);
      PIXEL(1);
      PIXEL(2);
      PIXEL(3);
      #undef PIXEL
    }
  }
  // CopyARGB(argb_half, surface);
}

// Tree of state exploration.
struct Tree {
  using Seq = vector<Problem::Input>;

  struct Node {
    Node(std::shared_ptr<Problem::State> state, Node *parent) :
      state(state), parent(parent) {}
    // Optional, except at the root. This can be recreated by
    // replaying the path from some ancestor.
    std::shared_ptr<Problem::State> state;

    // Only null for the root.
    Node *parent = nullptr;

    // Child nodes. Currently, no guarantee that these don't
    // share prefixes, but there should not be duplicates.
    map<Seq, Node *> children;
  };

  Tree(const Problem::State &state) {
    root = new Node(std::make_shared<Problem::State>(state), nullptr);
  }

  // XXX heap...
  
  Node *root = nullptr;
};


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

  // XXX Need to initialize this tree with the save-state for
  // the very beginning (post warmup), which means designating
  // a single worker to do that. (Or they can all fight over
  // it, I guess.)
  Tree *tree = nullptr;
  // Coarse locking.
  std::mutex tree_m;

  
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
	
	// sdlutil::clearsurface(screen, 0x00000000);

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

  // XXX: This is a silly policy. Use a heap or something...
  pair<Tree::Node *, shared_ptr<Problem::State>> Descend(Tree::Node *n) {
    MutexLock ml(&pftwo->tree_m);
    for (;;) {
      CHECK(n != nullptr);
      // If a leaf, it must have a state, and we must return it.
      if (n->children.empty()) {
	CHECK(n->state.get() != nullptr);
	return {n, n->state};
      }
    
      if (n->state.get() != nullptr && rc.Byte() < 16)
	return {n, n->state};
    
      int idx = RandTo(&rc, n->children.size());
      auto it = n->children.begin();
      while (idx--) ++it;
      n = it->second;
    }
  }

  Tree::Node *Ascend(Tree::Node *n) {
    MutexLock ml(&pftwo->tree_m);
    while (n->parent != nullptr && rc.Byte() < 128) {
      n = n->parent;
    }
    return n;
  }

  Tree::Node *ExtendNode(Tree::Node *n,
			 const vector<Problem::Input> &step,
			 shared_ptr<Problem::State> newstate) {
    CHECK(n != nullptr);
    Tree::Node *child = new Tree::Node(newstate, n);
    MutexLock ml(&pftwo->tree_m);
    auto res = n->children.insert({step, child});
    if (!res.second) {
      // By dumb luck, we already have a node with this
      // exact path. We don't allow replacing it.
      delete child;
      // Maintain the invariant that the worker is at the
      // state of the returned node.
      Tree::Node *ch = res.first->second;
      // Just find any descendant with a state. Eventually
      // we get to a leaf, which must have a state.
      for (;;) {
	CHECK(ch != nullptr);
	if (ch->state.get() != nullptr) {
	  worker->Restore(*ch->state);
	  return ch;
	}
	CHECK(!ch->children.empty());
	ch = ch->children.begin()->second;
      }
    } else {
      return child;
    }
  }
  
  void InitializeTree() {
    MutexLock ml(&pftwo->tree_m);
    if (pftwo->tree == nullptr) {
      // I won the race!
      pftwo->tree = new Tree(worker->Save());
    }
  }

  void Run() {
    worker->Init();

    InitializeTree();

    Tree::Node *last = pftwo->tree->root;
    CHECK(last != nullptr);

    static constexpr int FRAMES_PER_STEP = 40;
    
    worker->SetDenom(50000 * FRAMES_PER_STEP);
    for (int i = 0; i < 50000; i++) {
      worker->SetNumer(i * FRAMES_PER_STEP);
      worker->SetStatus("Find start node");
      Tree::Node *next;
      shared_ptr<Problem::State> state;
      std::tie(next, state) = Descend(Ascend(last));

      // PERF skip this if it's the same as last?
      worker->SetStatus("Load");
      CHECK(next != nullptr);
      CHECK(state.get() != nullptr);
      worker->Restore(*state);
      
      worker->SetStatus("Make inputs");
      vector<Problem::Input> step;
      step.reserve(40);
      for (int num_left = FRAMES_PER_STEP; num_left--;)
	step.push_back(worker->RandomInput(&rc));

      worker->SetStatus("Execute inputs");
      for (const Problem::Input &input : step)
	worker->Exec(input);

      worker->SetStatus("Update tree.");
      shared_ptr<Problem::State> newstate{
	new Problem::State(worker->Save())};
      last = ExtendNode(next, step, newstate);

      worker->SetStatus("Check for death");
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
	int x = i % 12;
	int y = i / 12;
	BlitARGBHalf(screenshots[i], 256, 256,
		     x * 128, y * 128 + 20, screen);
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
