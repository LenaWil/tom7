// Nodes per pixel. Beyond the R, G, B values, the inputs will be zero and
// the outputs ignored.
#define NPP 4

// Size of of image in pixels (width/height). Note that there are
// three nodes per pixel (RGB).
#define SIZE 256

// Target 1 gigabyte layer sizes.
// 2^30 = 1GB        = 1073741824
//   / 4-byte floats = 268435456
//   / 256 / 256     = 4096
//   / 3             = 1365.3
//
// (We also need the same for indices unless they are computed
// as a function of the node's index.)
//
// This size could later be layer-specific, btw.
//
// Does NOT include bias term.

// #define INDICES_PER_NODE 1024
// #define NEIGHBORHOOD 5
#define INDICES_PER_NODE 64
#define NEIGHBORHOOD 1

#define NUM_NODES (SIZE * SIZE * NPP)
