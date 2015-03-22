
#include <vector>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <deque>

#include "util.h"
#include "timer.h"
#include "threadutil.h"
#include "arcfour.h"
#include "randutil.h"
#include "base/logging.h"

#include "makeparticles.h"

using namespace std;

int main() {
  vector<string> dict = Util::ReadFileToLines("wordlist.asc");
  printf("%d words.\n", (int)dict.size());
  ArcFour rc("portmantout");
  
  vector<string> particles = MakeParticles(&rc, dict, true, nullptr);

  {
    FILE *f = fopen("particles.txt", "wb");
    CHECK(f != nullptr);
    for (const string &p : particles) {
      fprintf(f, "%s\n", p.c_str());
    }
    fclose(f);
    printf("Wrote particles.txt.\n");
  }

  return 0;
}
