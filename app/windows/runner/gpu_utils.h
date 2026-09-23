#ifndef RUNNER_GPU_UTILS_H_
#define RUNNER_GPU_UTILS_H_

#include <flutter/encodable_value.h>

#include <vector>

// V7/D135: enumerate DXGI adapters for the GPU settings card.
// Filters out software and virtual adapters (e.g. emulator display drivers).
std::vector<flutter::EncodableValue> EnumerateGpuAdapters();

#endif  // RUNNER_GPU_UTILS_H_
