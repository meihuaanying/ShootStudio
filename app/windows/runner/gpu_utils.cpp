#include "gpu_utils.h"

#include <dxgi.h>
#include <windows.h>

#include <cwctype>
#include <string>

namespace {

std::string WideToUtf8(const std::wstring& text) {
  if (text.empty()) return std::string();
  const int size = ::WideCharToMultiByte(CP_UTF8, 0, text.c_str(),
                                         static_cast<int>(text.size()),
                                         nullptr, 0, nullptr, nullptr);
  if (size <= 0) return std::string();
  std::string out(static_cast<size_t>(size), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, text.c_str(),
                        static_cast<int>(text.size()), out.data(), size,
                        nullptr, nullptr);
  return out;
}

bool LooksVirtual(const std::wstring& name) {
  static const wchar_t* kTokens[] = {L"virtual", L"mumu", L"basic render",
                                     L"swiftshader", L"remote", L"parsec",
                                     L"spacedesk", L"idd", L"mirror"};
  std::wstring lower = name;
  for (wchar_t& ch : lower) {
    ch = static_cast<wchar_t>(::towlower(ch));
  }
  for (const wchar_t* token : kTokens) {
    if (lower.find(token) != std::wstring::npos) return true;
  }
  return false;
}

}  // namespace

std::vector<flutter::EncodableValue> EnumerateGpuAdapters() {
  std::vector<flutter::EncodableValue> out;
  IDXGIFactory1* factory = nullptr;
  const HRESULT hr = ::CreateDXGIFactory1(
      __uuidof(IDXGIFactory1), reinterpret_cast<void**>(&factory));
  if (FAILED(hr) || factory == nullptr) {
    return out;
  }
  UINT index = 0;
  IDXGIAdapter1* adapter = nullptr;
  while (factory->EnumAdapters1(index, &adapter) != DXGI_ERROR_NOT_FOUND) {
    DXGI_ADAPTER_DESC1 desc = {};
    if (SUCCEEDED(adapter->GetDesc1(&desc))) {
      const bool software = (desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) != 0;
      const std::wstring wide_name(desc.Description);
      if (!software && !LooksVirtual(wide_name)) {
        const unsigned long long dedicated = desc.DedicatedVideoMemory;
        const bool discrete =
            dedicated >= (512ull * 1024ull * 1024ull) && desc.VendorId != 0x8086;
        flutter::EncodableMap item;
        item[flutter::EncodableValue("index")] =
            flutter::EncodableValue(static_cast<int32_t>(index));
        item[flutter::EncodableValue("name")] =
            flutter::EncodableValue(WideToUtf8(wide_name));
        item[flutter::EncodableValue("vendorId")] =
            flutter::EncodableValue(static_cast<int32_t>(desc.VendorId));
        item[flutter::EncodableValue("deviceId")] =
            flutter::EncodableValue(static_cast<int32_t>(desc.DeviceId));
        item[flutter::EncodableValue("dedicatedVideoMb")] =
            flutter::EncodableValue(
                static_cast<int32_t>(dedicated / (1024ull * 1024ull)));
        item[flutter::EncodableValue("discrete")] =
            flutter::EncodableValue(discrete);
        out.emplace_back(flutter::EncodableValue(item));
      }
    }
    adapter->Release();
    adapter = nullptr;
    index++;
  }
  factory->Release();
  return out;
}
