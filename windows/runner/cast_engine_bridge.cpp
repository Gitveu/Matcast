#include "cast_engine_bridge.h"

#include <iostream>
#include <vector>
#include <fstream>

static void LogBridge(const std::string& msg) {
  std::ofstream ofs("matcast_engine.log", std::ios::app);
  if (ofs.is_open()) {
    ofs << msg << std::endl;
  }
}

CastEngineBridge& CastEngineBridge::GetInstance() {
  static CastEngineBridge instance;
  return instance;
}

CastEngineBridge::CastEngineBridge() {}

CastEngineBridge::~CastEngineBridge() {
  Shutdown();
}

void CastEngineBridge::CallGoogleReceiverInitDirectly() {
  LogBridge("[CastEngineBridge] Calling google_receiver_init directly...");
  if (!google_module_) {
    google_module_ = ::LoadLibraryW(L"googlecast_receiver.dll");
  }
  if (!google_module_) {
    LogBridge("[CastEngineBridge] Failed to load googlecast_receiver.dll! Error: " + std::to_string(::GetLastError()));
    return;
  }
  if (google_module_ && !google_receiver_init_fn_) {
    google_receiver_init_fn_ = reinterpret_cast<void* (*)(void*)>(
        ::GetProcAddress(google_module_, "google_receiver_init"));
  }
  if (google_receiver_init_fn_) {
    static uint8_t receiver_ctx_buffer[1024] = {0};
    void* res = google_receiver_init_fn_(receiver_ctx_buffer);
    LogBridge("[CastEngineBridge] google_receiver_init returned: " + std::to_string(reinterpret_cast<uintptr_t>(res)));
  } else {
    LogBridge("[CastEngineBridge] GetProcAddress google_receiver_init failed!");
  }
}

