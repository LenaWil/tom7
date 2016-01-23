
// TODO: Bug? Why are scores bigger than 1 until the first reheap?
//
// TODO: Try to deduce that a state is hopeless and stop expanding
// it. -or- try to estimate the maximum reachable score from each
// node using some Bayesian method.
// 
// TODO: Super Meat Brothers-style multi future visualization of tree.
//
// TODO: Get rid of optional heap location? We often need the score.
// TODO: Always expand nodes 100 times or whatever?
//
// TODO: Serialization of tree state and restarting
//
// TODO: Find values we don't want to go down by setting them to 1 or
// zero as they go down (or something), and testing whether that is
// really bad.

#include <algorithm>
#include <vector>
#include <string>
#include <set>
#include <memory>

#ifdef __MINGW32__
#include <windows.h>
#undef ARRAYSIZE
#endif

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
#include "../cc-lib/stb_image_write.h"
#include "../cc-lib/sdl/chars.h"
#include "../cc-lib/sdl/font.h"
#include "../cc-lib/heap.h"
#include "../cc-lib/randutil.h"

#include "atom7ic.h"

#include "motifs.h"
#include "weighted-objectives.h"

#include "SDL.h"

#include "problem-twoplayer.h"

#define WIDTH 1920
#define HEIGHT 1080

// XXX way too small, but I wanna see it churn!
#define MAX_NODES 100000
#define NUM_NEXTS 10

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

static string Rtos(double d) {
  char out[16];
  sprintf(out, "%.5f", d);
  char *o = out;
  while (*o == '0') o++;
  return string{o};
}

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

static void SaveARGB(const vector<uint8> &argb, int width, int height,
		     const string &filename) {
  CHECK(argb.size() == width * height * 4);
  vector<uint8> rgba;
  rgba.resize(width * height * 4);
  for (int i = 0; i < width * height * 4; i += 4) {
    // This is all messed up, maybe because I got ARGB wrong in emu
    // (TODO: fix that) and also stb_ wants little-endian words. But
    // anyway, it works like this.
    uint8 b = argb[i + 0];
    uint8 g = argb[i + 1];
    uint8 r = argb[i + 2];
    uint8 a = argb[i + 3];
    
    rgba[i + 0] = r;
    rgba[i + 1] = g;
    rgba[i + 2] = b;
    rgba[i + 3] = a;
    // 3, 2, 1, 0   / 1 2 3 0 has alpha in the right place at least.
  }
  stbi_write_png(filename.c_str(), width, height, 4, rgba.data(), 4 * width);
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
  using State = Problem::State;
  using Seq = vector<Problem::Input>;
  static constexpr int UPDATE_FREQUENCY = 1000;

  #if 0
  // If set, some worker is expanding this node and it can't
  // be deleted.
  static constexpr uint8 FLAG_IN_USE = 1 << 0;
  static constexpr uint8 FLAG_DELETEME = 1 << 1;
  static constexpr uint8 FLAG_ANOTHER = 1 << 2;

  static_assert(DisjointBits(FLAG_IN_USE,
			     FLAG_DELETEME,
			     FLAG_ANOTHER), "flags share bits??");
  #endif
  
  struct Node {
    Node(State state, Node *parent) : state(std::move(state)),
				      parent(parent) {}
    // Note that this can be recreated by replaying the moves from the
    // root. It once was optional and could be made that way again, at
    // the cost of many complications.
    const State state;

    // Only null for the root.
    Node *parent = nullptr;

    // Child nodes. Currently, no guarantee that these don't
    // share prefixes, but there should not be duplicates.
    map<Seq, Node *> children;

    // Total number of times chosen for expansion. This will
    // be related to the number of children, but can be more
    // in the case that the tree is pruned or children collide.
    int chosen = 0;

    // Number of times that expansion yielded a loss on the
    // objective function. Used to compute the chance that
    // a node is hopeless.
    int was_loss = 0;

    // For heap. Not all nodes will be in the heap.
    int location = -1;

    uint8 num_workers_using = 0;
  };

  Tree(double score, State state) {
    root = new Node(std::move(state), nullptr);
    heap.Insert(-score, root);
  }

  // Tree prioritized by negation of score at current epoch. Not all
  // nodes are guaranteed to be present. Negation is used so that the
  // minimum node is actually the node with the best score.
  Heap<double, Node> heap;

  Node *root = nullptr;
  int steps_until_update = UPDATE_FREQUENCY;
  // If this is true, a thread is updating the tree. It does not
  // necessarily hold the lock, because some calculations can be
  // done without the tree (like sorting observations). If set,
  // another thread should avoid also beginning an update.
  bool update_in_progress = false;
  int64 num_nodes = 0;
};

