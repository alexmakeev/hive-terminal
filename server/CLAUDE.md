# Hive Server Development

## Completed Phases

### Phase 1: Foundation (Complete)
- User management (CRUD)
- API key authentication (generation, hashing, validation)
- Database migrations with sqlx

### Phase 2: SSH Connection (Complete)
- gRPC Connections CRUD service
- SSH client with russh library
- PTY allocation and basic I/O
- E2E tests for SSH functionality

### Phase 3: Terminal Streaming (Complete)
- Terminal.Attach bidirectional gRPC streaming
- SessionManager with active sessions
- Multi-client session attachment via broadcast channels
- E2E tests for terminal streaming

### Phase 4: Persistence (Complete)
- Scrollback storage in 64KB chunks
- Session recovery after disconnect
- E2E tests for persistence and recovery

## Architecture

### gRPC Services
- `AuthServer` - User authentication via API keys
- `ConnectionsServer` - SSH connection config CRUD
- `SessionsServer` - Session lifecycle management
- `TerminalServer` - Bidirectional terminal I/O streaming

### Key Components
- `SessionManager` - Manages active SSH sessions with broadcast channels
- `SshSession` - Wrapper around russh for SSH operations
- `ScrollbackChunk` - 64KB chunk storage for session history

## Docker Environment

Start development environment:
```bash
cd /home/alexmak/hive-terminal/server
docker compose up -d
```

Database connection:
```bash
export DATABASE_URL="postgres://hive:hive@localhost:5432/hive"
```

SSH test container:
- Host: localhost
- Port: 2222
- User: testuser
- Password: testpass

## Quick Commands

```bash
# Run tests (23 total)
DATABASE_URL="postgres://hive:hive@localhost:5432/hive" cargo test

# Build
cargo build

# Build release
cargo build --release

# Run server
DATABASE_URL="postgres://hive:hive@localhost:5432/hive" cargo run -- serve

# Stop containers
docker compose down
```

## Test Coverage

- auth_test.rs: 4 tests (user CRUD, API key operations)
- connection_test.rs: 3 tests (connection CRUD, sessions)
- ssh_test.rs: 4 tests (SSH connection, commands, resize, auth)
- terminal_test.rs: 12 tests (session manager, multi-client, scrollback, recovery)

Total: 23 integration tests
