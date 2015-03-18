#include "../cc-lib/sdl/sdlutil.h"
#include "SDL.h"
#include "SDL_main.h"
#include "../cc-lib/sdl/chars.h"
#include "../cc-lib/sdl/font.h"

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

#if 1
#define ECHECK(a)
#define ECHECK_EQ(a, b)
#define ECHECK_LT(a, b)
#define ECHECK_GT(a, b)
#define ECHECK_LE(a, b)
#define ECHECK_GE(a, b)
#else
#error implement these
#endif

// Graphics.
#define FONTWIDTH 9
#define FONTHEIGHT 16
static Font *font = nullptr;
#define SCREENW 1920
#define SCREENH 1280
static SDL_Surface *screen = nullptr;

// Thread-safe, so shared between train and ui threads.
static CL *global_cl = nullptr;

// You can read the previous versions (redi-random.cc) to see some of
// the history / thoughts.

static constexpr int NUM_LAYERS = 3;

static_assert((NPP >= 3), "Must have at least R, G, B pixels.");
// static_assert((NEIGHBORHOOD & 1) == 1, "neighborhood must be odd.");
// static_assert((NUM_NODES % CHUNK_SIZE) == 0, "chunk size must divide input.");

// static_assert(RANDOM == 0, "random not yet supported.");

std::mutex print_mutex;
#define Printf(fmt, ...) do {		\
  MutexLock Printf_ml(&print_mutex);		\
  printf(fmt, ##__VA_ARGS__);			\
  } while (0);

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

static uint8 FloatByte(float f) {
  if (f <= 0.0f) return 0;
  if (f >= 1.0f) return 255;
  else return f * 255.0;
}

static constexpr float ByteFloat(uint8 b) {
  return (b / 255.0);
}

static void WriteLayerAsImage(const string &filename, const vector<float> &values) {
  vector<uint8> rgba;
  // TODO: Write other channels as separate transparent images?
  for (int i = 0; i < NUM_NODES / NPP; i++) {
    for (int j = 0; j < 3; j++) {
      const float f = values[i * NPP + j];
      rgba.push_back(FloatByte(f));
    }
    rgba.push_back(0xFF);
  }
  CHECK_EQ(rgba.size(), SIZE * SIZE * 4);
  ImageRGBA img(rgba, SIZE, SIZE);
  img.Save(filename);
  Printf("Wrote %s...\n", filename.c_str());
 
  // XXX PERF and as text file.
  if (false) {
    string tf = (string)"text-" + filename + (string)".txt";
    FILE *ftxt = fopen(tf.c_str(), "wb");
    for (int i = 0; i < values.size(); i++) {
      if (i % 8 == 0) fprintf(ftxt, "\n");
      fprintf(ftxt, "% f ", values[i]);
    }
    fclose(ftxt);
    Printf("And %s.\n", tf.c_str());
  }

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
static ImageA *FontChar(const string &filename, char c, int size) {
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

// Reduce to 4-bit color.
static void Quantize(ImageRGBA *img) {
  // three bit color
  static constexpr uint8 MASK = 0xE0;
  for (int i = 0; i < img->rgba.size(); i++) {
    // Don't change alpha channel.
    if (((i + 1) % 4) == 0) continue;
    img->rgba[i] = MASK & img->rgba[i];
  }
}

static void BlitChannel(uint8 r, uint8 g, uint8 b, const ImageA &channel, 
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
	}
      }
    }
  }
}