// Lockless counter. Should only be used for reporting stats in
// the UI since it uses relaxed memory ordering.
struct Counter {
  inline void IncrementBy(int d) {
    value.fetch_add(d, std::memory_order_relaxed);
  }
  inline void Increment() {
    value.fetch_add(1, std::memory_order_relaxed);
  }
  inline int Get() {
    return value.load(std::memory_order_relaxed);
  }
  std::atomic<int> value{0};
};

struct PF2 {
  std::unique_ptr<Motifs> motifs;

  // Should not be modified after initialization.
  std::unique_ptr<Problem> problem;

  // Approximately one per CPU. Created at startup and lives
  // until should_die becomes true. Pointers owned by PF2.
  vector<WorkThread *> workers;
  int num_workers = 0;

  UIThread *ui_thread = nullptr;

  // Initialized by one of the workers with the post-warmup
  // state.
  Tree *tree = nullptr;
  // Coarse locking.
  std::mutex tree_m;

  struct Stats {
    // Generated the same exact move sequence for a node
    // more than once.
    Counter same_expansion;
    Counter sequences_tried;
    Counter sequences_improved;
  };
  Stats stats;
  

  PF2() {
    map<string, string> config = Util::ReadFileToMap("config.txt");
    if (config.empty()) {
      fprintf(stderr, "Missing config.txt.\n");
      abort();
    }

    num_workers = atoi(config["workers"].c_str());
    if (num_workers <= 0) {
      fprintf(stderr, "Warning: In config, 'workers' should be set >0.\n");
      num_workers = 1;
    }
    // An absurd amount, but we want to not overflow 8-bit ref counts.
    if (num_workers > 250) {
      fprintf(stderr, "Warning: In config, 'workers' must be <250.\n");
      num_workers = 250;
    }

    problem.reset(new Problem(config));
    printf("Problem at %p\n", problem.get());
  }

  void StartThreads();
  void DestroyThreads();

  void Play() {
    // Doesn't return until UI thread exits.
    StartThreads();

    DestroyThreads();
  }
};

struct WorkThread {
  using Node = Tree::Node;
  WorkThread(PF2 *pftwo, int id) : pftwo(pftwo), id(id),
				   rc(StringPrintf("worker_%d", id)),
				   gauss(&rc),
				   worker(pftwo->problem->CreateWorker()),
				   th{&WorkThread::Run, this} {}

  // Get the root node of the tree and associated state (which must be
  // present). Used during initialization.
  Node *GetRoot() {
    MutexLock ml(&pftwo->tree_m);
    Node *n = pftwo->tree->root;
    n->num_workers_using++;
    return n;
  }
  
  // Pick the next node to explore. Must increment the chosen field.
  // n is the current node, which may be discarded; this function
  // also maintains correct reference counts.
  Node *FindNodeToExtend(Node *n) {
    MutexLock ml(&pftwo->tree_m);

    CHECK(n->num_workers_using > 0);
    
    // Simple policy: 50% chance of switching to the best node
    // in the heap; 50% chance of staying with the current node.
    if (rc.Byte() < 128 + 64 /* XXX */) {
      const int size = pftwo->tree->heap.Size();
      CHECK(size > 0) << "Heap should always have root, at least.";

      // Gaussian centered on 0; use 0 for anything out of bounds.
      // (n.b. this doesn't seem to help get unstuck -- evaluate it)
      const int g = (int)(gauss.Next() * (size * 0.25));
      const int idx = (g <= 0 || g >= size) ? 0 : g;
      
      Heap<double, Node>::Cell cell = pftwo->tree->heap.GetByIndex(idx);
      Node *ret = cell.value;

      // Now ascend up the tree to avoid picking nodes that have high
      // scores but have been explored at lot (this means it's likely
      // that they're dead ends).
      for (;;) {
	if (ret->parent == nullptr)
	  break;

	double p_to_ascend = 0.1 +
	  // Sigmoid with a chance of ~3.5% for cell that's never been chosen
	  // before, a 50% chance around 300, and a plateau at 80%.
	  (0.8 / (1.0 + exp((ret->chosen - 300.0) * -.01)));
	if (RandDouble(&rc) >= p_to_ascend)
	  break;
	// printf("[A]");
	ret = ret->parent;
      }

      // Giving up on n.
      n->num_workers_using--;
      ret->num_workers_using++;
      
      ret->chosen++;
      return ret;
    } else {
      n->chosen++;
      // Keep reference count.
      return n;
    }
  }

