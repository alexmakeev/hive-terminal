import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';

import '../../src/generated/hive.pbgrpc.dart';
import 'hive_client.dart';

/// Service for managing terminal streaming via Hive Server gRPC.
///
/// Provides bidirectional streaming for terminal I/O with session management.
class HiveTerminalService {
  final HiveClient _client;

  HiveTerminalService({required HiveClient client}) : _client = client;

  /// Create a new terminal session for a connection.
  ///
  /// The [password] is required to authenticate with the SSH server.
  /// It is only used for connection establishment and is not stored.
  Future<Session?> createSession(String connectionId, {required String password}) async {
    if (!_client.isConnected) {
      debugPrint('HiveTerminalService: Not connected to server');
      return null;
    }

    try {
      final session = await _client.sessions.create(
        CreateSessionRequest(connectionId: connectionId, password: password),
        options: _client.callOptions,
      );
      debugPrint('HiveTerminalService: Created session ${session.id}');
      return session;
    } on GrpcError catch (e) {
      debugPrint('HiveTerminalService: gRPC error creating session: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('HiveTerminalService: Error creating session: $e');
      return null;
    }
  }

  /// Close a terminal session.
  Future<bool> closeSession(String sessionId) async {
    if (!_client.isConnected) {
      return false;
    }

    try {
      await _client.sessions.close(
        CloseSessionRequest(id: sessionId),
        options: _client.callOptions,
      );
      debugPrint('HiveTerminalService: Closed session $sessionId');
      return true;
    } on GrpcError catch (e) {
      debugPrint('HiveTerminalService: gRPC error closing session: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('HiveTerminalService: Error closing session: $e');
      return false;
    }
  }

  /// Attach to a terminal session with bidirectional streaming.
  ///
  /// Returns a [TerminalStream] that provides input/output streams.
  TerminalStream? attach(String sessionId) {
    if (!_client.isConnected) {
      debugPrint('HiveTerminalService: Not connected to server');
      return null;
    }

    final inputController = StreamController<TerminalInput>();

    try {
      final outputStream = _client.terminal.attach(
        inputController.stream,
        options: _client.callOptions,
      );

      return TerminalStream(
        sessionId: sessionId,
        inputSink: inputController,
        outputStream: outputStream,
      );
    } catch (e) {
      debugPrint('HiveTerminalService: Error attaching to terminal: $e');
      inputController.close();
      return null;
    }
  }

  /// Create a TerminalInput message with data payload.
  static TerminalInput createDataInput({
    required String sessionId,
    required List<int> data,
  }) {
    return TerminalInput(
      sessionId: sessionId,
      data: data,
    );
  }

  /// Create a TerminalInput message with resize payload.
  static TerminalInput createResizeInput({
    required String sessionId,
    required int cols,
    required int rows,
  }) {
    return TerminalInput(
      sessionId: sessionId,
      resize: Resize(cols: cols, rows: rows),
    );
  }

  /// Create a TerminalInput message with file upload payload.
  static TerminalInput createFileInput({
    required String sessionId,
    required String filename,
    required List<int> data,
  }) {
    return TerminalInput(
      sessionId: sessionId,
      file: FileUpload(filename: filename, data: data),
    );
  }

  /// Check if output contains terminal data.
  static bool isData(TerminalOutput output) {
    return output.whichPayload() == TerminalOutput_Payload.data;
  }

  /// Check if output contains scrollback data.
  static bool isScrollback(TerminalOutput output) {
    return output.whichPayload() == TerminalOutput_Payload.scrollback;
  }

  /// Check if output contains an error.
  static bool isError(TerminalOutput output) {
    return output.whichPayload() == TerminalOutput_Payload.error;
  }

  /// Check if output indicates session closed.
  static bool isClosed(TerminalOutput output) {
    return output.whichPayload() == TerminalOutput_Payload.closed;
  }

  /// Check if output contains file upload confirmation.
  static bool isFileUploaded(TerminalOutput output) {
    return output.whichPayload() == TerminalOutput_Payload.file;
  }
}

/// Represents an active terminal stream connection.
///
/// Use [send] to send input, listen to [output] for terminal data.
/// Call [close] when done.
class TerminalStream {
  final String sessionId;
  final StreamController<TerminalInput> _inputController;
  final ResponseStream<TerminalOutput> _outputStream;

  bool _closed = false;

  TerminalStream({
    required this.sessionId,
    required StreamController<TerminalInput> inputSink,
    required ResponseStream<TerminalOutput> outputStream,
  })  : _inputController = inputSink,
        _outputStream = outputStream;

  /// Stream of terminal output from server.
  Stream<TerminalOutput> get output => _outputStream;

  /// Whether the stream has been closed.
  bool get isClosed => _closed;

  /// Send data to terminal.
  void sendData(List<int> data) {
    if (_closed) return;
    _inputController.add(HiveTerminalService.createDataInput(
      sessionId: sessionId,
      data: data,
    ));
  }

  /// Send resize event to terminal.
  void sendResize(int cols, int rows) {
    if (_closed) return;
    _inputController.add(HiveTerminalService.createResizeInput(
      sessionId: sessionId,
      cols: cols,
      rows: rows,
    ));
  }

  /// Send file upload to terminal.
  void sendFile(String filename, List<int> data) {
    if (_closed) return;
    _inputController.add(HiveTerminalService.createFileInput(
      sessionId: sessionId,
      filename: filename,
      data: data,
    ));
  }

  /// Close the terminal stream.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _inputController.close();
  }
}
