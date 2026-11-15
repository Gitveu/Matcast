#include "flutter_window.h"

#include <optional>
#include <fstream>

#include "flutter/generated_plugin_registrant.h"
#include "cast_engine_bridge.h"

static void LogWindow(const std::string& msg) {
  std::ofstream ofs("matcast_engine.log", std::ios::app);
  if (ofs.is_open()) {
    ofs << msg << std::endl;
  }
}

static std::wstring GetSettingsFilePathW() {
  wchar_t buffer[MAX_PATH];
  if (::GetModuleFileNameW(nullptr, buffer, MAX_PATH) > 0) {
    std::wstring path(buffer);
    size_t last_slash = path.find_last_of(L"\\/");
    if (last_slash != std::wstring::npos) {
      std::wstring dir = path.substr(0, last_slash);
      std::wstring fullPath = dir + L"\\matcast_settings.json";
      std::ifstream check(fullPath);
      if (check.is_open()) return fullPath;
    }
  }
  return L"matcast_settings.json";
}

static void LoadStreamSettings(std::string& name, int& width, int& height, int& fps) {
  name = "Matcast";
  width = 1920;
  height = 1080;
  fps = 60;
  std::ifstream f(GetSettingsFilePathW());
  if (f.is_open()) {
    std::string content((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
    size_t pos = content.find("\"receiverName\"");
    if (pos != std::string::npos) {
      size_t col = content.find(':', pos);
      if (col != std::string::npos) {
        size_t q1 = content.find('"', col);
        if (q1 != std::string::npos) {
          size_t q2 = content.find('"', q1 + 1);
          if (q2 != std::string::npos) {
            std::string n = content.substr(q1 + 1, q2 - q1 - 1);
            if (!n.empty()) name = n;
          }
        }
      }
    }
    pos = content.find("\"targetWidth\"");
    if (pos != std::string::npos) {
      size_t col = content.find(':', pos);
      if (col != std::string::npos) {
        int w = std::atoi(content.c_str() + col + 1);
        if (w > 0) width = w;
      }
    }
    pos = content.find("\"targetHeight\"");
    if (pos != std::string::npos) {
      size_t col = content.find(':', pos);
      if (col != std::string::npos) {
        int h = std::atoi(content.c_str() + col + 1);
        if (h > 0) height = h;
      }
    }
    pos = content.find("\"targetFps\"");
    if (pos != std::string::npos) {
      size_t col = content.find(':', pos);
      if (col != std::string::npos) {
        int f_val = std::atoi(content.c_str() + col + 1);
        if (f_val > 0) fps = f_val;
      }
    }
  }
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  LogWindow("[FlutterWindow] OnCreate enter");
  if (!Win32Window::OnCreate()) {
    LogWindow("[FlutterWindow] Win32Window::OnCreate failed");
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    LogWindow("[FlutterWindow] flutter_controller engine or view is null");
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Initialize Cast Engine Bridge
  CastEngineBridge::GetInstance().Initialize(GetHandle(), flutter_controller_->engine());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    std::string initial_name;
    int initial_w = 1920, initial_h = 1080, initial_fps = 60;
    LoadStreamSettings(initial_name, initial_w, initial_h, initial_fps);
    LogWindow("[FlutterWindow] NextFrameCallback: showing window and starting cast engine with name: " +
              initial_name + ", res: " + std::to_string(initial_w) + "x" + std::to_string(initial_h) +
              " @" + std::to_string(initial_fps) + "fps");
    this->Show();
    CastEngineBridge::GetInstance().Start(initial_name, initial_w, initial_h, initial_fps);
  });

  flutter_controller_->ForceRedraw();
  LogWindow("[FlutterWindow] OnCreate exit true");
  return true;
}

void FlutterWindow::OnDestroy() {
  LogWindow("[FlutterWindow] OnDestroy enter");
  CastEngineBridge::GetInstance().Shutdown();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
  LogWindow("[FlutterWindow] OnDestroy exit");
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  // Handle Cast Engine synchronous JSON IPC messages
  if (CastEngineBridge::GetInstance().ProcessWindowMessage(hwnd, message, wparam, lparam)) {
    return 0;
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_DESTROY:
      LogWindow("[FlutterWindow] MessageHandler received WM_DESTROY");
      break;
    case WM_CLOSE:
      LogWindow("[FlutterWindow] MessageHandler received WM_CLOSE");
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
