#include <utility>

#include "makeparticles.h"

int main () {
  int max_length = 4;
  string particle = "aaaaaaaaqwertyuiop";

  for (int st = std::max(0, (int)particle.size() - max_length * 2);
       st < particle.size();
       st++) {
    for (int len = 1; len <= particle.size() - st; len++) {
      printf("%s\n", particle.substr(st, len).c_str());
   }
  }

  for (int len = std::min(max_length, (int)particle.size()); len > 0; len--) {
    string suffix = particle.substr(particle.size() - len, string::npos);
    printf(".. %s\n", suffix.c_str());
  }

}
