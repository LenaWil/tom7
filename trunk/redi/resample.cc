// XXX: Left off cleaning corpus at "dog"

#include <CL/cl.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <time.h>

#include <thread>
#include <mutex>

#include "mingw.thread.h"
#include "mingw.mutex.h"
// ugh, conflict...
#undef ARRAYSIZE

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

#define CHECK_SUCCESS(e) \
  do { int ret = (e); if (ret != CL_SUCCESS) { \
  fprintf(stderr, "Not successful with code %d.\n", ret); \
  abort(); } } while (0)

// Shares with the host memory and we don't control when it gets copied. This is
// quite inefficient.
template<class T>
static cl_mem BufferFromVector(cl_context context, bool readonly, vector<T> *v) {
  return clCreateBuffer(context, 
			(readonly ? CL_MEM_READ_ONLY : 0) | 
			CL_MEM_USE_HOST_PTR,
			sizeof (T) * v->size(),
			(void *) v->data(),
			nullptr);
}

// Creates a new buffer on the GPU and copies the memory there. They do not alias.
// Note that the command queue is not flushed, so you should not touch the source
// memory until it is.
template<class T>
static cl_mem MoveMemoryToGPU(cl_context context, cl_command_queue cmd,
			      bool readonly, vector<T> *v) {
  cl_mem buf = clCreateBuffer(context, 
			      (readonly ? CL_MEM_READ_ONLY : 0),
			      sizeof (T) * v->size(),
			      nullptr,
			      nullptr);
  clEnqueueWriteBuffer(cmd, buf, CL_TRUE, 0, 
		       sizeof (T) * v->size(), v->data(), 0, nullptr, nullptr);
  return buf;
}

// Same, but with a constant vector. Implies read-only.
template<class T>
static cl_mem MoveMemoryToGPUConst(cl_context context, cl_command_queue cmd,
				   const vector<T> &v) {
  cl_mem buf = clCreateBuffer(context, 
			      CL_MEM_READ_ONLY,
			      sizeof (T) * v.size(),
			      nullptr,
			      nullptr);
  clEnqueueWriteBuffer(cmd, buf, CL_TRUE, 0, 
		       sizeof (T) * v.size(), v.data(), 0, nullptr, nullptr);
  return buf;
}

template<class T>
static cl_mem CreateUninitializedGPUMemory(cl_context context, int n) {
  return clCreateBuffer(context, 0, sizeof (T) * n, nullptr, nullptr);
}

template<class T>
static vector<T> CopyBufferFromGPU(cl_command_queue cmd, cl_mem buf, int n) {
  vector<T> vec;
  vec.resize(n);
  CHECK_SUCCESS(clEnqueueReadBuffer(cmd, buf, CL_TRUE, 0, sizeof (T) * n,
				    vec.data(),
				    // No wait-list or event.
				    0, nullptr,
				    nullptr));
  clFinish(cmd);
  return vec;
}

// Get the 1024x1024 square out of the center of the image.
bool LoadImage1024(const string &filename, vector<uint8> *out) {
  // printf("%s\n", filename.c_str());
  int width, height, bpp_unused;
  uint8 *stb_rgba = stbi_load(filename.c_str(), 
			      &width, &height, &bpp_unused, 4);
  if (stb_rgba == nullptr) {
    fprintf(stderr, "%s: error opening/parsing\n", filename.c_str());
    return false;
  }

  // Converted by stb for us.
  static constexpr int bpp = 4;

  if (width < 1024 || height < 1024) {
    fprintf(stderr, "%s: is only %dx%d\n", filename.c_str(), width, height);
    return false;
  }

  const int skip_left = (width - 1024) >> 1;
  const int skip_top = (height - 1024) >> 1;
  // fprintf(stderr, "%s Skip %d/%d\n", filename.c_str(), skip_left, skip_top);

  out->resize(1024 * 1024 * bpp);

  for (int y = 0; y < 1024; y++) {
    int srcy = y + skip_top;
    for (int x = 0; x < 1024; x++) {
      int srcx = x + skip_left;
      int src = srcy * width * bpp +
	(srcx * bpp);
      int dst = y * 1024 * bpp +
	(x * bpp);
      for (int i = 0; i < 4; i++) {
	(*out)[dst + i] = stb_rgba[src + i];
      }
    }
  }

  stbi_image_free(stb_rgba);
  return true;
}

