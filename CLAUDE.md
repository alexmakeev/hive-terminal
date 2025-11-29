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
