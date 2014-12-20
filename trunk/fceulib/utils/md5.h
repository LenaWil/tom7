#ifndef _MD5_H
#define _MD5_H

#include "../types.h"
#include "fixedarray.h"

struct md5_context {
  uint32 total[2];
  uint32 state[4];
  uint8 buffer[64];
};

typedef FixedArray<uint8,16> MD5DATA;

void md5_starts( struct md5_context *ctx );
void md5_update( struct md5_context *ctx, uint8 *input, uint32 length );
void md5_finish( struct md5_context *ctx, uint8 digest[16] );

#endif /* md5.h */