static void SaveImage(const string &filename, const vector<uint8> &img, int size) {
  CHECK(img.size() == size * size * 4);
  stbi_write_png(filename.c_str(), size, size, 4, img.data(), 4 * size);
}

// Run the function f on each element of vec in parallel. The caller must of course
// synchronize any accesses to shared data structures. Return value of function is
// ignored.
template<class T>
void ParallelApp(const vector<T> &vec, 
		 std::function<void(const T&)> &f,
		 int max_concurrency) {
  std::mutex index_m;
  int next_index = 0;
  
  // Thread applies f repeatedly until there are no more indices.
  // PERF: Can just start each thread knowing its start index, and avoid
  // the synchronization overhead at startup.
  auto th = [&index_m, &next_index, &vec, &f]() {
    for (;;) {
      index_m.lock();
      if (next_index == vec.size()) {
	// All done. Don't increment counter so that other threads can
	// notice this too.
	index_m.unlock();
	return;
      }
      int my_index = next_index++;
      index_m.unlock();

      // Do work, not holding mutex.
      (void)f(vec[my_index]);
    }
  };

  vector<std::thread> threads;
  threads.reserve(max_concurrency);
  for (int i = 0; i < max_concurrency; i++) {
    threads.emplace_back(th);
  }
  // Now just wait for them all to finish.
  for (std::thread &t : threads) t.join();
}

struct MutexLock {
  explicit MutexLock(std::mutex *m) : m(m) { m->lock(); }
  ~MutexLock() { m->unlock(); }
  std::mutex *m;
};

struct ResamplerCL {
  ResamplerCL(cl_device_id *devices,
	      cl_context context, cl_command_queue command_queue, int orig_width) :
    devices(devices), context(context), command_queue(command_queue),
    new_size(orig_width >> 1) {

    const string kernel_src = 
      StringPrintf("#define ORIG_WIDTH %d\n", orig_width) +
      Util::ReadFile("resample.cl");

    Timer gpu_compile;
    const char *sources[] = { kernel_src.c_str() };
    size_t source_size[] = { kernel_src.size() };
    program = clCreateProgramWithSource(context, 1, sources, source_size, nullptr);
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

    kernel = clCreateKernel(program, "resample", nullptr);
  }

