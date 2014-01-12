#include <CL/cl.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <time.h>

#include "timer.h"
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

// v[i] is true if i always falls through to instruction i + 1
// (ignoring iteration count).
vector<bool> MakeFallthrough(const vector<uint8> &rom) {
  vector<bool> fallthrough(256, false);
  // 255 is always false, because our switch ends there.
  for (int i = 0; i < 255; i++) {
    uchar inst = rom[i];
    uchar opcode = inst >> 5;
    uchar reg_dst = (inst >> 3) & 3;

    switch (opcode) {
    case 0:
    case 1:
    case 2:
    case 4:
    case 5:
    case 7:
      fallthrough[i] = reg_dst != 0;
      break;

    case 3:
      fallthrough[i] = false;
      break;

    case 6: {
      // Swap 1th register with nth.
      uchar lreg = inst & 15;
      if (lreg != 1) {
	fallthrough[i] = lreg != 0;
      } else {
	fallthrough[i] = true;
      }
      break;
    }

    default:
      CHECK(!"impossible - makefallthrough");
    }
  }
  return fallthrough;
}

vector<uint32> MakeDeadRegs(const vector<uint8> &rom) {
  vector<uint32> dead(256, 0);

  vector<bool> fallthrough = MakeFallthrough(rom);
  // A reg is "dead" at a location if it will surely be overwritten by
  // a later instruction without being used. For 255, nothing is dead
  // because we always loop after that. (PERF: though we could analyze
  // as if mod 256 in some conditions?)
  for (int i = 254; i >= 0; i--) {
    // If we know we're falling through, then we inherit the dead
    // value from the next instruction. Otherwise, nothing is assumed
    // dead.
    if (!fallthrough[i]) {
      // Can't assume anything about what follows this instruction
      // if we're not falling through.
      dead[i] = 0;
      continue;
    }

    uint32 next_dead = dead[i + 1];
    uchar next_inst = rom[i + 1];

    uchar opcode = next_inst >> 5;
    uchar reg_srca = next_inst & 1;
    uchar reg_srcb = (next_inst >> 1) & 3;
    uchar reg_dst = (next_inst >> 3) & 3;

#   define ADD(reg)    | (1 << (reg))
#   define REMOVE(reg) & ~(1 << (reg))
    // A simple read of reg 0 doesn't need to mark it live, since we
    // just fill this in with a constant.
#   define SIMPLE_READ(reg)   & ((reg) ? ~(1 << (reg)) : ~0)

    // PERF: We don't need to worry about explicit reads of
    // m[0] since we always know the value and can replace it
    // with a constant. But we don't do that yet.
    switch (opcode) {
      // default:
      // CHECK(!"impossible - makedeadregs");
      // break;

    case 0:
      dead[i] = next_dead  ADD(reg_dst);
      break;

    case 1:
      // Reads from A and B, so those are live.
      dead[i] = (next_dead  ADD(reg_dst))
	SIMPLE_READ(reg_srca)
	SIMPLE_READ(reg_srcb);
      break;

    case 7:
      // Like add, though PERF when reg_srca == reg_srcb
      // since we don't actually need to read it.
      dead[i] = (next_dead  ADD(reg_dst))
	SIMPLE_READ(reg_srca)
	SIMPLE_READ(reg_srcb);
      break;

    case 2:
      // Indirect load. Could read from anything so
      // nothing is dead. Lose everything.
      dead[i] = 0;
      break;

    case 3:
      // Indirect store; could write to any memory
      // location, but that just increases the
      // amount of deadness (in an unknowable way).
      // Does three reads. (However, since it also
      // always branches into unknown code, we
      // won't ever know for sure that any reg is
      // dead -- this is handled at the top when
      // we check for fallthrough.)
      dead[i] = next_dead
	REMOVE(reg_srca)
	REMOVE(reg_srcb)
	REMOVE(reg_dst);
      break;

    default:
      CHECK(!"impossible - nextdead");
      break;

    case 4:
      // Add if zero. Can't be sure it writes to dst, so this doesn't
      // add any deadness. It does read from the two regs and may read
      // from dst (+=). However, if it falls though then we can still
      // inherit deadness.
      dead[i] = next_dead
	REMOVE(reg_dst)
	SIMPLE_READ(reg_srca)
	SIMPLE_READ(reg_srcb);
      break;

    case 5:
      // Left shift. Reads one reg, writes another.
      // reg_b is used as data, not a register name
      dead[i] = (next_dead  ADD(reg_dst))
	SIMPLE_READ(reg_srca);
      break;

    case 6: {
      // Swap the deadness of the two regs.
      uchar lreg = next_inst & 15;
      bool deadone = next_dead & (1 << 1);
      bool deaddst = next_dead & (1 << lreg);

      /*
      printf("inst %d nextdead %d  %s %s %s ",
	     i, next_dead,
	     deadone ? "ONE" : "_",
	     deaddst ? "DST" : "_",
	     fallthrough[i] ? "FT" : "br");
      */

      // Clear both.
      next_dead = next_dead
	REMOVE(1)
	REMOVE(lreg);

      // Now add them back, but swapped.
      if (deadone) {
	next_dead = next_dead
	  ADD(lreg);
      }

      if (deaddst) {
	next_dead = next_dead
	  ADD(1);
      }

      printf(" -> %d\n", next_dead);

      dead[i] = next_dead;
      break;
    }

    }
    }
  return dead;
}

