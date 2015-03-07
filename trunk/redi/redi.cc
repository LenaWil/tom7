#include <CL/cl.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include <algorithm>
#include <tuple>
#include <utility>
#include <set>
#include <vector>
#include <map>
#include <unordered_set>

#include "base/stringprintf.h"
#include "base/logging.h"
#include "arcfour.h"
#include "util.h"
#include "timer.h"
#include "stb_image.h"
#include "stb_image_write.h"
#include "stb_truetype.h"

#include "threadutil.h"
#include "clutil.h"
#include "randutil.h"

#include "constants.h"

using namespace std;

// Little byte machine.
using uint8 = uint8_t;
// Better compatibility with CL.
using uchar = uint8_t;

using uint32 = uint32_t;
using uint64 = uint64_t;

// You can read the previous versions (redi-random.cc) to see some of
// the history / thoughts.

// static_assert((NPP >= 3), "Must have at least R, G, B pixels.");
// static_assert((NEIGHBORHOOD & 1) == 1, "neighborhood must be odd.");
// static_assert((NUM_NODES % CHUNK_SIZE) == 0, "chunk size must divide input.");

// static_assert(RANDOM == 0, "random not yet supported.");

template<class C>
static void DeleteElements(C *cont) {
  for (auto &elt : *cont) {
    delete elt;
  }
  cont->clear();
}

struct ImageRGBA {
  static ImageRGBA *Load(const string &filename) {
    vector<uint8> ret;
    int width, height, bpp_unused;
    uint8 *stb_rgba = stbi_load(filename.c_str(), 
				&width, &height, &bpp_unused, 4);
    const int bytes = width * height * 4;
    ret.resize(bytes);
    if (stb_rgba == nullptr) return nullptr;
    memcpy(ret.data(), stb_rgba, bytes);
    // Does this move image data all the way in, or do we need to
    // write a move constructor manually? Better way?
    return new ImageRGBA(std::move(ret), width, height);
  }

  ImageRGBA(const vector<uint8> &rgba, int width, int height) 
    : width(width), height(height), rgba(rgba) {
    CHECK(rgba.size() == width * height * 4);
  }

  void Save(const string &filename) {
    CHECK(rgba.size() == width * height * 4);
    stbi_write_png(filename.c_str(), width, height, 4, rgba.data(), 4 * width);
  }

  ImageRGBA *Copy() const {
    return new ImageRGBA(rgba, width, height);
  }

  // TODO:: Save a vector of images of the same size in a grid.
  const int width, height;
  vector<uint8> rgba;
};

// Single-channel bitmap.
struct ImageA {
  ImageA(const vector<uint8> &alpha, int width, int height)
    : width(width), height(height), alpha(alpha) {
    CHECK(alpha.size() == width * height);
  }
  const int width, height;
  vector<uint8> alpha;
};

// Pretty much only useful for this application since it loads the whole font each time.
ImageA *FontChar(const string &filename, char c, int size) {
  printf("Fopen...\n");
  fflush(stdout);

  FILE *file = fopen(filename.c_str(), "rb");
  if (file == nullptr) {
    fprintf(stderr, "Failed to fopen %s\n", filename.c_str());
    return nullptr;
  }
  printf("fopen ok\n");
  // XXX check read size
  uint8 *ttf_buffer = (uint8*)malloc(1<<25);
  fread(ttf_buffer, 1, 1 << 25, file);
  fclose(file);
  printf("Fread ok.\n");

  stbtt_fontinfo font;
  stbtt_InitFont(&font, ttf_buffer, stbtt_GetFontOffsetForIndex(ttf_buffer, 0));
  int width, height;
  uint8 *bitmap = stbtt_GetCodepointBitmap(&font, 0, stbtt_ScaleForPixelHeight(&font, size),
					   c, &width, &height, 0, 0);
  if (bitmap == nullptr) {
    fprintf(stderr, "Failed to getcodepoint\n");
    free(ttf_buffer);
    return nullptr;
  }
  const int bytes = width * height;
  vector<uint8> ret;
  ret.resize(bytes);
  memcpy(ret.data(), bitmap, bytes);
  free(ttf_buffer);
  return new ImageA(ret, width, height);
}

