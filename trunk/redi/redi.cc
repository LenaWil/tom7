#include "../cc-lib/sdl/sdlutil.h"
#include "SDL.h"
#include "SDL_main.h"

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

static_assert((NPP >= 3), "Must have at least R, G, B pixels.");
// static_assert((NEIGHBORHOOD & 1) == 1, "neighborhood must be odd.");
// static_assert((NUM_NODES % CHUNK_SIZE) == 0, "chunk size must divide input.");

// static_assert(RANDOM == 0, "random not yet supported.");

static SDL_Surface *screen = nullptr;
#define SCREENW 1920
#define SCREENH 1080

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

// Using standard region of -1 to 1.
static uint8 FloatByte(float f) {
  if (f < -1.0f) return 0;
  else if (f > 1.0f) return 255;
  else return (uint8)((f + 1.0f) * 127.5);
}

static float ByteFloat(uint8 b) {
  return (b / 127.5f) - 1.0f;
}

static void WriteLayerAsImage(const string &filename, const vector<float> &values) {
  vector<uint8> rgba;
  for (int i = 0; i < NUM_NODES; i++) {
    rgba.push_back(FloatByte(values[i]));
    if ((rgba.size() + 1) % 4 == 0) {
      rgba.push_back(0xFF);
    }
  }
  CHECK_EQ(rgba.size(), SIZE * SIZE * 4);
  ImageRGBA img(rgba, SIZE, SIZE);
  img.Save(filename);
  printf("Wrote %s...\n", filename.c_str());
}

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
  fflush(stdout);

  FILE *file = fopen(filename.c_str(), "rb");
  if (file == nullptr) {
    fprintf(stderr, "Failed to fopen %s\n", filename.c_str());
    return nullptr;
  }
  // XXX check read size
  uint8 *ttf_buffer = (uint8*)malloc(1<<25);
  fread(ttf_buffer, 1, 1 << 25, file);
  fclose(file);

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
    biases(num_layers, vector<float>(NUM_NODES, 0.0f)),
    inverted_indices_span(num_layers,
			  vector<pair<uint32, uint32>>(NUM_NODES, make_pair(0, 0))),
    inverted_indices(num_layers, vector<uint32>(INDICES_PER_NODE * NUM_NODES, 0)) {}
  int64 Bytes() const {
    return 
      // indices
      (INDICES_PER_NODE * NUM_NODES * sizeof (uint32) * num_layers) +
      // weights
      (INDICES_PER_NODE * NUM_NODES * sizeof (float) * num_layers) +
      // biases
      (NUM_NODES * sizeof (float) * num_layers) +
      // inverted_indices_span
      (NUM_NODES * sizeof (uint32) * 2 * num_layers) +
      // inverted_indices
      (INDICES_PER_NODE * NUM_NODES * sizeof (uint32) * num_layers);
  }

  // The number of "real" layers, that is, not counting the input.
  const int num_layers;

  // For all of the fields in this struct, the outer vector has size num_layers.
  // (It might even be a good idea to make this into a Layer struct.)
  // INDICES_PER_NODE * NUM_NODES
  vector<vector<uint32>> indices;
  // INDICES_PER_NODE * NUM_NODES
  vector<vector<float>> weights;
  // NUM_NODES
  vector<vector<float>> biases;

  // For a given node, where do I output to in the next layer?
  // Note that nodes don't all have the same number of outputs.
  // This is a packed structure to facilitate GPU operations.
  //
  // For a given node, where do my output indices start in
  // the inverted_indices array, and how many are there?
  // NUM_NODES
  vector<vector<pair<uint32, uint32>>> inverted_indices_span;
  // Packed array of indices. Since every node on the next layer
  // has exactly INDICES_PER_NODE inputs, this will be of
  // size INDICES_PER_NODE * NUM_NODES. However, any given node
  // on this layer may be used more or fewer times.
  //
  // There are num_layers of these, but be careful about the offset.
  // The 0th inverted index is about the gap between the input layer
  // (otherwise not represented in the network) and the first hidden
  // layer. The last one is about the last gap, not the output layer,
  // since the output layer is not indexed by anything.
  //
  // The value here gives the index into the indices/weights vectors
  // for the next layer. If for each index i within the span (defined
  // by inverted_indices_span[layer][z]) for node id z
  // let gidx = inverted_indices[layer][i]
  // and then indices[layer][gidx] == z. (The same for the weight
  // vector gives us the weight, which is the point, and dividing
  // by INDICES_PER_NODE gives us the output node.) As such, this is
  // a permutation of 0..(NUM_NODES * INDICES_PER_NODE - 1).
  vector<vector<uint32>> inverted_indices;
};

