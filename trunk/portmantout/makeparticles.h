
#include <vector>
#include <string>

using namespace std;

struct ArcFour;

struct Round {
  vector<string> path;
  vector<string> covered;
};
struct Trace {
  vector<Round> rounds;
};

// Trace can be null; it's expensive.
vector<string> MakeParticles(ArcFour *rc, const vector<string> &dict, bool verbose,
			     Trace *trace);