void BlitChannel(uint8 r, uint8 g, uint8 b, const ImageA &channel, 
		 int xpos, int ypos,
		 ImageRGBA *dest) {
  for (int y = 0; y < channel.height; y++) {
    int dsty = ypos + y;
    if (dsty >= 0 && dsty < dest->height) {
      for (int x = 0; x < channel.width; x++) {
	int dstx = xpos + x;
	if (dstx >= 0 && dstx <= dest->width) {
	  int sidx = x + channel.width * y;
	  int ch = channel.alpha[sidx];

	  auto Blend = [&dest](int idx, uint8 val, uint8 a) {
	    uint8 old = dest->rgba[idx];
	    uint8 oma = 0xFF - a;
	    uint8 replacement = ((oma * (int)old) + (a * (int)val)) >> 8;
	    dest->rgba[idx] = replacement;
	  };

	  int didx = dstx * 4 + (dsty * dest->width) * 4;
	  Blend(didx + 0, r, ch);
	  Blend(didx + 1, g, ch);
	  Blend(didx + 2, b, ch);
	  dest->rgba[didx + 3] = 0xFF;
	  /*
	  dest->rgba[didx + 0] = r;
	  dest->rgba[didx + 1] = g;
	  dest->rgba[didx + 2] = b;
	  dest->rgba[didx + 3] = ch;
	  */
	}
      }
    }
  }
}

struct Network {
  // Creates arrays of the appropriate size, but all zeroes.
  Network(int num_layers) : 
    num_layers(num_layers),
    indices(num_layers, vector<uint32>(INDICES_PER_NODE * NUM_NODES, 0)),
    weights(num_layers, vector<float>(INDICES_PER_NODE * NUM_NODES, 0.0f)),
    biases(num_layers, vector<float>(NUM_NODES, 0.0f)) {
  }
  int64 Bytes() const {
    return (INDICES_PER_NODE * NUM_NODES * sizeof (uint32) * num_layers) +
      (INDICES_PER_NODE * NUM_NODES * sizeof (float) * num_layers) +
      (NUM_NODES * sizeof (float) * num_layers);
  }

  // The number of "real" layers, that is, not counting the input.
  const int num_layers;

  // For each of these fields, the outer vector has size num_layers.
  // INDICES_PER_NODE * NUM_NODES
  vector<vector<uint32>> indices;
  // INDICES_PER_NODE * NUM_NODES
  vector<vector<float>> weights;
  // NUM_NODES
  vector<vector<float>> biases;

  // TODO: Also need inverted indices.
};

struct Stimulation {
  // PERF is this really the fastest way? It seems to involve a bunch
  // of vector copies.
  Stimulation(int num_layers) :
    num_layers(num_layers),
    values(num_layers + 1, vector<float>(NUM_NODES, 0.0f)) {
  }
  int64 Bytes() const {
    return (num_layers + 1) * NUM_NODES * sizeof (float);
  }

  // Same as in Network.
  const int num_layers;

  // Keep track of what's actually been computed?

  // Here the outer vector has size num_layers + 1; first is the input.
  // Inner vector is size NUM_NODES, and just contains their output values.
  vector<vector<float>> values;
};

struct Errors {
  const int num_layers;
  // XXX HERE
};

struct ForwardLayerCL {
  explicit ForwardLayerCL(CL *cl) : cl(cl) {
    const string kernel_src = 
      Util::ReadFile("constants.h") + "\n" +
      Util::ReadFile("forwardlayer.cl");

    std::tie(program, kernel) = cl->BuildOneKernel(kernel_src, "ForwardLayer");
  }

  struct ForwardContext {
    ForwardContext(ForwardLayerCL *parent, const Network &net, int layer) :
      parent(parent), net(net), layer(layer) {
      CL *cl = parent->cl;
      indices = MoveMemoryToGPUConst(cl->context, cl->queue, net.indices[layer]);
      weights = MoveMemoryToGPUConst(cl->context, cl->queue, net.weights[layer]);
      biases = MoveMemoryToGPUConst(cl->context, cl->queue, net.biases[layer]);
    }

