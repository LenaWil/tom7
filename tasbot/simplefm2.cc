
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

void SimpleFM2::WriteInputs(const string &outputfile,
			    const string &romfilename,
			    const string &romchecksum,
			    const vector<uint8> &inputs) {
  // XXX Create one of these by hashing inputs.
  string fakeguid = "FDAEE33C-B32D-B38C-765C-FADEFACE0000";
  FILE *f = fopen(outputfile.c_str(), "wb");
  fprintf(f,
	  "version 3\n"
	  "emuversion 9815\n"
	  "romFilename %s\n"
	  "romChecksum %s\n"
	  "guid %s\n"
	  // Read from settings?
	  "palFlag 0\n"
	  "NewPPU 0\n"
	  "fourscore 0\n"
	  "microphone 0\n"
	  "port0 1\n"
	  "port1 1\n"
	  "port2 0\n"
	  // ?
	  "FDS 1\n"
	  "comment author tasbot-simplefm2\n",
	  romfilename.c_str(),
	  romchecksum.c_str(),
	  fakeguid.c_str());
  for (int i = 0; i < inputs.size(); i++) {
    fprintf(f, "|%c|", (i == 0) ? '2' : '0');
    static const char gamepad[] = "RLDUTSBA";
    for (int j = 0; j < 8; j++) {
      fprintf(f, "%c",
	      (inputs[i] & (1 << (7 - j))) ? gamepad[j] : '.');
    }
    fprintf(f, "|........||\n");
  }
  fclose(f);
}
