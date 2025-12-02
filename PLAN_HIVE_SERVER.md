# Hive Server - Plan

## Overview

Hive Server - self-hosted сервер для персистентных SSH-сессий с мультидевайс доступом.

```
[Hive Terminal]              [Hive Terminal]
     (phone)                    (laptop)
         \                        /
          \        gRPC          /
           \    (streaming)     /
            +--> [Hive Server] <--+
                     |
                     | SSH
                     v
              [Target Servers]
```

---

## Competitor Analysis

### Сравнительная таблица

| Критерий | Teleport | Boundary | Eternal Terminal | Mosh | tmux+SSH | Termius | **Hive Server** |
|:---------|:--------:|:--------:|:----------------:|:----:|:--------:|:-------:|:---------------:|
| Self-hosted | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Сложность деплоя | 🔴 | 🔴 | 🟡 | 🟢 | 🟢 | N/A | 🟢 |
| Персистентность | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Мультидевайс | ✅ | ✅ | ❌ | ❌ | ⚠️ | ✅ | ✅ |
| Scrollback | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| Mobile apps | ❌ | ❌ | ❌ | ⚠️ | ⚠️ | ✅ | ✅ |
| Web UI | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | 🔜 |
| Zoom интерфейс | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Adaptive voice (vocabulary) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| File upload → path paste | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Mobile screenshot → AI | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Бесплатно | ⚠️ | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Для команд | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ |

### Детали по конкурентам

