
typedef struct {
  // RNG state.  All values are possible.
  ulong state;
  // Controls which RNG sequence (stream) is selected. Must *always* be odd.
  ulong inc;
} pcg;

uint pcg_next(pcg *rng) {
  ulong oldstate = rng->state;
  rng->state = oldstate * 6364136223846793005ULL + rng->inc;
  ulong xorshifted = ((oldstate >> 18) ^ oldstate) >> 27;
  ulong rot = oldstate >> 59;
  return (xorshifted >> rot) | (xorshifted << ((-rot) & 31));
}

// Evaluation of single layer.

float GetOutput(float fv[FEATURES_PER_NODE], float inputs[INPUTS_SUMMED]) {
  float input_sum = 0.0;
  for (int i = 0; i < INPUTS_SUMMED; i++) {
    // PERF: Store these in unnormalized form, duh.
    float weight = fv[i] * 2.0 - 1.0;
    float weighted_value = inputs[i] * weight;
    input_sum += weighted_value;
  }

  // Evaluate the sigmoid on the input.
  int featurenum = INPUTS_SUMMED;
  float kf = fv[featurenum];
  featurenum++;
  float x0f = fv[featurenum];
  featurenum++;

  // Range in [0.1, 100] looks good. This is an exponent (in 10^x)
  // between -1 and 2.
  float k = exp10(kf * 3.0 - 1.0);

  // XXX not sure what good bounds for this are. Maximum range for the weighted sum
  // would be [-INPUTS_SUMMED, INPUTS_SUMMED] so we can use that.
  float x0 = x0f * (2 * INPUTS_SUMMED) - INPUTS_SUMMED;

  float output = 1.0 / (1.0 + exp(-k * (input_sum - x0)));

  return output;
}

void GetFeatures(__global float *feature_vector,
                 int num,
                 float fv[FEATURES_PER_NODE]) {
  // Copy of my features from the global array.
  const int featurenum_src = num * FEATURES_PER_NODE;

  for (int i = 0; i < FEATURES_PER_NODE; i++)
    fv[i] = feature_vector[featurenum_src + i];
}

void MakeInputVector(__global float *input_image,
                     int num,
                     int image_num,
                     float *inputs) {
  int pixel_num = num / NPP;
  // int channel_num = num % NPP;

  int pixel_y = pixel_num / WIDTH;
  int pixel_x = pixel_num % WIDTH;

  int image_src = image_num * NUM_NODES;

  // Neighbors first.
  int halfnb = NEIGHBORHOOD / 2;
  int input_idx = 0;
  for (int ny = -halfnb; ny <= halfnb; ny++) {
    for (int nx = -halfnb; nx <= halfnb; nx++) {
      int srcpx = (pixel_x + nx) % WIDTH;
      int srcpy = (pixel_y + ny) % HEIGHT;

      int srcnodenum = (srcpx + srcpy * WIDTH) * NPP;
      for (int ch = 0; ch < NPP; ch++) {
        inputs[input_idx] = input_image[image_src + srcnodenum + ch];
        input_idx++;
      }
    }
  }
}

__kernel void evaluate(__global float *input_image,
                       __global float *feature_vector,
                       __global float *output_image) {
  int num = get_global_id(0);
  float fv[FEATURES_PER_NODE];
  GetFeatures(feature_vector, num, fv);
  float inputs[INPUTS_SUMMED];
  MakeInputVector(input_image, num, 0, inputs);
  output_image[num] = GetOutput(fv, inputs);
}

__kernel void train(__global uchar *seeds,
                    __global float *input_image,
                    __global float *feature_vector,
                    __global float *output_image,
                    __global float *expected_image) {
  int num = get_global_id(0);
  float expected[IMAGES_PER_BATCH];
  for (int i = 0; i < IMAGES_PER_BATCH; i++) {
    expected[i] = expected_image[i * NUM_NODES + num];
  }
  pcg seed;
  seed.state = seeds[num % NUM_SEEDS] | (num << 8);
  seed.inc = num * 2 + 1;
  // First value is way too predictable.
  (void)pcg_next(&seed);

  // These are the same for each image.
  float fv[FEATURES_PER_NODE];
  GetFeatures(feature_vector, num, fv);

  // Packed array of inputs, one for each image in the batch.
  float inputs[INPUTS_SUMMED * IMAGES_PER_BATCH];
  for (int i = 0; i < IMAGES_PER_BATCH; i++) {
    MakeInputVector(input_image, num, i, &inputs[i * INPUTS_SUMMED]);
  }

  float outputs[IMAGES_PER_BATCH];
  float best_loss = 0;
  for (int i = 0; i < IMAGES_PER_BATCH; i++) {
    outputs[i] = GetOutput(fv, &inputs[i * INPUTS_SUMMED]);
    best_loss += fabs(outputs[i] - expected[i]);
  }

  // nb: This part could be parallelized too, as a subproblem num.
  // But what's the advantage when we have three million independent nodes to compute?
  bool improved_features = false;
  for (int rounds = 0; rounds < 50; rounds++) {
    float fvv[FEATURES_PER_NODE];
    for (int f = 0; f < FEATURES_PER_NODE; f++) {
      ulong b = pcg_next(&seed);
      // Only update one in four randomly.
      if ((b & 3) == 0) {
        // If we try to use too many bits here, something goes wrong,
        // either because it gets signed or because division by large
        // numbers is inaccurate in floating point or something. (Or
        // maybe the shift happens in 32 bits so it's always small?)
        // XXX Learn about this and fix!
        float rf = ((b >> 3) & 0x0FFFFFFF) / (float)0x0FFFFFFF;
        // Weight this blend by the magnitude of the current loss, maybe?
        fvv[f] = rf; // (fv[f] + rf) / 2.0;
      } else {
        fvv[f] = fv[f];
        // (Note: wastes randomness..)
      }
    }

    // Now evaluate and compare.
    float new_outputs[IMAGES_PER_BATCH];
    float new_loss = 0;
    for (int i = 0; i < IMAGES_PER_BATCH; i++) {
      new_outputs[i] = GetOutput(fvv, &inputs[i * INPUTS_SUMMED]);
      new_loss += fabs(new_outputs[i] - expected[i]);
    }
    if (new_loss < best_loss) {
      improved_features = true;
      best_loss = new_loss;
      for (int i = 0; i < IMAGES_PER_BATCH; i++) {
        outputs[i] = new_outputs[i];
      }
      for (int f = 0; f < FEATURES_PER_NODE; f++) {
        fv[f] = fvv[f];
      }
    }
  }

  if (improved_features) {
    // Now, update feature vector.
    const int featurenum_src = num * FEATURES_PER_NODE;
    for (int f = 0; f < FEATURES_PER_NODE; f++) {
      feature_vector[featurenum_src + f] = fv[f];
    }
  }

  for (int i = 0; i < IMAGES_PER_BATCH; i++) {
    output_image[i * NUM_NODES + num] = outputs[i];
  }

  // uint g = pcg_next(&seed); // MWC64X(&seed);
  // output_image[num] = g / (float)0xFFFFFFFF;

  if (num < NUM_SEEDS) {
    seeds[num] = pcg_next(&seed) & 255;
  }
}
