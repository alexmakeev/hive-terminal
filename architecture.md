# Hive Terminal — Architecture

## Technology Stack

### Core Framework
- **Flutter 3.29+** (Dart)
- Single codebase for all platforms
- Skia rendering engine (native, not WebView)

### Target Platforms
| Platform | Status | Build |
|----------|--------|-------|
| Android | Primary | Local + CI |
| iOS | Primary | CI (GitHub Actions) |
| macOS | Secondary | CI (GitHub Actions) |
| Windows | Secondary | Local + CI |
| Linux | Secondary | Local + CI |

### Language
- **Dart** with sound null safety
- Strict analysis options enabled

---

## Key Components

### 1. Terminal Emulation
- Custom terminal renderer optimized for Flutter
- ANSI escape sequence parsing
- 1000+ lines/sec rendering target
- 10+ concurrent terminal sessions
- Memory budget: <300MB for 10 sessions

### 2. MCP Client
- Model Context Protocol implementation
- WebSocket transport (primary)
- HTTP/SSE transport (fallback)
- Session state management
- Reconnection logic on foreground resume

### 3. Voice Input
| Mode | Technology | Use Case |
|------|------------|----------|
| Cloud | OpenAI Whisper API | Primary, low latency |
| On-device | whisper.cpp via flutter_whisper | Offline, privacy |

Platform channels for native microphone access.

### 4. UI/Navigation
- Swipe gestures for terminal switching
- Terminal grid overview (see all sessions)
- Minimal chrome, maximum terminal space
- Custom terminal keyboard (arrows, Ctrl, function keys)

---

## Background Behavior

```
FOREGROUND:
  - All MCP sessions active
  - Real-time terminal updates
  - Voice input available

BACKGROUND:
  - Zero resource consumption
  - All connections closed
  - No background services

RESUME:
  - Reconnect all MCP sessions
  - Fetch missed state updates
  - Restore terminal buffers

FUTURE (optional):
  - 10-minute periodic wake for state sync
```

---

## CI/CD Pipeline

### GitHub Actions (free for open source)

```
Triggers: push to main, PR

Jobs:
├── test
│   ├── flutter analyze
│   ├── flutter test
│   └── integration tests
│
├── build-android
│   ├── runs-on: ubuntu-latest
│   └── artifact: .apk, .aab
│
├── build-ios
│   ├── runs-on: macos-latest
│   └── artifact: .ipa (unsigned for dev)
│
├── build-macos
│   ├── runs-on: macos-latest
│   └── artifact: .app, .dmg
│
├── build-windows
│   ├── runs-on: windows-latest
│   └── artifact: .msix, .exe
│
└── build-linux
    ├── runs-on: ubuntu-latest
    └── artifact: .deb, .AppImage
```

### Code Signing (production)
- iOS: Apple Developer certificates via GitHub Secrets
- Android: Keystore via GitHub Secrets
- macOS: Developer ID for notarization
- Windows: Code signing certificate (optional)

---

## Project Structure

```
hive-terminal/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── mcp/              # MCP client implementation
│   │   ├── terminal/         # Terminal emulator
│   │   └── voice/            # Voice input abstraction
│   ├── features/
│   │   ├── session/          # Session management
│   │   ├── terminal_view/    # Terminal UI
│   │   └── settings/         # App settings
│   └── shared/
│       ├── widgets/          # Reusable widgets
│       └── utils/            # Helpers
├── android/
├── ios/
├── macos/
├── windows/
├── linux/
├── test/
├── integration_test/
├── .github/
│   └── workflows/
│       ├── ci.yml            # Test on every PR
│       └── release.yml       # Build all platforms
├── CLAUDE.md
├── architecture.md
└── pubspec.yaml
```

---

## Dependencies (planned)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State management
  riverpod: ^2.x

  # Networking
  web_socket_channel: ^2.x
  dio: ^5.x

  # Terminal
  xterm: ^4.x                 # or custom implementation

  # Voice (cloud)
  # OpenAI API via dio

  # Voice (on-device, optional)
  flutter_whisper: ^x.x

  # Storage
  hive: ^2.x                  # Local DB for session configs

  # Platform
  permission_handler: ^11.x

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.x
  integration_test:
    sdk: flutter
```

---

## Performance Targets

| Metric | Target |
|--------|--------|
| App startup | <2s cold start |
| Terminal FPS | 60fps scrolling |
| Terminal throughput | 1000+ lines/sec |
| Memory (10 sessions) | <300MB |
| APK size | <30MB |
| Battery (active) | Minimal GPU usage |
| Battery (background) | Zero |

---

## Security Considerations

- MCP credentials stored in secure storage (flutter_secure_storage)
- No credentials in logs
- Certificate pinning for production APIs
- On-device Whisper for sensitive voice data (optional)

---

## Future Considerations

- Push notifications for agent activity (requires backend)
- Session sharing/collaboration
- Plugin system for custom terminal commands
- Themes and customization
