# Matcast

[![Works on My Machine](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/Gitveu/Matcast/main/badge/status.json)](https://github.com/Gitveu/Matcast/actions)
[![Build Status](https://github.com/Gitveu/Matcast/actions/workflows/build.yml/badge.svg)](https://github.com/Gitveu/Matcast/actions/workflows/build.yml)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows&logoColor=white)](https://github.com/Gitveu/Matcast)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Material 3](https://img.shields.io/badge/Material%20Design-3-6750A4?logo=materialdesign&logoColor=white)](https://m3.material.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<img width="1266" height="793" alt="image" src="https://github.com/user-attachments/assets/4c39b0e7-93b9-4103-a950-e4aa78ad23a6" />

> Looks like this is the first Google Cast / AirPlay app for Windows. So enjoy!

Portable Google Cast / AirPlay / Miracast / DLNA screen mirroring receiver for Windows.

---

## Key Features

- **Google Cast (Chromecast)** — Low-latency system-wide screen and audio mirroring directly from Android's quick settings shade (*Cast / Smart View*).
- **Apple AirPlay** — Screen mirroring and audio streaming from iPhone, iPad, and Mac.
- **Miracast & DLNA** — Standard wireless projection from Windows and Android devices.
- **Zero-config mDNS** — Automatic local network discovery without manual IP configuration.
- **Material Design 3** — Modern adaptive interface with custom Material You color schemes.
- **Portable** — Single-folder executable: zero installation, no administrative privileges required.

> **Note on In-App Casting (e.g. YouTube):** Matcast currently focuses on native system-wide screen mirroring (H.264 / WebRTC stream). In-app Cast web receivers (which require an embedded Chromium browser to render `youtube.com/tv`) are on the future roadmap. To watch YouTube on PC, simply mirror your screen from the Android shade.

---

## Project Structure

```text
Matcast/
├── lib/                               # Flutter / Dart source code
│   ├── main.dart                      # Application entry point, window setup & service init
│   ├── app.dart                       # MaterialApp configuration, localization & routing
│   ├── l10n/                          # Multi-language localization (EN / RU)
│   ├── models/                        # Data models (receiver state, stream stats, devices)
│   ├── state/                         # State management (Provider: settings, receiver)
│   ├── services/                      # Protocol & networking service layer:
│   │   ├── mdns_service.dart          # mDNS/DNS-SD advertiser (_googlecast._tcp, _airplay._tcp)
│   │   ├── cast_protocol_server.dart  # CASTV2 socket handling & message dispatch
│   │   ├── cast_certificates.dart     # TLS certificate management for Cast handshake
│   │   ├── rtsp_miracast_server.dart  # RTSP/RTP server for Miracast display sessions
│   │   ├── network_service.dart       # Network interface monitoring & local IP detection
│   │   ├── ssdp_service.dart          # SSDP announcer for DLNA / UPnP discovery
│   │   └── native_cast_bridge.dart    # FFI bridge to native C++ receiver libraries
│   └── ui/                            # User interface:
│       ├── theme/                     # Material Design 3 theme definitions
│       ├── views/                     # Core screens (Display, Settings, Devices, Guide)
│       └── widgets/                   # UI components (M3 Stat Card, Stream HUD, Badges)
│
├── windows/                           # Native Windows runner (C++ / Win32)
│   ├── runner/                        # Win32 window loop, resource compiler & manifest
│   │   └── resources/                 # Application icons (app_icon.ico, app_icon.png)
│   └── receiver_libs/                 # Precompiled native streaming receiver engines:
│       ├── cast_plugin.dll            # Core Google Cast protocol engine
│       ├── googlecast_receiver.dll    # Google Cast media stream receiver
│       ├── airplay_receiver.dll       # Apple AirPlay / RAOP audio/video receiver
│       ├── dlna_receiver.dll          # DLNA streaming engine
│       └── matcast_sys.dll            # Low-level system utilities
│
├── assets/                            # Static application assets
│   └── certs/                         # TLS certificates for Cast handshake (cert.pem, key.pem)
│
├── scripts/                           # Automation scripts
│   └── build_release.ps1              # Release builder & packager into Matcast-Windows-Portable.zip
│
└── dist/                              # Portable release bundles and ZIP archives
```

---

## Building & Running

### Prerequisites
- Flutter SDK (3.x+)
- Visual Studio 2022 (with *Desktop development with C++* workload)

### Development Run
```bash
flutter pub get
flutter run -d windows
```

### Production Release Build & Packaging
```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_release.ps1
```
The script compiles the release binary, verifies and synchronizes native DLLs, and packages a distribution archive into:
`dist/Matcast-Windows-Portable.zip`.

---

## Configuration

Settings are stored in `matcast_settings.json` next to the executable:
- `receiverName` — Network name broadcasted to Android Cast and Apple AirPlay devices.
- `castPort` — Google Cast listening port (default `8009`).
- `miracastPort` — Miracast RTSP listening port (default `7236`).
- `hardwareDecoding` — Enable GPU hardware acceleration for video decoding.
- `targetFps` / `targetWidth` / `targetHeight` — Stream resolution and framerate targets.

---

## Credits

- [keqdroid](https://github.com/Lemonochka/keqdroid) ([@Lemonochka](https://github.com/Lemonochka)) and [vysh](https://github.com/vyto4ka/vysh) ([@vyto4ka](https://github.com/vyto4ka)) for design idea

---

## License

The Matcast source code is licensed under the **[MIT License](LICENSE)**.

Third-party binary libraries and receiver engines (`windows/receiver_libs/`) remain under their respective licenses and terms of their owners.
