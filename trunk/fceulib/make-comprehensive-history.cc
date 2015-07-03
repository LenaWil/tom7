
#include <cstdlib>
#include <string>
#include <vector>
#include <unistd.h>

#include "base/logging.h"
#include "base/stringprintf.h"

using namespace std;

// Plan is something like this:

//  - this program generates the result file for a given revision (on
//     the command-line) -- it's basically a shell script
//  - a makefile can be used to generate many result files in parallel

void System(const string &commandline) {
  CHECK(0 == system(commandline.c_str())) << commandline;  
}

int main(int argc, char **argv) {
  int rev = 0;

  string additional_files;
  
  for (int i = 1; i < argc; i++) {
    string arg = argv[i];
    if (arg == "--rev") {
      CHECK(i + 1 < argc);
      i++;
      rev = atoi(argv[i]);
    } else {
      additional_files += " ";
      additional_files += argv[i];
    }
  }

  CHECK(rev > 0) << "A --rev must be specified.";
  
  {
    string commandline =
      StringPrintf("svn checkout -r %d "
		   "svn://svn.code.sf.net/p/tom7misc/svn/trunk/fceulib "
		   "clean_%d", rev, rev);
    // This seems to work fine if it's already there.
    System(commandline);
  }

  // TODO: Some time later, compute md5sum of the source tree?

  // Copy in emulator_test.cc from current version, so that we get
  // consistent results.
  {
    string commandline =
      StringPrintf("cp emulator_test.cc *.nes %s clean_%d/",
		   additional_files.c_str(),
		   rev);
    System(commandline);
  }

  // build and run emulator_test with --make-comprehensive result_%d.txt
  {
    string commandline =
      StringPrintf("make -j 12 -C clean_%d emulator_test.exe", rev);
    System(commandline);
  }

  // Actually run the test; this is what takes hours.
  {
    // Merely specifying --output-file enables comprehensive mode.
    string commandline =
      StringPrintf("cd clean_%d && emulator_test.exe "
		   "--romdir ../roms/ "
		   "--output-file ../results-%d.txt", rev, rev);
    System(commandline);
  }
  
  // Clean up the source after.
  {
    string commandline =
      StringPrintf("make -C clean_%d clean", rev);
    System(commandline);
  }

  {
    string commandline =
      StringPrintf("rm -f clean_%d/*.nes", rev);
    System(commandline);
  }
  
  // And delete the source tree?
  printf("\n\n\n"
	 "*********************************\n"
	 "Done generating results-%d.txt.\n"
	 "*********************************\n\n", rev);
  return 0;
}
