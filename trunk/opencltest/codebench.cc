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
// Better compatibility with CL.
typedef unsigned char uchar;

// static const int64 kNumProblems = 200; // 2000;
static const int64 kNumProblems = 9000;
// static const int64 kNumIters = 100000; // 1000000;
static const int64 kNumIters = 100000;

// We can't send too much work to a kernel at a given
// time, or else the screen freezes and Windows kills
// the display driver. There are multiple ways to deal
// with this, but one way is to split up the work.
static const int64 kMaxItersPerKernel = 110000000;

// Mem is 256 bytes.
void ByteMachine(const vector<uint8> &rom, 
		 uint8 *mem, int iters) {
  for (int i = 0; i < iters; i++) {
    // byte 0 is instruction pointer
    uint8 inst = rom[mem[0]];
    // 3 bits opcode, 5 bits regs/data
    uint8 opcode = inst >> 5;
    uint8 reg_srca = inst & 1;
    uint8 reg_srcb = (inst >> 1) & 3;
    uint8 reg_dst = (inst >> 3) & 3;

    // printf("%d:  %d(%d, %d, %d)\n", inst, opcode, reg_srca, reg_srcb, reg_dst);

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
  return; // XXX
  for (int p = 0; p < kNumProblems; p++) {
    printf("== Problem %d ==\n", p);
    for (int i = 0; i < 256; i++) {
      printf("%02x ", mems[p * 256 + i]);
    }
    printf("\n");
  }
}

static string MakeKernel(const vector<uint8> &rom) {
  string prelude =
    "/* Generated file! Do not edit */\n"
    "void ByteMachine(__global uchar *mem, int iters) {\n"
    "";

  string code =
    "for (int i = 0; i < iters; i++) {\n"
    "  // byte 0 is instruction pointer\n"
    "  uchar inst = mem[0];\n"
    "  switch (inst) {\n";

  // TODO PERF: Do some merging of branches? It's
  // easy when each one is independent like this,
  // though not clear it'd actually be better (e.g.
  // if it's using a dense jump table, this may
  // be equivalent or better.)
  for (int i = 0; i < 256; i++) {
    code += StringPrintf("  case %d: {\n", i);
    uchar inst = rom[i];
    // 3 bits opcode, 5 bits regs/data
    uchar opcode = inst >> 5;
    uchar reg_srca = inst & 1;
    uchar reg_srcb = (inst >> 1) & 3;
    uchar reg_dst = (inst >> 3) & 3;
    switch (opcode) {
    default:
      CHECK(!"impossible!");
      break;

    case 0: {
      // Load immediate.
      uchar imm = (inst & 15);
      code += StringPrintf("    mem[%d] = %d;\n",
			   reg_dst, imm);
      break;
    }

    case 1:
      // Add mod 256.
      code += StringPrintf("    mem[%d] = "
	                   "mem[%d] + mem[%d];\n",
	                   reg_dst,
			   reg_srca, reg_srcb);
      break;

    case 2:
      // Load indirect.
      code += StringPrintf("    mem[%d] = "
			   "mem[(uchar)(mem[%d] + mem[%d])];\n",
			   reg_dst,
			   reg_srca, reg_srcb);
      break;

    case 3:
      // Store indirect.
      code += StringPrintf("    mem[(uchar)(mem[%d] + mem[%d])] = "
			   "mem[%d];\n",
			   reg_srca, reg_srcb,
			   reg_dst);
      break;

    case 4:
      // Add if zero.
      code += StringPrintf("    if (!mem[%d]) { "
			   "mem[%d] += mem[%d]; }\n",
			   reg_srcb, 
			   reg_dst, reg_srca);
      break;

    case 5:
      // Left shift.
      // TODO: Maybe should mean shift by srcb+1.
      if (reg_srcb > 0) {
	code += StringPrintf("    mem[%d] = mem[%d] << %d;\n",
			     reg_dst,
			     reg_srca, reg_srcb);
      } else {
	// Constant shift by zero, but still have to move.
	code += StringPrintf("    mem[%d] = mem[%d];\n",
			     reg_dst, reg_srca);
      }
      break;

    case 6: {
      // Swap 1th register with nth.
      uchar lreg = inst & 15;
      if (lreg != 1) {
	code += StringPrintf("    uchar tmp = mem[1]; mem[1] = mem[%d]; mem[%d] = tmp;\n",
			     lreg, lreg);
      } else {
	code += "    /* Swap 1 with 1 = nop */\n";
      }
      break;
    }

    case 7:
      // xor
      if (reg_srca == reg_srcb) {
	code += StringPrintf("    mem[%d] = 0; /* self-xor */\n",
			     reg_dst);
      } else {
	code += StringPrintf("    mem[%d] = "
			     "mem[%d] ^ mem[%d];\n",
			     reg_dst,
			     reg_srca, reg_srcb);
      }
      break;
    }

    // On every instruction, break out of switch
    code += "    break;\n"
      "  }\n";
  }
      
  // End switch.
  code += "  }\n";

  // Increment instruction pointer after every inst.
  code += "mem[0]++;\n";
  // End for loop.
  code += "}\n";

  string epilogue =
    "}\n"
    "\n"
    "__kernel void codebench(__global uchar *rom, __global uchar *in) {\n"
    "  int num = get_global_id(0);\n"
    "  __global uchar *mem = &in[num * 256];\n"
    "  ByteMachine(mem, ITERS);\n"
    "}\n";

  return prelude + code + epilogue;
}

static void BenchmarkCPU(const vector<uint8> &rom,
			 vector<uint8> *mems) {
  printf("[CPU] Running sequentially on CPU.\n");
  uint64 start_time = time(NULL);
  
  for (int i = 0; i < kNumProblems; i++) {
    ByteMachine(rom,
		&(*mems)[i * 256], 
		kNumIters);
  }

  uint64 end_time = time(NULL);

  uint64 used_time = end_time - start_time;
  printf("[CPU] Ran %d problems for %d iterations in %.2f seconds.\n"
	 " (%.2f mega-iters/s)\n",
	 kNumProblems, kNumIters, 
	 (double)used_time,
	 (double)(kNumProblems * kNumIters) / 
	 (double)(used_time * 1000000.0));
}

int main(int argc, char* argv[])  {

  ArcFour rc("codebench");
  rc.Discard(2000);

  vector<uint8> rom;
  for (int i = 0; i < 256; i++) {
    // uchar b = rc.Byte();
    // uchar opcode = 5;
    // b = 1;
    // rom.push_back((opcode << 5) | (b & 31));
    rom.push_back(rc.Byte());
    // rom.push_back((3 << 5) | 33);
  }

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
  BenchmarkCPU(rom, &cpu_mem);

  printf(" **** CPU AFTER **** \n");
  PrintMems(cpu_mem);

  printf("[GPU] Initializing GPU.\n");
  
  // const string kernel_src = Util::ReadFile("codebench.cl");

  const string kernel_src = MakeKernel(rom);
  Util::WriteFile("gen-rom.cl", kernel_src);

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

  uint64 gpu_compile_start = time(NULL);
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
  uint64 gpu_compile_end = time(NULL);

  cl_mem rom_buffer = clCreateBuffer(context, CL_MEM_READ_ONLY | CL_MEM_USE_HOST_PTR,
				     rom.size(), (void *) &rom[0], NULL);

  cl_mem input_buffer = clCreateBuffer(context, CL_MEM_READ_WRITE | CL_MEM_USE_HOST_PTR, 
                                       gpu_mem.size(), (void *) &gpu_mem[0], NULL);

  /* Step 8: Create kernel object */
  printf("[GPU] Running on GPU.\n");
  uint64 gpu_start_time = time(NULL);
  cl_kernel kernel = clCreateKernel(program, "codebench", NULL);

  /* Step 9: Sets Kernel arguments. */
  CHECK(CL_SUCCESS == clSetKernelArg(kernel, 0, sizeof(cl_mem), (void *)&rom_buffer));
  CHECK(CL_SUCCESS == clSetKernelArg(kernel, 1, sizeof(cl_mem), (void *)&input_buffer));

  // Start multiple kernels pointing at the same arg. Conceptually this is a single
  // 1D kernel with work size kNumProblems, but we want to keep each Kernel
  // small enough that it doesn't freeze the screen or make Windows think the driver
  // has crashed.

  // Note, it's also possible to chunk by iteration count; just call the kernel
  // multiple times on the same global id.
  // Implicit floor.
  int64 problems_per_kernel = kMaxItersPerKernel / kNumIters;
  if (!problems_per_kernel) problems_per_kernel = 1;
  printf("[GPU] Total %d iters, max per kernel %d\n", 
	 kNumProblems * kNumIters, kMaxItersPerKernel);

  printf("[GPU] Running %d problem(s) (= %d iters) per kernel.\n",
	 problems_per_kernel, problems_per_kernel * kNumIters);
  
  // XXX assumes ppk | kNumProblems
  for (int i = 0; i < kNumProblems; i += problems_per_kernel) {
    int num_problems = min(problems_per_kernel, kNumProblems - i);
    printf("[GPU] Running %d at offset %d\n", num_problems, i);
    size_t global_work_offset[] = { i };
    size_t global_work_size[] = { num_problems };
    CHECK(CL_SUCCESS == clEnqueueNDRangeKernel(command_queue, kernel, 
					       // work dimensions
					       1, 
					       // global work offset
					       global_work_offset, 
					       // global work size
					       global_work_size, 
					       // local work size
					       NULL, 
					       // no wait list
					       0, NULL, 
					       // no event
					       NULL));
    // PERF any way to make this not have to FINISH the tasks?
    clFinish(command_queue);
    // Flush "works" but seems to slow down the interface more without
    // reducing the time to finish.
    // clFlush(command_queue);
  }

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
  printf("[GPU] Program generation/compilation took <%.2f sec.\n",
	 (double)(1 + gpu_compile_end - gpu_compile_start));
  printf("[GPU] Ran %d problems for %d iterations in %.2f seconds.\n"
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
