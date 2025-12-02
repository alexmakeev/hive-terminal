# Hive Server

Self-hosted SSH session server for Hive Terminal.

## Quick Start

```bash
# Start PostgreSQL and SSH test container
docker-compose up -d

# Set database URL
export DATABASE_URL="postgres://hive:hive@localhost:5432/hive"

# Run migrations
cargo run -- migrate

# Create a user and API key
cargo run -- user create alice
cargo run -- key create --user alice --name laptop

# Start the server
cargo run -- serve
```

## CLI Commands

```bash
# User management
hive-server user create <username>
hive-server user list

# API key management
hive-server key create --user <username> --name <key-name>
hive-server key list --user <username>
hive-server key revoke <api-key>

# Server
hive-server migrate
hive-server serve --listen [::1]:50051
```

## Environment Variables

- `DATABASE_URL` - PostgreSQL connection string
- `RUST_LOG` - Log level (default: `hive_server=info`)

## Development

```bash
# Check code
cargo check

# Run tests
cargo test

# Build release
cargo build --release
```