  // Holding a reference to n, extend it and return the new
  // child; drops the reference to n and acquires a reference to
  // the new child.
  Node *ExtendNode(Node *n,
		   const vector<Problem::Input> &step,
		   Problem::State newstate,
		   double newscore) {
    CHECK(n != nullptr);
    Node *child = new Node(std::move(newstate), n);
    MutexLock ml(&pftwo->tree_m);
    
    const double oldscore = pftwo->problem->Score(n->state);
    if (oldscore > newscore) {
      n->was_loss++;
    }

    auto res = n->children.insert({step, child});

    CHECK(n->num_workers_using > 0);
    n->num_workers_using--;

    if (!res.second) {
      // By dumb luck (this might not be that rare if the markov
      // model is sparse), we already have a node with this
      // exact path. We don't allow replacing it.
      pftwo->stats.same_expansion.Increment();
      
      delete child;
      // Maintain the invariant that the worker is at the
      // state of the returned node.
      Node *ch = res.first->second;

      CHECK(ch != nullptr);
      worker->Restore(ch->state);
      ch->num_workers_using++;
      return ch;

    } else {
      pftwo->tree->num_nodes++;
      pftwo->tree->heap.Insert(-newscore, child);
      CHECK(child->location != -1);

      child->num_workers_using++;
      return child;
    }
  }

  void InitializeTree() {
    MutexLock ml(&pftwo->tree_m);
    if (pftwo->tree == nullptr) {
      // I won the race!
      printf("Initialize tree...\n");
      Problem::State s = worker->Save();
      pftwo->tree = new Tree(pftwo->problem->Score(s), s);
    }
  }