static void CheckInvertedIndices(const Network &net) {
  for (int layer = 0; layer < net.num_layers; layer++) {
    const vector<uint32> &indices = net.indices[layer];
    const vector<uint32> &inv = net.inverted_indices[layer];
    const vector<pair<uint32, uint32>> &span = net.inverted_indices_span[layer];
    CHECK_EQ(NUM_NODES * INDICES_PER_NODE, indices.size());
    CHECK_EQ(NUM_NODES, span.size());
    CHECK_EQ(NUM_NODES * INDICES_PER_NODE, inv.size());
    // z is a node id from the src layer.
    for (int z = 0; z < span.size(); z++) {
      // i is the index within the compacted inverted index.
      for (int i = span[z].first; i < span[z].first + span[z].second; i++) {
	// Global index into 'indices'.
	const int gidx = inv[i];
	// This should map back to our current node id.
	CHECK_EQ(indices[gidx], z);
      }
    }
  }
}

static void ComputeInvertedIndices(Network *net) {
  // Computes the values for inverted_indices[layer] and
  // inverted_indices_span[layer]. Note that although we use the
  // [layer] offset throughout, both are really talking about the gap
  // between layers, with the 0th element's index being the way the
  // first hidden layer uses the inputs, and the 0th element's invert
  // index being about the way the inputs map to the first hidden
  // layer.
  auto OneLayer = [net](int layer) {
    CHECK_LT(layer, net->inverted_indices.size());
    CHECK_LT(layer, net->inverted_indices_span.size());
    vector<pair<uint32, uint32>> *span = &net->inverted_indices_span[layer];
    CHECK_EQ(NUM_NODES, span->size());
    vector<uint32> *inverted = &net->inverted_indices[layer];
    CHECK_EQ(INDICES_PER_NODE * NUM_NODES, inverted->size());
    
    // Indexed by node id in the source layer.
    vector<vector<uint32>> occurrences;
    occurrences.resize(NUM_NODES);
    for (int dest_indices_idx = 0;
	 dest_indices_idx < NUM_NODES * INDICES_PER_NODE;
	 dest_indices_idx++) {
      // This index gets put into exactly one place in occurrences.
      const int src_nodes_idx = net->indices[layer][dest_indices_idx];
      occurrences[src_nodes_idx].push_back(dest_indices_idx);
    }

    // Sort each subvector, for locality of access.
    for (vector<uint32> &v : occurrences) {
      std::sort(v.begin(), v.end());
    }

    // Now flatten.
    int flat_size = 0;
    for (int src_nodes_idx = 0;
	 src_nodes_idx < NUM_NODES;
	 src_nodes_idx++) {
      (*span)[src_nodes_idx] = make_pair(flat_size, occurrences[src_nodes_idx].size());
      
      for (int val : occurrences[src_nodes_idx]) {
	(*inverted)[flat_size] = val;
	flat_size++;
      }
    }
    CHECK_EQ(NUM_NODES * INDICES_PER_NODE, flat_size);
  };

  ParallelComp(net->num_layers, OneLayer, 12);
}

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
  Errors(int num_layers) : 
    num_layers(num_layers),
    error(num_layers + 1, vector<float>(NUM_NODES, 0.0f)),
    bias_error(num_layers, vector<float>(NUM_NODES, 0.0f)) {
  }
  const int num_layers;
  int64 Bytes() const {
    return 
      // Error
      (num_layers + 1) * NUM_NODES * sizeof (float) +
      // Bias error
      num_layers * NUM_NODES * sizeof (float);
  }

  // These are the delta terms in Mitchell. We have num_layers + 1 of them, where
  // the error[0] is the input deltas (we obviously don't update the input, but we do
  // update the weights of the first real layer, which reads from it) and
  // and error[num_layers] is the error for the output.
  vector<vector<float>> error;
  // Each node also has a bias term, which is just like having a node
  // in the previous layer that always outputs 1. These are the delta
  // terms for those phantom nodes; we have num_layers of them, where
  // we do have these terms for the input layer (as though it has
  // phantom bias nodes) but not for the output. Each one is NUM_NODES
  // in size, corresponding to the single bias input for each node in
  // the next layer.
  // PERF: Probably don't need to actually represent this since it's
  // not a summation and doesn't need to be propagated; it can just be
  // computed at the time we do the update?
  vector<vector<float>> bias_error;
};

