# План интеграции Flutter клиента с Hive Server

## Обзор

Интеграция существующего Flutter SSH терминала с Rust gRPC сервером для:
- Централизованного управления сессиями
- Scrollback persistence (история сохраняется на сервере + кэш клиента)
- Session recovery (auto-reconnect без потери данных)
- Multi-device sync (одна сессия с разных устройств)

## Архитектура (ЗАФИКСИРОВАНО)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          FLUTTER CLIENT                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────────┐   │
│  │  xterm.dart  │◄──►│ HiveTerminal │◄──►│    gRPC Client           │   │
│  │  (VT100 emu) │    │   Session    │    │ (bidirectional stream)   │   │
│  └──────────────┘    └──────────────┘    └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                              gRPC/TLS
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          HIVE SERVER (Rust)                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────────┐   │
│  │ Terminal.    │◄──►│  Session     │◄──►│    SSH Client            │   │
│  │ Attach       │    │  Manager     │    │    (russh)               │   │
│  │ (streaming)  │    │ + Scrollback │    │                          │   │
│  └──────────────┘    └──────────────┘    └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                  SSH
                                   │
                                   ▼
                         ┌──────────────────┐
                         │   SSH Server     │
                         │   (target host)  │
                         └──────────────────┘
```

## Ключевые решения

### Терминал
- **Эмулятор:** `xterm.dart` (оставляем) — полноценный VT100/xterm, все платформы
- **SSH клиент:** Удаляем `dartssh2` — SSH теперь делает сервер
- **Данные:** Сырые ANSI коды от сервера → xterm.dart парсит и рендерит

### Протокол
- **gRPC** bidirectional streaming (HTTP/2 + Protobuf)
- **TLS** обязательно
- **CDN (Cloudflare)** — позже, не для MVP

### Scrollback
- Сервер хранит 64KB чанками (уже реализовано)
- Клиент кэширует локально в xterm.dart
- При reconnect: сервер отправляет scrollback

### Reconnect
- **Auto-reconnect** при потере соединения
- Exponential backoff
- Индикатор состояния в UI

## Фазы

### Phase 1: gRPC Setup в Flutter ✅ DONE
- [x] Добавить grpc/protobuf зависимости в pubspec.yaml
- [x] Сгенерировать Dart код из hive.proto
- [x] Создать HiveClient сервис для gRPC коммуникации
- [x] Unit тесты для gRPC клиента (15 тестов)

### Phase 2: Authentication Flow ✅ DONE
- [x] HiveServerService для управления подключением
- [x] Secure storage для credentials (flutter_secure_storage)
- [x] UI для ввода server URL + port + API key
- [x] Settings screen интеграция
- [x] Тесты auth flow (11 тестов)

### Phase 3: Connections Management 🔄 IN PROGRESS
- [ ] Удалить SSH/Mosh код (dartssh2, SshSession, MoshSession)
- [ ] HiveConnectionsService для CRUD через gRPC
- [ ] Миграция локальных connections на server
- [ ] UI адаптация для server-backed connections
- [ ] Тесты CRUD операций

### Phase 4: Terminal Streaming Integration
- [ ] HiveTerminalSession — wrapper для gRPC streaming
- [ ] Terminal.Attach bidirectional streaming
- [ ] Интеграция с xterm.dart (write output, read input)
- [ ] Resize events через gRPC
- [ ] Auto-reconnect с восстановлением scrollback
- [ ] Тесты streaming

### Phase 5: Session Management
- [ ] Sessions.List/Create/Close через gRPC
- [ ] UI для списка активных сессий
- [ ] Session recovery при reconnect
- [ ] Multi-device attach (одна сессия — много клиентов)
- [ ] Тесты session lifecycle

### Phase 6: E2E Integration Tests
- [ ] Test harness: запуск server + Flutter tests
- [ ] E2E: Auth → Create Connection → Create Session → Send Commands → Verify Output
- [ ] E2E: Disconnect → Reconnect → Verify Scrollback Recovery
- [ ] E2E: Multiple commands sequence
- [ ] E2E: Resize terminal during session

### Phase 7: Production Hardening
- [ ] Cloudflare CDN для защиты от блокировок
- [ ] TLS сертификаты (Let's Encrypt)
- [ ] Rate limiting
- [ ] Monitoring/logging

## Удаляемый код

### Файлы для удаления
- `lib/features/terminal/terminal_view.dart` (SSH terminal)
- `lib/features/terminal/mosh_terminal_view.dart` (Mosh terminal)
- `lib/features/connection/ssh_session.dart` (SshSession class)
- `lib/features/connection/mosh_session_wrapper.dart` (Mosh wrapper)

### Зависимости для удаления (pubspec.yaml)
- `dartssh2: ^2.9.0`
- `mosh_client` (если есть)

### Код для сохранения
- `xterm: ^4.0.0` — терминальный эмулятор
- `lib/features/connection/connection_repository.dart` — локальное хранилище
- `lib/shared/widgets/terminal_keyboard.dart` — мобильная клавиатура

## Детали реализации

### gRPC Dependencies (pubspec.yaml)
```yaml
dependencies:
  grpc: ^4.0.0
  protobuf: ^3.1.0
  xterm: ^4.0.0  # терминальный эмулятор
  flutter_secure_storage: ^9.0.0

dev_dependencies:
  protoc_plugin: ^21.1.2
```

### HiveTerminalSession (новый)
```dart
class HiveTerminalSession {
  final HiveServerService server;
  final String sessionId;
  final Terminal terminal;

  StreamSubscription? _outputSubscription;
  StreamController<TerminalInput>? _inputController;

  Future<void> attach();
  void write(String data);
  void resize(int cols, int rows);
  Future<void> detach();
  Future<void> reconnect();
}
```

## Критерии успеха

1. ✅ Все тесты Flutter проходят (сейчас 84)
2. ✅ Все тесты Rust сервера проходят (23)
3. [ ] SSH/Mosh код полностью удалён
4. [ ] Терминал работает через gRPC stream
5. [ ] Auto-reconnect восстанавливает сессию
6. [ ] Scrollback сохраняется между reconnects
