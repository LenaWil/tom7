#include <CL/cl.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <time.h>

#include "base/stringprintf.h"
#include "base/logging.h"
#include "arcfour.h"
#include "util.h"
#include "timer.h"
#include "stb_image.h"
#include "stb_image_write.h"

#include "constants.h"

using namespace std;

// Little byte machine.
using uint8 = uint8_t;
// Better compatibility with CL.
using uchar = uint8_t;

using uint64 = uint64_t;

// The idea would be something like this. We have a huge array of nodes,
// corresponding to the image's RGB channels. Let's say that we have N layers.
// Each is that same size. On a given layer, a node gets inputs from all of
// the inputs "nearby" on the previous layer, plus a random subset of other
// nodes on the previous layer. The final layer is also an image, which should
// be with any "red i" removed. This setup is simple and pretty simple to
// implement on a GPU.
//
// Training: We can easily generate training data. We take random images from
// the world, like a bunch of images from the web, or even just random noise,
// gradients, etc. We then take a bunch of truetype fonts and draw a "red i"
// on the image in a random place (and orientation, etc.?). This gives us an
// example of the function, where the red i image is the input and the
// original is the output.
//
// OK, so we can run the training instance and compare its output to the real
// output. Then we have to update weights. I don't really know how people do
// this but it'd be fun to make something up. I guess the simplest thing is to
// generate some random perturbations of the parameter vector, and take the
// one that has the best loss. It would be better if we updated the weights of
// the features implicated in the loss. You could do this by looking at the
// pixel differences to produce a weight, then looking at just that
// corresponding pixel's node(s), and doing a weighted update of its
// parameters.
//
// Note that it would make sense to accumulate layers -- we start with a
// simple two-layer system, train it "until it converges" or whatever, then
// insert a new layer at the end. (End because end gets all the updates in
// that previous story.) OK, let's do this.


// Facts about the transfer function. We'd like every node to output a value
// between 0 and 1, which is accomplished with a sigmoid. The sigmoid has a
// formula like
//
//    fn x => (1 / (1 + e^(-k * (x - x0))))
//
// where k is some kind of smoothness parameter (controls how steep the
// activation is) and x0 is an offset. In practice, smoothness from -1 (very
// smooth) to -100 (very steep) seems like the right range.

static_assert((NPP >= 3), "Must have at least R, G, B pixels.");
static_assert((NEIGHBORHOOD & 1) == 1, "neighborhood must be odd.");

static_assert(RANDOM == 0, "random not yet supported.");

template<class T>
static cl_mem BufferFromVector(cl_context context, bool readonly, vector<T> *v) {
  return clCreateBuffer(context, 
			(readonly ? CL_MEM_READ_ONLY : 0) | 
			CL_MEM_USE_HOST_PTR,
			sizeof (T) * v->size(),
			(void *) v->data(),
			nullptr);
}

static void LoadImage(const string &filename, vector<cl_float> *img) {
  CHECK(img->size() == WIDTH * HEIGHT * NPP);
  int width, height, bpp_unused;
  uint8 *stb_rgba = stbi_load(filename.c_str(), 
			      &width, &height, &bpp_unused, 4);
  CHECK(stb_rgba);
  CHECK_EQ(WIDTH, width);
  CHECK_EQ(HEIGHT, height);
  // Converted by stb for us.
  static constexpr int bpp = 4;
  for (int i = 0; i < WIDTH * HEIGHT; i++) {
    int src = i * bpp;
    int dst = i * NPP;
    for (int j = 0; j < 3; j++) {
      (*img)[dst + j] = stb_rgba[src + j] / 255.0;
    }

    for (int j = 3; j < NPP; j++) {
      (*img)[dst + j] = 0.0f;
    }
  }
  stbi_image_free(stb_rgba);
}

