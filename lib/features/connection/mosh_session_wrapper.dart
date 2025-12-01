import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:mosh_client/mosh_client.dart';
import 'package:xterm/xterm.dart';

import 'ssh_session.dart';

/// MOSH session state
enum MoshSessionState {
  disconnected,
  bootstrapping, // SSH phase to get key/port
  connecting, // MOSH connecting
  connected,
  error,
}

/// MOSH session wrapper that handles SSH bootstrap and MOSH connection
class MoshSessionWrapper {
  final ConnectionConfig config;
  final Terminal terminal;
  final void Function(MoshSessionState state)? onStateChange;
  final Future<String?> Function(String keyName)? onPassphraseRequest;
  final String? sshFolderPath;

  MoshSession? _moshSession;
  MoshSessionState _state = MoshSessionState.disconnected;
  String? _lastError;
  StreamSubscription? _screenSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _stateSub;

  MoshSessionWrapper({
    required this.config,
    required this.terminal,
    this.onStateChange,
    this.onPassphraseRequest,
    this.sshFolderPath,
  });

  MoshSessionState get state => _state;
  String? get lastError => _lastError;
  bool get isConnected => _state == MoshSessionState.connected;

  void _setState(MoshSessionState newState) {
    _state = newState;
    onStateChange?.call(newState);
  }

