# Hive Terminal

Mobile terminal app for managing multiple AI agents via MCP protocol.

## Project Vision

Lightweight mobile terminal client connecting to multiple remote AI agents simultaneously. Each agent runs on its own remote terminal server (shell). Primary interaction is voice-based (AI agents), with fallback keyboard for system emergencies.

## Core Features

- **Multi-agent connections** - 10+ simultaneous terminal sessions
- **MCP protocol** - connect to AI agents via Model Context Protocol
- **Voice-first UI** - primary interaction through voice commands
- **Terminal keyboard** - arrow keys, function keys for emergency/manual control
- **Swipe navigation** - quick switching between active terminals
- **Session overview** - see activity across all terminals at glance

## Target Platforms

- Android
- iOS
- (potentially other mobile platforms)

## UX Principles

- Lightweight, fast, responsive
- Easy multi-terminal management
- Swipe gestures for navigation
- Minimal UI, maximum terminal space
- Quick voice command activation

## Technical Requirements

- MCP client implementation
- SSH/shell connectivity to remote servers
- Real-time terminal emulation
- Voice recognition integration (OpenAI Whisper API, potentially on-device whisper.cpp)
- Push notifications for agent activity
- Offline queue for commands

## Background Behavior

- **Zero background consumption** - app does nothing in background
- On foreground: reconnect all MCP sessions, fetch state updates
- Future: optional 10-minute wake for state sync (if agent working in background)

## Stack

- **Framework:** Flutter 3.29+ (Dart)
- **Platforms:** Android, iOS, Windows, macOS, Linux
- **Voice:** OpenAI Whisper API (cloud) + whisper.cpp (on-device optional)
- **Protocol:** MCP over WebSocket
- **CI/CD:** GitHub Actions (free for open source)
- **State:** Riverpod
- **Storage:** Hive (local DB)

See `architecture.md` for full technical details.

## Versioning Policy

- **Patch (x.x.X)** - default for all changes (features, fixes, improvements)
- **Minor (x.X.0)** - only for breaking changes or incompatibilities
- **Major (X.0.0)** - only when explicitly requested by user

## Development Methodology: TDD

**Test-Driven Development обязателен:**
1. Сначала пишем тесты для новой функциональности
2. Запускаем тесты - они должны FAIL (red)
3. Имплементируем минимальный код для прохождения тестов (green)
4. Рефакторим при необходимости
5. После каждого этапа/фазы - все тесты должны проходить

**Тестирование:**
- Unit тесты для бизнес-логики
- Widget тесты для UI компонентов
- Integration тесты для E2E сценариев
- После каждой фазы - полный прогон всех тестов

## Hive Server Integration

Приложение поддерживает два режима:
1. **Server mode** - через Hive Server (gRPC) для persistence и multi-device
2. **Direct mode** - прямое SSH подключение (fallback)

**Server:** `server/` - Rust gRPC сервер
**Proto:** `server/proto/hive.proto` - API definition
**Generated:** `lib/src/generated/` - Dart gRPC клиент

### Запуск для разработки

```bash
# Сервер (в server/)
docker compose up -d
DATABASE_URL="postgres://hive:hive@localhost:5432/hive" cargo run -- serve

# Flutter (в корне)
flutter run
```

### E2E тесты

```bash
# Запуск сервера + тесты
./scripts/e2e_test.sh
```