    void Forward(Stimulation *stim) {
      CHECK_LT(layer + 1, stim->values.size());

      CL *cl = parent->cl;

      // Technically these are thread-safe, but we should avoid moving lots of memory
      // onto the GPU before we can use it, because our working set for one kernel call
      // is pretty sizable compared to total gpu memory!
      cl_mem src_values = MoveMemoryToGPUConst(cl->context, cl->queue,
					       stim->values[layer]);
      cl_mem dst_values = CreateUninitializedGPUMemory<float>(cl->context,
							      SIZE * SIZE * NPP);

      // Can't have multiple threads setting a kernel's argument at one time.
      {
	MutexLock ml(&parent->m);

	CHECK_SUCCESS(clSetKernelArg(parent->kernel, 0, sizeof(cl_mem), (void *)&src_values));
	CHECK_SUCCESS(clSetKernelArg(parent->kernel, 1, sizeof(cl_mem), (void *)&indices));
	CHECK_SUCCESS(clSetKernelArg(parent->kernel, 2, sizeof(cl_mem), (void *)&weights));
	CHECK_SUCCESS(clSetKernelArg(parent->kernel, 3, sizeof(cl_mem), (void *)&biases));
	CHECK_SUCCESS(clSetKernelArg(parent->kernel, 4, sizeof(cl_mem), (void *)&dst_values));

	size_t global_work_offset[] = { 0 };
	size_t global_work_size[] = { (size_t)(SIZE * SIZE * NPP) };
	Timer kernel_timer;
	CHECK(CL_SUCCESS == clEnqueueNDRangeKernel(cl->queue, parent->kernel, 
						   // work dimensions
						   1, 
						   // global work offset
						   global_work_offset,
						   // global work size
						   global_work_size, 
						   // local work size
						   nullptr, 
						   // no wait list
						   0, nullptr, 
						   // no event
						   nullptr));
	clFinish(cl->queue);
	kernel_ms += kernel_timer.MS();
      }

      // Immediately release stuff we don't need any more; other threads may be trying
      // to get GPU resources in parallel.
      CHECK_SUCCESS(clReleaseMemObject(src_values));

      CopyBufferFromGPUTo<float>(cl->queue, dst_values, &stim->values[layer + 1]);

      CHECK_SUCCESS(clReleaseMemObject(dst_values));
    }
    
    ~ForwardContext() {
      CHECK_SUCCESS(clReleaseMemObject(indices));
      CHECK_SUCCESS(clReleaseMemObject(weights));
      CHECK_SUCCESS(clReleaseMemObject(biases));
    }

    cl_mem indices;
    cl_mem weights;
    cl_mem biases;
    ForwardLayerCL *parent = nullptr;
    const Network &net;
    const int layer;
    double kernel_ms = 0.0;
  };

  ~ForwardLayerCL() {
    CHECK_SUCCESS(clReleaseKernel(kernel));
    CHECK_SUCCESS(clReleaseProgram(program));
  }

  CL *cl = nullptr;
  // Owned:
  cl_program program;
  cl_kernel kernel;

  std::mutex m;
};

static void InitializeLayerFromImage(const ImageRGBA *rgba, vector<float> *values) {
  CHECK_EQ(SIZE, rgba->width);
  CHECK_EQ(SIZE, rgba->height);
  CHECK_EQ(values->size(), NUM_NODES);
  int dst = 0;
  for (int i = 0; i < SIZE * SIZE; i++) {
    (*values)[dst++] = rgba->rgba[3 * i] / 255.0;
    (*values)[dst++] = rgba->rgba[3 * i + 1] / 255.0;
    (*values)[dst++] = rgba->rgba[3 * i + 2] / 255.0;
    for (int j = 0; j < NPP - 3; j++) {
      (*values)[dst++] = 0.0f;
    }
  }
  CHECK_EQ(dst, NUM_NODES);
}

