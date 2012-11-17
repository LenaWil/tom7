
#include "simplefm2.h"

#include "../cc-lib/util.h"

using namespace std;

vector<uint8> SimpleFM2::ReadInputs(const string &filename) {
  vector<string> contents = Util::ReadFileToLines(filename);
  vector<uint8> out;
  for (int i = 0; i < contents.size(); i++) {
    const string &line = contents[i];
    if (line.empty() || line[0] != '|')
      continue;

    // Parse the line.
    if (line.size() < 12) {
      fprintf(stderr, "Illegal line: [%s]\n", line.c_str());
      abort();
    }
    
    if (!(line[1] == '0' ||
	  (line[1] == '2' && out.empty()))) {
      fprintf(stderr, "Command must be zero except hard "
	      "reset in first input: [%s]\n", line.c_str());
      abort();
    }

    /*
      |2|........|........||
      |0|....T...|........||
    */
    
    const string player = line.substr(3, 8);
    uint8 command = 0;
    for (int j = 0; j < 8; j++) {
      if (player[j] != '.') {
	command |= (1 << (7 - j));
      }
    }
    out.push_back(command);
  }

  return out;
}