  void MaybeUpdateTree() {
    Tree *tree = pftwo->tree;
    {
      MutexLock ml(&pftwo->tree_m);
      // No use in decrementing update counter -- when we
      // finish we reset it to the max value.
      if (tree->update_in_progress)
	return;

      if (tree->steps_until_update == 0) {
	tree->steps_until_update = Tree::UPDATE_FREQUENCY;
	tree->update_in_progress = true;
	// Enter fixup below.
      } else {
	tree->steps_until_update--;
	return;
      }
    }

    // This is run every UPDATE_FREQUENCY calls, in some
    // arbitrary worker thread. We don't hold any locks right
    // now, but only one thread will enter this section at
    // a time because of the update_in_progress flag.
    worker->SetStatus("Tree: Commit observations");

    pftwo->problem->Commit();

    // Re-build heap.
    {
      worker->SetStatus("Tree: Reheap");
      const uint32 start_ms = SDL_GetTicks();
      {
	MutexLock ml(&pftwo->tree_m);
	printf("Reheap ... ");
	// tree->heap.Clear();

	std::function<void(Node *)> ReHeapRec =
	  [this, tree, &ReHeapRec](Node *n) {
	  // Act on the node if it's in the heap. 
	  if (n->location != -1) {
	    const double new_score = pftwo->problem->Score(n->state);
	    // Note negation of score so that bigger real scores
	    // are more minimum for the heap ordering.
	    tree->heap.AdjustPriority(n, -new_score);
	    CHECK(n->location != -1);
	  }
	  for (pair<const Tree::Seq, Node *> &child : n->children) {
	    ReHeapRec(child.second);
	  }
	};
	ReHeapRec(tree->root);
      }
      const uint32 end_ms = SDL_GetTicks();
      printf("Done in %.4f sec.\n", (end_ms - start_ms) / 1000.0);
    }
      
    {
      MutexLock ml(&pftwo->tree_m);
      if (tree->num_nodes > MAX_NODES) {
	const uint32 start_ms = SDL_GetTicks();
	uint64 deleted_nodes = 0ULL;
	printf("Trim tree ...\n");
	// We can't delete any ancestor of a node that's being
	// used, including the node itself.
	// We want to delete the worst scoring nodes.

	vector<double> cutoffs;
	cutoffs.reserve(tree->num_nodes);
	std::function<void(const Node *)> GetScoresRec =
	  // Returns true if any descendant is in use.
	  [this, tree, &cutoffs, &GetScoresRec](const Node *n) {
	  CHECK(n->location != -1);
	  const double score = -tree->heap.GetCell(n).priority;
	  cutoffs.push_back(score);
	  for (const auto &p : n->children) {
	    GetScoresRec(p.second);
	  }
	};
	GetScoresRec(tree->root);

	// Find best scores. PERF: This can be done much faster than
	// sorting the whole array.
	std::sort(cutoffs.begin(), cutoffs.end(), std::greater<double>());
	CHECK(cutoffs.size() > MAX_NODES) << "Should have inserted one "
	  "score for every node in the tree, and we know there are more "
	  "than MAX_NODES of them now: " << cutoffs.size();
	
	const double min_score = cutoffs[MAX_NODES];
	printf("\n ... Min score is %.4f\n", min_score);
	cutoffs.clear();
	
	std::function<bool(Node *)> CleanRec =
	  // Returns true if we should keep this node; otherwise,
	  // the node is deleted.
	  [this, tree, &deleted_nodes, min_score, &CleanRec](Node *n) -> bool {
	  CHECK(n->location != -1);
	  const double score = -tree->heap.GetCell(n).priority;
	  bool keep = n->num_workers_using > 0 || score >= min_score;

	  map<Tree::Seq, Node *> new_children;
	  for (auto &p : n->children) {
	    if (CleanRec(p.second)) {
	      new_children.insert({p.first, p.second});
	      keep = true;
	    }
	  }
	  n->children.swap(new_children);
	  
	  if (!keep) {
	    tree->heap.Delete(n);
	    deleted_nodes++;
	    tree->num_nodes--;
	    CHECK(n->location == -1);
	    delete n;
	  }

	  return keep;
	};

	// This should not happen for multiple reasons -- there should
	// always be a worker working within it, and since it contains
	// all nodes, one of the MAX_NODES best scores should be beneath
	// the root!
	CHECK(CleanRec(tree->root)) << "Uh, the root was deleted.";
	
	const uint32 end_ms = SDL_GetTicks();
	printf(" ... Deleted %llu in %.4f sec. Done.\n",
	       deleted_nodes,
	       (end_ms - start_ms) / 1000.0);
      }
    }

    
    {
      MutexLock ml(&pftwo->tree_m);
      tree->update_in_progress = false;
    }
  }

 
  void Run() {
    worker->Init();

    InitializeTree();


    // Handle to the last node expanded, which will match the current
    // state of the worker. Worker has an outstanding reference count.
    Node *last = nullptr;

    // Initialize the worker so that its previous state is the root.
    // With the current setup it should already be in this state, but
    // it's inexpensive to explicitly establish the invariant.
    {
      worker->SetStatus("Load root");
      last = GetRoot();
      CHECK(last != nullptr);
      worker->Restore(last->state);
    }

    for (;;) {
      // Starting this loop, the worker is in some problem state that
      // corresponds to the node 'last' in the tree. We'll extend this
      // node or find a different one.
      worker->SetStatus("Find start node");
      // XXX too many "Nexts" in this code! Rename to "expand_me" or
      // something
      Node *next = FindNodeToExtend(last);
      
      // PERF skip this if it's the same as last!
      worker->SetStatus("Load");
      CHECK(next != nullptr);
      worker->Restore(next->state);

      worker->SetStatus("Gen inputs");
      int num_frames = gauss.Next() * 100.0 + 200.0;
      if (num_frames < 1) num_frames = 1;

      vector<vector<Problem::Input>> nexts;
      nexts.reserve(NUM_NEXTS);
      for (int num_left = NUM_NEXTS; num_left--;) {
	Problem::InputGenerator gen = worker->Generator();
	vector<Problem::Input> step;
	step.reserve(num_frames);
	for (int frames_left = num_frames; frames_left--;) {
	  step.push_back(gen.RandomInput(&rc));
	}
	nexts.push_back(std::move(step));
      }

      // PERF: Should drop duplicates and drop sequences that
      // are already in the node. Collisions do happen!

      worker->SetDenom(nexts.size());
      double best_score = -1.0;
      std::unique_ptr<Problem::State> best;
      int best_step_idx = -1;
      for (int i = 0; i < nexts.size(); i++) {
	pftwo->stats.sequences_tried.Increment();
	worker->SetStatus("Re-restore");
	if (i != 0) {
	  worker->Restore(next->state);
	}

	worker->SetStatus("Execute");
	worker->SetNumer(i);
	const vector<Problem::Input> &step = nexts[i];
	for (const Problem::Input &input : step) {
	  worker->Exec(input);
	}

	worker->SetStatus("Observe");
	worker->Observe();

	Problem::State state = worker->Save();
	const double score = pftwo->problem->Score(state);
	if (best.get() == nullptr || score > best_score) {
	  if (best.get() != nullptr) {
	    pftwo->stats.sequences_improved.Increment();
	  }
	  best.reset(new Problem::State(std::move(state)));
	  best_step_idx = i;
	  best_score = score;
	}
      }

      worker->SetStatus("Extend tree");
      // TODO: Consider inserting nodes other than the best one?
      // PERF move best?
      last = ExtendNode(next, nexts[best_step_idx], *best, best_score);

      MaybeUpdateTree();
      
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
  // Private gaussian stream, aliasing rc.
  RandomGaussian gauss;
  Problem::Worker *worker = nullptr;
  std::thread th;
};

// Note: This is really the main thread. SDL really doesn't
// like being called outside the main thread, even if it's
// exclusive.
struct UIThread {
  UIThread(PF2 *pftwo) : pftwo(pftwo) {}

  // Dump the tree to the "tree" subdirectory as some HTML/JSON/PNGs.
  // Your responsibility to clean this all up and deal with multiple
  // versions being spit into the same dir.
  void DumpTree() {
    MutexLock ml(&pftwo->tree_m);
    printf("Dumping tree.");
    Util::makedir("tree");

    std::unique_ptr<Worker> tmp{pftwo->problem->CreateWorker()};

    vector<int> expansion_cutoff;
    std::function<void(const Tree::Node *)> Count =
      [this, &expansion_cutoff, &Count](const Tree::Node *node) {
      if (node->chosen > 0) {
	expansion_cutoff.push_back(node->chosen);
      }
      for (const auto &p : node->children) {
	Count(p.second);
      }
    };
    Count(pftwo->tree->root);
    std::sort(expansion_cutoff.begin(), expansion_cutoff.end(),
	      std::greater<int>());

    static constexpr int kMaxImages = 1000;
    const int cutoff = expansion_cutoff.size() > kMaxImages ?
      expansion_cutoff[kMaxImages] : 0;
    expansion_cutoff.clear();
    printf("Nodes expanded more than %d times will have images.\n",
	   cutoff);
    
    int images = 0;
    int node_num = 0;
    std::function<string(const Tree::Node *)> Rec =
      [this, &tmp, cutoff, &images, &node_num, &Rec](const Tree::Node *node) {
      int id = node_num++;
      string ret = StringPrintf("{i:%d", id);
      if (node->location != -1) {
	double score = -pftwo->tree->heap.GetCell(node).priority;
	ret += StringPrintf(",s:%s", Rtos(score).c_str());
      }
      if (node->chosen > 0) {
	ret += StringPrintf(",e:%d,w:%d", node->chosen, node->was_loss);
      }

      if (node->chosen > cutoff) {
	tmp->Restore(node->state);

	// Piercing the veil here.
	// We want the X to indicate the actual value before playing
	// a random move below in order to get a screenshot, so save
	// a copy of the actual memory.
	vector<uint8> xxx = tmp->emu->GetMemory();

	// UGH HACK. After restoring a state we don't have an image
	// unless we make a step. We could replay to here from the parent
	// node, or be storing these in the state (but they are 260kb each!)
	tmp->Exec(tmp->RandomInput(&rc));
	vector<uint8> argb256x256;
	argb256x256.resize(256 * 256 * 4);
	tmp->Visualize(&argb256x256);

	// TODO: Move this visualization to Visualize; it's nice.
	if (xxx[50] < 29) {
	  for (int y = 0; y < 256; y++) {
	    int x = y;
	    // actual color order: b, g, r, a?
	    argb256x256[y * 256 * 4 + x * 4] = 0xFF;
	    if (y < 255)
	      argb256x256[y * 256 * 4 + x * 4 + 4] = 0xFF;
	  }
	}

	if (xxx[51] < 29) {
	  for (int y = 0; y < 256; y++) {
	    int x = 255 - y;
	    argb256x256[y * 256 * 4 + x * 4 + 2] = 0xFF;
	    if (y > 0)
	      argb256x256[y * 256 * 4 + x * 4 + 4 + 2] = 0xFF;
	  }
	}

	SaveARGB(argb256x256, 256, 256, StringPrintf("tree/%d.png", id));
	images++;
	ret += ",g:1";
      }
	
      if (!node->children.empty()) {
	string ch;
	for (const auto &p : node->children) {
	  if (!ch.empty()) ch += ",";
	  // Note, discards sequence.
	  ch += Rec(p.second);
	}
	ret += ",c:[";
	ret += ch;
	ret += "]";
      }
      ret += "}";
      return ret;
    };

    string json = StringPrintf(
	"/* Generated by pftwo.cc. Do not edit! */\n"
	"var treedata = %s\n;",
	Rec(pftwo->tree->root).c_str());
    printf("Wrote %d images. Writing to tree/tree.js\n", images);
    Util::WriteFile("tree/tree.js", json);
  }
  
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

    double start = SDL_GetTicks() / 1000.0;

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

	case SDLK_t:
	  DumpTree();
	  break;
	default:
	  break;
	}
	break;
      default:
	break;
      }