// This doesn't blend; it assumes we have 0 in every slot to start.
// (This is only used to draw into the unused image channel in the
// training data to try to coax it to recognize the position of the 'i').
static void BlitNodeChannel(int ch_offset, const ImageA &channel,
			    int xpos, int ypos,
			    vector<float> *dest) {
  CHECK_LT(ch_offset, NPP);
  CHECK_GE(ch_offset, 0);
  CHECK_EQ(dest->size(), SIZE * SIZE * NPP);
  for (int y = 0; y < channel.height; y++) {
    int dsty = ypos + y;
    if (dsty >= 0 && dsty < SIZE) {
      for (int x = 0; x < channel.width; x++) {
	int dstx = xpos + x;
	if (dstx >= 0 && dstx <= SIZE) {
	  int sidx = x + channel.width * y;
	  uint8 value = channel.alpha[sidx];

	  int didx = (dsty * SIZE + dstx) * NPP + ch_offset;
	  (*dest)[didx] = ByteFloat(value);
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
    inverted_indices_start(num_layers, vector<uint32>(NUM_NODES, 0U)),
    inverted_indices_length(num_layers, vector<uint32>(NUM_NODES, 0U)),
    inverted_indices(num_layers, vector<uint32>(INDICES_PER_NODE * NUM_NODES, 0)) {}
  int64 Bytes() const {
    return 
      // indices
      (INDICES_PER_NODE * NUM_NODES * sizeof (uint32) * num_layers) +
      // weights
      (INDICES_PER_NODE * NUM_NODES * sizeof (float) * num_layers) +
      // biases
      (NUM_NODES * sizeof (float) * num_layers) +
      // inverted_indices_start
      (NUM_NODES * sizeof (uint32) * num_layers) +
      // inverted_indices_length
      (NUM_NODES * sizeof (uint32) * num_layers) +
      // inverted_indices
      (INDICES_PER_NODE * NUM_NODES * sizeof (uint32) * num_layers);
  }

  void CopyFrom(const Network &other) {
    CHECK_EQ(this->num_layers, other.num_layers);
    this->indices = other.indices;
    this->weights = other.weights;
    this->biases = other.biases;
    this->inverted_indices_start = other.inverted_indices_start;
    this->inverted_indices_length = other.inverted_indices_length;
    this->inverted_indices = other.indices;
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
  vector<vector<uint32>> inverted_indices_start;
  vector<vector<uint32>> inverted_indices_length;
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
  // by inverted_indices_start[layer][z]) for node id z
  // let gidx = inverted_indices[layer][i]
  // and then indices[layer][gidx] == z. (The same for the weight
  // vector gives us the weight, which is the point, and dividing
  // by INDICES_PER_NODE gives us the output node.) As such, this is
  // a permutation of 0..(NUM_NODES * INDICES_PER_NODE - 1).
  vector<vector<uint32>> inverted_indices;
};

void ReadNetworkBinary(const string &filename, Network *net) {
  Printf("Reading [%s]\n", filename.c_str());
  FILE *file = fopen(filename.c_str(), "rb");
  CHECK(file != nullptr) << "If this fails but is present, you may "
    "have a permissions problem.";

  auto Read32 = [file]() {
    int32_t i;
    CHECK(!feof(file));
    CHECK(1 == fread(&i, 4, 1, file));
    return i;
  };
  auto ReadFloat = [file]() {
    float value;
    CHECK(!feof(file));
    CHECK(1 == fread(&value, 4, 1, file));
    return value;
  };
  auto ReadFloats = [&ReadFloat](vector<float> *vec) {
    for (int i = 0; i < vec->size(); i++) {
      (*vec)[i] = ReadFloat();
    }
  };

  CHECK(Read32() == 0x27000700) << "Wrong magic number!";
  CHECK_EQ(Read32(), NPP);
  CHECK_EQ(Read32(), SIZE);
  // This one we could probably increase, though.
  CHECK_EQ(Read32(), INDICES_PER_NODE);
  // And adding more layers would be totally reasonable.
  int file_num_layers = Read32();
  CHECK_EQ(file_num_layers, net->num_layers);
  for (int i = 0; i < file_num_layers; i++) {
    for (int j = 0; j < INDICES_PER_NODE * NUM_NODES; j++) {
      net->indices[i][j] = Read32();
    }
  }

  for (int i = 0; i < file_num_layers; i++)
    ReadFloats(&net->weights[i]);

  for (int i = 0; i < file_num_layers; i++)
    ReadFloats(&net->biases[i]);
  
  fclose(file);
  Printf("Read from %s.\n", filename.c_str());
}

static void SaveNetworkBinary(const Network &net, const string &filename) {
  // Not portable, obviously.
  FILE *file = fopen(filename.c_str(), "wb");
  auto Write32 = [file](int32_t i) {
    CHECK(1 == fwrite(&i, 4, 1, file));
  };
  auto WriteFloat = [file](float value) {
    CHECK(1 == fwrite(&value, 4, 1, file));
  };
  auto WriteFloats = [&WriteFloat](const vector<float> &vec) {
    for (float f : vec)
      WriteFloat(f);
  };

  Write32(0x27000700);
  Write32(NPP);
  Write32(SIZE);
  Write32(INDICES_PER_NODE);
  Write32(net.num_layers);

  for (int i = 0; i < net.num_layers; i++) {
    for (uint32 idx : net.indices[i]) {
      Write32(idx);
    }
  }

  for (int i = 0; i < net.num_layers; i++)
    WriteFloats(net.weights[i]);

  for (int i = 0; i < net.num_layers; i++)
    WriteFloats(net.biases[i]);

  Printf("Wrote %s.\n", filename.c_str());
  fclose(file);
}

static void WriteNetwork(const Network &net, const string &filename) {
  bool truncate = false;
  if (net.Bytes() > 20000000LL) {
    truncate = true;
    Printf("Writing trucated network because it's too big.\n");
  }
  FILE *f = fopen(filename.c_str(), "wb");
  for (int layer = 0; layer < net.num_layers; layer++) {
    fprintf(f, "\n"
	    "===================\n"
	    "Layer %d:\n"
	    "===================\n", layer);

    const int max_nodes = truncate ? 8 : NUM_NODES;
    for (int node_idx = 0; node_idx < max_nodes; node_idx++) {
      fprintf(f, "n %d: % f ", node_idx, net.biases[layer][node_idx]);
      for (int i = 0; i < INDICES_PER_NODE; i++) {
	fprintf(f, " + %f*n%d",
		net.weights[layer][node_idx * INDICES_PER_NODE + i],
		net.indices[layer][node_idx * INDICES_PER_NODE + i]);
      }
      fprintf(f, "\n");
    }
  }
  fclose(f);
}

static void CheckInvertedIndices(const Network &net) {
  for (int layer = 0; layer < net.num_layers; layer++) {
    const vector<uint32> &indices = net.indices[layer];
    const vector<uint32> &inv = net.inverted_indices[layer];
    const vector<uint32> &starts = net.inverted_indices_start[layer];
    const vector<uint32> &lengths = net.inverted_indices_length[layer];
    CHECK_EQ(NUM_NODES * INDICES_PER_NODE, indices.size());
    CHECK_EQ(NUM_NODES, starts.size());
    CHECK_EQ(NUM_NODES, lengths.size());
    CHECK_EQ(NUM_NODES * INDICES_PER_NODE, inv.size());
    // z is a node id from the src layer.
    for (int z = 0; z < starts.size(); z++) {
      // i is the index within the compacted inverted index.
      for (int i = starts[z]; i < starts[z] + lengths[z]; i++) {
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
    CHECK_LT(layer, net->inverted_indices_start.size());
    CHECK_LT(layer, net->inverted_indices_length.size());
    vector<uint32> *starts = &net->inverted_indices_start[layer];
    vector<uint32> *lengths = &net->inverted_indices_length[layer];
    CHECK_EQ(NUM_NODES, starts->size());
    CHECK_EQ(NUM_NODES, lengths->size());
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
      (*starts)[src_nodes_idx] = flat_size;
      (*lengths)[src_nodes_idx] = occurrences[src_nodes_idx].size();

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

  void CopyFrom(const Stimulation &other) {
    CHECK_EQ(this->num_layers, other.num_layers);
    this->values = other.values;
  }
};

struct Errors {
  Errors(int num_layers) : 
    num_layers(num_layers),
    error(num_layers, vector<float>(NUM_NODES, 0.0f)) {
  }
  const int num_layers;
  int64 Bytes() const {
    return num_layers * NUM_NODES * sizeof (float);
  }

  // These are the delta terms in Mitchell. We have num_layers of them, where
  // the error[0] is the first real layer (we don't compute errors for the input)
  // and error[num_layers] is the error for the output.
  vector<vector<float>> error;
};

// Set the error values; this is almost just a memcpy so don't bother doing it
// on GPU.
static void SetOutputError(const Stimulation &stim, const vector<float> &expected, Errors *err) {
  // One more value vector than layers, since we have values for the input "layer" too.
  const int num_layers = stim.num_layers;
  ECHECK(stim.values.size() == num_layers + 1);
  const vector<float> &output = stim.values[num_layers];

  ECHECK_EQ(NUM_NODES, expected.size());
  ECHECK_EQ(NUM_NODES, output.size()); 
  ECHECK(err->error.size() == num_layers);
  vector<float> *output_error = &err->error[num_layers - 1];
  ECHECK_EQ(NUM_NODES, output_error->size());
  for (int k = 0; k < NUM_NODES; k++) {
    // Here we want to multiply by the derivative, sigma'(input),
    // which is sigma(input) * (1.0 - sigma(input)), and we already have
    // sigma(input) -- it's the output.
    float out_k = output[k];
    // Note in some presentations this is out_k - expected_k.
    (*output_error)[k] = out_k * (1.0 - out_k) * (expected[k] - out_k);
  }
}

// Propagate the error backwards from the dest_layer to the src_layer.
// (Note that the error terms go FROM the destination TO the source;
// here I'm keeping the same terminology about "source" and
// "destination" based on how data flows in the normal forward
// direction.)
//
// This is now a kernel, so this function is uncalled. But it should
// still work.
static void BackwardsError(const Network &net, const Stimulation &stim,
			   int dest_layer, Errors *err) {
  // If we have
  //
  //   inputs     h        h'    outputs
  //     o ------ o ------ o ------ o 
  //     o ------ o ------ o ------ o
  //     o ------ o ------ o ------ o
  //         layer 0   layer 1   layer 2
  //         error 0   error 1   error 2
  //       gap 0    gap 1     gap 2
  //   vals 0   vals 1   vals 2   vals 3
  //
  // We also have error deltas for each real layer. We are propagating the error
  // from layer dest_layer to layer dest_layer-1, which is the gap dest_layer.
  //
  // Errors only go to real layers, so the dest layer is 1 at minimum.
  ECHECK_GT(dest_layer, 0);
  const int gap = dest_layer;

  const int src_layer = dest_layer - 1;
  ECHECK_GE(src_layer, 0);

  // Note that stim has an extra data layer in it because it does
  // represent the values of the input layer, thus the +1 here.
  ECHECK_LT(src_layer + 1, stim.values.size());
  const vector<float> &src_output = stim.values[src_layer + 1];

  // The inverted index is really in the gap.
  ECHECK_LT(gap, net.inverted_indices_start.size());
  ECHECK_LT(gap, net.inverted_indices_length.size());
  const vector<uint32> &starts = net.inverted_indices_start[gap];
  const vector<uint32> &lengths = net.inverted_indices_length[gap];
  const vector<uint32> &inverted_index = net.inverted_indices[gap];
  const vector<uint32> &dest_indices = net.indices[dest_layer];
  (void)dest_indices;  // Suppress lint -- only used for debug check.
  const vector<float> &dest_weights = net.weights[dest_layer];

  // One error layer for each real layer (not the input).
  ECHECK_LT(dest_layer, err->error.size());
  const vector<float> &dest_error = err->error[dest_layer];
  vector<float> *src_error = &err->error[src_layer];
  // Loop over every node in the previous layer, index h.
  for (int h = 0; h < NUM_NODES; h++) {
    const float out_h = src_output[h];
    // Unpack inverted index for this node, so that we can loop over all of
    // the places its output is sent.
    const uint32 start = starts[h];
    const uint32 length = lengths[h];
    
    // The error for a hidden node is the sum of all the errors for
    // the next layer, but modulated by the weight of the edge.
    double weighted_error_sum = 0.0;
    for (int i = start; i < start + length; i++) {
      const int gidx = inverted_index[i];
      // gidx is an index into the index and weights vectors on the
      // destination layer.
      ECHECK_EQ(dest_indices[gidx], h);
      // Compute from the index which destination node it belongs to.
      const int dest_node_idx = gidx / INDICES_PER_NODE;
      weighted_error_sum += dest_weights[gidx] * dest_error[dest_node_idx];
    }
    
    (*src_error)[h] = out_h * (1.0f - out_h) * weighted_error_sum;
  }
}

// In some presentations, this is positive, and others, negative. It
// all comes down to the signs of the error; whether we compute
// (expected - actual) or (actual - expected). Either way, we want to be DECREASING
// error, not INCREASING it. For this setup, positive.
// static constexpr float LEARNING_RATE = +0.05f;
// static constexpr float LEARNING_RATE = +0.05f;
// Learning rate should be a small positive constant (0 < lr < 1) constant, probably
// around 0.05, and decreasing as we run more rounds.
static void UpdateWeights(const float learning_rate,
			  Network *net, const Stimulation &stim, const Errors &err) {
  // This one is doing a simple thing with a lot of parallelism, but unfortunately
  // writes would collide if we tried to add in all the weight updates in parallel.
  // Not clear what the best approach is here. Parallelizing over layers is easy,
  // at least.
  
  // Here we parallelize over all nodes in all layers; updating the weights and
  // bias for that node in a chunk.
  const int num_layers = net->num_layers;
  ParallelComp(num_layers * NUM_NODES,
	       [learning_rate, &net, &stim, &err, num_layers](int work_id) {
		 // Update the weights for this node.
		 const int layer = work_id % num_layers;
		 const int node_idx = work_id / num_layers;

		 // Error term is for this node.
		 // Since error is not represented for the input layer, 'layer' is
		 // the correct index. (That is, the 0th layer is the earliest one
		 // that has weights.)
		 ECHECK_LT(layer, err.error.size());
		 ECHECK_LT(node_idx, err.error[layer].size());
		 const float delta_j = err.error[layer][node_idx];
		 const float learning_rate_times_delta_j = learning_rate * delta_j;

		 vector<float> *layer_weights = &net->weights[layer];
		 const vector<uint32> &layer_indices = net->indices[layer];

		 // Note since stim has an additional layer for the input, layer
		 // here is referring to the output values of the previous layer,
		 // which is what we want. (The 0th layer is the earliest one
		 // that we read: the input layer.)
		 ECHECK_LT(layer, stim.values.size());
		 const vector<float> &layer_values = stim.values[layer];

		 // There is one weight for each input index.
		 for (int input_idx = 0; input_idx < INDICES_PER_NODE; input_idx++) {
		   const int gidx = INDICES_PER_NODE * node_idx + input_idx;
		   ECHECK_GE(gidx, 0);
		   ECHECK_LT(gidx, layer_indices.size());

		   // Offset of the node, which we use to get its output.
		   const int src_idx = layer_indices[gidx];
		   ECHECK_GE(src_idx, 0);
		   ECHECK_LT(src_idx, NUM_NODES);

		   ECHECK_LT(src_idx, layer_values.size());
		   const float x_ji = layer_values[src_idx];

		   (*layer_weights)[gidx] += learning_rate_times_delta_j * x_ji;
		 }

		 // The bias terms are basically the same, but the output of that
		 // node is 1. There's just one per node.
		 ECHECK_LT(layer, net->biases.size());
		 ECHECK_LT(node_idx, net->biases[layer].size());
		 net->biases[layer][node_idx] += learning_rate_times_delta_j;
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

    // TODO: Do we really want to share the same command queue across threads?
    // Presumably clFinish can't tell "this thread's commands" apart from others,
    // so we may be prematurely waiting/running other thread's work.
    void Forward(Stimulation *stim) {
      ECHECK_LT(layer + 1, stim->values.size());

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

struct BackwardLayerCL {
  explicit BackwardLayerCL(CL *cl) : cl(cl) {
    const string kernel_src = 
      Util::ReadFile("constants.h") + "\n" +
      Util::ReadFile("backwardlayer.cl");

    std::tie(program, kernel) = cl->BuildOneKernel(kernel_src, "BackwardLayer");
  }

  struct BackwardContext {
    BackwardContext(BackwardLayerCL *parent, const Network &net, int dest_layer) :
      parent(parent), net(net), dest_layer(dest_layer) {
      CL *cl = parent->cl;

      const int gap = dest_layer;
      // const int src_layer = dest_layer - 1;

      starts = MoveMemoryToGPUConst(cl->context, cl->queue,
				    net.inverted_indices_start[gap]);
      lengths = MoveMemoryToGPUConst(cl->context, cl->queue,
				    net.inverted_indices_length[gap]);

      inverted_index = MoveMemoryToGPUConst(cl->context, cl->queue,
					    net.inverted_indices[gap]);

      dest_weights = MoveMemoryToGPUConst(cl->context, cl->queue,
					  net.weights[dest_layer]);
    }

    // TODO: Do we really want to share the same command queue across threads?
    // Presumably clFinish can't tell "this thread's commands" apart from others,
    // so we may be prematurely waiting/running other thread's work.
    void Backward(const Stimulation &stim, Errors *err) {
      CL *cl = parent->cl;

      // const int gap = dest_layer;
      const int src_layer = dest_layer - 1;

      //  const vector<float> &dest_error = err->error[dest_layer];
      //  vector<float> *src_error = &err->error[src_layer];

      cl_mem src_output = MoveMemoryToGPUConst(cl->context, cl->queue,
					       stim.values[src_layer + 1]);
      cl_mem dest_error = MoveMemoryToGPUConst(cl->context, cl->queue,
					       err->error[dest_layer]);

      cl_mem src_error = CreateUninitializedGPUMemory<float>(cl->context, NUM_NODES);

      // Can't have multiple threads setting a kernel's argument at one time.
      {
	MutexLock ml(&parent->m);

	CHECK_SUCCESS(clSetKernelArg(parent->kernel, 0, sizeof(cl_mem), (void *)&starts));
	CHECK_SUCCESS(clSetKernelArg(parent->kernel, 1, sizeof(cl_mem), (void *)&lengths));
	CHECK_SUCCESS(clSetKernelArg(parent->kernel, 2, sizeof(cl_mem), (void *)&inverted_index));
	CHECK_SUCCESS(clSetKernelArg(parent->kernel, 3, sizeof(cl_mem), (void *)&dest_weights));
	CHECK_SUCCESS(clSetKernelArg(parent->kernel, 4, sizeof(cl_mem), (void *)&src_output));
	CHECK_SUCCESS(clSetKernelArg(parent->kernel, 5, sizeof(cl_mem), (void *)&dest_error));
	CHECK_SUCCESS(clSetKernelArg(parent->kernel, 6, sizeof(cl_mem), (void *)&src_error));

	size_t global_work_offset[] = { 0 };
	size_t global_work_size[] = { (size_t)NUM_NODES };
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
      CHECK_SUCCESS(clReleaseMemObject(src_output));
      CHECK_SUCCESS(clReleaseMemObject(dest_error));

      CopyBufferFromGPUTo<float>(cl->queue, src_error, &err->error[src_layer]);

      CHECK_SUCCESS(clReleaseMemObject(src_error));
    }
    
    ~BackwardContext() {
      CHECK_SUCCESS(clReleaseMemObject(starts));
      CHECK_SUCCESS(clReleaseMemObject(lengths));
      CHECK_SUCCESS(clReleaseMemObject(inverted_index));
      CHECK_SUCCESS(clReleaseMemObject(dest_weights));
    }

    cl_mem starts, lengths, inverted_index, dest_weights;
    BackwardLayerCL *parent = nullptr;
    const Network &net;
    const int dest_layer;
    double kernel_ms = 0.0;
  };

  ~BackwardLayerCL() {
    CHECK_SUCCESS(clReleaseKernel(kernel));
    CHECK_SUCCESS(clReleaseProgram(program));
  }

  CL *cl = nullptr;
  // Owned:
  cl_program program;
  cl_kernel kernel;

  std::mutex m;
};

struct UpdateWeightsCL {
  explicit UpdateWeightsCL(CL *cl) : cl(cl) {
    const string kernel_src = 
      Util::ReadFile("constants.h") + "\n" +
      Util::ReadFile("updateweights.cl");

    std::tie(program, kernel) = cl->BuildOneKernel(kernel_src, "UpdateWeights");
  }

  struct UpdateContext {
    UpdateContext(UpdateWeightsCL *parent, Network *net, int layer) :
      parent(parent), net(net), layer(layer) {
      CL *cl = parent->cl;

      layer_indices = MoveMemoryToGPUConst(cl->context, cl->queue, net->indices[layer]);
      layer_weights = MoveMemoryToGPU(cl->context, cl->queue, false, &net->weights[layer]);
      layer_biases = MoveMemoryToGPU(cl->context, cl->queue, false, &net->biases[layer]);
    }

    void Update(float learning_rate, const Stimulation &stim, const Errors &err, int layer) {
      CL *cl = parent->cl;

      // Really can't run these in parallel because of concurrent writes to net.
      MutexLock ml(&parent->m);

      cl_mem layer_error = MoveMemoryToGPUConst(cl->context, cl->queue,
						err.error[layer]);
      cl_mem layer_values = MoveMemoryToGPUConst(cl->context, cl->queue,
						 stim.values[layer]);

      CHECK_SUCCESS(clSetKernelArg(parent->kernel, 0, sizeof(cl_float), (void *)&learning_rate));
      CHECK_SUCCESS(clSetKernelArg(parent->kernel, 1, sizeof(cl_mem), (void *)&layer_error));
      CHECK_SUCCESS(clSetKernelArg(parent->kernel, 2, sizeof(cl_mem), (void *)&layer_indices));
      CHECK_SUCCESS(clSetKernelArg(parent->kernel, 3, sizeof(cl_mem), (void *)&layer_values));
      CHECK_SUCCESS(clSetKernelArg(parent->kernel, 4, sizeof(cl_mem), (void *)&layer_weights));
      CHECK_SUCCESS(clSetKernelArg(parent->kernel, 5, sizeof(cl_mem), (void *)&layer_biases));

      size_t global_work_offset[] = { 0 };
      size_t global_work_size[] = { (size_t)NUM_NODES };
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
      CHECK_SUCCESS(clReleaseMemObject(layer_error));
      CHECK_SUCCESS(clReleaseMemObject(layer_values));
    }

    void Finish() {
      CL *cl = parent->cl;
      CopyBufferFromGPUTo(cl->queue, layer_weights, &net->weights[layer]);
      CopyBufferFromGPUTo(cl->queue, layer_biases, &net->biases[layer]);
      clFinish(cl->queue);
    }

    ~UpdateContext() {
      CHECK_SUCCESS(clReleaseMemObject(layer_indices));
      CHECK_SUCCESS(clReleaseMemObject(layer_weights));
      CHECK_SUCCESS(clReleaseMemObject(layer_biases));
    }

    cl_mem layer_indices, layer_weights, layer_biases;
    UpdateWeightsCL *parent = nullptr;
    Network *net;
    const int layer;
    double kernel_ms = 0.0;
  };

  ~UpdateWeightsCL() {
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
  static constexpr double STDDEV = SIZE / 16.0;
  // static constexpr int NEIGHBORHOOD = 5;

  // For best results, use false, true:
  static constexpr bool SYMMETRIC_GAUSSIAN = false;
  static constexpr bool GAUSSIAN = true;

  // Fastest initialization, worse quality
  // static constexpr bool SYMMETRIC_GAUSSIAN = true;
  // static constexpr bool GAUSSIAN = false;

  static_assert(STDDEV > 1.0, "surprisingly small stddev");
  static_assert(NEIGHBORHOOD >= 0, "must include the pixel itself.");
  static_assert((NEIGHBORHOOD * 2 + 1) * (NEIGHBORHOOD * 2 + 1) * NPP <= INDICES_PER_NODE,
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
      ECHECK_GE(cc, 0);
      ECHECK_LT(cc, NPP);
      if (xx < 0 || yy < 0 || xx >= SIZE || yy >= SIZE) return;
      int idx = (yy * SIZE * NPP) + (xx * NPP) + cc;
      ECHECK_GE(idx, 0);
      ECHECK_LT(idx, NUM_NODES);
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
  ParallelComp(net->num_layers, [&rcs, &OneNode, &net](int layer) {
    Printf("Intializing indices for layer %d...\n", layer);
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
	Printf("  [%d/%d] %.1f%%\n", y, SIZE, (100.0 * y) / SIZE);
      }
    }
  }, 12);

  DeleteElements(&rcs);
}

// Randomize the weights in a network. Doesn't do anything to indices.
static void RandomizeNetwork(ArcFour *rc, Network *net) {
  auto RandomizeFloats = [](ArcFour *rc, vector<float> *vec) {
    for (int i = 0; i < vec->size(); i++) {
      (*vec)[i] = RandFloat(rc) * 0.1f - 0.05f;
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

static constexpr int NUM_VIDEO_STIMULATIONS = 4;
std::mutex video_export_m;
int current_round = 0;
vector<Stimulation> current_stimulations(NUM_VIDEO_STIMULATIONS, Stimulation(NUM_LAYERS));
Network current_network(NUM_LAYERS);
static bool allow_updates = true;

void ExportRound(int r) {
  MutexLock ml(&video_export_m);
  if (allow_updates) {
    current_round = r;
  }
}

void ExportNetworkToVideo(const Network &net) {
  MutexLock ml(&video_export_m);
  if (allow_updates) {
    current_network.CopyFrom(net);
  }
}

void ExportStimulusToVideo(int example_id, const Stimulation &stim) {
  MutexLock ml(&video_export_m);
  if (allow_updates) {
    CHECK_GE(example_id, 0);
    CHECK_LT(example_id, current_stimulations.size());
    current_stimulations[example_id].CopyFrom(stim);
  }
}


vector<ImageRGBA *> LoadImagesFromDirectory(const string &dir) {
  vector<string> filenames = 
    Map(Util::ListFiles(dir),
	[dir](const string &s) -> string { return dir + s; });

  Printf("Loading %d files from %s...\n", (int)filenames.size(), dir.c_str());
  vector<ImageRGBA *> result =
    ParallelMap(filenames,
		[](const string &s) { return ImageRGBA::Load(s); },
		16);
  CHECK(result.size() > 0);
  return result;
}

// Communication between threads.
static bool train_should_die = false;
std::mutex train_should_die_m;
static bool train_done = false;
std::mutex train_done_m;

void UIThread() {
  enum Mode {
    MODE_STIMULUS,
    MODE_NETWORK,
    MODE_EVALUATE,
  };
  Mode mode = MODE_STIMULUS;
  struct ModeDescriptor {
    char key;
    const char *desc;
    Mode mode;
  };
  auto all_modes = {
    ModeDescriptor{'s', "Stimulus mode", MODE_STIMULUS},
    {'n', "Network mode", MODE_NETWORK},
    {'e', "Evaluate mode", MODE_EVALUATE},
  };

  static constexpr int I_SIZE = 80;
  vector<string> font_filenames = Util::ListFiles("fonts/");
  vector<ImageA *> fonts =
    ParallelMap(font_filenames,
		[](const string &s) { 
		  ImageA *f = FontChar((string)"fonts/" + s, 'i', I_SIZE);
		  CHECK(f != nullptr) << s;
		  return f;
		},
		16);
  CHECK(fonts.size() > 0);

  // Just used in eval mode.
  // XXX leaked.
  vector<ImageRGBA *> heldout_corpus = 
    // LoadImagesFromDirectory("corpus256/");
    LoadImagesFromDirectory("eval256/");
  CHECK(heldout_corpus.size() > 0);
  ForwardLayerCL forwardlayer{global_cl};

  int offset = 0;
  int mousex = 0, mousey = 0;

  for (;;) {
    int round = ReadWithLock(&video_export_m, &current_round);
    sdlutil::clearsurface(screen, 0x0);

    string menu = "";
    for (const ModeDescriptor &md : all_modes) {
      if (md.mode == mode) {
	menu += StringPrintf("[^3%c: %s^<]   ", md.key, md.desc);
      } else {
	menu += StringPrintf("^0%c^<^1: %s^<   ", md.key, md.desc);
      }
    }
    
    if (allow_updates) {
      menu += "^0(space to pause)^<";
    } else {
      menu += "^3[space to unpause]^<";
    }

    menu += StringPrintf("  round %d", round);

    font->draw(2, 2, menu);

    static constexpr int MARGIN = 24;
    static constexpr int GAP = 10;

    auto DrawStimulus = [](int column, const Stimulation &stim) {
	int sx = MARGIN + column * (SIZE + GAP);
	for (int layer = 0; layer < NUM_LAYERS + 1; layer++) {
	  int sy = MARGIN + layer * (SIZE + GAP);
	  const vector<float> &values = stim.values[layer];
	  for (int y = 0; y < SIZE; y++) {
	    for (int x = 0; x < SIZE; x++) {
	      int pixel_id = y * SIZE + x;
	      const uint8 r = FloatByte(values[pixel_id * NPP + 0]);
	      const uint8 g = FloatByte(values[pixel_id * NPP + 1]);
	      const uint8 b = FloatByte(values[pixel_id * NPP + 2]);
	      sdlutil::drawpixel(screen, sx + x, sy + y, r, g, b);
	    }
	  }
	}
    };

    if (mode == MODE_STIMULUS) {
      MutexLock ml(&video_export_m);
      for (int i = 0; i < current_stimulations.size(); i++) {
	DrawStimulus(i, current_stimulations[i]);
      }
    } else if (mode == MODE_NETWORK) {
      MutexLock ml(&video_export_m);
      // In this mode, draw the different nodes per pixel as separate rectangles.
      // We just show one example at a time.
      const int ex = offset % current_stimulations.size();
      int show_channels = std::min(NPP, NUM_VIDEO_STIMULATIONS);
      for (int ch = 0; ch < show_channels; ch++) {
	int sx = MARGIN + ch * (SIZE + GAP);
	for (int layer = 0; layer < NUM_LAYERS + 1; layer++) {
	  const vector<float> &values = current_stimulations[ex].values[layer];
	  int sy = MARGIN + layer * (SIZE + GAP);

	  for (int y = 0; y < SIZE; y++) {
	    for (int x = 0; x < SIZE; x++) {
	      int pixel_id = y * SIZE + x;
	      const uint8 v = FloatByte(values[pixel_id * NPP + ch]);

	      if (ch == 0) {
		sdlutil::drawpixel(screen, sx + x, sy + y, v, 0, 0);
	      } else if (ch == 1) {
		sdlutil::drawpixel(screen, sx + x, sy + y, 0, v, 0);
	      } else if (ch == 2) {
		sdlutil::drawpixel(screen, sx + x, sy + y, 0, 0, v);
	      } else {
		sdlutil::drawpixel(screen, sx + x, sy + y, v, v, v);
	      }
	    }
	  }
	}

	// Is the mouse in one of the layers?
	int mx = (mousex - MARGIN) / (SIZE + GAP);
	int my = (mousey - MARGIN) / (SIZE + GAP);
	if (mx >= 0 && mx < show_channels &&
	    my >= 0 && my < NUM_LAYERS + 1) {
	  int ox = (mousex - MARGIN) % (SIZE + GAP);
	  int oy = (mousey - MARGIN) % (SIZE + GAP);
	  if (ox >= 0 && oy >= 0 && ox < SIZE && oy < SIZE) {
	    // Okay, we are actually pointing at a layer then.
	    const int channel = mx;
	    const int layer = my;
	    int node_id = (oy * SIZE + ox) * NPP + channel;
	    
	    CHECK_GE(node_id, 0) << node_id << " " << oy << " " << ox << " " << channel;
	    CHECK_GE(channel, 0);
	    CHECK_GE(ox, 0);
	    CHECK_GE(oy, 0);
	    CHECK_LT(node_id, NUM_NODES);
	    CHECK_LE(layer, NUM_LAYERS);
	    CHECK_GE(node_id, 0);
	    float value = current_stimulations[ex].values[layer][node_id];

	    font->draw(2, SCREENH - FONTHEIGHT - 2,
		       StringPrintf("layer %d channel %d x %d y %d node %d (val ^2%f^<)",
				    layer, channel, ox, oy, node_id, value));
	    // And draw its source indices.
	    if (layer > 0) {
	      int sy = MARGIN + (layer - 1) * (GAP + SIZE);
	      for (int i = 0; i < INDICES_PER_NODE; i++) {
		int src_idx = current_network.indices[layer - 1][node_id * INDICES_PER_NODE + i];
		float weight = current_network.indices[layer - 1][node_id * INDICES_PER_NODE + i];
		// Decompose source index:
		int src_ch = src_idx % NPP;
		int src_pixel = src_idx / NPP;
		int src_y = src_pixel / SIZE;
		int src_x = src_pixel % SIZE;

		int sx = MARGIN + src_ch * (GAP + SIZE);
		if (weight > 0) {
		  sdlutil::drawpixel(screen, sx + src_x, sy + src_y, 0xFF, 0xFF, 0);
		} else {
		  sdlutil::drawpixel(screen, sx + src_x, sy + src_y, 0, 0xFF, 0xFF);
		}
	      }
	    }
	  }
	}
      }
    } else if (mode == MODE_EVALUATE) {
      {
	MutexLock ml(&video_export_m);

	// XXX allow mouse-over

	vector<Stimulation> stims;
	stims.reserve(NUM_VIDEO_STIMULATIONS);
	for (int i = 0; i < NUM_VIDEO_STIMULATIONS; i++) stims.emplace_back(NUM_LAYERS);

	for (int src = 0; src < NUM_LAYERS; src++) {
	  ForwardLayerCL::ForwardContext fc(&forwardlayer, current_network, src);
	  ParallelComp(NUM_VIDEO_STIMULATIONS,
		       [&DrawStimulus, &heldout_corpus, &stims, &fc, 
			&fonts,
			mousex, mousey,
			src, offset](int column) {
			 Stimulation *stim = &stims[column];
			 int example = (offset + column) % heldout_corpus.size();
			 if (src == 0) {
			   // PERF we only really need the copy if we are mousing
			   // over it...
			   ImageRGBA *img = heldout_corpus[example]->Copy();

			   // Is the mouse in one of the layers?
			   int mx = (mousex - MARGIN) / (SIZE + GAP);
			   int my = (mousey - MARGIN) / (SIZE + GAP);
			   if (mx == column &&
			       // TODO: Would be interesting to draw into arbitrary
			       // layer though?
			       my == 0
			       /* my >= 0 && my < NUM_LAYERS + 1 */ ) {
			     int ox = (mousex - MARGIN) % (SIZE + GAP);
			     int oy = (mousey - MARGIN) % (SIZE + GAP);
			     if (ox >= 0 && oy >= 0 && ox < SIZE && oy < SIZE) {
			       // Okay, we are actually pointing at the image. Draw
			       // a red i to evaluate.

			       // XXX uhhhh -- to match buggy logic in training data
			       uint8 x_dice = ox & 0x255;
			       uint8 y_dice = oy & 0x255;

			       if (x_dice < 12) x_dice += 12;
			       if (y_dice < 12) y_dice += 12;
			       if (x_dice > 255 - I_SIZE) x_dice -= I_SIZE;
			       if (y_dice > 255 - I_SIZE) y_dice -= I_SIZE;


			       BlitChannel(0xFF, 0x0, 0x0, *fonts[0],
					   x_dice, y_dice,
					   img);
			     }
			   }

			   InitializeLayerFromImage(img, &stim->values[0]);
			   // And done with the temporary image.
			   delete img;
			 }
			 fc.Forward(stim);

			 if (src == NUM_LAYERS - 1) {
			   DrawStimulus(column, *stim);
			 }
		       }, 
		       // Try to not starve training thread.
		       6);
	}
      }
      Printf("(drew eval)\n");

      // SDL_Delay(1000);
    }

    SDL_Flip(screen);

    if (ReadWithLock(&train_done_m, &train_done)) {
      Printf("UI thread saw that training finished.\n");
      return;
    }

    SDL_Event event;
    if (SDL_PollEvent(&event)) {
      if (event.type == SDL_QUIT) {
	Printf("QUIT.\n");
	return;

      } else if (event.type == SDL_MOUSEMOTION) {
	SDL_MouseMotionEvent *e = (SDL_MouseMotionEvent*)&event;

	mousex = e->x;
	mousey = e->y;
	// (and immediately redraw)

      } else if (event.type == SDL_KEYDOWN) {
	switch (event.key.keysym.sym) {
	case SDLK_KP_PLUS:
	case SDLK_PLUS:
	case SDLK_EQUALS:
	case SDLK_PAGEDOWN:
	  if (mode == MODE_EVALUATE) {
	    offset += NUM_VIDEO_STIMULATIONS;
	  } else {
	    offset++;
	  }
	  break;

	case SDLK_KP_MINUS:
	case SDLK_MINUS:
	case SDLK_PAGEUP:
	  offset--;
	  // Don't be negative or modulus goes negative :-(
	  if (offset < 0) offset = 0;
	  break;

	case SDLK_ESCAPE:
	  Printf("ESCAPE.\n");
	  return;
	case SDLK_s:
	  Printf("Stimulus mode.\n");
	  mode = MODE_STIMULUS;
	  break;
	case SDLK_n:
	  Printf("Network mode.\n");
	  mode = MODE_NETWORK;
	  break;
	case SDLK_e:
	  Printf("Evaluate mode.\n");
	  mode = MODE_EVALUATE;
	  break;
	case SDLK_SPACE: {
	  MutexLock ml(&video_export_m);
	  allow_updates = !allow_updates;
	}
	default:;
	}
      }
    } else {
      // PERF
      SDL_Delay(10);
    }
  }
}

void TrainThread() {
  Timer setup_timer;
  
  string start_seed = StringPrintf("%d  %lld", getpid(), (int64)time(NULL));
  Printf("Start seed: [%s]\n", start_seed.c_str());
  ArcFour rc(start_seed);
  rc.Discard(2000);

  // Create kernels right away so that we get compilation errors early.
  ForwardLayerCL forwardlayer{global_cl};
  BackwardLayerCL backwardlayer{global_cl};
  UpdateWeightsCL updateweights{global_cl};

  // Replacing these functions; don't warn.
  (void)BackwardsError;
  (void)UpdateWeights;

  // Create the initial network.
  // TODO: Serialize and load from disk if we have one.
  Timer initialize_network_timer;
  Network net{NUM_LAYERS};
  printf("Network uses %.2fMB of storage (without overhead).\n", 
	 net.Bytes() / (1000.0 * 1000.0));

  // printf("Network init:\n");
  // RandomizeNetwork(&rc, &net);
  // printf("Make indices:\n");
  // MakeIndices(&rc, &net);
  (void)RandomizeNetwork;
  (void)MakeIndices;
  ReadNetworkBinary("jnet.val", &net);

  printf("Invert index:\n");
  ComputeInvertedIndices(&net);
  printf("Check it:\n");
  CheckInvertedIndices(net);
  printf("Initialized network in %.1fms.\n", initialize_network_timer.MS());

  vector<ImageRGBA *> corpus = LoadImagesFromDirectory("jpegs256/");

  static constexpr int I_SIZE = 80;
  vector<string> font_filenames = Util::ListFiles("fonts/");
  vector<ImageA *> fonts =
    ParallelMap(font_filenames,
		[](const string &s) { 
		  ImageA *f = FontChar((string)"fonts/" + s, 'i', I_SIZE);
		  CHECK(f != nullptr) << s;
		  return f;
		},
		16);
  CHECK(fonts.size() > 0);

  {
    Stimulation stim{NUM_LAYERS};
    printf("A stimulation uses %.2fMB.\n", stim.Bytes() / (1000.0 * 1000.0));
  }

  auto ShouldDie = [&net]() {
    bool should_die = ReadWithLock(&train_should_die_m, &train_should_die);
    if (should_die) {
      Printf("Train thread signaled death.\n");
      Printf("Saving...\n");
      SaveNetworkBinary(net, "jnetwork-onexit.bin");
    }
    return should_die;
  };

  printf("The corpus is of size %d.\n", (int)corpus.size());

  // Training round: Loop over all images in random order.
  double setup_ms = 0.0, stimulation_init_ms = 0.0, forward_ms = 0.0,
    fc_init_ms = 0.0, bc_init_ms = 0.0, kernel_ms = 0.0, backward_ms = 0.0, output_error_ms = 0.0,
    update_ms = 0.0, writing_ms = 0.0;
  static constexpr int MAX_ROUNDS = 50000; // 10000;
  static constexpr int EXAMPLES_PER_ROUND = 4;
  static constexpr int VERBOSE_ROUND_EVERY = 250;

  Timer total_timer;
  for (int round_number = 0; round_number < MAX_ROUNDS; round_number++) {
    Printf("\n\n ** ROUND %d **\n", round_number);

    // When starting from a fresh network, consider this:
    const float round_learning_rate = 
      0.05;
    /*
      std::max(0.000001, std::min(0.9,
				  exp(-0.2275 * (round_number + 1)/200.0)));
    */
  // const float round_learning_rate = 0.0025;

    Printf("Learning rate: %.4f\n", round_learning_rate);

    bool is_verbose_round = 0 == ((round_number /* + 1 */) % VERBOSE_ROUND_EVERY);
    if (is_verbose_round) {
      Printf("Writing network:\n");
      WriteNetwork(net, StringPrintf("jnetwork-%d.txt", round_number));
      SaveNetworkBinary(net, "jnetwork-checkpoint.bin");
    }

    Printf("Export network:\n");
    ExportRound(round_number);
    ExportNetworkToVideo(net);

    Timer setup_timer;
    Printf("Setting up batch:\n");
    // Shuffle corpus for this round (pointers alias originals).
    vector<ImageRGBA *> corpuscopy = corpus;
    Shuffle(&rc, &corpuscopy);
    // Don't run the full corpus.
    corpuscopy.resize(EXAMPLES_PER_ROUND);

    // Copy to make training data; same order.
    // TODO: These leak when we exit the thread early.
    vector<ImageRGBA *> examples = Map(corpuscopy, [](ImageRGBA *img) { return img->Copy(); });

    // Expected is weights, because we want to use non-RGB channels to encode other facts.
    vector<vector<float>> expected(examples.size(), vector<float>(NUM_NODES, 0.0f));

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

    vector<uint64> seeds;
    seeds.reserve(examples.size());
    for (int i = 0; i < examples.size(); i++) seeds.push_back(Rand64(&rc));
    ParallelComp(examples.size(),
		 [&seeds, &examples, &expected, &stims](int i) {
		   // This will always be the original image.
		   InitializeLayerFromImage(examples[i], &expected[i]);
		   Quantize(examples[i]);
		   InitializeLayerFromImage(examples[i], &stims[i].values[0]);
		 }, 12);

    // XXX Apply some effect to the example or expected!
    setup_ms += setup_timer.MS();
    stimulation_init_ms += stimulation_init_timer.MS();

    if (ShouldDie()) return;
    // The loop over layers must be in serial.
    for (int src = 0; src < NUM_LAYERS; src++) {
      Printf("FWD Layer %d: ", src);
      Timer fc_init_timer;
      ForwardLayerCL::ForwardContext fc(&forwardlayer, net, src);
      fc_init_ms += fc_init_timer.MS();

      // PERF could be parallel, but watch out about loading the GPU with
      // too many simultaneous value src/dst buffers.
      Timer forward_timer;
      ParallelComp(examples.size(),
		   [&examples, &fc, &stims](int example) {
		     fc.Forward(&stims[example]);
		     if (example % 10 == 0) {
		       Printf("[%d/%d] (%.2f%%) ", example, (int)examples.size(),
			      100.0 * example / examples.size());
		     }
		     
		     if (example < NUM_VIDEO_STIMULATIONS) {
		       // Copy to screen.
		       ExportStimulusToVideo(example, stims[example]);
		     }

		   }, 12);
      forward_ms += forward_timer.MS();
      kernel_ms += fc.kernel_ms;
      Printf("\n");
    }
    // TODO PERF: Can kill transformed input eagerly, if having memory pressure issues.

    if (is_verbose_round) {
      if (ShouldDie()) return;
      // Write outputs as graphics.
      Timer writing_timer;
      ParallelComp(min((int)examples.size(), 10),
		   [&stims, round_number](int example) {
		     const Stimulation &stim = stims[example];
		     for (int i = 0; i < stim.values.size(); i++) {
		       string filename = StringPrintf("jround-%d-ex-%d-layer-%d.png",
						      round_number,
						      example,
						      i);
		       WriteLayerAsImage(filename, stim.values[i]);
		     }
		   }, 16);
      writing_ms += writing_timer.MS();
    }
   
    if (ShouldDie()) return;
    Printf("Error calc.\n");
    Timer output_error_timer;
    ParallelComp(examples.size(),
		 [&examples, &expected, &stims, &errs](int example) {
		   SetOutputError(stims[example], expected[example], &errs[example]);
		 }, 12);
    output_error_ms += output_error_timer.MS();

    CHECK_EQ(examples.size(), errs.size());
    CHECK_EQ(examples.size(), stims.size());

    if (ShouldDie()) return;
    Printf("Backwards:\n");
    // Also serial, but in reverse.
    Timer backward_timer;
    // We do NOT propagate errors to the input layer, so dst is strictly greater than 1.
    for (int dst = NUM_LAYERS - 1; dst > 0; dst--) {
      Printf("BWD Layer %d: ", dst);

      Timer bc_init_timer;
      BackwardLayerCL::BackwardContext bc{&backwardlayer, net, dst};
      bc_init_ms += bc_init_timer.MS();

      ParallelComp(examples.size(),
		   [&examples, &stims, &errs, &bc](int example) {
		     bc.Backward(stims[example], &errs[example]);
		     // BackwardsError(net, stims[example], dst, &errs[example]);
		     if (example % 5 == 0) {
		       Printf("[%d/%d] (%.2f%%) ", example, (int)examples.size(),
			      100.0 * example / examples.size());
		     }
		   }, 12);
      Printf("\n");
    }
    backward_ms += backward_timer.MS();

    if (ShouldDie()) return;
    Printf("Update weights:\n");
    Timer update_timer;
    // Don't parallelize! These are all writing to the same network weights. Each
    // call is parallelized, though.

    // for (int example = 0; example < examples.size(); example++) {
    //   UpdateWeights(round_learning_rate, &net, stims[example], errs[example]);
    // }

    for (int layer = 0; layer < NUM_LAYERS; layer++) {
      UpdateWeightsCL::UpdateContext uc(&updateweights, &net, layer);

      // PERF Faster to try to run these in parallel (maybe parallelizing memory traffic
      // with kernel execution -- but we can't run the kernels at the same time).
      for (int example = 0; example < examples.size(); example++) {
	uc.Update(round_learning_rate, stims[example], errs[example], layer);
      }
      
      // Must call this to copy weights back!
      uc.Finish();
    }
    update_ms += update_timer.MS();

    DeleteElements(&examples);
    if (ShouldDie()) return;

    double total_ms = total_timer.MS();
    auto Pct = [total_ms](double d) { return (100.0 * d) / total_ms; };
    double denom = round_number + 1;
    Printf("Total so far %.1fs.\n"
	   "Time per round: %.1fs.\n"
	   "We spent %.1fms in setup (%.1f%%),\n"
	   "%.1fms in stimulation init (%.1f%%),\n"
	   "%.1fms in forward layer (%.1f%%),\n"
	   "%.1fms in fc init (%.1f%%),\n"
	   "%.1fms in forward layer kernel (at most; %.1f%%).\n"
	   "%.1fms in bc init (%.1f%%),\n"
	   "%.1fms in backwards pass (%.1f%%),\n"
	   "%.1fms in error for output layer (%.1f%%),\n"
	   "%.1fms in updating weights (%.1f%%),\n"
	   "%.1fms in writing images (%.1f%%),\n",
	   total_ms / 1000.0,
	   (total_ms / 1000.0) / denom,
	   setup_ms, Pct(setup_ms),
	   stimulation_init_ms, Pct(stimulation_init_ms),
	   forward_ms / denom, Pct(forward_ms),
	   fc_init_ms / denom, Pct(fc_init_ms),
	   kernel_ms / denom, Pct(kernel_ms),
	   bc_init_ms / denom, Pct(bc_init_ms),
	   backward_ms / denom, Pct(backward_ms),
	   output_error_ms / denom, Pct(output_error_ms),
	   update_ms / denom, Pct(update_ms),
	   writing_ms / denom, Pct(writing_ms));

    SDL_Delay(100000);


  }

  Printf(" ** Done. **");

  WriteWithLock(&train_done_m, &train_done, true);
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

  font = Font::create(screen,
		      "font.png",
		      FONTCHARS,
		      FONTWIDTH, FONTHEIGHT, FONTSTYLES, 1, 3);
  CHECK(font != nullptr) << "Couldn't load font.";

  global_cl = new CL;

  std::thread train_thread(&TrainThread);

  UIThread();
  
  Printf("Killing train thread (might need to wait for round to finish)...\n");
  WriteWithLock(&train_should_die_m, &train_should_die, true);
  train_thread.join();

  Printf("Train is dead; now UI exiting.\n");
  /*
    BlitChannel(0xFF, 0x0, 0x0, *font, 
		30, 30,
		corpus[0]);

    printf("Save it..\n");
    corpus[0]->Save("testi.png");

    printf("Done.\n");
  */
  // ui_thread.join();

  SDL_Quit();
  return 0;
}

