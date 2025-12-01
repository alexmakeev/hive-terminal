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

/// Connection protocol
enum ConnectionProtocol {
  ssh,
  mosh,
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
  final ConnectionProtocol protocol;

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
    this.protocol = ConnectionProtocol.ssh,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'privateKey': privateKey,
        'passphrase': passphrase,
        'startupCommand': startupCommand,
        'useDefaultKeys': useDefaultKeys,
        'protocol': protocol.name,
      };

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ConnectionConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      privateKey: json['privateKey'] as String?,
      passphrase: json['passphrase'] as String?,
      startupCommand: json['startupCommand'] as String?,
      useDefaultKeys: json['useDefaultKeys'] as bool? ?? true,
      protocol: ConnectionProtocol.values.firstWhere(
        (p) => p.name == json['protocol'],
        orElse: () => ConnectionProtocol.ssh,
      ),
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
  final Future<String?> Function(String keyName)? onPassphraseRequest;
  final String? sshFolderPath;

  SSHClient? _client;
  SSHSession? _session;
  SessionState _state = SessionState.disconnected;
  String? _lastError;
  bool _startupCommandSent = false;

  SshSession({
    required this.config,
    required this.terminal,
    this.onStateChange,
    this.onPassphraseRequest,
    this.sshFolderPath,
  });

  SessionState get state => _state;
  String? get lastError => _lastError;
  bool get isConnected => _state == SessionState.connected;

  void _setState(SessionState newState) {
    _state = newState;
    onStateChange?.call(newState);
  }

  /// Load default SSH keys from selected folder
  Future<List<SSHKeyPair>> _loadDefaultKeys() async {
    final keys = <SSHKeyPair>[];
    final errors = <String>[];

    // Use provided folder path only (don't try default on macOS - causes hangs)
    String? sshPath = sshFolderPath;

    if (sshPath == null) {
      if (Platform.isMacOS) {
        // On macOS, require explicit folder selection
        terminal.write('\x1B[33mSSH folder not selected. Use menu → Select SSH Folder\x1B[0m\r\n');
        return keys;
      } else {
        // On other platforms, try default
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (home != null) {
          sshPath = '$home/.ssh';
        }
      }
    }

    if (sshPath == null) {
      terminal.write('\x1B[33mWarning: SSH folder not configured\x1B[0m\r\n');
      return keys;
    }

    try {
      final sshDir = Directory(sshPath);

      // Use timeout to prevent hanging on permission issues
      final exists = await sshDir.exists().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          terminal.write('\x1B[33mWarning: SSH folder access timeout\x1B[0m\r\n');
          return false;
        },
      );

      if (!exists) {
        terminal.write('\x1B[33mWarning: SSH folder not found: $sshPath\x1B[0m\r\n');
        return keys;
      }

      // Common key file names
      final keyNames = ['id_ed25519', 'id_rsa', 'id_ecdsa'];

      for (final name in keyNames) {
        final keyFile = File('${sshDir.path}/$name');
        if (await keyFile.exists()) {
          try {
            final keyContent = await keyFile.readAsString();
            // Try with config passphrase first (or no passphrase if null)
            final keyPairs = SSHKeyPair.fromPem(keyContent, config.passphrase);
            keys.addAll(keyPairs);
            terminal.write('Loaded key: $name\r\n');
          } catch (e) {
            final errorMsg = e.toString();
            final needsPassphrase = errorMsg.contains('passphrase') ||
                                    errorMsg.contains('decrypt') ||
                                    errorMsg.contains('encrypted');

            if (needsPassphrase && onPassphraseRequest != null) {
              // Ask user for passphrase for this specific key
              terminal.write('\x1B[33mKey $name requires passphrase...\x1B[0m\r\n');
              final passphrase = await onPassphraseRequest!(name);

              if (passphrase != null && passphrase.isNotEmpty) {
                try {
                  final keyContent = await keyFile.readAsString();
                  final keyPairs = SSHKeyPair.fromPem(keyContent, passphrase);
                  keys.addAll(keyPairs);
                  terminal.write('Loaded key: $name (with passphrase)\r\n');
                } catch (e2) {
                  errors.add('$name: invalid passphrase');
                }
              } else {
                errors.add('$name: passphrase not provided');
              }
            } else if (needsPassphrase) {
              errors.add('$name: needs passphrase');
            } else {
              errors.add('$name: $errorMsg');
            }
          }
        }
      }

      // Show errors for failed keys
      for (final err in errors) {
        terminal.write('\x1B[33mFailed to load $err\x1B[0m\r\n');
      }
    } catch (e) {
      terminal.write('\x1B[31mError loading SSH keys: $e\x1B[0m\r\n');
    }

    return keys;
  }

  /// Connect to SSH server
  Future<void> connect() async {
    if (_state == SessionState.connecting || _state == SessionState.connected) {
      return;
    }

    _startupCommandSent = false;
    _setState(SessionState.connecting);
    _lastError = null;

    try {
      terminal.write('Connecting to ${config.host}:${config.port}...\r\n');

      // Debug: show what credentials are available
      terminal.write('\x1B[90mCredentials: ');
      final authMethods = <String>[];
      if (config.password != null && config.password!.isNotEmpty) {
        authMethods.add('password(${config.password!.length}ch)');
      }
      if (config.privateKey != null && config.privateKey!.isNotEmpty) {
        authMethods.add('key(${config.privateKey!.length}ch)');
        if (config.passphrase != null && config.passphrase!.isNotEmpty) {
          authMethods.add('passphrase');
        }
      } else if (config.useDefaultKeys) {
        authMethods.add('defaultKeys');
      }
      if (authMethods.isEmpty) {
        terminal.write('NONE - check saved connection!\x1B[0m\r\n');
      } else {
        terminal.write(authMethods.join(', '));
        terminal.write('\x1B[0m\r\n');
      }

      final socket = await SSHSocket.connect(config.host, config.port);

      // Build identities list
      final identities = <SSHKeyPair>[];

      // Add explicit private key if provided
      final hasExplicitKey = config.privateKey != null && config.privateKey!.isNotEmpty;

      if (hasExplicitKey) {
        try {
          identities.addAll(SSHKeyPair.fromPem(
            config.privateKey!,
            config.passphrase,
          ));
          terminal.write('Using provided private key.\r\n');
        } catch (e) {
          terminal.write('\x1B[31mFailed to load private key: $e\x1B[0m\r\n');
          // Don't continue if explicit key failed - user needs to fix the config
          _handleError('Private key error: $e');
          return;
        }
      }

      // Load default keys ONLY if no explicit key provided
      if (!hasExplicitKey && config.useDefaultKeys && (Platform.isLinux || Platform.isMacOS)) {
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
    terminal.write('\x1B[90mPress reconnect button to try again.\x1B[0m\r\n');
    _setState(SessionState.error);
  }

  void _handleDisconnect() {
    if (_state == SessionState.disconnected) return;

    terminal.write('\r\n\x1B[33mDisconnected.\x1B[0m\r\n');
    _setState(SessionState.disconnected);
    _cleanup();
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
    _cleanup();
    _setState(SessionState.disconnected);
  }

  void dispose() {
    disconnect();
  }
}