  vector<uchar> Resample(const vector<uchar> &img) {
    // Can't have multiple threads setting a kernel's argument at one time.
    MutexLock ml(&m);

    cl_mem img_buf = MoveMemoryToGPUConst(context, command_queue, img);
    CHECK(img.size() == (new_size * 2) * (new_size * 2) * 4);
    cl_mem output_buf =
      CreateUninitializedGPUMemory<uchar>(context, new_size * new_size * 4);

    CHECK_SUCCESS(clSetKernelArg(kernel, 0, sizeof(cl_mem), (void *)&img_buf));
    CHECK_SUCCESS(clSetKernelArg(kernel, 1, sizeof(cl_mem), (void *)&output_buf));

    size_t global_work_offset[] = { 0 };
    size_t global_work_size[] = { (size_t)(new_size * new_size) };
    CHECK(CL_SUCCESS == clEnqueueNDRangeKernel(command_queue, kernel, 
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

    vector<uchar> result = 
      CopyBufferFromGPU<uchar>(command_queue, output_buf, new_size * new_size * 4);

    CHECK_SUCCESS(clReleaseMemObject(img_buf));
    CHECK_SUCCESS(clReleaseMemObject(output_buf));

    return result;
  }

  ~ResamplerCL() {
    CHECK_SUCCESS(clReleaseKernel(kernel));
    CHECK_SUCCESS(clReleaseProgram(program));
  }

  cl_device_id *devices;
  cl_context context;
  cl_command_queue command_queue;
  const int new_size = 0;
  // Owned:
  cl_program program;
  cl_kernel kernel;

  std::mutex m;
};

int main(int argc, char* argv[])  {
  Timer setup_timer;

  // Reports 1, currently, ugh.
  printf("[CPU] Has %d hardware concurrency\n", std::thread::hardware_concurrency());

  printf("[GPU] Initializing GPU.\n");
  
  cl_uint numPlatforms;
  cl_platform_id platform = nullptr;
  CHECK(CL_SUCCESS == clGetPlatformIDs(0, nullptr, &numPlatforms));
  printf("[GPU] There are %d platforms.\n", numPlatforms);

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

  cl_context context = clCreateContext(nullptr, 1, devices, nullptr, nullptr, nullptr);
  cl_command_queue command_queue = clCreateCommandQueue(context, devices[0], 0, nullptr);

  // Do this early so we see CL compilation errors.
  ResamplerCL resampler1{devices, context, command_queue, 1024};
  ResamplerCL resampler2{devices, context, command_queue, 512};

  vector<string> files = Util::ListFiles("corpus/");
  printf("Loading images:\n");

  // if (files.size() > 10) files.resize(10);

  vector<vector<uchar>> images;
  {
    std::mutex images_m;  
    uint64 bytes = 0ull;
    int loaded = 0, deleted = 0, failed = 0;
    int fs = (int)files.size();
    std::function<void(const string &s)> load_add = [&bytes, &loaded, &deleted, &failed, fs,
						     &images, &images_m](const string &f) {
      const string path = (string)"corpus/" + f;
      // printf("%s\n", f.c_str());
      vector<uint8> img;
      if (LoadImage1024(path, &img)) {
	MutexLock ml(&images_m);
	bytes += img.size();
	images.push_back(std::move(img));
	loaded++;

	if (images.size() % 10 == 0)
	  printf("%d/%d (%.2f%%), %d MB [deleted %d, failed %d]\n", 
		 loaded, fs,
		 (100.0 * loaded) / fs,
		 (int)(bytes / (1024 * 1024)),
		 deleted, failed);

      } else {
	{
	  MutexLock ml(&images_m);
	  printf("Unable to load %s.\n", path.c_str());
	}

	#if 1
	if (0 == unlink(path.c_str())) {
	  MutexLock ml(&images_m);
	  deleted++;
	} else {
	  MutexLock ml(&images_m);
	  failed++;
	}
	#endif
      }
    };

    ParallelApp(files, load_add, 16);
  }

  {
    std::mutex m, output;
    int num = (int)images.size();
    int done = 0;
    std::function<void(const vector<uint8> &v)> ResampleSave =
      [&resampler1, &resampler2, &m, &output, num, &done](const vector<uint8> &v) {
      vector<uchar> newimg = resampler1.Resample(v);
      vector<uchar> newimg2 = resampler2.Resample(newimg);
      
      int local_done = 0;
      {
	MutexLock ml(&m);
	local_done = done;
	done++;
      }

      SaveImage(StringPrintf("corpus256/img%d.png", local_done), newimg2, 256);

      if (local_done % 10 == 0) {
	MutexLock ml(&output);
	printf("%d/%d (%.2f%%) written\n", local_done, num,
	       (100.0 * local_done) / num);
      }
    };

    ParallelApp(images, ResampleSave, 8);
  }

  CHECK_SUCCESS(clReleaseCommandQueue(command_queue));
  CHECK_SUCCESS(clReleaseContext(context));
  free(devices);
  return 0;
}
