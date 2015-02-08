#include <cstdio>

int main () {
  unsigned int crc_table[256] = {0};
  int i,j;
  for(i=0; i < 256; i++)
    for (crc_table[i]=i, j=0; j < 8; ++j)
      crc_table[i] = (crc_table[i] >> 1) ^ (crc_table[i] & 1 ? 0xedb88320 : 0);
  
  printf("static constexpr unsigned int crc_table[256] = {\n");
  for (i = 0; i < 256; i++) {
    if (!(i % 6)) printf("\n");
    printf("%u, ", crc_table[i]);
  }
  printf("};\n");
  return 0;
}
