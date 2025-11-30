import 'dart:async';
import 'dart:convert';

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

      // Build identities
      final identities = <SSHKeyPair>[];
      if (config.privateKey != null && config.privateKey!.isNotEmpty) {
        try {
          identities.addAll(SSHKeyPair.fromPem(
            config.privateKey!,
            config.passphrase,
          ));
        } catch (e) {
          terminal.write('\x1B[31mFailed to load private key: $e\x1B[0m\r\n');
        }
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
}

/// MOSH connection info from mosh-server
class _MoshConnectionInfo {
  final String port;
  final String key;

  _MoshConnectionInfo({required this.port, required this.key});
}