      SDL_Delay(1000.0 / 30.0);

      // Every ten thousand frames, write FM2 file.
      // TODO: Superimpose all of the trees at once.
      if (frame % 10000 == 0) {
	MutexLock ml(&pftwo->tree_m);
	printf("Saving best.\n");
	auto best = pftwo->tree->heap.GetByIndex(0);
	vector<Problem::Input> path_rev;
	const Tree::Node *n = best.value;
	while (n->parent != nullptr) {
	  const Tree::Node *parent = n->parent;

	  auto GetKey = [n, parent]() -> const Tree::Seq * {
	    // Find among my siblings.
	    for (const auto &p : parent->children) {
	      if (p.second == n) {
		return &p.first;
	      }
	    };
	    return nullptr;	    
	  };

	  const Tree::Seq *seq = GetKey();
	  CHECK(seq != nullptr) << "Oops, when saving, I couldn't find "
	    "the path to this node; it must have been misparented!";

	  for (int i = seq->size() - 1; i >= 0; i--) {
	    path_rev.push_back((*seq)[i]);
	  }
	  n = parent;
	}

	// Reverse path.
	vector<Problem::Input> path;
	path.reserve(path_rev.size());
	for (int i = path_rev.size() - 1; i >= 0; i--) {
	  path.push_back(path_rev[i]);
	}
	pftwo->problem->SaveSolution(StringPrintf("frame-%lld", frame),
				     path,
				     best.value->state,
				     "info TODO");
      }

      
      sdlutil::clearsurface(screen, 0x11111111);

