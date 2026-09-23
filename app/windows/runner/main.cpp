#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Allow WebView2 to XHR/fetch engine assets (GLB/manifest) from file:// URLs.
  // V7/D135: append GPU flags from %LOCALAPPDATA%\ShootStudio\gpu_mode.txt
  // (written by the app's GPU settings card: auto/discrete/integrated/software).
  // Keep comments ASCII-only (MSVC C4819 with /WX on non-UTF8 code pages).
  std::wstring browser_args = L"--allow-file-access-from-files";
  {
    wchar_t local_appdata[MAX_PATH] = {0};
    const DWORD len =
        ::GetEnvironmentVariableW(L"LOCALAPPDATA", local_appdata, MAX_PATH);
    if (len > 0 && len < MAX_PATH) {
      const std::wstring path = std::wstring(local_appdata) +
                                L"\\ShootStudio\\gpu_mode.txt";
      HANDLE file = ::CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ,
                                  nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
                                  nullptr);
      if (file != INVALID_HANDLE_VALUE) {
        char buffer[32] = {0};
        DWORD read = 0;
        if (::ReadFile(file, buffer, sizeof(buffer) - 1, &read, nullptr) &&
            read > 0) {
          std::string mode(buffer, read);
          while (!mode.empty() && (mode.back() == '\n' ||
                                   mode.back() == '\r' || mode.back() == ' ')) {
            mode.pop_back();
          }
          if (mode == "discrete") {
            browser_args += L" --force_high_performance_gpu";
          } else if (mode == "software") {
            browser_args += L" --disable-gpu --use-angle=swiftshader"
                            L" --enable-unsafe-swiftshader";
          }
        }
        ::CloseHandle(file);
      }
    }
  }
  _wputenv_s(L"WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS", browser_args.c_str());

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // F8: single instance - the second instance activates the existing window
  // and exits (quit-on-close, no tray). Keep this comment ASCII-only: MSVC
  // treats C4819 as an error under /WX on non-UTF8 code pages.
  HANDLE instance_mutex =
      ::CreateMutexW(nullptr, TRUE, L"ShootStudioSingleInstance-v1");
  if (instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", nullptr);
    if (existing != nullptr) {
      if (::IsIconic(existing)) {
        ::ShowWindow(existing, SW_RESTORE);
      }
      ::SetForegroundWindow(existing);
    }
    ::CloseHandle(instance_mutex);
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"shoot_studio", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
