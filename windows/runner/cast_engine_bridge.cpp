#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>

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

typedef SOCKET (WSAAPI *AcceptFn)(SOCKET s, struct sockaddr* addr, int* addrlen);
static AcceptFn g_real_accept = nullptr;

static bool HookModuleIAT(HMODULE target_module, const char* target_dll_name, void* old_func, void* new_func) {
  if (!target_module || !old_func || !new_func) return false;

  auto* dos_header = reinterpret_cast<PIMAGE_DOS_HEADER>(target_module);
  if (dos_header->e_magic != IMAGE_DOS_SIGNATURE) return false;

  auto* nt_headers = reinterpret_cast<PIMAGE_NT_HEADERS>(
      reinterpret_cast<uint8_t*>(target_module) + dos_header->e_lfanew);
  if (nt_headers->Signature != IMAGE_NT_SIGNATURE) return false;

  IMAGE_DATA_DIRECTORY import_dir =
      nt_headers->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
  if (!import_dir.VirtualAddress || import_dir.Size == 0) return false;

  auto* import_desc = reinterpret_cast<PIMAGE_IMPORT_DESCRIPTOR>(
      reinterpret_cast<uint8_t*>(target_module) + import_dir.VirtualAddress);

  bool hooked = false;
  for (; import_desc->Name != 0; ++import_desc) {
    const char* dll_name = reinterpret_cast<const char*>(
        reinterpret_cast<uint8_t*>(target_module) + import_desc->Name);
    if (_stricmp(dll_name, target_dll_name) == 0) {
      auto* thunk = reinterpret_cast<PIMAGE_THUNK_DATA>(
          reinterpret_cast<uint8_t*>(target_module) + import_desc->FirstThunk);
      for (; thunk->u1.Function != 0; ++thunk) {
        if (reinterpret_cast<void*>(thunk->u1.Function) == old_func) {
          DWORD old_protect = 0;
          if (::VirtualProtect(&thunk->u1.Function, sizeof(void*), PAGE_EXECUTE_READWRITE, &old_protect)) {
            thunk->u1.Function = reinterpret_cast<uintptr_t>(new_func);
            ::VirtualProtect(&thunk->u1.Function, sizeof(void*), old_protect, &old_protect);
            hooked = true;
          }
        }
      }
    }
  }
  return hooked;
}

static bool IsLocalIpAddress(const std::string& ip) {
  if (ip.empty() || ip == "127.0.0.1" || ip == "::1" || ip == "0.0.0.0") return true;
  if (ip.rfind("169.254.", 0) == 0) return true;

  char hostname[256] = {0};
  if (::gethostname(hostname, sizeof(hostname)) == 0) {
    addrinfo hints{};
    hints.ai_family = AF_UNSPEC;
    addrinfo* res = nullptr;
    if (::getaddrinfo(hostname, nullptr, &hints, &res) == 0) {
      for (addrinfo* p = res; p != nullptr; p = p->ai_next) {
        char buf[INET6_ADDRSTRLEN] = {0};
        if (p->ai_family == AF_INET) {
          auto* sin = reinterpret_cast<sockaddr_in*>(p->ai_addr);
          ::inet_ntop(AF_INET, &(sin->sin_addr), buf, sizeof(buf));
        } else if (p->ai_family == AF_INET6) {
          auto* sin6 = reinterpret_cast<sockaddr_in6*>(p->ai_addr);
          ::inet_ntop(AF_INET6, &(sin6->sin6_addr), buf, sizeof(buf));
        }
        if (ip == buf) {
          ::freeaddrinfo(res);
          return true;
        }
      }
      ::freeaddrinfo(res);
    }
  }
  return false;
}