// Make indices. This assumes that nodes are 2D pixel data where we have
// SIZE * SIZE pixels, NPP nodes per pixel, in row-major order.
//
// We mostly sample from a Gaussian near each pixel, but:
//  - we reject duplicates (inefficient),
//  - we reject pixels off the image (doesn't make sense; wrapping around
//      would work but an image is not a torus)
//  - we require that a small neighborhood around the pixel is mapped
//      directly (especially the pixel itself; this preserves spatial
//      locality and makes sure we don't have any statically dead nodes).
static void MakeIndices(ArcFour *rc, Network *net) {
  static constexpr double STDDEV = SIZE / 4.0;
  static constexpr int NEIGHBORHOOD = 5;

  // For best results, use false, true:
  static constexpr bool SYMMETRIC_GAUSSIAN = false;
  static constexpr bool GAUSSIAN = true;

  static_assert(STDDEV > 1.0, "surprisingly small stddev");
  static_assert(NEIGHBORHOOD >= 0, "must include the pixel itself.");
  static_assert(NEIGHBORHOOD * NEIGHBORHOOD * NPP <= INDICES_PER_NODE,
		"neighborhood doesn't fit in indices!");
  auto OneNode = [](ArcFour *rc, int x, int y, int channel) -> vector<uint32> {
    // PERF if not parallel, this can be outside and waste fewer tails...
    RandomGaussian gauss{rc};
    // (Note that channel is unused: The neighborhood is the same for each
    // channel because we insert all NPP nodes for each source. Random sources
    // are separate but don't depend on channel.)
    // Use set for deduplication, and so that we output them with maximum
    // locality.
    unordered_set<int> indices;
    // clips xx,yy if they are out of the image, but cc must be a valid
    // channel in [0, NPP).
    auto AddNodeByCoordinates = [&indices](int xx, int yy, int cc) {
      CHECK_GE(cc, 0);
      CHECK_LT(cc, NPP);
      if (xx < 0 || yy < 0 || xx >= SIZE || yy >= SIZE) return;
      int idx = (yy * SIZE * NPP) + (xx * NPP) + cc;
      CHECK_GE(idx, 0);
      CHECK_LT(idx, NUM_NODES);
      indices.insert(idx);
    };
    
    for (int ny = -NEIGHBORHOOD; ny <= NEIGHBORHOOD; ny++) {
      for (int nx = -NEIGHBORHOOD; nx <= NEIGHBORHOOD; nx++) {
	for (int c = 0; c < NPP; c++) {
	  // We take all three (or NPP) channels. Note that the pixel
	  // may be clipped.
	  AddNodeByCoordinates(x + nx, y + ny, c);
	}
      }
    }

    CHECK_LE(indices.size(), INDICES_PER_NODE);

    if (GAUSSIAN) {
      while (indices.size() < INDICES_PER_NODE) {
	double dx = gauss.Next() * STDDEV;
	double dy = gauss.Next() * STDDEV;

	// XXX tiny bias if NPP doesn't divide 2^32. Make RandTo function.
	int ch = Rand32(rc) % NPP;
	// Insert symmetrically...
	AddNodeByCoordinates((int)(x + dx), (int)(y + dy), ch);
	if (SYMMETRIC_GAUSSIAN) {
	  if (indices.size() < INDICES_PER_NODE)
	    AddNodeByCoordinates((int)(x - dx), (int)(y + dy), ch);
	  if (indices.size() < INDICES_PER_NODE)
	    AddNodeByCoordinates((int)(x - dx), (int)(y - dy), ch);
	  if (indices.size() < INDICES_PER_NODE)
	    AddNodeByCoordinates((int)(x + dx), (int)(y - dy), ch);
	}
      }
    } else {
      while (indices.size() < INDICES_PER_NODE) {
	// Assuming power of two...
	int dx = Rand32(rc) % SIZE;
	int dy = Rand32(rc) % SIZE;
	// XXX tiny bias if NPP doesn't divide 2^32. Make RandTo function.
	int ch = Rand32(rc) % NPP;

	AddNodeByCoordinates(dx, dy, ch);
      }
    }

    CHECK_EQ(INDICES_PER_NODE, indices.size());
    vector<uint32> ret;
    ret.reserve(INDICES_PER_NODE);
    for (int idx : indices) {
      CHECK_GE(idx, 0);
      CHECK_LT(idx, NUM_NODES);
      ret.push_back(idx);
    }
    return ret;
  };

  // This must access rc serially.
  vector<ArcFour *> rcs;
  for (int i = 0; i < net->num_layers; i++) rcs.push_back(Substream(rc, i));

  // Just for printf.
  std::mutex m;
  ParallelComp(net->num_layers, [&m, &rcs, &OneNode, &net](int layer) {
    printf("Intializing indices for layer %d...\n", layer);
    int node_idx = 0;
    vector<uint32> *layer_indices = &net->indices[layer];
    for (int y = 0; y < SIZE; y++) {
      for (int x = 0; x < SIZE; x++) {
	for (int c = 0; c < NPP; c++) {
	  vector<uint32> indices = OneNode(rcs[layer], x, y, c);
	  // Sort them, for better locality of access later.
	  std::sort(indices.begin(), indices.end());
	  CHECK_EQ(INDICES_PER_NODE, indices.size());
	  const int start_idx = node_idx * INDICES_PER_NODE;
	  for (int i = 0; i < INDICES_PER_NODE; i++) {
	    (*layer_indices)[start_idx + i] = indices[i];
	  }
	  node_idx++;
	}
      }
      if (y % 10 == 0) {
	MutexLock ml(&m);
	printf("  [%d/%d] %.1f%%\n", y, SIZE, (100.0 * y) / SIZE);
      }
    }
  }, 12);

  DeleteElements(&rcs);
}

