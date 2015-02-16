

// Nodes per pixel. Beyond the R, G, B values, the inputs will be zero and
// the outputs ignored.
#define NPP 3

// Size of one layer in pixels. Note that there are three nodes per pixel (RGB).
// This is probably too big?
#define WIDTH 1024
#define HEIGHT 1024

// How many pixels in the x and y direction do we sample from the previous
// layer? (Uses modular arithmetic to keep the program simplest.) This is
// NEIGHBORHOOD^2 * NPP actual parameters.
#define NEIGHBORHOOD 5

// Now many random nodes (not pixels) do we also sample? Currently the identity
// of those nodes is part of the model but not updated.
#define RANDOM 0

#define NUM_NODES (WIDTH * HEIGHT * NPP)
// Must divide num_nodes.
#define CHUNK_SIZE (NUM_NODES >> 4)

// Transfer function is: Multiply each incoming edge by a weight. Add them.
// Apply two-parameter sigmoid to result. All features are stored as floats in [0, 1];
// weights are treated as (x * 2 - 1) so that the effective range is [-1, 1].
// and sigmoid params are TBD.
#define FEATURES_PER_INPUT_EDGE 1
#define ADDITIONAL_FEATURES_PER_NODE 2

#define INPUTS_SUMMED (NEIGHBORHOOD * NEIGHBORHOOD * NPP + RANDOM)

#define FEATURES_PER_NODE (ADDITIONAL_FEATURES_PER_NODE + (INPUTS_SUMMED * FEATURES_PER_INPUT_EDGE))

#define NUM_FEATURES (NUM_NODES * FEATURES_PER_NODE)

#define NUM_SEEDS (WIDTH * HEIGHT)

#define IMAGES_PER_BATCH 5
