#include <CL/cl.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <time.h>

#include "base/stringprintf.h"
#include "codebench.h"
#include "arcfour.h"

using namespace std;

// Little byte machine.
typedef unsigned char uint8;

static const int64 kNumProblems = 3000;
// XXX note this is duplicated in the cl code
static const int64 kNumIters = 1000000;

// Mem is 256 bytes.
void ByteMachine(uint8 *mem, int iters) {
  for (int i = 0; i < iters; i++) {
    // byte 0 is instruction pointer
    uint8 inst = mem[mem[0]];
    // 3 bits opcode, 5 bits regs/data
    uint8 opcode = inst >> 5;
    uint8 reg_srca = inst & 1;
    uint8 reg_srcb = (inst >> 1) & 3;
    uint8 reg_dst = (inst >> 3) & 3;
    switch (opcode) {
    case 0: {
      // Load immediate.
      uint8 imm = (inst & 15);
      mem[reg_dst] = imm;
      break;
    }

    case 1: {
      // Add mod 256.
      uint8 res = mem[reg_srca] + mem[reg_srcb];
      mem[reg_dst] = res;
      break;
    }

    case 2: {
      // Load indirect.
      uint8 addr = mem[reg_srca] + mem[reg_srcb];
      mem[reg_dst] = mem[addr];
      break;
    }

    case 3: {
      // Store indirect.
      uint8 addr = mem[reg_srca] + mem[reg_srcb];
      mem[addr] = mem[reg_dst];
      break;
    }

    case 4: {
      // Add if zero.
      if (!mem[reg_srcb]) {
	mem[reg_dst] += mem[reg_srca];
      }
      break;
    }
      
    case 5: {
      // Left shift.
      uint8 res = mem[reg_srca] << reg_srcb;
      mem[reg_dst] = res;
      break;
    }

    case 6: {
      // Swap 1th register with nth.
      uint8 lreg = inst & 15;
      uint8 tmp = mem[1];
      mem[1] = mem[lreg];
      mem[lreg] = tmp;
      break;
    }

    case 7: {
      // xor
      uint8 res = mem[reg_srca] ^ mem[reg_srcb];
      mem[reg_dst] = res;
      break;
    }
    }

    // And increment instruction pointer.
    mem[0]++;
  }
}

static void PrintMems(const vector<uint8> &mems) {
  return;
  for (int p = 0; p < kNumProblems; p++) {
    printf("== Problem %d ==\n", p);
    for (int i = 0; i < 256; i++) {
      printf("%02x ", mems[p * 256 + i]);
    }
    printf("\n");
  }
}

static void BenchmarkCPU(vector<uint8> *mems) {
  printf("[CPU] Running sequentially on CPU.\n");
  uint64 start_time = time(NULL);
  
  for (int i = 0; i < kNumProblems; i++) {
    ByteMachine(&(*mems)[i * 256], kNumIters);
  }

  uint64 end_time = time(NULL);

  uint64 used_time = end_time - start_time;
  printf("[CPU] Ran %lld problems for %lld iterations in %.2f seconds.\n"
	 " (%.2f mega-iters/s)\n",
	 kNumProblems, kNumIters, 
	 (double)used_time,
	 (double)(kNumProblems * kNumIters) / 
	 (double)(used_time * 1000000.0));
}

