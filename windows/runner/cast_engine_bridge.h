#ifndef RUNNER_CAST_ENGINE_BRIDGE_H_
#define RUNNER_CAST_ENGINE_BRIDGE_H_

#include <windows.h>
#include <flutter_plugin_registrar.h>
#include <flutter/flutter_engine.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/plugin_registrar_windows.h>

#include <string>
#include <memory>

class CastEngineBridge {
 public:
  static CastEngineBridge& GetInstance();

  bool Initialize(HWND top_hwnd, flutter::FlutterEngine* engine);
  bool ProcessWindowMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
  bool Start(const std::string& device_name, int width = 1920, int height = 1080, int fps = 60);
  void Stop();
  std::string InvokeJson(const std::string& json_request);
  std::string GetMirrorStatusJson();
  void Shutdown();

  static void OnPromoteGui();
  void CallGoogleReceiverInitDirectly();

 private:
  CastEngineBridge();
  ~CastEngineBridge();

  HMODULE cast_module_ = nullptr;
  HMODULE google_module_ = nullptr;
  HWND hwnd_ = nullptr;
  UINT sync_msg_id_ = 0;

  void (*set_hwnd_fn_)(HWND) = nullptr;
  void (*deliver_sync_msg_fn_)(void*) = nullptr;
  int (*invoke_json_sync_fn_)(const char*, char*, int, int, void*) = nullptr;
  void (*mirror_status_fn_)(char*, size_t) = nullptr;
  void (*set_promote_callback_fn_)(void (*)()) = nullptr;
  void (*register_plugin_fn_)(FlutterDesktopPluginRegistrarRef) = nullptr;
  void* (*google_receiver_init_fn_)(void*) = nullptr;

  bool is_running_ = false;
  std::string current_device_name_ = "";
  int current_width_ = 1920;
  int current_height_ = 1080;
  int current_fps_ = 60;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;
};

#endif  // RUNNER_CAST_ENGINE_BRIDGE_H_
