/* This standalone program is part of the fceulib distribution, but shouldn't
   be compiled into it. */

#include <vector>
#include <string>

#include "simplefm2.h"
#include "base/stringprintf.h"
#include "rle.h"

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, 
	    "Dumps an fm2 file as an rle-compressed array of bytes in C++, "
	    "on standard out.\n\n"
	    "Usage: fm2tocc karate.fm2 > karate-bytes.cc\n\n");
    return -1;
  }

  vector<uint8> fm2 = RLE::Compress(SimpleFM2::ReadInputs(argv[1]));
  fprintf(stderr, "Loaded %s with %lld inputs.\n", argv[1], fm2.size());
  
  printf("// Imported from %s\n"
	 "const vector<uint8> name = RLE::Decompress({\n"
	 "    ",
	 argv[1]);

  int width = 4;
  for (uint8 c : fm2) {
    string b = StringPrintf("%d, ", (int)c);
    if (width + b.size() > 80) {
      width = 4;
      printf("\n    ");
    }
    printf("%s", b.c_str());
    width += b.size();
  }

  printf("\n});\n");

  return 0;
}
