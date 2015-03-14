
// Port of BackwardsError in C++ code.

__kernel void BackwardLayer(// Size NUM_NODES.
			    __global const uint *inverted_indices_start,
			    __global const uint *inverted_indices_length,
			    // Size NUM_NODES * INDICES_PER_NODE.
			    __global const int *inverted_indices,
			    // Size NUM_NODES * INDICES_PER_NODE.
			    __global const float *dest_weights,
			    // Size NUM_NODES.
			    __global const float *src_output,
			    // Size NUM_NODES.
			    __global const float *dest_error,
			    // Size NUM_NODES; finally where we write:
			    __global float *src_error) {
  const int h = get_global_id(0);
  const float out_h = src_output[h];
  // Unpack inverted index for this node, so that we can loop over all of
  // the places its output is sent.
  const uint start = inverted_indices_start[h];
  const uint length = inverted_indices_length[h];

  // The error for a hidden node is the sum of all the errors for
  // the next layer, but modulated by the weight of the edge.
  float weighted_error_sum = 0.0f;
  for (int i = start; i < start + length; i++) {
    const int gidx = inverted_indices[i];
    // Compute from the index which destination node it belongs to.
    const int dest_node_idx = gidx / INDICES_PER_NODE;
    weighted_error_sum += dest_weights[gidx] * dest_error[dest_node_idx];
  }

  src_error[h] = out_h * (1.0f - out_h) * weighted_error_sum;
}
