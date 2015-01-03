#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <iomanip>
#include <fstream>
#include <limits.h>
#include <stdarg.h>

#include "emufile.h"
#include "version.h"
#include "types.h"
#include "utils/endian.h"
#include "palette.h"
#include "input.h"
#include "fceu.h"
#include "driver.h"
#include "state.h"
#include "file.h"
#include "video.h"
#include "movie.h"
#include "fds.h"

#include "utils/guid.h"
#include "utils/memory.h"
#include "utils/xstring.h"
#include <sstream>


