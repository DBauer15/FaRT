// ======================================================================== //
// Copyright 2018-2019 Ingo Wald                                            //
//                                                                          //
// Licensed under the Apache License, Version 2.0 (the "License");          //
// you may not use this file except in compliance with the License.         //
// You may obtain a copy of the License at                                  //
//                                                                          //
//     http://www.apache.org/licenses/LICENSE-2.0                           //
//                                                                          //
// Unless required by applicable law or agreed to in writing, software      //
// distributed under the License is distributed on an "AS IS" BASIS,        //
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. //
// See the License for the specific language governing permissions and      //
// limitations under the License.                                           //
// ======================================================================== //

#pragma once

#include <cuda_runtime.h>
#include <optix.h>
#include <optix_stubs.h>

#include "common/defs.h"

#define OPTIX_CHECK( call )                                             \
  {                                                                     \
    OptixResult res = call;                                             \
    if( res != OPTIX_SUCCESS )                                          \
      {                                                                 \
        ERR("Optix call " + std::string(#call) + " failed with code " + std::to_string(res) + " (" + __FILE__ + ":" + std::to_string(__LINE__) + ")"); \
        exit(EXIT_FAILURE);                                                      \
      }                                                                 \
  }

#define CUDA_CHECK( call ) do {                         \
  cudaError_t err = call;                            \
  if (err != cudaSuccess) {                         \
    ERR(cudaGetErrorString(err));                   \
    ERR("CUDA call " + std::string(#call) + " failed with code " + std::to_string(err) + " (" + __FILE__ + ":" + std::to_string(__LINE__) + ")"); \
    exit(EXIT_FAILURE);                             \
  }                                                 \
} while(0)

#define CUDA_SYNC_CHECK()                                               \
  {                                                                     \
    cudaDeviceSynchronize();                                            \
    cudaError_t err = cudaGetLastError();                             \
    if( err != cudaSuccess )                                          \
      {                                                                 \
        ERR(cudaGetErrorString(err));                   \
        ERR("CUDA call failed with code " + std::to_string(err) + " (" + __FILE__ + ":" + std::to_string(__LINE__) + ")"); \
        exit(EXIT_FAILURE);                             \
      }                                                                 \
  }
