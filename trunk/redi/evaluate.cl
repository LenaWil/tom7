
// Evaluation of single layer.

__kernel void evaluate(__global float *input_image,
                       __global float *feature_vector,
                       __global float *output_image) {
  int num = get_global_id(0);
  int pixel_num = num / NPP;
  // int channel_num = num % NPP;

  int pixel_y = pixel_num / WIDTH;
  int pixel_x = pixel_num % WIDTH;

  // Compute weighted sum of inputs.

  // Neighbors first.
  int halfnb = NEIGHBORHOOD / 2;
  // Index of current feature. Start at my own 0th feature.
  int featurenum = num * FEATURES_PER_NODE;
  float input_sum = 0.0;
  for (int ny = -halfnb; ny <= halfnb; ny++) {
    for (int nx = -halfnb; nx <= halfnb; nx++) {
      int srcpx = (pixel_x + nx) % WIDTH;
      int srcpy = (pixel_y + ny) % HEIGHT;

      int srcnodenum = (srcpx + srcpy * WIDTH) * NPP;
      for (int ch = 0; ch < NPP; ch++) {
        // PERF: Store these in unnormalized form, duh.
        float weight = feature_vector[featurenum] * 2.0 - 1.0;
        featurenum++;

        float srcvalue = input_image[srcnodenum + ch];
        float weighted_value = srcvalue * weight;
        input_sum += weighted_value;
      }
    }
  }

  // Evaluate the sigmoid on the input.
  float kf = feature_vector[featurenum];
  featurenum++;
  float x0f = feature_vector[featurenum];
  featurenum++;

  // Range in [0.1, 100] looks good. This is an exponent (in 10^x)
  // between -1 and 2.
  float k = exp10(kf * 3.0 - 1.0);

  // XXX not sure what good bounds for this are. Maximum range for the weighted sum
  // would be [-INPUTS_SUMMED, INPUTS_SUMMED] so we can use that.
  float x0 = x0f * (2 * INPUTS_SUMMED) - INPUTS_SUMMED;

  float output = 1.0 / (1.0 + exp(-k * (input_sum - x0)));
  output_image[num] = output;
}