// Randomize the weights in a network. Doesn't do anything to indices.
static void RandomizeNetwork(ArcFour *rc, Network *net) {
  auto RandomizeFloats = [](ArcFour *rc, vector<float> *vec) {
    for (int i = 0; i < vec->size(); i++) {
      (*vec)[i] = RandFloat(rc) - 0.5f;
    }
  };

  // This must access rc serially.
  vector<ArcFour *> rcs;
  for (int i = 0; i < net->num_layers; i++) rcs.push_back(Substream(rc, i));

  // But now we can do all layers in parallel.
  ParallelComp(net->num_layers, [&rcs, &RandomizeFloats, &net](int i) {
    RandomizeFloats(rcs[i], &net->biases[i]);
    RandomizeFloats(rcs[i], &net->weights[i]);
  }, 12);

  DeleteElements(&rcs);
}

template<class A, class F>
static auto Map(const vector<A> &vec, const F &f) -> vector<decltype(f(vec[0]))> {
  using B = decltype(f(vec[0]));
  vector<B> ret;
  ret.resize(vec.size());
  for (int i = 0; i < vec.size(); i++) {
    ret[i] = f(vec[i]);
  }
  return ret;
}

template<class A, class F>
static void App(const vector<A> &vec, const F &f) {
  for (const auto &elt : vec) f(elt);
}

