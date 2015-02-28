
__kernel void resample(__global uchar *input_image,
                       __global uchar *output_image) {
  // Call for new_size * new_size pixels.

  int outnum = get_global_id(0);

  int newsize = ORIG_WIDTH >> 1;

  int dsty = outnum / newsize;
  int dstx = outnum % newsize;

  int one_row = ORIG_WIDTH * 4;

  // Source pixel (top left).
  int src = (dsty * 2) * one_row + (dstx * 2) * 4;

  int r4 = 
    // top-left
    input_image[src] +
    // top-right
    input_image[src + 4] +
    // bottom-left
    input_image[src + one_row] +
    // bottom-right
    input_image[src + one_row + 4];
  src++;
  int g4 = 
    // top-left
    input_image[src] +
    // top-right
    input_image[src + 4] +
    // bottom-left
    input_image[src + one_row] +
    // bottom-right
    input_image[src + one_row + 4];
  src++;
  int b4 = 
    // top-left
    input_image[src] +
    // top-right
    input_image[src + 4] +
    // bottom-left
    input_image[src + one_row] +
    // bottom-right
    input_image[src + one_row + 4];
  src++;

  uchar r = r4 >> 2;
  uchar g = g4 >> 2;
  uchar b = b4 >> 2;

  // int outnum = (y * newsize) * 4 + (x * 4);

  output_image[4 * outnum] = r;
  output_image[4 * outnum + 1] = g;
  output_image[4 * outnum + 2] = b;
  output_image[4 * outnum + 3] = 0xFF;  // alpha

  /*
  output_image[4 * outnum] = (outnum % 3) ? 0xFF : 0x20;
  output_image[4 * outnum + 1] = (outnum % 2) ? 0xFF : 0x20;
  output_image[4 * outnum + 2] = (outnum % 7) ? 0xFF : 0x20;
  output_image[4 * outnum + 3] = 0xFF;
  */
}