// Set the error values; this is almost just a memcpy so don't bother doing it
// on GPU.
static void SetOutputError(const Stimulation &stim, const vector<float> &expected, Errors *err) {
  // One more value vector than layers, since we have values for the input "layer" too.
  const int num_layers = stim.num_layers;
  CHECK(stim.values.size() == num_layers + 1);
  const vector<float> &output = stim.values[num_layers];

  CHECK_EQ(NUM_NODES, expected.size());
  CHECK_EQ(NUM_NODES, output.size()); 
  CHECK(err->error.size() == num_layers + 1);
  vector<float> *output_error = &err->error[num_layers];
  CHECK_EQ(NUM_NODES, output_error->size());
  for (int k = 0; k < NUM_NODES; k++) {
    // Here we want to multiply by the derivative, sigma'(input),
    // which is sigma(input) * (1.0 - sigma(input)), and we already have
    // sigma(input) -- it's the output.
    float out_k = output[k];
    // Note in some presentations this is out_k - expected_k.
    (*output_error)[k] = out_k * (1.0 - out_k) * (expected[k] - out_k);
  }
}

// Propagate the error backwards from the dest_layer to the src_layer. (Note that
// the "destination" of the error terms is the source; here I'm keeping the same
// terminology about "source" and "destination" based on how data flows in the
// normal forward direction.)
//
// PERF Could/should be a kernel.
static void BackwardsError(const Network &net, const Stimulation &stim,
			   int dest_layer, Errors *err) {
  // If we have
  //
  //   inputs     h        h'    outputs
  //     o ------ o ------ o ------ o 
  //     o ------ o ------ o ------ o
  //     o ------ o ------ o ------ o
  //         layer 0   layer 1   layer 2
  //       gap 0    gap 1     gap 2
  //   vals 0   vals 1   vals 2    vals 3
  //
  // (also remark about bias nodes in this graph)
  //
  // we are propagating the error from layer n to layer n-1, which is the gap n.
  //
  // We do have to propagate error everywhere that we have a value, that is,
  // all the way to the input layer. So this gets called with dest_layer = 0.
  CHECK_GE(dest_layer, 0);
  const int gap = dest_layer;

  // We'll only look at src_layer in stim and err, where we add one to it.
  const int src_layer = dest_layer - 1;
  CHECK_GE(src_layer + 1, 0);

  // Loop over every node in the previous layer, index h. Note that stim has an
  // extra data layer in it because it does represent the values of the input
  // layer, thus the +1 here.
  const vector<float> &src_output = stim.values[src_layer + 1];

  // The inverted index is really in the gap.
  const vector<pair<uint32, uint32>> &spans = net.inverted_indices_span[gap];
  const vector<uint32> &inverted_index = net.inverted_indices[gap];
  const vector<uint32> &dest_indices = net.indices[dest_layer];
  const vector<float> &dest_weights = net.weights[dest_layer];

  // Note that like with the stimulation, we have an error corresponding to
  // each value, including in the input. This is used to update the value's
  // corresponding weight wherever it's used. Thus, the +1s in these.
  CHECK_LT(dest_layer + 1, err->error.size());
  const vector<float> &dest_error = err->error[dest_layer + 1];
  vector<float> *src_error = &err->error[src_layer + 1];
  for (int h = 0; h < NUM_NODES; h++) {
    const float out_h = src_output[h];
    // Unpack inverted index for this node, so that we can loop over all of
    // the places its output is sent.
    const pair<uint32, uint32> &span = spans[h];
    
    // The error for a hidden node is the sum of all the errors for
    // the next layer, but modulated by the weight of the edge.
    double weighted_error_sum = 0.0;
    for (int i = span.first; i < span.first + span.second; i++) {
      int gidx = inverted_index[i];
      // gidx is an index into the index and weights vectors on the
      // destination layer.
      CHECK_EQ(dest_indices[gidx], h);
      // Compute from the index which destination node it belongs to.
      int dest_node_idx = gidx / INDICES_PER_NODE;
      weighted_error_sum += dest_weights[gidx] * dest_error[dest_node_idx];
    }
    
    (*src_error)[h] = out_h * (1.0f - out_h) * weighted_error_sum;

    // XXX ?
    // Delta for bias term: Isn't it always zero because we have 1 * (1 - 1) * etc.?
    // (yes I think that's right; but we don't ever need that delta)
  }
}

