import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

/// Popular AI CLI commands with descriptions
class AiCliCommand {
  final String command;
  final String name;
  final String description;

  const AiCliCommand({
    required this.command,
    required this.name,
    required this.description,
  });

  static const List<AiCliCommand> suggestions = [
    AiCliCommand(
      command: 'claude',
      name: 'Claude Code',
      description: 'Anthropic Claude AI coding assistant',
    ),
    AiCliCommand(
      command: 'claude --dangerously-skip-permissions',
      name: 'Claude Code (auto)',
      description: 'Claude Code with auto-approve permissions',
    ),
    AiCliCommand(
      command: 'aider',
      name: 'Aider',
      description: 'AI pair programming in terminal',
    ),
    AiCliCommand(
      command: 'aider --model claude-3-5-sonnet',
      name: 'Aider (Claude)',
      description: 'Aider with Claude Sonnet model',
    ),
    AiCliCommand(
      command: 'gemini',
      name: 'Gemini CLI',
      description: 'Google Gemini AI agent',
    ),
    AiCliCommand(
      command: 'codex',
      name: 'Codex CLI',
      description: 'OpenAI Codex coding agent',
    ),
    AiCliCommand(
      command: 'aichat',
      name: 'AIChat',
      description: 'Multi-LLM CLI (OpenAI, Claude, Gemini, Ollama)',
    ),
    AiCliCommand(
      command: 'gpt',
      name: 'GPT CLI',
      description: 'ChatGPT command line interface',
    ),
    AiCliCommand(
      command: 'gh copilot',
      name: 'GitHub Copilot',
      description: 'GitHub Copilot in terminal',
    ),
  ];
}

/// Connection configuration
class ConnectionConfig {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? passphrase;
  final String? startupCommand;
  final bool useDefaultKeys;

  const ConnectionConfig({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
    this.passphrase,
    this.startupCommand,
    this.useDefaultKeys = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'startupCommand': startupCommand,
        'useDefaultKeys': useDefaultKeys,
      };

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ConnectionConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      startupCommand: json['startupCommand'] as String?,
      useDefaultKeys: json['useDefaultKeys'] as bool? ?? true,
    );
  }
}

/// SSH session state
enum SessionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// SSH session wrapper with auto-reconnect
class SshSession {
  final ConnectionConfig config;
  final Terminal terminal;
  final void Function(SessionState state)? onStateChange;

  SSHClient? _client;
  SSHSession? _session;
  SessionState _state = SessionState.disconnected;
  String? _lastError;
  Timer? _reconnectTimer;
  bool _shouldReconnect = true;
  bool _startupCommandSent = false;

  SshSession({
    required this.config,
    required this.terminal,
    this.onStateChange,
  });

  SessionState get state => _state;
  String? get lastError => _lastError;
  bool get isConnected => _state == SessionState.connected;

  void _setState(SessionState newState) {
    _state = newState;
    onStateChange?.call(newState);
  }