bool CastEngineBridge::Initialize(HWND top_hwnd, flutter::FlutterEngine* engine) {
  LogBridge("[CastEngineBridge] Initialize entered. HWND=" + std::to_string(reinterpret_cast<uintptr_t>(top_hwnd)));
  hwnd_ = top_hwnd;
  sync_msg_id_ = ::RegisterWindowMessageW(L"PigeonCast_HostJsonSyncCall_v1");
  LogBridge("[CastEngineBridge] Registered HostJsonSyncCall_v1 msg_id=" + std::to_string(sync_msg_id_));

  // Call google_receiver_init directly as requested
  CallGoogleReceiverInitDirectly();

  // Load cast_plugin.dll
  if (!cast_module_) {
    cast_module_ = ::LoadLibraryW(L"cast_plugin.dll");
  }
  if (!cast_module_) {
    LogBridge("[CastEngineBridge] Failed to load cast_plugin.dll! Error: " + std::to_string(::GetLastError()));
    return false;
  }
  LogBridge("[CastEngineBridge] Loaded cast_plugin.dll successfully.");

  set_hwnd_fn_ = reinterpret_cast<void (*)(HWND)>(
      ::GetProcAddress(cast_module_, "CastHostSetJsonSyncTargetHwnd"));
  deliver_sync_msg_fn_ = reinterpret_cast<void (*)(void*)>(
      ::GetProcAddress(cast_module_, "CastHostDeliverJsonSyncMessage"));
  invoke_json_sync_fn_ = reinterpret_cast<int (*)(const char*, char*, int, int, void*)>(
      ::GetProcAddress(cast_module_, "CastHostInvokeJsonCallSync"));
  mirror_status_fn_ = reinterpret_cast<void (*)(char*, size_t)>(
      ::GetProcAddress(cast_module_, "CastHostSenderMirrorStatusJson"));
  set_promote_callback_fn_ = reinterpret_cast<void (*)(void (*)())>(
      ::GetProcAddress(cast_module_, "CastHostSetPromoteGuiCallback"));
  register_plugin_fn_ = reinterpret_cast<void (*)(FlutterDesktopPluginRegistrarRef)>(
      ::GetProcAddress(cast_module_, "CastPluginCApiRegisterWithRegistrar"));

  if (set_promote_callback_fn_) {
    LogBridge("[CastEngineBridge] Setting PromoteGuiCallback...");
    set_promote_callback_fn_(&CastEngineBridge::OnPromoteGui);
    LogBridge("[CastEngineBridge] PromoteGuiCallback configured.");
  }

  if (set_hwnd_fn_ && hwnd_) {
    LogBridge("[CastEngineBridge] Calling CastHostSetJsonSyncTargetHwnd...");
    set_hwnd_fn_(hwnd_);
    LogBridge("[CastEngineBridge] CastHostSetJsonSyncTargetHwnd called.");
  }

  if (register_plugin_fn_ && engine) {
    LogBridge("[CastEngineBridge] Registering cast_plugin with FlutterEngine...");
    FlutterDesktopPluginRegistrarRef registrar = engine->GetRegistrarForPlugin("cast_plugin");
    if (registrar) {
      register_plugin_fn_(registrar);
      LogBridge("[CastEngineBridge] CastPluginCApiRegisterWithRegistrar succeeded.");
    } else {
      LogBridge("[CastEngineBridge] GetRegistrarForPlugin returned nullptr!");
    }
  }

  // Set up Flutter MethodChannel for Dart interaction
  if (engine) {
    method_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        engine->messenger(), "matcast/native_engine",
        &flutter::StandardMethodCodec::GetInstance());

    method_channel_->SetMethodCallHandler(
        [this](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
          if (call.method_name() == "startEngine") {
            std::string name = "Matcast";
            int width = 1920;
            int height = 1080;
            int fps = 60;
            const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            if (args) {
              auto it = args->find(flutter::EncodableValue("name"));
              if (it != args->end() && std::holds_alternative<std::string>(it->second)) {
                name = std::get<std::string>(it->second);
              }
              auto it_w = args->find(flutter::EncodableValue("width"));
              if (it_w != args->end()) {
                auto v = it_w->second.TryGetLongValue();
                if (v.has_value()) width = static_cast<int>(v.value());
              }
              auto it_h = args->find(flutter::EncodableValue("height"));
              if (it_h != args->end()) {
                auto v = it_h->second.TryGetLongValue();
                if (v.has_value()) height = static_cast<int>(v.value());
              }
              auto it_fps = args->find(flutter::EncodableValue("fps"));
              if (it_fps != args->end()) {
                auto v = it_fps->second.TryGetLongValue();
                if (v.has_value()) fps = static_cast<int>(v.value());
              }
            }
            bool ok = this->Start(name, width, height, fps);
            result->Success(flutter::EncodableValue(ok));
          } else if (call.method_name() == "stopEngine") {
            this->Stop();
            result->Success(flutter::EncodableValue(true));
          } else if (call.method_name() == "invokeJson") {
            std::string json;
            const auto* str_arg = std::get_if<std::string>(call.arguments());
            if (str_arg) {
              json = *str_arg;
            }
            std::string resp = this->InvokeJson(json);
            result->Success(flutter::EncodableValue(resp));
          } else if (call.method_name() == "getMirrorStatus") {
            std::string status = this->GetMirrorStatusJson();
            result->Success(flutter::EncodableValue(status));
          } else {
            result->NotImplemented();
          }
        });
    LogBridge("[CastEngineBridge] MethodChannel matcast/native_engine ready.");
  }

  // Init engine stack
  char outBuf[1024] = {0};
  if (invoke_json_sync_fn_) {
    LogBridge("[CastEngineBridge] Calling Init json call...");
    int r = invoke_json_sync_fn_("{\"id\":1,\"type\":\"Init\",\"data\":{\"dwDebugMode\":0}}",
                         outBuf, sizeof(outBuf), 0, nullptr);
    LogBridge("[CastEngineBridge] Init call returned: " + std::to_string(r) + " resp: " + outBuf);
  }

  return true;
}

