// Build a complete graph telling us how to efficiently get from the
// source letter to destination, where both source and destination
// are in [a-z]. We'll fill in the diagonal too, but we won't need
// to use it.

#include <string>
#include <vector>

using namespace std;

struct Path {
  Path() {}
  bool has = false;
  // Must start with src character and end with dst character.
  string word;
};

// Note that source letter will be ending a particle we're trying
// to join, and dst will be beginning one.
// matrix[src][dst]
vector<vector<Path>> MakeJoin(const vector<string> &dict);