int main(int argc, char* argv[])  {

  ArcFour rc("codebench");
  rc.Discard(2000);
  
  vector<uint8> flatmem;
  flatmem.reserve(256 * kNumProblems);
  for (int p = 0; p < kNumProblems; p++) {
    for (int i = 0; i < 256; i++) {
      flatmem.push_back(rc.Byte());
    }
  }

  vector<uint8> cpu_mem = flatmem;
  vector<uint8> gpu_mem = flatmem;

  printf(" **** Before **** \n");
  PrintMems(cpu_mem);
  BenchmarkCPU(&cpu_mem);

  printf(" **** CPU AFTER **** \n");
  PrintMems(cpu_mem);

  // XXX don't skip
  // BenchmarkCPU(&cpu_mem);

  printf("[GPU] Initializing GPU.\n");
  const string kernel_src = Util::ReadFile("codebench.cl");

  cl_uint numPlatforms;
  cl_platform_id platform = NULL;
  CHECK(CL_SUCCESS == clGetPlatformIDs(0, NULL, &numPlatforms));

  // Choose the first platform. XXX Tom: Look into this to ensure this is what we actually want.
  if (numPlatforms > 0) {
    cl_platform_id *platforms = (cl_platform_id *)malloc(numPlatforms * sizeof(cl_platform_id));
    CHECK(CL_SUCCESS == clGetPlatformIDs(numPlatforms, platforms, NULL));
    platform = platforms[0];
    free(platforms);
  }

  // Get the GPU device.
  cl_uint numDevices = 0;
  cl_device_id *devices;
  CHECK(CL_SUCCESS == clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, 0, NULL, &numDevices));
  CHECK(numDevices > 0);

  devices = (cl_device_id *)malloc(numDevices * sizeof(cl_device_id));
  CHECK(CL_SUCCESS == clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, numDevices, devices, NULL));

  /* Step 3: Create context. */
  cl_context context = clCreateContext(NULL, 1, devices, NULL, NULL, NULL);
        
  /* Step 4: Creating command queue associate with the context. */
  cl_command_queue command_queue = clCreateCommandQueue(context, devices[0], 0, NULL);

  /* Step 5: Create program object */
  string full_src = StringPrintf("#define ITERS %lld\n\n%s",
				 kNumIters,
				 kernel_src.c_str());
  const char *sources[] = { full_src.c_str() };
  size_t source_size[] = { full_src.size() };
  cl_program program = clCreateProgramWithSource(context, 1, sources,
                                                 source_size, NULL);
        
  /* Step 6: Build program. */
  if (CL_SUCCESS != clBuildProgram(program, 1, devices, NULL, NULL, NULL)) {

    size_t blsize;
    
    CHECK(CL_SUCCESS == clGetProgramBuildInfo(program, devices[0], 
					      CL_PROGRAM_BUILD_LOG, 0, NULL, &blsize));
    char *build_log = (char *)malloc(blsize + 1);
    CHECK(CL_SUCCESS == clGetProgramBuildInfo(program, devices[0], 
					      CL_PROGRAM_BUILD_LOG, blsize, build_log, NULL));
    build_log[blsize] = 0;
    printf("Failed to compile:\n %s", build_log);
    exit(-1);
  }


  cl_mem input_buffer = clCreateBuffer(context, CL_MEM_READ_WRITE | CL_MEM_USE_HOST_PTR, 
                                       gpu_mem.size(), (void *) &gpu_mem[0], NULL);

  /*
  cl_mem output_buffer = clCreateBuffer(context, CL_MEM_WRITE_ONLY,
                                        strlength + 1, NULL, NULL);
  */

  /* Step 8: Create kernel object */
  printf("[GPU] Running on GPU.\n");
  uint64 gpu_start_time = time(NULL);
  cl_kernel kernel = clCreateKernel(program, "codebench", NULL);

  /* Step 9: Sets Kernel arguments. */
  CHECK(CL_SUCCESS == clSetKernelArg(kernel, 0, sizeof(cl_mem), (void *)&input_buffer));
  // CHECK(CL_SUCCESS == clSetKernelArg(kernel, 1, sizeof(cl_mem), (void *)&output_buffer));

  /* Step 10: Running the kernel. */
  size_t global_work_size[] = { kNumProblems };
  CHECK(CL_SUCCESS == clEnqueueNDRangeKernel(command_queue, kernel, 1, NULL, 
					     global_work_size, NULL, 0, NULL, NULL));

  /* Step 11: Read the cout put back to host memory. */
  // CHECK(CL_SUCCESS == clEnqueueReadBuffer(command_queue, output_buffer,
  // Blocking.
  // CL_TRUE, 0, strlength, output, 0, NULL, NULL));
  
  // Need to tell it that we're going to read from the gpu_mem vector again.
  // Note, this will safely wait for the kernel to complete because we did not
  // pass CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE when we created the command
  // queue. But for best performance we should probably do that.
  // www.khronos.org/registry/cl/sdk/1.0/docs/man/xhtml/clCreateCommandQueue.html
  cl_int errcode;
  clEnqueueMapBuffer(command_queue, input_buffer,
		     // Blocking.
		     CL_TRUE,
		     CL_MAP_READ | CL_MAP_WRITE,
		     // Offset, size.
		     0, gpu_mem.size(),
		     // wait list.
		     0, NULL,
		     // event
		     NULL,
		     &errcode);
  CHECK(CL_SUCCESS == errcode);

  uint64 gpu_end_time = time(NULL);
  
  printf(" **** GPU AFTER **** \n");
  PrintMems(gpu_mem);

  CHECK(gpu_mem.size() == cpu_mem.size());
  for (int i = 0; i < gpu_mem.size(); i++) {
    if (gpu_mem[i] != cpu_mem[i]) {
      printf("Didn't work: gpu_mem[%d] is %02x but expected %02x\n",
	     i, gpu_mem[i], cpu_mem[i]);
      exit(-1);
    }
  } 
  
  printf("OK!\n");

  uint64 used_time = gpu_end_time - gpu_start_time;
  printf("[GPU] Ran %lld problems for %lld iterations in %.2f seconds.\n"
	 " (%.2f mega-iters/s)\n",
	 kNumProblems, kNumIters, 
	 (double)used_time,
	 (double)(kNumProblems * kNumIters) / 
	 (double)(used_time * 1000000.0));
  		     
  // TODO: Should probably clEnqueueUnmapMemObject.

  /* Step 12: Clean the resources. */
  CHECK(CL_SUCCESS == clReleaseKernel(kernel));
  CHECK(CL_SUCCESS == clReleaseProgram(program));
  CHECK(CL_SUCCESS == clReleaseMemObject(input_buffer));
  CHECK(CL_SUCCESS == clReleaseCommandQueue(command_queue));
  CHECK(CL_SUCCESS == clReleaseContext(context));

  free(devices);

  return 0;
}