| Решение | Плюсы | Минусы | Self-hosted |
|:--------|:------|:-------|:------------|
| **[Teleport](https://goteleport.com/)** | Enterprise-функционал, audit logs, SSO, K8s/DB/RDP | Сложный деплой, дорого ($70+/user), избыточен | Да, Community Edition ограничена |
| **[Boundary](https://www.boundaryproject.io/)** | Интеграция с Vault, identity-based access | Сложная настройка, требует HashiCorp экосистему | Да, Enterprise версия |
| **[Eternal Terminal](https://eternalterminal.dev/)** | Простой, автореконнект, scrollback | Нужен ET на обоих концах, orphaned sessions | Да, полностью |
| **[Mosh](https://mosh.org)** | Отличный reconnect, predictive echo, IP roaming | Нет scrollback, нет port forwarding, stale с 2022 | Да |
| **Termius** | Отличный UX, кросс-платформа, синхронизация | Облачный сервис, платная подписка | Нет |

### Ниша Hive Server

```
                    Сложность
                        ↑
        Teleport ●      │      ● Boundary
                        │
                        │
         ────────────────┼──────────────── Enterprise
                        │
                        │         ● Hive Server
                        │
      Mosh ●            │
   ET ●   tmux ●        │           ● Termius
         ────────────────┼──────────────── Personal
                        │
                        └─────────────────────────→
                    Free            Paid
```

---

## Unique Features

### 1. Zoom Interface
Динамический зум терминалов при наведении/фокусе. Удобно для работы с несколькими сессиями.

### 2. Adaptive Voice Recognition (Killer Feature)

Голосовой ввод с автоматически обучаемым словарём технических терминов.

**Проблема:** Whisper плохо распознаёт технические термины ("kubernetes" → "cube net is")

**Решение:** Vocabulary hint через `initial_prompt`

```python
# БЕЗ словаря
whisper.transcribe(audio)
# "перезагрузи dev сервер" → "перезагрузи deaf сервер" ❌

# СО словарём
whisper.transcribe(audio, initial_prompt="dev server, staging, kubernetes, docker")
# "перезагрузи dev сервер" → "перезагрузи dev сервер" ✅
```

**Automatic Vocabulary Building:**

| Источник | Как собираем |
|:---------|:-------------|
| Project files | `package.json`, `Cargo.toml` → extract names |
| Git history | Branch names, commit messages |
| Command history | Frequent commands |
| AI learning | Анализ input + AI action → infer terms |
| Manual | Юзер добавляет слова |

**Vocabulary Levels:**

```
┌─────────────────────────────────────────────┐
│  Industry (shared, opt-in)                  │
│  "kubernetes", "nginx", "postgres"          │
├─────────────────────────────────────────────┤
│  Team vocabulary                            │
│  "прод", "стейдж", "деплой"                │
├─────────────────────────────────────────────┤
│  Personal vocabulary                        │
│  User-specific pronunciations               │
├─────────────────────────────────────────────┤
│  Project vocabulary                         │
│  "hive-api", "auth-service"                 │
└─────────────────────────────────────────────┘
```

**AI-Assisted Learning:**

```
User says: "перезагрузи деф сервер"
Whisper: "перезагрузи deaf сервер"
Claude: *restarts dev server* ✓
         ↓
System analyzes: input="deaf" → action="dev"
         ↓
💡 "Add 'dev server' to vocabulary?" [Yes]
```

**Уникальность:** Никто не делает адаптивный voice recognition для терминалов.

### 3. File Upload → Path Paste (Killer Feature)

```
[Телефон]                    [Сервер]
   📱                           🖥️
   │                            │
   │ Скриншот ошибки            │ Claude Code запущен
   │         ↓                  │
   │   Hive Terminal            │
   │   "Вставить файл"          │
   │         ↓                  │
   │   SFTP → /tmp/img_123.png  │
   │         ↓                  │
   │   Путь вставляется:        │
   │   > /tmp/img_123.png█      │
   │         ↓                  │
   │   Claude видит изображение │
   │   и понимает контекст      │
```

**Реализация Upload:**
1. Клиент: пользователь выбирает файл / вставляет из clipboard
2. Клиент → Hive Server: WebSocket binary frame с файлом
3. Hive Server: сохраняет в `/tmp/hive_uploads/` с уникальным именем
4. Hive Server → SSH session: вставляет путь как input в PTY
5. Результат: `/tmp/hive_uploads/abc123.png` появляется в терминале

**Реализация Download (варианты):**
1. Команда: `hive-get /path/to/file` — Hive Server читает файл, отправляет клиенту
2. Escape-sequence: программа выводит `\e]1337;File=...` (как iTerm2)
3. Click-to-download: клик по пути в output → скачивается

**Сравнение с iTerm2:**

| Фича | iTerm2 | **Hive Terminal** |
|:-----|:------:|:-----------------:|
| Drag-n-drop upload | ✅ Option+Drop | ✅ Любой drop |
| Вставка пути в терминал | ❌ | ✅ |
| Требует Shell Integration | ✅ На обоих концах | ❌ |
| Mobile | ❌ macOS only | ✅ iOS/Android |
| Скриншоты с телефона | ❌ | ✅ |

---

## Decisions Made

| Вопрос | Решение |
|:-------|:--------|
| Цель | Персистентность + мультидевайс |
| Деплой | Self-hosted (каждый ставит свой) |
| Auth | API ключи (админ генерит в консоли) |
| SSH ключи | Хранятся на Hive Server |
| Протокол к серверам | Только SSH (MOSH позже) |
| Протокол клиент↔сервер | gRPC (type-safe, streaming) |
| Язык | Rust |
| Упаковка | Бинарник (+ Docker как обёртка) |
| Юзеры | 2-10 на сервер (команда/семья) |
| Репозиторий | Monorepo (server/ в hive-terminal) |
| БД | PostgreSQL |
| Scrollback | PostgreSQL chunks (64KB) |
| Шифрование at rest | Не приоритет для MVP |
| Web UI | После MVP |
| Режим клиента | Только Hive Server (без direct SSH) |

---

## Architecture

### Repository Structure

```
hive-terminal/
├── lib/                    # Flutter app
├── server/                 # Rust server
│   ├── src/
│   │   ├── main.rs
│   │   ├── api/           # REST endpoints
│   │   ├── ws/            # WebSocket handlers
│   │   ├── ssh/           # SSH session management
│   │   ├── auth/          # Authentication
│   │   ├── db/            # Database models
│   │   ├── terminal/      # PTY/scrollback
│   │   └── files/         # File upload/download
│   ├── Cargo.toml
│   ├── Dockerfile
│   └── config.example.toml
├── protocol/               # Shared API schemas
│   ├── messages.json       # WebSocket message types
│   └── api.yaml            # OpenAPI spec
└── VERSION                 # Shared version
```

### Tech Stack (Server)

| Компонент | Технология |
|:----------|:-----------|
| Runtime | Rust (tokio async) |
| RPC | tonic (gRPC) |
| SSH | russh (pure Rust SSH) |
| Database | sqlx + PostgreSQL |
| Auth | API keys (sha256 hashed) |
| Config | toml + clap |
| Voice (optional) | whisper-rs (local), cpal (audio) |

### Database Schema

```sql
-- Users
CREATE TABLE users (
    id UUID PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- SSH Keys (stored for target servers)
CREATE TABLE ssh_keys (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    name VARCHAR(255) NOT NULL,
    private_key_encrypted TEXT NOT NULL,
    public_key TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Connections (saved server configs)
CREATE TABLE connections (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    name VARCHAR(255) NOT NULL,
    host VARCHAR(255) NOT NULL,
    port INTEGER DEFAULT 22,
    username VARCHAR(255) NOT NULL,
    ssh_key_id UUID REFERENCES ssh_keys(id),
    startup_command TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Sessions (active SSH sessions)
CREATE TABLE sessions (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    connection_id UUID REFERENCES connections(id),
    status VARCHAR(50) DEFAULT 'active', -- active, suspended, closed
    created_at TIMESTAMP DEFAULT NOW(),
    last_activity TIMESTAMP DEFAULT NOW()
);

-- Scrollback history (64KB chunks)
CREATE TABLE scrollback_chunks (
    id BIGSERIAL PRIMARY KEY,
    session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    data BYTEA NOT NULL,  -- 64KB max
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(session_id, chunk_index)
);
CREATE INDEX idx_scrollback_session ON scrollback_chunks(session_id, chunk_index);

-- API Keys
CREATE TABLE api_keys (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    key_hash VARCHAR(64) NOT NULL,  -- SHA256
    last_used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_api_keys_hash ON api_keys(key_hash);

-- Uploaded files
CREATE TABLE uploads (
    id UUID PRIMARY KEY,
    session_id UUID REFERENCES sessions(id),
    filename VARCHAR(255) NOT NULL,
    path VARCHAR(512) NOT NULL,
    size_bytes BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### gRPC Protocol

```protobuf
// server/proto/hive.proto

syntax = "proto3";
package hive;

// Authentication
service Auth {
  rpc ValidateApiKey(ApiKeyRequest) returns (AuthResponse);
}

// SSH Key management
service Keys {
  rpc List(Empty) returns (KeyListResponse);
  rpc Create(CreateKeyRequest) returns (Key);
  rpc Delete(DeleteKeyRequest) returns (Empty);
}

// Connection configs
service Connections {
  rpc List(Empty) returns (ConnectionListResponse);
  rpc Create(CreateConnectionRequest) returns (Connection);
  rpc Update(UpdateConnectionRequest) returns (Connection);
  rpc Delete(DeleteConnectionRequest) returns (Empty);
}

// Terminal sessions
service Sessions {
  rpc List(Empty) returns (SessionListResponse);
  rpc Create(CreateSessionRequest) returns (Session);
  rpc Close(CloseSessionRequest) returns (Empty);
}

// Terminal I/O (bidirectional streaming)
service Terminal {
  rpc Attach(stream TerminalInput) returns (stream TerminalOutput);
}

message TerminalInput {
  string session_id = 1;
  oneof payload {
    bytes data = 2;           // keyboard input
    Resize resize = 3;        // terminal resize
    FileUpload file = 4;      // file upload
  }
}

message TerminalOutput {
  oneof payload {
    bytes data = 1;           // terminal output
    bytes scrollback = 2;     // initial scrollback on attach
    FileUploaded file = 3;    // uploaded file path
    SessionClosed closed = 4; // session terminated
  }
}
```

### CLI Commands (Admin)

```bash
# Generate API key for user
hive-server key create --user alice --name "laptop"
# Output: hive_abc123def456...

# List API keys
hive-server key list

# Revoke key
hive-server key revoke hive_abc123def456

# Create user
hive-server user create alice

# List users
hive-server user list
```

---

## Voice Integration (from voice-keyboard)

### Три уровня Whisper

| Уровень | Где работает | Latency | Качество | Когда использовать |
|:--------|:------------|:--------|:---------|:-------------------|
| **OpenAI API** | Облако (через Hive Server) | ~2s | Лучшее | Нет GPU, нужно качество |
| **Hive Server local** | На сервере | ~1s | Хорошее | Сервер с GPU |
| **Client-side** | На устройстве | ~0.5s | Хорошее | macOS M1+, оффлайн |

### Переиспользование из voice-keyboard

```rust
// Ключевые компоненты (MIT license, наш код)
// Путь: /home/alexmak/voice-keyboard/src/

transcribe.rs    // whisper-rs интеграция, TranscriptionResult
audio.rs         // cpal захват аудио, 16kHz mono f32
inject.rs        // clipboard + paste для вставки текста
config.rs        // конфигурация моделей и хоткеев
```

### Vocabulary Hints (не реализовано в voice-keyboard)

```rust
// whisper-rs поддерживает initial_prompt
let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
params.set_initial_prompt("kubernetes, docker, nginx, dev server, staging");
```

**Источники словаря:**
1. История команд пользователя
2. Названия серверов/connections
3. AI-анализ: input → action mapping
4. Ручное добавление

---

## Implementation Phases

**Принцип:** Каждая фаза = рабочий клиент + сервер + E2E тесты.
**Тестовая инфраструктура:** Docker SSH контейнер для E2E.

### Phase 1: Foundation + E2E Infrastructure
- [ ] `server/` directory structure
- [ ] Rust project (tonic, sqlx, tokio)
- [ ] `docker-compose.yml` (PostgreSQL + SSH test container)
- [ ] Database migrations (users, api_keys)
- [ ] CLI: `hive-server user create`, `hive-server key create`
- [ ] gRPC: Auth.ValidateApiKey
- [ ] **E2E test:** API key validation works

### Phase 2: SSH Connection
- [ ] gRPC: Connections CRUD
- [ ] SSH client (russh) connecting to test container
- [ ] PTY allocation + basic I/O
- [ ] **E2E test:** Connect to SSH, run `echo hello`, verify output

### Phase 3: Terminal Streaming
- [ ] gRPC: Terminal.Attach (bidirectional streaming)
- [ ] Session create/close
- [ ] Input → SSH → Output loop
- [ ] Terminal resize
- [ ] **E2E test:** Interactive session, resize, multiple commands

### Phase 4: Persistence
- [ ] Scrollback storage (64KB chunks)
- [ ] Session survives client disconnect
- [ ] Attach restores scrollback
- [ ] **E2E test:** Disconnect, reconnect, verify scrollback

### Phase 5: Flutter Client (gRPC)
- [ ] Dart gRPC generated code
- [ ] API key storage (secure storage)
- [ ] Session list UI
- [ ] Terminal I/O via gRPC stream
- [ ] **E2E test:** Flutter app connects, runs commands

### Phase 6: File Transfer
- [ ] File upload in TerminalInput
- [ ] Save to server, inject path
- [ ] **E2E test:** Upload file, verify path appears

### Phase 7: Voice Input
- [ ] Client-side Whisper (macOS)
- [ ] Server-side Whisper (optional)
- [ ] Vocabulary hints from history
- [ ] **E2E test:** Audio → text → terminal input

### Phase 8: Polish
- [ ] Docker packaging
- [ ] Config file (TOML)
- [ ] Logging (tracing)
- [ ] CI/CD

---

## Open Questions

1. **Scrollback size limit?** - Store last N lines or time-based cleanup?
2. **Session timeout?** - Auto-close inactive sessions after X hours?
3. **Multi-attach behavior?** - Read-only for second client or full control?
4. **Version compatibility?** - Strict match or semver ranges?
5. **File cleanup?** - Auto-delete uploaded files after X hours?

---

## Monetization Strategy

### Анализ подходов

| Подход | Примеры | Плюсы | Минусы |
|:-------|:--------|:------|:-------|
| **Open Core** | GitLab, Teleport | Широкое adoption, community | Сложно определить границу free/paid |
| **Features-based** | Termius | Понятная ценность | Killer-фичи за paywall = медленное adoption |
| **Limits-based** | Многие SaaS | Простой upsell | Не подходит для self-hosted |
| **Support/Enterprise** | Redis, PostgreSQL | Всё бесплатно, платят за поддержку | Нужна критическая масса пользователей |

### Рекомендация: Open Core + Enterprise

```
┌─────────────────────────────────────────────────────────────┐
│                    HIVE SERVER                              │
├─────────────────────────────────────────────────────────────┤
│  COMMUNITY (Free)           │  ENTERPRISE (Paid)            │
│                             │                               │
│  ✅ Persistent sessions     │  ✅ Всё из Community +        │
│  ✅ Multi-device            │  ✅ Multi-user (team)         │
│  ✅ Scrollback              │  ✅ User roles & permissions  │
│  ✅ File upload → path      │  ✅ Audit logs                │
│  ✅ Voice input             │  ✅ SSO (OIDC, SAML)          │
│  ✅ Zoom interface          │  ✅ Session recording         │
│  ✅ 1 user                  │  ✅ Priority support          │
│  ✅ Unlimited sessions      │  ✅ Custom branding           │
│                             │                               │
└─────────────────────────────────────────────────────────────┘
```

### Почему все killer-фичи бесплатно?

| Фича | Почему FREE | Риск если PAID |
|:-----|:------------|:---------------|
| **Voice input** | Accessibility — плохой PR за paywall | Конкуренты скопируют и дадут бесплатно |
| **File upload → path** | Главный дифференциатор для adoption | Медленный word-of-mouth |
| **Zoom interface** | UX-фича, сложно объяснить ценность | Пользователи не поймут за что платят |
| **Mobile screenshot → AI** | Часть file upload | — |

### На чём зарабатывать

| Tier | Цена | Аудитория | Фичи |
|:-----|:-----|:----------|:-----|
| **Community** | $0 | Индивидуальные разработчики | Всё для 1 пользователя |
| **Team** | $10/user/mo | Малые команды (2-10) | Multi-user, shared sessions |
| **Enterprise** | Custom | Компании | SSO, audit, compliance, support |

### Альтернатива: Donation/Sponsor model

Если не хочется Enterprise-фич:
- GitHub Sponsors
- Open Collective
- "Buy me a coffee"
- Paid support/consulting

### Приоритизация разработки с учётом монетизации

| Фаза | Фичи | Цель |
|:-----|:-----|:-----|
| **MVP** | Core SSH, persistence, 1 user | Рабочий продукт |
| **Adoption** | File upload, voice input, zoom | Killer-фичи → word-of-mouth |
| **Community** | Open source, docs, Docker | Расширение базы |
| **Monetization** | Multi-user, team features | Начало заработка |
| **Enterprise** | SSO, audit, recording | Крупные клиенты |

### Вывод

**Все уникальные фичи — бесплатно.** Это:
1. Ускоряет adoption (главная проблема нового продукта)
2. Создаёт word-of-mouth ("смотри, Claude видит мои скриншоты с телефона!")
3. Защищает от конкурентов (они скопируют, но мы будем первыми)

**Монетизация — на team/enterprise фичах:**
- Multi-user — реальная ценность для команд
- SSO — обязательно для enterprise
- Audit logs — compliance требования

---

## Next Steps

1. Create `server/` directory structure
2. Initialize Rust project with dependencies
3. Set up PostgreSQL docker-compose for dev
4. Implement Phase 1 (auth + basic API)

---

## Resources

- [Teleport](https://goteleport.com/) - Enterprise SSH access
- [Boundary](https://www.boundaryproject.io/) - HashiCorp identity-based access
- [Eternal Terminal](https://eternalterminal.dev/) - Persistent SSH
- [Mosh](https://mosh.org) - Mobile shell
- [russh](https://github.com/warp-tech/russh) - Rust SSH library
- [axum](https://github.com/tokio-rs/axum) - Rust web framework
