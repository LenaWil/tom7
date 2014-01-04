#include <CL/cl.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <string>

#include "codebench.h"

using namespace std;

int main(int argc, char* argv[])  {
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

  devices = (cl_device_id*)malloc(numDevices * sizeof(cl_device_id));
  CHECK(CL_SUCCESS == clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, numDevices, devices, NULL));

  /* Step 3: Create context. */
  cl_context context = clCreateContext(NULL, 1, devices, NULL, NULL, NULL);
        
  /* Step 4: Creating command queue associate with the context. */
  cl_command_queue command_queue = clCreateCommandQueue(context, devices[0], 0, NULL);

  /* Step 5: Create program object */
  const char *sources[] = { kernel_src.c_str() };
  size_t source_size[] = { kernel_src.size() };
  cl_program program = clCreateProgramWithSource(context, 1, sources,
                                                 source_size, NULL);
        
  /* Step 6: Build program. */
  CHECK(CL_SUCCESS == clBuildProgram(program, 1, devices, NULL, NULL, NULL));

  /* Step 7: Initial input, output for the host and create memory objects for the kernel */
  const char *input = "GdkknVnqkc";
  size_t strlength = strlen(input);
  printf("input string: [%s]\n", input);
  char *output = (char *) malloc(strlength + 1);

  cl_mem input_buffer = clCreateBuffer(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, 
                                       strlength + 1, (void *) input, NULL);
  cl_mem output_buffer = clCreateBuffer(context, CL_MEM_WRITE_ONLY,
                                        strlength + 1, NULL, NULL);

  /* Step 8: Create kernel object */
  cl_kernel kernel = clCreateKernel(program, "helloworld", NULL);

  /* Step 9: Sets Kernel arguments. */
  CHECK(CL_SUCCESS == clSetKernelArg(kernel, 0, sizeof(cl_mem), (void *)&input_buffer));
  CHECK(CL_SUCCESS == clSetKernelArg(kernel, 1, sizeof(cl_mem), (void *)&output_buffer));

  /* Step 10: Running the kernel. */
  size_t global_work_size[] = { strlength };
  CHECK(CL_SUCCESS == clEnqueueNDRangeKernel(command_queue, kernel, 1, NULL, 
					    global_work_size, NULL, 0, NULL, NULL));

  /*Step 11: Read the cout put back to host memory.*/
  CHECK(CL_SUCCESS == clEnqueueReadBuffer(command_queue, output_buffer, CL_TRUE, 0,
					  strlength, output, 0, NULL, NULL));

  output[strlength] = '\0';        
  printf("output string: [%s]\n", output);

  if (!strcmp("HelloWorld", output)) {
    printf("Got the expected result\n");
  } else {
    printf("Did not Got the expected result\n");
  }

  /* Step 12: Clean the resources. */
  CHECK(CL_SUCCESS == clReleaseKernel(kernel));
  CHECK(CL_SUCCESS == clReleaseProgram(program));
  CHECK(CL_SUCCESS == clReleaseMemObject(input_buffer));
  CHECK(CL_SUCCESS == clReleaseMemObject(output_buffer));
  CHECK(CL_SUCCESS == clReleaseCommandQueue(command_queue));
  CHECK(CL_SUCCESS == clReleaseContext(context));

  free(output);
  free(devices);

  return 0;
}