static void SaveImage(const string &filename, const vector<cl_float> &img) {
  auto FloatByte = [](cl_float f) -> uint8 {
    if (f > 1.0) return 0xFF;
    else if (f < 0.0) return 0x00;
    else return (uint8)(f * 255.0);
  };

  vector<uint8> rgba;
  rgba.reserve(WIDTH * HEIGHT * 4);
  for (int i = 0; i < WIDTH * HEIGHT; i++) {
    for (int j = 0; j < 3; j++) {
      rgba.push_back(FloatByte(img[i * NPP + j]));
    }
    rgba.push_back(0xFF);
  }
  CHECK(rgba.size() == WIDTH * HEIGHT * 4);
  stbi_write_png(filename.c_str(), WIDTH, HEIGHT, 4, rgba.data(),
		 4 * WIDTH);
}

#define CHECK_SUCCESS(e) \
  do { int ret = (e); if (ret != CL_SUCCESS) { \
  fprintf(stderr, "Not successful with code %d.\n", ret); \
  abort(); } } while (0)

int main(int argc, char* argv[])  {
  Timer setup_timer;
  ArcFour rc("redi");
  rc.Discard(2000);

  auto RandFloat = [&rc]() -> float {
    uint32 uu = 0u;
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    return (float)(uu / (double)0xFFFFFFFF);
  };


  auto Rand64 = [&rc]() -> uint64 {
    uint64 uu = 0ULL;
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    uu = rc.Byte() | (uu << 8);
    return uu;
  };
  (void)Rand64;

  printf("[GPU] Initializing GPU.\n");
  
  const string kernel_src = 
    Util::ReadFile("constants.h") + "\n" +
    Util::ReadFile("evaluate.cl");


  cl_uint numPlatforms;
  cl_platform_id platform = nullptr;
  CHECK(CL_SUCCESS == clGetPlatformIDs(0, nullptr, &numPlatforms));

  // Choose the first platform. XXX Tom: Look into this to ensure this is what we actually want.
  if (numPlatforms > 0) {
    cl_platform_id *platforms = (cl_platform_id *)malloc(numPlatforms * sizeof(cl_platform_id));
    CHECK(CL_SUCCESS == clGetPlatformIDs(numPlatforms, platforms, nullptr));
    platform = platforms[0];
    free(platforms);
  }

  // Get the GPU device.
  cl_uint numDevices = 0;
  cl_device_id *devices;
  CHECK(CL_SUCCESS == clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, 0, nullptr, &numDevices));
  CHECK(numDevices > 0);

  devices = (cl_device_id *)malloc(numDevices * sizeof(cl_device_id));
  CHECK(CL_SUCCESS == clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, numDevices, devices, nullptr));

  /* Step 3: Create context. */
  cl_context context = clCreateContext(nullptr, 1, devices, nullptr, nullptr, nullptr);
        
  /* Step 4: Creating command queue associate with the context. */
  cl_command_queue command_queue = clCreateCommandQueue(context, devices[0], 0, nullptr);

  Timer gpu_compile;
  /* Step 5: Create program object */
  const char *sources[] = { kernel_src.c_str() };
  size_t source_size[] = { kernel_src.size() };
  cl_program program = clCreateProgramWithSource(context, 1, sources,
                                                 source_size, nullptr);

  /* Step 6: Build program. */
  if (CL_SUCCESS != clBuildProgram(program, 1, devices, nullptr, nullptr, nullptr)) {

    size_t blsize;
    
    CHECK(CL_SUCCESS == clGetProgramBuildInfo(program, devices[0], 
					      CL_PROGRAM_BUILD_LOG, 0, nullptr, &blsize));
    char *build_log = (char *)malloc(blsize + 1);
    CHECK(CL_SUCCESS == clGetProgramBuildInfo(program, devices[0], 
					      CL_PROGRAM_BUILD_LOG, blsize, build_log, nullptr));
    build_log[blsize] = 0;
    printf("Failed to compile:\n %s", build_log);
    exit(-1);
  }
  // double gpu_compile_ms = gpu_compile.MS();

  // Training instance.
  vector<cl_float> input_image(NUM_NODES, 0.0f);
  LoadImage("tom7.png", &input_image);
  vector<cl_float> expected_image = input_image;
  LoadImage("tom7-edges.png", &expected_image);
  // (expected image is currently unused.)
  // Actual result.
  vector<cl_float> output_image(NUM_NODES, 0.0f);

  vector<cl_float> eval_input(NUM_NODES, 0.0f);
  LoadImage("sick.png", &eval_input);
  vector<cl_float> eval_output(NUM_NODES, 0.0f);

  vector<uint8> seeds;
  seeds.reserve(NUM_SEEDS);
  for (int i = 0; i < NUM_SEEDS; i++) seeds.push_back(rc.Byte());

  cl_mem input_image_buf = BufferFromVector(context, true, &input_image);
  cl_mem expected_image_buf = BufferFromVector(context, true, &expected_image);
  cl_mem output_image_buf = BufferFromVector(context, false, &output_image);
  cl_mem seed_buf = BufferFromVector(context, false, &seeds);

  cl_mem eval_input_buf = BufferFromVector(context, true, &eval_input);
  cl_mem eval_output_buf = BufferFromVector(context, false, &eval_output);

  auto FloatMB = [](int n) {
    return StringPrintf("%.1f", (n * 4) / (1024.0 * 1024.0));
  };

  LOG(INFO) << "Nodes per layer: " << NUM_NODES << " (" << FloatMB(NUM_NODES) << "mb)";
  LOG(INFO) << "Total features per layer: " << NUM_FEATURES 
	    << " (" << FloatMB(NUM_FEATURES) << "mb)";
  vector<cl_float> features(NUM_FEATURES, 0.0f);

  cl_mem fv_buf = BufferFromVector(context, false, &features);

  // Randomize feature buffer to start.
  for (int i = 0; i < NUM_FEATURES; i++) {
    features[i] = RandFloat();
  }

  /* Step 8: Create kernel object */
  printf("[GPU] Running on GPU.\n");
  Timer create_kernel;
  cl_kernel train_kernel = clCreateKernel(program, "train", nullptr);
  cl_kernel eval_kernel = clCreateKernel(program, "evaluate", nullptr);
  double create_kernel_ms = create_kernel.MS();
  Timer gputimer;  

  // uint64 random_seed = Rand64();

  /* Step 9: Sets Kernel arguments. */
  Timer set_args;
  CHECK_SUCCESS(clSetKernelArg(train_kernel, 0, sizeof(cl_mem), (void *)&seed_buf));
  CHECK_SUCCESS(clSetKernelArg(train_kernel, 1, sizeof(cl_mem), (void *)&input_image_buf));
  CHECK_SUCCESS(clSetKernelArg(train_kernel, 2, sizeof(cl_mem), (void *)&fv_buf));
  CHECK_SUCCESS(clSetKernelArg(train_kernel, 3, sizeof(cl_mem), (void *)&output_image_buf));
  CHECK_SUCCESS(clSetKernelArg(train_kernel, 4, sizeof(cl_mem), (void *)&expected_image_buf));

  CHECK_SUCCESS(clSetKernelArg(eval_kernel,  0, sizeof(cl_mem), (void *)&eval_input_buf));
  CHECK_SUCCESS(clSetKernelArg(eval_kernel,  1, sizeof(cl_mem), (void *)&fv_buf));
  CHECK_SUCCESS(clSetKernelArg(eval_kernel,  2, sizeof(cl_mem), (void *)&eval_output_buf));
  double set_args_ms = set_args.MS();


  double setup_ms = setup_timer.MS();
  printf("Time creating kernel: %.4fs\n"
	 "Time setting args: %.4fs\n"
	 "Time setting up: %.4fs\n",
	 create_kernel_ms / 1000.0,
	 set_args_ms / 1000.0,
	 setup_ms / 1000.0);

  static constexpr int ITERATIONS = 2000;
  vector<double> iteration_times;
  for (int iter = 0; iter < ITERATIONS; iter++) {
    Timer iteration_timer;
    for (int h = 0; h < (NUM_NODES / CHUNK_SIZE); h++) {
      size_t global_work_offset[] = { (uint64)h * CHUNK_SIZE };
      size_t global_work_size[] = { CHUNK_SIZE };
      CHECK(CL_SUCCESS == clEnqueueNDRangeKernel(command_queue, train_kernel, 
						 // work dimensions
						 1, 
						 // global work offset
						 global_work_offset,
						 // global work size
						 global_work_size, 
						 // local work size
						 nullptr, 
						 // no wait list
						 0, nullptr, 
						 // no event
						 nullptr));
      clFinish(command_queue);
      printf("-");
    }
    // PERF any way to make this not have to FINISH the tasks?

    // Flush "works" but seems to slow down the interface more without
    // reducing the time to finish.
    // clFlush(command_queue);
    double iteration_ms = iteration_timer.MS();
    iteration_times.push_back(iteration_ms);
    // printf("[%.2f].", setup_timer.MS());
    printf("#");

    if (true || iter % 10 == 0) {
      CHECK(iteration_times.size() > 0);
      double sum = 0.0;
      for (int i = 0; i < iteration_times.size(); i++) {
	sum += iteration_times[i];
      }
      printf("\nAverage (full) iteration time: %fms.\n", sum / iteration_times.size());
      
      // Need to tell it that we're going to read from the gpu_mem vector again.
      // Note, this will safely wait for the kernel to complete because we did not
      // pass CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE when we created the command
      // queue. But for best performance we should probably do that.
      // www.khronos.org/registry/cl/sdk/1.0/docs/man/xhtml/clCreateCommandQueue.html
      cl_int errcode;
      clEnqueueMapBuffer(command_queue, output_image_buf,
			 // Blocking.
			 CL_TRUE,
			 CL_MAP_READ | CL_MAP_WRITE,
			 // Offset, size.
			 0, output_image.size(),
			 // wait list.
			 0, nullptr,
			 // event
			 nullptr,
			 &errcode);
      CHECK(CL_SUCCESS == errcode);
      string filename = StringPrintf("out-tom7-%d.png", iter);
      SaveImage(filename, output_image);
      printf("\nWrote %s.\n", filename.c_str());

      size_t global_work_offset[] = { 0 };
      size_t global_work_size[] = { NUM_NODES };
      CHECK(CL_SUCCESS == clEnqueueNDRangeKernel(command_queue, eval_kernel,
						 1,
						 global_work_offset,
						 global_work_size,
						 nullptr,
						 0, nullptr,
						 nullptr));
      clEnqueueMapBuffer(command_queue, eval_output_buf,
			 // Blocking.
			 CL_TRUE,
			 CL_MAP_READ | CL_MAP_WRITE,
			 // Offset, size.
			 0, output_image.size(),
			 // wait list.
			 0, nullptr,
			 // event
			 nullptr,
			 &errcode);
      CHECK(CL_SUCCESS == errcode);
      string evalfilename = StringPrintf("out-eval-%d.png", iter);
      SaveImage(evalfilename, eval_output);
      printf("\nWrote %s too.\n", evalfilename.c_str());
    }
  }
  printf("\n");


  double gpu_ms = gputimer.MS();
  
  printf(" **** GPU AFTER **** \n");


  printf("OK!\n");

  double used_time = gpu_ms / 1000.0;
  printf("[GPU] Time on GPU: %.4f sec\n"
	 "(%.4f sec/iteration)\n", 
	 used_time, used_time / ITERATIONS);
  		     
  // TODO: Should probably clEnqueueUnmapMemObject.

  /* Step 12: Clean the resources. */
  CHECK_SUCCESS(clReleaseKernel(train_kernel));
  CHECK_SUCCESS(clReleaseKernel(eval_kernel));
  CHECK_SUCCESS(clReleaseProgram(program));
  CHECK_SUCCESS(clReleaseMemObject(input_image_buf));
  CHECK_SUCCESS(clReleaseMemObject(expected_image_buf));
  CHECK_SUCCESS(clReleaseMemObject(output_image_buf));
  CHECK_SUCCESS(clReleaseMemObject(fv_buf));
  CHECK_SUCCESS(clReleaseMemObject(eval_output_buf));
  CHECK_SUCCESS(clReleaseMemObject(eval_input_buf));
  CHECK_SUCCESS(clReleaseCommandQueue(command_queue));
  CHECK_SUCCESS(clReleaseContext(context));


  free(devices);

  return 0;
}