bool CastEngineBridge::ProcessWindowMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  if (sync_msg_id_ && message == sync_msg_id_) {
    if (deliver_sync_msg_fn_) {
      deliver_sync_msg_fn_(reinterpret_cast<void*>(lparam));
      return true;
    }
  }
  return false;
}

bool CastEngineBridge::Start(const std::string& device_name, int width, int height, int fps) {
  if (is_running_ && current_device_name_ == device_name && current_width_ == width &&
      current_height_ == height && current_fps_ == fps) {
    LogBridge("[CastEngineBridge] Already running with same parameters: " + device_name + " " +
              std::to_string(width) + "x" + std::to_string(height) + " @" + std::to_string(fps));
    return true;
  }
  if (is_running_) {
    LogBridge("[CastEngineBridge] Stopping previous session before restarting with new params...");
    Stop();
  }
  if (!invoke_json_sync_fn_) return false;
  char outBuf[1024] = {0};
  std::string startJson =
      "{\"id\":2,\"type\":\"Start\",\"data\":{\"setting\":{\"name\":\"" +
      device_name +
      "\",\"resolution\":[" + std::to_string(width) + "," + std::to_string(height) + "],\"fps\":" +
      std::to_string(fps) + ",\"decode\":0,\"security\":0,\"encode\":0,\"sound\":1,\"mouse\":1}}}";
  LogBridge("[CastEngineBridge] Calling Start json call: " + startJson);
  int ret = invoke_json_sync_fn_(startJson.c_str(), outBuf, sizeof(outBuf), 0, nullptr);
  LogBridge("[CastEngineBridge] Start call returned: " + std::to_string(ret) + " resp: " + outBuf);
  if (ret == 0) {
    is_running_ = true;
    current_device_name_ = device_name;
    current_width_ = width;
    current_height_ = height;
    current_fps_ = fps;
    return true;
  }
  return false;
}

void CastEngineBridge::Stop() {
  if (!invoke_json_sync_fn_) return;
  char outBuf[512] = {0};
  LogBridge("[CastEngineBridge] Calling Stop json call...");
  invoke_json_sync_fn_("{\"id\":3,\"type\":\"Stop\",\"data\":{}}", outBuf, sizeof(outBuf), 0, nullptr);
  is_running_ = false;
}

std::string CastEngineBridge::InvokeJson(const std::string& json_request) {
  if (!invoke_json_sync_fn_) return "{\"error\":\"not_initialized\"}";
  std::vector<char> outBuf(4096, 0);
  int ret = invoke_json_sync_fn_(json_request.c_str(), outBuf.data(), static_cast<int>(outBuf.size()), 0, nullptr);
  if (ret == 0) {
    return std::string(outBuf.data());
  }
  return "{\"error\":\"invoke_failed\",\"code\":" + std::to_string(ret) + "}";
}

std::string CastEngineBridge::GetMirrorStatusJson() {
  if (!mirror_status_fn_) return "{}";
  char buf[4096] = {0};
  mirror_status_fn_(buf, sizeof(buf));
  return std::string(buf);
}

void CastEngineBridge::OnPromoteGui() {
  LogBridge("[CastEngineBridge] OnPromoteGui callback triggered by Cast plugin!");
  auto& inst = GetInstance();
  if (inst.method_channel_) {
    std::string status = inst.GetMirrorStatusJson();
    LogBridge("[CastEngineBridge] Forwarding onNativeStreamStarted to Dart. Status: " + status);
    inst.method_channel_->InvokeMethod("onNativeStreamStarted",
        std::make_unique<flutter::EncodableValue>(status));
  }
}

void CastEngineBridge::Shutdown() {
  Stop();
  if (cast_module_) {
    ::FreeLibrary(cast_module_);
    cast_module_ = nullptr;
  }
  if (google_module_) {
    ::FreeLibrary(google_module_);
    google_module_ = nullptr;
  }
}