/////////////////////////////////////////////////////////////////////////////////////
/// Update wednesday: I think we do not need to compute deltas all the way up to the
/// input nodes, nor for bias terms. I was mistakenly reading x_ji in mitchell as
/// "the input from j to i" but it's really "the input to j from i".
///
/// Error calculation looks okay (though we'll change the number of error layers
/// probably). UpdateWeights is wrong.
/////////////////////////////////////////////////////////////////////////////////////


// This is 'eta' in Mitchell. I'm pretty sure this is supposed to be negative (since
// the derivative tells us how quickly the error changes as the value changes, and
// we want error to go down), so I think that's a typo in the book. But maybe I am
// the one screwing up.
//
// (Actually, I think this all comes down to whether we take (expected - actual) or
// (actual - expected) when computing the error in the output layer.
static constexpr float LEARNING_RATE = +0.05f;
static void UpdateWeights(Network *net, const Stimulation &stim, const Errors &err) {
  // This one is doing a simple thing with a lot of parallelism, but unfortunately
  // writes would collide if we tried to add in all the weight updates in parallel.
  // Not clear what the best approach is here. Parallelizing over layers is easy,
  // at least.
  
  // Here we parallelize over nodes (in all layers), and update all of
  // the weights for that node (as well as the bias term) in a chunk.
  const int num_layers = net->num_layers;
  ParallelComp(num_layers * NUM_NODES,
	       [&net, &stim, &err, num_layers](int work_id) {
		 int layer = work_id % num_layers;
		 int node_idx = work_id / num_layers;

		 for (int input_idx = 0; input_idx < INDICES_PER_NODE; input_idx++) {
		   const int gidx = INDICES_PER_NODE * node_idx + input_idx;
		   CHECK_GE(gidx, 0);
		   CHECK_LT(gidx, net->indices[layer].size());
		   int src_idx = net->indices[layer][gidx];
		   CHECK_GE(src_idx, 0);
		   CHECK_LT(src_idx, NUM_NODES);
		   // Note since stim has an additional layer for the input, layer
		   // here is referring to the output values of the previous layer.
		   float x_ji = stim.values[layer][src_idx];

		   // Similarly, we need the error from the previous layer, which
		   // is arranged in parallel with stimulation.
		   //
		   // XXX 11 Mar 2015 I think this is supposed to be the delta
		   // for the layer whose weights we're updating?
		   float delta_j = err.error[layer][src_idx];

		   net->weights[layer][gidx] += LEARNING_RATE * delta_j * x_ji;
		 }
		 
		 // The output of the bias node.
		 float x_bias = 1.0f;
		 // Its error.
		 // aha and here it's not the "delta of the bias node" but the delta
		 // of this node we're updating, which is why this is not degenerate.
		 float delta_j = 0.0f;
		 // so this means no update ?

		 // XXX and the bias term. We need its delta.
	       }, 12);
}

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
    (*values)[dst++] = ByteFloat(rgba->rgba[4 * i + 0]);
    (*values)[dst++] = ByteFloat(rgba->rgba[4 * i + 1]);
    (*values)[dst++] = ByteFloat(rgba->rgba[4 * i + 2]);
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

  // Fastest initialization, worse quality
  // static constexpr bool SYMMETRIC_GAUSSIAN = true;
  // static constexpr bool GAUSSIAN = false;

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
      (*vec)[i] = RandFloat(rc) * 0.1 - 0.05f;
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

