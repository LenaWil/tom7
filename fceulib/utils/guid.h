#ifndef _guid_h_
#define _guid_h_

#include <string>
#include "../types.h"
#include "fixedarray.h"

struct FCEU_Guid : public FixedArray<uint8,16> {
  void newGuid();
  std::string toString();
  static FCEU_Guid fromString(const std::string &str);
  static uint8 hexToByte(char** ptrptr);
 private:
  void scan(std::string& str);
};


#endif