  /// Load default SSH keys from ~/.ssh/
  Future<List<SSHKeyPair>> _loadDefaultKeys() async {
    final keys = <SSHKeyPair>[];

    try {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home == null) return keys;

      final sshDir = Directory('$home/.ssh');
      if (!await sshDir.exists()) return keys;

      // Common key file names
      final keyNames = ['id_ed25519', 'id_rsa', 'id_ecdsa'];

      for (final name in keyNames) {
        final keyFile = File('${sshDir.path}/$name');
        if (await keyFile.exists()) {
          try {
            final keyContent = await keyFile.readAsString();
            final keyPairs = SSHKeyPair.fromPem(keyContent, config.passphrase);
            keys.addAll(keyPairs);
            debugPrint('Loaded SSH key: $name');
          } catch (e) {
            debugPrint('Failed to load key $name: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading default keys: $e');
    }

    return keys;
  }

  /// Connect to SSH server
  Future<void> connect() async {
    if (_state == SessionState.connecting || _state == SessionState.connected) {
      return;
    }

    _shouldReconnect = true;
    _startupCommandSent = false;
    _setState(SessionState.connecting);
    _lastError = null;

    try {
      terminal.write('Connecting to ${config.host}:${config.port}...\r\n');

      final socket = await SSHSocket.connect(config.host, config.port);

      // Build identities list
      final identities = <SSHKeyPair>[];

      // Add explicit private key if provided
      if (config.privateKey != null && config.privateKey!.isNotEmpty) {
        try {
          identities.addAll(SSHKeyPair.fromPem(
            config.privateKey!,
            config.passphrase,
          ));
          terminal.write('Using provided private key.\r\n');
        } catch (e) {
          terminal.write('\x1B[33mWarning: Failed to load private key: $e\x1B[0m\r\n');
        }
      }

      // Load default keys on Linux/macOS if enabled
      if (config.useDefaultKeys && (Platform.isLinux || Platform.isMacOS)) {
        final defaultKeys = await _loadDefaultKeys();
        if (defaultKeys.isNotEmpty) {
          identities.addAll(defaultKeys);
          terminal.write('Loaded ${defaultKeys.length} default SSH key(s).\r\n');
        }
      }

      _client = SSHClient(
        socket,
        username: config.username,
        onPasswordRequest: () => config.password ?? '',
        identities: identities,
        onAuthenticated: () {
          terminal.write('Authenticated.\r\n');
        },
      );

      _session = await _client!.shell(
        pty: SSHPtyConfig(
          width: terminal.viewWidth,
          height: terminal.viewHeight,
        ),
      );

      _setState(SessionState.connected);
      terminal.write('Connected!\r\n\r\n');

      // Pipe session output to terminal
      _session!.stdout.listen(
        (data) {
          terminal.write(String.fromCharCodes(data));
          // Send startup command after shell is ready (first prompt received)
          _sendStartupCommandIfNeeded();
        },
        onError: (e) => _handleError('Stream error: $e'),
        onDone: () => _handleDisconnect(),
      );

      _session!.stderr.listen(
        (data) => terminal.write(String.fromCharCodes(data)),
      );

      // Handle terminal resize
      terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        _session?.resizeTerminal(width, height);
      };

    } catch (e) {
      _handleError('Connection failed: $e');
    }
  }

  /// Send startup command after shell prompt is detected
  void _sendStartupCommandIfNeeded() {
    if (_startupCommandSent) return;
    if (config.startupCommand == null || config.startupCommand!.isEmpty) return;

    // Mark as sent to avoid sending multiple times
    _startupCommandSent = true;

    // Small delay to ensure shell is fully ready
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_state == SessionState.connected && _session != null) {
        write('${config.startupCommand}\n');
      }
    });
  }

  void _handleError(String error) {
    _lastError = error;
    terminal.write('\r\n\x1B[31m$error\x1B[0m\r\n');
    _setState(SessionState.error);
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    if (_state == SessionState.disconnected) return;

    terminal.write('\r\n\x1B[33mDisconnected.\x1B[0m\r\n');
    _setState(SessionState.disconnected);
    _cleanup();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_shouldReconnect && _state != SessionState.connected) {
        terminal.write('\r\nReconnecting...\r\n');
        connect();
      }
    });
  }

  /// Write data to session
  void write(String data) {
    if (_session != null && _state == SessionState.connected) {
      _session!.stdin.add(Uint8List.fromList(utf8.encode(data)));
    }
  }

  /// Send special key
  void sendKey(TerminalKey key, {bool ctrl = false, bool alt = false}) {
    String? sequence;

    switch (key) {
      case TerminalKey.escape:
        sequence = '\x1B';
        break;
      case TerminalKey.tab:
        sequence = '\t';
        break;
      case TerminalKey.arrowUp:
        sequence = '\x1B[A';
        break;
      case TerminalKey.arrowDown:
        sequence = '\x1B[B';
        break;
      case TerminalKey.arrowRight:
        sequence = '\x1B[C';
        break;
      case TerminalKey.arrowLeft:
        sequence = '\x1B[D';
        break;
      case TerminalKey.home:
        sequence = '\x1B[H';
        break;
      case TerminalKey.end:
        sequence = '\x1B[F';
        break;
      case TerminalKey.pageUp:
        sequence = '\x1B[5~';
        break;
      case TerminalKey.pageDown:
        sequence = '\x1B[6~';
        break;
      case TerminalKey.delete:
        sequence = '\x1B[3~';
        break;
      default:
        return;
    }

    if (ctrl && sequence.length == 1) {
      // Convert to control character
      final char = sequence.codeUnitAt(0);
      if (char >= 64 && char <= 95) {
        sequence = String.fromCharCode(char - 64);
      } else if (char >= 97 && char <= 122) {
        sequence = String.fromCharCode(char - 96);
      }
    }

    write(sequence);
  }

  void _cleanup() {
    _session?.close();
    _client?.close();
    _session = null;
    _client = null;
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _cleanup();
    _setState(SessionState.disconnected);
  }

  void dispose() {
    disconnect();
  }
}