static string RegExp(int inst, int reg) {
  if (reg == 0) return StringPrintf("((uchar)%d)", inst);
  else return StringPrintf("m[%d]", reg);
}

static string MakeKernel(const vector<uint8> &rom) {
  string prelude =
    "/* Generated file! Do not edit */\n" +
    // Defines ByteMachineExact(rom, mem, iters)
    Util::ReadFile("bytemachine-exact.cl") + "\n"
    // Returns number of iterations
    "int ByteMachine(__global uchar *m, int iters) {\n"
    "";

  string code =
    // - 256? what's the actual worst case?
    "int i = 0;\n"
    "for (; i < iters - 257; i++) {\n"
    "  // byte 0 is instruction pointer\n"
    "  uchar addr = m[0];\n"
    "  switch (addr) {\n";

  // TODO PERF: Do some merging of branches? It's
  // easy when each one is independent like this,
  // though not clear it'd actually be better (e.g.
  // if it's using a dense jump table, this may
  // be equivalent or better.)

  vector<uint32> dead = MakeDeadRegs(rom);
  vector<bool> fallthrough = MakeFallthrough(rom);

  int skip_set_ip = 0;

  // PERF: If setting m[0] to a constant and breaking, 
  // can set to that value + 1, then continue.
  for (int i = 0; i < 256; i++) {
    string deadmask = "/* ";
    for (int b = 0; b < 8; b++) {
      deadmask += (dead[i] & (1 << b)) ? "X" : ".";
    }
    deadmask += fallthrough[i] ? " F" : " -";
    deadmask += " */";

    code += StringPrintf("  %s case %d: ", 
			 deadmask.c_str(), i);
    uchar inst = rom[i];
    // 3 bits opcode, 5 bits regs/data
    uchar opcode = inst >> 5;
    uchar reg_srca = inst & 1;
    uchar reg_srcb = (inst >> 1) & 3;
    uchar reg_dst = (inst >> 3) & 3;

    // We can always end an instruction by just breaking,
    // which will increment the instruction pointer and
    // loop (which tests the iteration count, and jumps
    // to the next address).
    string next_safe = " break;";

    // But most of the time we can tell that the IP was
    // not modified. In that case we can fall through.
    string set_ip = (dead[i] & (1 << 0)) ? 
      " /* m0 dead */ " :
      StringPrintf(" m[0] = %d; ", (i + 1) & 255);
    string next_fallthrough =
      set_ip +
      "++i;";

    string next = fallthrough[i] ? next_fallthrough : next_safe;

    if (fallthrough[i] && (dead[i] & (1 << 0))) {
      skip_set_ip++;
    }

    switch (opcode) {
    default:
      CHECK(!"impossible!");
      break;

    case 0: {
      // Load immediate.
      uchar imm = (inst & 15);
      code += StringPrintf("m[%d] = %d;",
			   reg_dst, imm);
      break;
    }

    case 1:
      // Add mod 256.
      code += StringPrintf("m[%d] = %s + %s;",
	                   reg_dst,
			   RegExp(i, reg_srca).c_str(),
			   RegExp(i, reg_srcb).c_str());
      break;

    case 2:
      // Load indirect.
      code += StringPrintf("m[%d] = "
			   "m[(uchar)(%s + %s)];",
			   reg_dst,
			   RegExp(i, reg_srca).c_str(),
			   RegExp(i, reg_srcb).c_str());
      break;

    case 3:
      // Store indirect.
      code += StringPrintf("m[(uchar)(%s + %s)] = "
			   "%s;",
			   RegExp(i, reg_srca).c_str(), 
			   RegExp(i, reg_srcb).c_str(),
			   RegExp(i, reg_dst).c_str());
      break;

    case 4:
      // Add if zero.
      // PERF nice simplification if reg happens to be 0
      code += StringPrintf("if (!%s) { "
			   "m[%d] += %s; }",
			   RegExp(i, reg_srcb).c_str(), 
			   reg_dst, 
			   RegExp(i, reg_srca).c_str());
      break;

    case 5:
      // Left shift.
      // TODO: Maybe should mean shift by srcb+1.
      if (reg_srcb > 0) {
	code += StringPrintf("m[%d] = %s << %d;",
			     reg_dst,
			     RegExp(i, reg_srca).c_str(), reg_srcb);
      } else {
	// Constant shift by zero, but still have to move.
	code += StringPrintf("m[%d] = %s;",
			     reg_dst, 
			     RegExp(i, reg_srca).c_str());
      }
      break;

    case 6: {
      // Swap 1th register with nth.
      uchar lreg = inst & 15;
      if (lreg != 1) {
	code += StringPrintf("{ uchar tmp = m[1]; m[1] = %s; m[%d] = tmp; }",
			     RegExp(i, lreg).c_str(), lreg);
      } else {
	code += "/* Swap 1 with 1 = nop */";
      }
      break;
    }

    case 7:
      // xor
      if (reg_srca == reg_srcb) {
	code += StringPrintf("m[%d] = 0; /* self-xor */",
			     reg_dst);
      } else {
	code += StringPrintf("m[%d] = %s ^ %s;",
			     reg_dst,
			     RegExp(i, reg_srca).c_str(), 
			     RegExp(i, reg_srcb).c_str());
      }
      break;
    }

    code += next;

    // Newline after next_break or next_safe.
    code += "\n";
  }
      
  // End switch.
  code += "  }\n";

  // Increment instruction pointer after every inst.
  code += "  m[0]++;\n";
  // End for loop.
  code += "}\n";

  // Number of actual iterations performed.
  code += "return i;\n";

  string epilogue =
    "}\n"
    "\n"
    "__kernel void codebench(__global uchar *rom, __global uchar *in) {\n"
    "  int num = get_global_id(0);\n"
    "  __global uchar *mem = &in[num * 256];\n"
    "  int itersleft = ITERS;\n"
    "  itersleft -= ByteMachine(mem, itersleft);\n"
    "  ByteMachineExact(rom, mem, itersleft);\n"
    "}\n";

  printf ("Skipped writing IP for %d instructions\n", skip_set_ip);

  return prelude + code + epilogue;
}

