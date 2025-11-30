/// MOSH Client Library for Flutter
///
/// Provides a high-level API for connecting to MOSH servers.
library mosh_client;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'mosh_client_bindings_generated.dart' hide MoshSession;

export 'mosh_client_bindings_generated.dart'
    show MoshState, MoshResult, MoshCell;

const String _libName = 'mosh_client';

/// The dynamic library in which the symbols for [MoshClientBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final MoshClientBindings _bindings = MoshClientBindings(_dylib);

/// Check if MOSH is available on this platform.
bool get isMoshAvailable {
  try {
    final version = moshVersion;
    return !version.contains('stub');
  } catch (e) {
    return false;
  }
}

/// Get the MOSH library version string.
String get moshVersion {
  final ptr = _bindings.mosh_version();
  return ptr.cast<Utf8>().toDartString();
}

/// Initialize the MOSH library.
/// Should be called once at app startup.
void moshInit() {
  final result = _bindings.mosh_init();
  if (result != MoshResult.MOSH_OK) {
    throw MoshException('Failed to initialize MOSH library', result);
  }
}

/// Cleanup the MOSH library.
/// Should be called when done using MOSH.
void moshCleanup() {
  _bindings.mosh_cleanup();
}

/// MOSH exception with error code.
class MoshException implements Exception {
  final String message;
  final MoshResult? errorCode;

  MoshException(this.message, [this.errorCode]);

  @override
  String toString() {
    if (errorCode != null) {
      return 'MoshException: $message (${errorCode!.name})';
    }
    return 'MoshException: $message';
  }
}

/// Screen update event from MOSH session.
class MoshScreenUpdate {
  final List<List<MoshCellData>> cells;
  final int width;
  final int height;
  final int cursorX;
  final int cursorY;

  MoshScreenUpdate({
    required this.cells,
    required this.width,
    required this.height,
    required this.cursorX,
    required this.cursorY,
  });
}

/// Dart-friendly cell data.
class MoshCellData {
  final int codepoint;
  final int foreground;
  final int background;
  final bool bold;
  final bool underline;
  final bool blink;
  final bool inverse;

  MoshCellData({
    required this.codepoint,
    required this.foreground,
    required this.background,
    required this.bold,
    required this.underline,
    required this.blink,
    required this.inverse,
  });

  String get character => String.fromCharCode(codepoint);
}

/// MOSH session.
///
/// Example usage:
/// ```dart
/// final session = MoshSession(
///   host: 'example.com',
///   port: '60001',
///   key: 'base64key==',
///   width: 80,
///   height: 24,
/// );
///
/// session.onScreenUpdate.listen((update) {
///   // Handle screen update
/// });
///
/// session.onError.listen((error) {
///   print('Error: $error');
/// });
///
/// await session.connect();
/// session.write('ls -la\n');
///
/// // Later
/// session.dispose();
/// ```
class MoshSession {
  final String host;
  final String port;
  final String key;
  int _width;
  int _height;

  Pointer<Void>? _handle;
  Timer? _pollTimer;

  final _screenController = StreamController<MoshScreenUpdate>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _stateController = StreamController<MoshState>.broadcast();

  /// Stream of screen updates.
  Stream<MoshScreenUpdate> get onScreenUpdate => _screenController.stream;

  /// Stream of error messages.
  Stream<String> get onError => _errorController.stream;

  /// Stream of state changes.
  Stream<MoshState> get onStateChange => _stateController.stream;

  /// Current terminal width.
  int get width => _width;

  /// Current terminal height.
  int get height => _height;

  /// Create a new MOSH session.
  ///
  /// [host] - The server hostname or IP address
  /// [port] - The UDP port (from mosh-server)
  /// [key] - The base64 session key (from mosh-server)
  /// [width] - Initial terminal width
  /// [height] - Initial terminal height
  MoshSession({
    required this.host,
    required this.port,
    required this.key,
    int width = 80,
    int height = 24,
  })  : _width = width,
        _height = height;

  /// Get current session state.
  MoshState get state {
    if (_handle == null) return MoshState.MOSH_STATE_DISCONNECTED;
    return _bindings.mosh_session_get_state(_handle!);
  }

  /// Check if connected.
  bool get isConnected => state == MoshState.MOSH_STATE_CONNECTED;

  /// Get last error message, if any.
  String? get lastError {
    if (_handle == null) return null;
    final ptr = _bindings.mosh_session_get_error(_handle!);
    if (ptr == nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  /// Connect to the MOSH server.
  Future<void> connect() async {
    if (_handle != null) {
      throw MoshException('Session already exists');
    }

    // Create session
    final hostPtr = host.toNativeUtf8().cast<Char>();
    final portPtr = port.toNativeUtf8().cast<Char>();
    final keyPtr = key.toNativeUtf8().cast<Char>();

    try {
      _handle = _bindings.mosh_session_create(
        hostPtr,
        portPtr,
        keyPtr,
        _width,
        _height,
      );

      if (_handle == null || _handle == nullptr) {
        throw MoshException('Failed to create session');
      }

      // Connect
      final result = _bindings.mosh_session_connect(_handle!);
      if (result != MoshResult.MOSH_OK) {
        final error = lastError ?? 'Unknown error';
        _bindings.mosh_session_destroy(_handle!);
        _handle = null;
        throw MoshException(error, result);
      }

      // Start polling for updates
      _startPolling();
    } finally {
      calloc.free(hostPtr);
      calloc.free(portPtr);
      calloc.free(keyPtr);
    }
  }

  /// Send input to the session.
  void write(String data) {
    if (_handle == null || !isConnected) {
      throw MoshException('Not connected');
    }

    final dataPtr = data.toNativeUtf8().cast<Char>();
    try {
      final result = _bindings.mosh_session_write(
        _handle!,
        dataPtr,
        data.length,
      );
      if (result != MoshResult.MOSH_OK) {
        throw MoshException('Failed to write', result);
      }
    } finally {
      calloc.free(dataPtr);
    }
  }

  /// Resize the terminal.
  void resize(int width, int height) {
    _width = width;
    _height = height;

    if (_handle == null || !isConnected) return;

    final result = _bindings.mosh_session_resize(_handle!, width, height);
    if (result != MoshResult.MOSH_OK) {
      throw MoshException('Failed to resize', result);
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _poll();
    });
  }

  MoshState _lastState = MoshState.MOSH_STATE_DISCONNECTED;

  void _poll() {
    if (_handle == null) return;

    try {
      // Poll with 10ms timeout
      _bindings.mosh_session_poll(_handle!, 10);

      // Check state changes
      final currentState = state;
      if (currentState != _lastState) {
        _lastState = currentState;
        _stateController.add(currentState);

        if (currentState == MoshState.MOSH_STATE_ERROR) {
          final error = lastError ?? 'Unknown error';
          _errorController.add(error);
        }
      }
    } catch (e) {
      _errorController.add(e.toString());
    }
  }

  /// Disconnect and cleanup.
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;

    if (_handle != null) {
      _bindings.mosh_session_destroy(_handle!);
      _handle = null;
    }

    _screenController.close();
    _errorController.close();
    _stateController.close();
  }
}
