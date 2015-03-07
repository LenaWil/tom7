
// A layer is simply defined by the values of the previous layer, and
// weights of the incoming edges. Because our layers are so big (as a
// consequence of representing image data), we don't store this as
// a dense vector (it would be like (3*2^16)^2 floats; ~150GB); instead
// each node has a sparse set of its inputs from the previous layer.
//
// We have to know how many indices each node uses, as a constant.

__kernel void ForwardLayer(// Size NUM_NODES, if each layer is the same
                           // size.
                           __global const float *previous_layer_outputs,
                           // Size NUM_NODES * INDICES_PER_NODE.
                           __global const int *indices,
                           // Size NUM_NODES * INDICES_PER_NODE; parallel
                           // to the previous.
                           __global const float *weights,
                           // Size NUM_NODES (this layer).
                           __global const float *bias,
                           // Size NUM_NODES.
                           __global float *output_values) {
  const int node_id = get_global_id(0);

  // Start with bias.
  double potential = bias[node_id];
  const __global float *my_weights = weights + (node_id * INDICES_PER_NODE);
  const __global int *my_indices = indices + (node_id * INDICES_PER_NODE);

  // Could itself be a kernel? Not sure what the right granularity of these is.
  for (int i = 0; i < INDICES_PER_NODE; i++) {
    const float w = my_weights[i];
    const float v = previous_layer_outputs[my_indices[i]];
    potential += w * v;
  }
  output_values[node_id] = 1.0 / (1.0 + exp(-potential));
}