static void BenchmarkCPU(const vector<uint8> &rom,
			 vector<uint8> *mems) {
  printf("[CPU] Running sequentially on CPU.\n");
  Timer timer;
  
  for (int i = 0; i < kNumProblems; i++) {
    ByteMachine(rom,
		&(*mems)[i * 256], 
		kNumIters);
  }

  double used_time = timer.MS() / 1000.0;
  printf("[CPU] Ran %d problems for %d iterations in %.4f seconds.\n"
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

  Timer gpu_compile;
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
  double gpu_compile_ms = gpu_compile.MS();

  cl_mem rom_buffer = clCreateBuffer(context, CL_MEM_READ_ONLY | CL_MEM_USE_HOST_PTR,
				     rom.size(), (void *) &rom[0], NULL);

  cl_mem input_buffer = clCreateBuffer(context, CL_MEM_READ_WRITE | CL_MEM_USE_HOST_PTR, 
                                       gpu_mem.size(), (void *) &gpu_mem[0], NULL);

  /* Step 8: Create kernel object */
  printf("[GPU] Running on GPU.\n");
  cl_kernel kernel = clCreateKernel(program, "codebench", NULL);

  Timer gputimer;
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

  double gpu_ms = gputimer.MS();
  
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

  double used_time = gpu_ms / 1000.0;
  printf("[GPU] Program generation/compilation took %.1f ms.\n",
	 gpu_compile_ms);
  printf("[GPU] Ran %d problems for %d iterations in %.4f seconds.\n"
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