      int64 tree_size = ReadWithLock(&pftwo->tree_m, &pftwo->tree->num_nodes);

      font->draw(10, 0, StringPrintf("This is frame %d! "
				     "%lld tree nodes "
				     "%d collisions "
				     "%.2f%% improvement ",
				     frame,
				     tree_size,
				     pftwo->stats.same_expansion.Get(),
				     (pftwo->stats.sequences_improved.Get() *
				      100.0) /
				     pftwo->stats.sequences_tried.Get()));

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
	total_steps += w->nes_frames.load(std::memory_order_relaxed);
      }

      // Update all screenshots.
      vector<vector<string>> texts;
      texts.resize(num_workers);
      for (int i = 0; i < num_workers; i++) {
	Worker *w = pftwo->workers[i]->GetWorker();
	w->Visualize(&screenshots[i]);
	w->VizText(&texts[i]);
      }

      for (int i = 0; i < num_workers; i++) {
	int x = i % 12;
	int y = i / 12;
	BlitARGBHalf(screenshots[i], 256, 256,
		     x * 128, y * 128 + 20, screen);

	for (int t = 0; t < texts[i].size(); t++) {
	  font->draw(x * 128,
		     (y + 1) * 128 + 20 + t * FONTHEIGHT,
		     texts[i][t]);
	}
      }

      // Gather tree statistics.
      struct LevelStats {
	int count = 0;
	int max_chosen = 0;
	int64 chosen = 0;
	int workers = 0;
	double best_score = 0.0;
      };
      vector<LevelStats> levels;

      struct TreeStats {
	int nodes = 0;
	int leaves = 0;
	int64 statebytes = 0LL;
      };
      TreeStats treestats;
      
      std::function<void(int, const Tree::Node *)> GetLevelStats =
	[this, &levels, &treestats, &GetLevelStats](
	    int depth, const Tree::Node *n) {
	while (depth >= levels.size())
	  levels.push_back(LevelStats{});

	treestats.nodes++;
	treestats.statebytes += Problem::StateBytes(n->state);
	
	LevelStats *ls = &levels[depth];
	ls->count++;
	ls->chosen += n->chosen;
	if (n->chosen > ls->max_chosen)
	  ls->max_chosen = n->chosen;
	
	ls->workers += n->num_workers_using;

	if (n->location != -1) {
	  double score = -pftwo->tree->heap.GetCell(n).priority;
	  if (score > ls->best_score) ls->best_score = score;
	  // TODO save node so that we can draw picture?
	}

	if (n->children.empty())
	  treestats.leaves++;
	
	for (const auto &child : n->children) {
	  GetLevelStats(depth + 1, child.second);
	}
      };

      {
	MutexLock ml(&pftwo->tree_m);
	GetLevelStats(0, pftwo->tree->root);
      }

      smallfont->draw(256 * 6 + 10, 220,
		      StringPrintf("^1Tree: ^3%d^< nodes, ^3%d^< leaves, "
				   "^3%lld^< state MB, ^4%.2f^< KB avg",
				   treestats.nodes, treestats.leaves,
				   treestats.statebytes / (1024LL * 1024LL),
				   treestats.statebytes / (1024.0 *
							   treestats.nodes)));
      for (int i = 0; i < levels.size(); i++) {
	string w;
	if (levels[i].workers) {
	  for (int j = 0; j < levels[i].workers; j++)
	    w += '*';
	}

	smallfont->draw(256 * 6 + 10, 230 + i * SMALLFONTHEIGHT,
			StringPrintf("^4%2d^<: ^3%d^< n %lld c %d mc, "
				     "%.3f ^5%s",
				     i, levels[i].count,
				     levels[i].chosen,
				     levels[i].max_chosen,
				     levels[i].best_score,
				     w.c_str()));
      }
      
      const double now = SDL_GetTicks() / 1000.0;
      double sec = now - start;
      font->draw(10, HEIGHT - FONTHEIGHT,
		 StringPrintf("%.2f NES Mframes in %.1f sec = %.2f NES kFPS "
			      "%.2f UI FPS",
			      total_steps / 1000000.0, sec,
			      (total_steps / sec) / 1000.0,
			      frame / sec));

     
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

    smallfont = Font::create(screen,
			     "fontsmall.png",
			     FONTCHARS,
			     SMALLFONTWIDTH, SMALLFONTHEIGHT,
			     FONTSTYLES, 0, 3);
    CHECK(smallfont != nullptr) << "Couldn't load smallfont.";

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
  static constexpr int SMALLFONTWIDTH = 6;
  static constexpr int SMALLFONTHEIGHT = 6;
  
  Font *font = nullptr, *smallfont = nullptr;

  ArcFour rc{"ui_thread"};
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


// The main loop for SDL.
int main(int argc, char *argv[]) {
  (void)CopyARGB;
  (void)BlitARGB;
  (void)HalveARGB;
  
  fprintf(stderr, "Init SDL\n");

  #ifdef __MINGW32__
  if (!SetPriorityClass(GetCurrentProcess(), BELOW_NORMAL_PRIORITY_CLASS)) {
    LOG(FATAL) << "Unable to go to BELOW_NORMAL priority.\n";
  }
  #endif
  
  /* Initialize SDL and network, if we're using it. */
  CHECK(SDL_Init(SDL_INIT_VIDEO) >= 0);
  fprintf(stderr, "SDL initialized OK.\n");

  SDL_Surface *icon = SDL_LoadBMP("icon.bmp");
  if (icon != nullptr) {
    SDL_WM_SetIcon(icon, nullptr);
  }
  
  {
    PF2 pftwo;
    pftwo.Play();
  }

  SDL_Quit();
  return 0;
}