void UIThread() {
  static uint32 ch = 0;
  for (;;) {
    ch++;
    ch &= 255;
    sdlutil::clearsurface(screen, (ch << 24) | (ch << 16) | (ch << 8) | ch);
    SDL_Flip(screen);

    SDL_Event event;
    if (SDL_PollEvent(&event)) {
      if (event.type == SDL_QUIT) {
	LOG(FATAL) << "QUIT.";
	return;
      } else if (event.type == SDL_KEYDOWN) {
	switch(event.key.keysym.sym) {
	case SDLK_ESCAPE:
	  LOG(FATAL) << "ESCAPE.";
	  return;
	default:;
	}
      }
    } else {
      SDL_Delay(1);
    }
  }
}

int SDL_main(int argc, char* argv[]) {

  if (!SetPriorityClass(GetCurrentProcess(), BELOW_NORMAL_PRIORITY_CLASS)) {
    LOG(FATAL) << "Unable to go to BELOW_NORMAL priority.\n";
  }

  /* Initialize SDL and network, if we're using it. */
  CHECK(SDL_Init(SDL_INIT_VIDEO |
		 SDL_INIT_TIMER | 
		 SDL_INIT_AUDIO) >= 0);
  fprintf(stderr, "SDL initialized OK.\n");

  SDL_EnableKeyRepeat(SDL_DEFAULT_REPEAT_DELAY,
                      SDL_DEFAULT_REPEAT_INTERVAL);

  SDL_EnableUNICODE(1);

  screen = sdlutil::makescreen(SCREENW, SCREENH);
  CHECK(screen);

  std::thread ui_thread(&UIThread);

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
  static constexpr int NUM_LAYERS = 1;
  Network net{NUM_LAYERS};
  printf("Network uses %.2fMB of storage (without overhead).\n", 
	 net.Bytes() / (1000.0 * 1000.0));
  printf("Network init:\n");
  RandomizeNetwork(&rc, &net);
  printf("Make indices:\n");
  MakeIndices(&rc, &net);
  printf("Invert index:\n");
  ComputeInvertedIndices(&net);
  printf("Check it:\n");
  CheckInvertedIndices(net);
  printf("Initialized network in %.1fms.\n", initialize_network_timer.MS());

  {
    Stimulation stim{NUM_LAYERS};
    printf("A stimulation uses %.2fMB.\n", stim.Bytes() / (1000.0 * 1000.0));
  }

  printf("The corpus is of size %d.\n", (int)corpus.size());

  // Training round: Loop over all images in random order.
  double setup_ms = 0.0, stimulation_init_ms = 0.0, forward_ms = 0.0,
    fc_init_ms = 0.0, kernel_ms = 0.0, backward_ms = 0.0, output_error_ms = 0.0,
    update_ms = 0.0, writing_ms = 0.0;
  static constexpr int MAX_ROUNDS = 100; // 10000;
  Timer total_timer;
  for (int round_number = 0; round_number < MAX_ROUNDS; round_number++) {
    Timer setup_timer;
    // Shuffle corpus for this round.
    vector<ImageRGBA *> corpuscopy = corpus;
    Shuffle(&rc, &corpuscopy);
    // Don't run the full corpus.
    corpuscopy.resize(50);

    // Copy to make training data; same order.
    vector<ImageRGBA *> examples = Map(corpuscopy, [](ImageRGBA *img) { return img->Copy(); });
    vector<ImageRGBA *> expected = Map(corpuscopy, [](ImageRGBA *img) { return img->Copy(); });

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
    vector<Errors> errs;
    errs.reserve(examples.size());
    for (int i = 0; i < examples.size(); i++) errs.emplace_back(NUM_LAYERS);

    {
      // Diagnostic only.
      int64 stim_bytes = 0ll, err_bytes = 0ll;
      for (int i = 0; i < examples.size(); i++) {
	stim_bytes += stims[i].Bytes();
	err_bytes += errs[i].Bytes();
      }
      printf("Size for all stimulations: %.1fMB\n", stim_bytes / (1000.0 * 1000.0));
      printf("Size for all errors: %.1fMB\n", err_bytes / (1000.0 * 1000.0));
    }
      
    // These are just memory copies; easy to do in parallel.
    ParallelComp(examples.size(),
		 [&examples, &stims](int i) {
		   InitializeLayerFromImage(examples[i], &stims[i].values[0]);		   
		 }, 16);
    stimulation_init_ms += stimulation_init_timer.MS();

    // The loop over layers must be in serial.
    for (int src = 0; src < NUM_LAYERS; src++) {
      printf("FWD Layer %d: ", src);
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
		       printf("[%d/%d] (%.2f%%) ", example, (int)examples.size(),
			      100.0 * example / examples.size());
		     }
		   }, 12);
      forward_ms += forward_timer.MS();
      kernel_ms += fc.kernel_ms;
      printf("\n");
    }
    // TODO PERF: Can kill transformed input eagerly, if having memory pressure issues.

    // Write outputs as graphics.
    Timer writing_timer;
    ParallelComp(min((int)examples.size(), 10),
		 [&stims, round_number](int example) {
		   const Stimulation &stim = stims[example];
		   for (int i = 0; i < stim.values.size(); i++) {
		     string filename = StringPrintf("round-%d-ex-%d-layer-%d.png",
						    round_number,
						    example,
						    i);
		     WriteLayerAsImage(filename, stim.values[i]);
		   }
		 }, 16);
    writing_ms += writing_timer.MS();
   
    // PERF Parallelize
    printf("Error calc.\n");
    Timer output_error_timer;
    ParallelComp(examples.size(),
		 [&examples, &expected, &stims, &errs](int example) {
		   // PERF: We only need the desired result temporarily, and could just
		   // compute it at the same time we do the error calculation.
		   vector<float> desired_result;
		   desired_result.resize(NUM_NODES);
		   InitializeLayerFromImage(expected[example], &desired_result);
		   SetOutputError(stims[example], desired_result, &errs[example]);
		 }, 12);
    output_error_ms += output_error_timer.MS();

    // Also serial, but in reverse.
    Timer backward_timer;
    for (int dst = NUM_LAYERS - 1; dst >= 0; dst--) {
      printf("BWD Layer %d: ", dst);

      std::mutex print_mutex;
      ParallelComp(examples.size(),
		   [&print_mutex, &net, &examples, &stims, dst, &errs](int example) {
		     BackwardsError(net, stims[example], dst, &errs[example]);
		     if (example % 5 == 0) {
		       MutexLock ml(&print_mutex);
		       printf("[%d/%d] (%.2f%%) ", example, (int)examples.size(),
			      100.0 * example / examples.size());
		     }
		   }, 12);
      printf("\n");
    }
    backward_ms += backward_timer.MS();

    Timer update_timer;
    // Don't parallelize! These are all writing to the same network weights. Each
    // call is parallelized, though.
    for (int example = 0; example < examples.size(); example++) {
      UpdateWeights(&net, stims[example], errs[example]);
    }
    update_ms += update_timer.MS();

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
	 "%.1fms in forward layer kernel (at most; %.1f%%).\n"
	 "%.1fms in backwards pass (%.1f%%),\n"
	 "%.1fms in error for output layer (%.1f%%),\n"
	 "%.1fms in updating weights (%.1f%%),\n"
	 "%.1fms in writing images (%.1f%%),\n",
	 total_ms / 1000.0,
	 setup_ms, Pct(setup_ms),
	 stimulation_init_ms, Pct(stimulation_init_ms),
	 forward_ms, Pct(forward_ms),
	 fc_init_ms, Pct(fc_init_ms),
	 kernel_ms, Pct(kernel_ms),
	 backward_ms, Pct(backward_ms),
	 output_error_ms, Pct(output_error_ms),
	 update_ms, Pct(update_ms),
	 writing_ms, Pct(writing_ms));

  /*
    BlitChannel(0xFF, 0x0, 0x0, *font, 
		30, 30,
		corpus[0]);

    printf("Save it..\n");
    corpus[0]->Save("testi.png");

    printf("Done.\n");
  */
  ui_thread.join();
  return 0;
}