static SOCKET WSAAPI HookedAccept(SOCKET s, struct sockaddr* addr, int* addrlen) {
  if (!g_real_accept) {
    HMODULE ws2 = ::GetModuleHandleA("ws2_32.dll");
    if (ws2) {
      g_real_accept = reinterpret_cast<AcceptFn>(::GetProcAddress(ws2, "accept"));
    }
  }
  if (!g_real_accept) {
    return INVALID_SOCKET;
  }

  SOCKET client = g_real_accept(s, addr, addrlen);
  if (client == INVALID_SOCKET) {
    return INVALID_SOCKET;
  }

  // Check the port of the listening socket s
  sockaddr_storage local_ss{};
  int local_len = sizeof(local_ss);
  int listening_port = 0;
  if (::getsockname(s, reinterpret_cast<sockaddr*>(&local_ss), &local_len) == 0) {
    if (local_ss.ss_family == AF_INET) {
      auto* sin = reinterpret_cast<sockaddr_in*>(&local_ss);
      listening_port = ntohs(sin->sin_port);
    } else if (local_ss.ss_family == AF_INET6) {
      auto* sin6 = reinterpret_cast<sockaddr_in6*>(&local_ss);
      listening_port = ntohs(sin6->sin6_port);
    }
  }

  // ONLY protect Google Cast session ports (8009 / 8008).
  // All internal data, media, and streaming sockets must pass freely!
  if (listening_port != 8009 && listening_port != 8008) {
    return client;
  }

  // Identify client IP
  sockaddr_storage ss{};
  int ss_len = sizeof(ss);
  char ip_buf[INET6_ADDRSTRLEN] = {0};
  if (::getpeername(client, reinterpret_cast<sockaddr*>(&ss), &ss_len) == 0) {
    if (ss.ss_family == AF_INET) {
      auto* sin = reinterpret_cast<sockaddr_in*>(&ss);
      ::inet_ntop(AF_INET, &(sin->sin_addr), ip_buf, sizeof(ip_buf));
    } else if (ss.ss_family == AF_INET6) {
      auto* sin6 = reinterpret_cast<sockaddr_in6*>(&ss);
      ::inet_ntop(AF_INET6, &(sin6->sin6_addr), ip_buf, sizeof(ip_buf));
    }
  } else if (addr && addrlen && *addrlen >= sizeof(sockaddr_in)) {
    if (addr->sa_family == AF_INET) {
      auto* sin = reinterpret_cast<sockaddr_in*>(addr);
      ::inet_ntop(AF_INET, &(sin->sin_addr), ip_buf, sizeof(ip_buf));
    } else if (addr->sa_family == AF_INET6) {
      auto* sin6 = reinterpret_cast<sockaddr_in6*>(addr);
      ::inet_ntop(AF_INET6, &(sin6->sin6_addr), ip_buf, sizeof(ip_buf));
    }
  }

  std::string client_ip(ip_buf);

  // Local loopback or local host interface connections must never be rejected
  if (IsLocalIpAddress(client_ip)) {
    return client;
  }

  if (CastEngineBridge::GetInstance().IsBusyReject(client_ip)) {
    LogBridge("[HookedAccept] REJECTED incoming connection on port " + std::to_string(listening_port) +
              " from " + client_ip + " because active stream is locked to " +
              CastEngineBridge::GetInstance().GetActiveClientIp());
    ::closesocket(client);
    ::WSASetLastError(WSAECONNREFUSED);
    return INVALID_SOCKET;
  }

  LogBridge("[HookedAccept] Accepted connection on port " + std::to_string(listening_port) + " from " + client_ip);
  return client;
}

static void EnsureAcceptHookInstalled(HMODULE mod, const char* mod_name) {
  if (!mod) return;
  if (!g_real_accept) {
    HMODULE ws2 = ::GetModuleHandleA("ws2_32.dll");
    if (!ws2) {
      ws2 = ::LoadLibraryA("ws2_32.dll");
    }
    if (ws2) {
      g_real_accept = reinterpret_cast<AcceptFn>(::GetProcAddress(ws2, "accept"));
    }
  }
  if (g_real_accept) {
    bool ok = HookModuleIAT(mod, "ws2_32.dll", reinterpret_cast<void*>(g_real_accept), reinterpret_cast<void*>(&HookedAccept));
    LogBridge(std::string("[CastEngineBridge] Installed accept hook on ") + mod_name + ": " + (ok ? "SUCCESS" : "FAILED"));
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

void CastEngineBridge::SetActiveStreamingIp(const std::string& ip) {
  std::lock_guard<std::mutex> lock(ip_mutex_);
  active_stream_ip_ = ip;
  LogBridge("[CastEngineBridge] SetActiveStreamingIp locked to: " + ip);
}

void CastEngineBridge::ClearActiveStreamingIp() {
  std::lock_guard<std::mutex> lock(ip_mutex_);
  LogBridge("[CastEngineBridge] ClearActiveStreamingIp released (was: " + active_stream_ip_ + ")");
  active_stream_ip_.clear();
}

bool CastEngineBridge::IsBusyReject(const std::string& incoming_ip) {
  std::lock_guard<std::mutex> lock(ip_mutex_);
  if (active_stream_ip_.empty()) {
    return false;
  }
  if (IsLocalIpAddress(incoming_ip)) {
    return false;
  }
  if (incoming_ip == active_stream_ip_) {
    return false;
  }
  return true;
}

std::string CastEngineBridge::GetActiveClientIp() {
  std::lock_guard<std::mutex> lock(ip_mutex_);
  return active_stream_ip_;
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
  // Install accept hook on googlecast_receiver.dll before initializing listening socket
  EnsureAcceptHookInstalled(google_module_, "googlecast_receiver.dll");

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
  sync_msg_id_ = ::RegisterWindowMessageW(L"Matcast_HostJsonSyncCall_v1");
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
          } else if (call.method_name() == "setActiveStreamingIp") {
            const auto* str_arg = std::get_if<std::string>(call.arguments());
            if (str_arg) {
              this->SetActiveStreamingIp(*str_arg);
            }
            result->Success(flutter::EncodableValue(true));
          } else if (call.method_name() == "clearActiveStreamingIp") {
            this->ClearActiveStreamingIp();
            result->Success(flutter::EncodableValue(true));
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