int main(int argc, char* argv[]) {
  Timer setup_timer;
  ArcFour rc("redi");
  rc.Discard(2000);

  CL cl;

  // Create kernels right away so that we get compilation errors early.
  ForwardLayerCL forwardlayer{&cl};

  vector<string> filenames = 
    // So gratuitous to use parallel map here..
    ParallelMap(Util::ListFiles("corpus256/"),
		[](const string &s) -> string { return (string)"corpus256/" + s; },
		8);

  printf("Loading %d...\n", (int)filenames.size());
  vector<ImageRGBA *> corpus =
    ParallelMap(filenames,
		[](const string &s) { return ImageRGBA::Load(s); },
		16);
  CHECK(corpus.size() > 0);

  // XXXXXXX
  corpus.resize(100);

  vector<string> font_filenames = Util::ListFiles("fonts/");
  vector<ImageA *> fonts =
    ParallelMap(font_filenames,
		[](const string &s) { 
		  ImageA *f = FontChar((string)"fonts/" + s, 'i', 80); 
		  CHECK(f != nullptr) << s;
		  return f;
		},
		16);
  CHECK(fonts.size() > 0);

  // Create the initial network.
  // TODO: Serialize and load from disk if we have one.
  Timer initialize_network_timer;
  static constexpr int NUM_LAYERS = 2;
  Network net{NUM_LAYERS};
  printf("Network uses %.2fMB of storage (without overhead).\n", 
	 net.Bytes() / (1000.0 * 1000.0));
  printf("Network init:\n");
  RandomizeNetwork(&rc, &net);
  MakeIndices(&rc, &net);
  printf("Initialized network in %.1fms.\n", initialize_network_timer.MS());

  {
    Stimulation stim{NUM_LAYERS};
    printf("A stimulation uses %.2fMB.\n", stim.Bytes() / (1000.0 * 1000.0));
  }

  printf("The corpus is of size %d.\n", (int)corpus.size());

  // Training round: Loop over all images in random order.
  double setup_ms = 0.0, stimulation_init_ms = 0.0, forward_ms = 0.0,
    fc_init_ms = 0.0, kernel_ms = 0.0;
  static constexpr int MAX_ROUNDS = 1; // 10000;
  Timer total_timer;
  for (int round_number = 0; round_number < MAX_ROUNDS; round_number++) {
    Timer setup_timer;
    // Shuffle corpus for this round.
    Shuffle(&rc, &corpus);
    // Copy to make training data; same order.
    vector<ImageRGBA *> examples = Map(corpus, [](ImageRGBA *img) { return img->Copy(); });
    vector<ImageRGBA *> expected = Map(corpus, [](ImageRGBA *img) { return img->Copy(); });

    // XXX Apply some effect to the example or expected!
    setup_ms += setup_timer.MS();

    CHECK_EQ(examples.size(), expected.size());
    // TODO: may make sense to parallelize this loop somehow, so that we can parallelize
    // CPU/GPU duties?

    // Run a batch of images all the way through. (Each layer requires significant setup.)
    Timer stimulation_init_timer;
    Stimulation stim{NUM_LAYERS};
    vector<Stimulation> stims;
    stims.reserve(examples.size());
    for (int i = 0; i < examples.size(); i++) stims.emplace_back(NUM_LAYERS);
    int64 stim_bytes = 0ll;
    for (const Stimulation &s : stims) stim_bytes += s.Bytes();
    printf("Size for all stimulations: %.1fMB\n", stim_bytes / (1000.0 * 1000.0));
    // These are just memory copies; easy to do in parallel.
    ParallelComp(examples.size(),
		 [&examples, &stims](int i) {
		   InitializeLayerFromImage(examples[i], &stims[i].values[0]);		   
		 }, 16);
    stimulation_init_ms += stimulation_init_timer.MS();

    // The loop over layer smust be in serial.
    for (int src = 0; src < NUM_LAYERS; src++) {
      printf("Layer %d.\n", src);
      Timer fc_init_timer;
      ForwardLayerCL::ForwardContext fc(&forwardlayer, net, src);
      fc_init_ms += fc_init_timer.MS();

      // PERF could be parallel, but watch out about loading the GPU with
      // too many simultaneous value src/dst buffers.
      Timer forward_timer;
      std::mutex print_mutex;
      ParallelComp(examples.size(),
		   [&examples, &fc, &stims, &print_mutex](int example) {
		     fc.Forward(&stims[example]);
		     if (example % 10 == 0) {
		       MutexLock ml(&print_mutex);
		       printf("[%d/%d] (%.2f%%)", example, (int)examples.size(),
			      100.0 * example / examples.size());
		     }
		   }, 12);
      forward_ms += forward_timer.MS();
      kernel_ms += fc.kernel_ms;
    }

    // XXX write out a sample of the round's performance as images.
    DeleteElements(&examples);
    DeleteElements(&expected);
  }

  double total_ms = total_timer.MS();
  auto Pct = [total_ms](double d) { return (100.0 * d) / total_ms; };
  printf("\n\n ** Done **\n"
	 "In total (which was %.1fs),\n"
	 "spent %.1fms in setup (%.1f%%),\n"
	 "%.1fms in stimulation init (%.1f%%),\n"
	 "%.1fms in forward layer (%.1f%%),\n"
	 "%.1fms in fc init (%.1f%%),\n"
	 "%.1fms in forward layer kernel (at most; %.1f%%).\n",
	 total_ms / 1000.0,
	 setup_ms, Pct(setup_ms),
	 stimulation_init_ms, Pct(stimulation_init_ms),
	 forward_ms, Pct(forward_ms),
	 fc_init_ms, Pct(fc_init_ms),
	 kernel_ms, Pct(kernel_ms));

  /*
    BlitChannel(0xFF, 0x0, 0x0, *font, 
		30, 30,
		corpus[0]);

    printf("Save it..\n");
    corpus[0]->Save("testi.png");

    printf("Done.\n");
  */

  return 0;
}