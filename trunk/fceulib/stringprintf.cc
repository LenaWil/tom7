
// THIS FILE ONLY: StringPrintf code is from Google's open source
// code, Apache 2.0 license. See the file APACHE20.txt for more
// information. Note that the FSF considers Apache 2.0 to be compatible
// with GPL, in the sense that the GPL-licensed FCEUlib can incorporate
// Apache 2.0 code and relicense it under the GPL (with these notices).

#include <stdarg.h>
#include <cstdio>
#include <string>

using namespace std;

// Copyright 2002 and onwards Google Inc.
static void StringAppendV(string* dst, const char* format, va_list ap) {
  // First try with a small fixed size buffer
  char space[1024];

  // It's possible for methods that use a va_list to invalidate
  // the data in it upon use.  The fix is to make a copy
  // of the structure before using it and use that copy instead.
  va_list backup_ap;
  va_copy(backup_ap, ap);
  int result = vsnprintf(space, sizeof(space), format, backup_ap);
  va_end(backup_ap);

  if ((result >= 0) && (result < sizeof(space))) {
    // It fit
    dst->append(space, result);
    return;
  }

  // Repeatedly increase buffer size until it fits
  int length = sizeof(space);
  while (true) {
    if (result < 0) {
      // Older behavior: just try doubling the buffer size
      length *= 2;
    } else {
      // We need exactly "result+1" characters
      length = result+1;
    }
    char* buf = new char[length];

    // Restore the va_list before we use it again
    va_copy(backup_ap, ap);
    result = vsnprintf(buf, length, format, backup_ap);
    va_end(backup_ap);

    if ((result >= 0) && (result < length)) {
      // It fit
      dst->append(buf, result);
      delete[] buf;
      return;
    }
    delete[] buf;
  }
}

string FCEU_StringPrintf(const char* format, ...) {
  va_list ap;
  va_start(ap, format);
  string result;
  StringAppendV(&result, format, ap);
  va_end(ap);
  return result;
}
