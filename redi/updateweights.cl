__kernel void UpdateWeights(float learning_rate,
                            __global const float *layer_error,
                            // NUM_NODES * INDICES_PER_NODE
                            __global const int *layer_indices,
                            __global const float *layer_values,
                            // NUM_NODES * INDICES_PER_NODE,
                            __global float *layer_weights,
                            // NUM_NODES
                            __global float *layer_biases) {
  const int node_idx = get_global_id(0);
  const float delta_j = layer_error[node_idx];
  const float learning_rate_times_delta_j = learning_rate * delta_j;

  for (int input_idx = 0; input_idx < INDICES_PER_NODE; input_idx++) {
    const int gidx = INDICES_PER_NODE * node_idx + input_idx;
    // Offset of the node, which we use to get its output.
    const int src_idx = layer_indices[gidx];
    const float x_ji = layer_values[src_idx];

    layer_weights[gidx] += learning_rate_times_delta_j * x_ji;
  }
  layer_biases[node_idx] += learning_rate_times_delta_j;
}