  /// Connect to MOSH server
  Future<void> connect() async {
    if (_state == MoshSessionState.bootstrapping ||
        _state == MoshSessionState.connecting ||
        _state == MoshSessionState.connected) {
      return;
    }

    _setState(MoshSessionState.bootstrapping);
    _lastError = null;

    try {
      terminal.write('MOSH: Bootstrapping via SSH...\r\n');

      // Step 1: SSH bootstrap to get MOSH key and port
      final moshInfo = await _sshBootstrap();
      if (moshInfo == null) {
        _handleError('Failed to start mosh-server');
        return;
      }

      terminal.write('MOSH: Got session - port ${moshInfo.port}\r\n');
      terminal.write('MOSH: Connecting via UDP...\r\n');

      _setState(MoshSessionState.connecting);

      // Step 2: Connect with MOSH
      _moshSession = MoshSession(
        host: config.host,
        port: moshInfo.port,
        key: moshInfo.key,
        width: terminal.viewWidth,
        height: terminal.viewHeight,
      );

      // Listen to MOSH events
      _screenSub = _moshSession!.onScreenUpdate.listen(_handleScreenUpdate);
      _errorSub = _moshSession!.onError.listen(_handleMoshError);
      _stateSub = _moshSession!.onStateChange.listen(_handleMoshState);

      await _moshSession!.connect();

      _setState(MoshSessionState.connected);
      terminal.write('MOSH: Connected!\r\n\r\n');

      // Handle terminal resize
      terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        _moshSession?.resize(width, height);
      };
    } catch (e) {
      _handleError('MOSH connection failed: $e');
    }
  }

  /// SSH bootstrap to start mosh-server and get connection info
  Future<_MoshConnectionInfo?> _sshBootstrap() async {
    SSHClient? client;

    try {
      terminal.write('SSH: Connecting to ${config.host}:${config.port}...\r\n');

      final socket = await SSHSocket.connect(config.host, config.port);

      // Build identities - same logic as SshSession
      final identities = <SSHKeyPair>[];
      final hasExplicitKey = config.privateKey != null && config.privateKey!.isNotEmpty;

      if (hasExplicitKey) {
        // Use explicit private key
        try {
          identities.addAll(SSHKeyPair.fromPem(
            config.privateKey!,
            config.passphrase,
          ));
          terminal.write('Using provided private key.\r\n');
        } catch (e) {
          terminal.write('\x1B[31mFailed to load private key: $e\x1B[0m\r\n');
        }
      }

      // Load default keys if enabled and no explicit key or as fallback
      if (config.useDefaultKeys && !hasExplicitKey) {
        final defaultKeys = await _loadDefaultKeys();
        identities.addAll(defaultKeys);
      }

      client = SSHClient(
        socket,
        username: config.username,
        onPasswordRequest: () => config.password ?? '',
        identities: identities,
      );

      terminal.write('SSH: Running mosh-server...\r\n');

      // Execute mosh-server new
      final session = await client.execute('mosh-server new -l LANG=en_US.UTF-8');

      final output = StringBuffer();
      await for (final data in session.stdout) {
        output.write(utf8.decode(data));
      }

      // Also capture stderr (mosh-server outputs to stderr)
      final stderrOutput = StringBuffer();
      await for (final data in session.stderr) {
        stderrOutput.write(utf8.decode(data));
      }

      final allOutput = output.toString() + stderrOutput.toString();
      terminal.write('\x1B[90mServer output: ${allOutput.trim()}\x1B[0m\r\n');

      // Parse MOSH CONNECT <port> <key>
      final moshInfo = _parseMoshConnect(allOutput);

      // Close SSH connection
      client.close();

      return moshInfo;
    } catch (e) {
      client?.close();
      terminal.write('\x1B[31mSSH bootstrap error: $e\x1B[0m\r\n');
      return null;
    }
  }

  /// Parse mosh-server output: MOSH CONNECT [port] [key]
  _MoshConnectionInfo? _parseMoshConnect(String output) {
    // Look for: MOSH CONNECT 60001 base64key==
    final regex = RegExp(r'MOSH CONNECT (\d+) (\S+)');
    final match = regex.firstMatch(output);

    if (match != null) {
      final port = match.group(1)!;
      final key = match.group(2)!;
      return _MoshConnectionInfo(port: port, key: key);
    }

    terminal.write('\x1B[31mCould not parse mosh-server output\x1B[0m\r\n');
    return null;
  }

  void _handleScreenUpdate(MoshScreenUpdate update) {
    // Convert MOSH screen to terminal output
    // This is a simplified version - MOSH provides full screen state
    // For now, we'll need to implement proper screen rendering
    // TODO: Implement full screen rendering from MOSH cells
  }

  void _handleMoshError(String error) {
    terminal.write('\x1B[31mMOSH error: $error\x1B[0m\r\n');
  }

  void _handleMoshState(MoshState state) {
    switch (state) {
      case MoshState.MOSH_STATE_CONNECTED:
        terminal.write('\x1B[32mMOSH: Connection established\x1B[0m\r\n');
        break;
      case MoshState.MOSH_STATE_DISCONNECTED:
        terminal.write('\x1B[33mMOSH: Disconnected\x1B[0m\r\n');
        _setState(MoshSessionState.disconnected);
        break;
      case MoshState.MOSH_STATE_ERROR:
        _handleError(_moshSession?.lastError ?? 'Unknown MOSH error');
        break;
      default:
        break;
    }
  }

  void _handleError(String error) {
    _lastError = error;
    terminal.write('\r\n\x1B[31m$error\x1B[0m\r\n');
    _setState(MoshSessionState.error);
  }

  /// Write data to session
  void write(String data) {
    if (_moshSession != null && _state == MoshSessionState.connected) {
      _moshSession!.write(data);
    }
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    _screenSub?.cancel();
    _errorSub?.cancel();
    _stateSub?.cancel();
    _moshSession?.dispose();
    _moshSession = null;
    _setState(MoshSessionState.disconnected);
  }

  void dispose() {
    disconnect();
  }

  /// Load default SSH keys from ~/.ssh folder
  Future<List<SSHKeyPair>> _loadDefaultKeys() async {
    final keys = <SSHKeyPair>[];
    final errors = <String>[];

    // Use provided folder path only (don't try default on macOS - causes hangs)
    String? sshPath = sshFolderPath;

    if (sshPath == null) {
      if (Platform.isMacOS) {
        terminal.write('\x1B[33mSSH folder not selected. Use menu → Select SSH Folder\x1B[0m\r\n');
        return keys;
      } else {
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

      for (final err in errors) {
        terminal.write('\x1B[33mFailed to load $err\x1B[0m\r\n');
      }
    } catch (e) {
      terminal.write('\x1B[31mError loading SSH keys: $e\x1B[0m\r\n');
    }

    return keys;
  }
}

/// MOSH connection info from mosh-server
class _MoshConnectionInfo {
  final String port;
  final String key;

  _MoshConnectionInfo({required this.port, required this.key});
}
