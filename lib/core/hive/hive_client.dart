import 'package:grpc/grpc.dart';

import '../../src/generated/hive.pbgrpc.dart';

/// Client for communicating with Hive Server via gRPC.
///
/// Provides access to all gRPC services:
/// - Auth: API key validation
/// - Keys: SSH key management
/// - Connections: Connection configuration CRUD
/// - Sessions: Session lifecycle management
/// - Terminal: Bidirectional terminal I/O streaming
class HiveClient {
  final String host;
  final int port;
  final ChannelOptions options;

  ClientChannel? _channel;
  String? _apiKey;
  String? _userId;

  AuthClient? _authClient;
  KeysClient? _keysClient;
  ConnectionsClient? _connectionsClient;
  SessionsClient? _sessionsClient;
  TerminalClient? _terminalClient;

  HiveClient({
    required this.host,
    required this.port,
    ChannelOptions? options,
  }) : options = options ?? const ChannelOptions(credentials: ChannelCredentials.insecure());

  /// Whether the client is connected to the server.
  bool get isConnected => _channel != null;

  /// Whether an API key has been set.
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Set API key for authentication.
  void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  /// Clear API key.
  void clearApiKey() {
    _apiKey = null;
  }

  /// Set user ID for authenticated requests.
  void setUserId(String userId) {
    _userId = userId;
  }

  /// Clear user ID.
  void clearUserId() {
    _userId = null;
  }

  /// Get call options with authentication metadata.
  CallOptions get callOptions {
    final metadata = <String, String>{};
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      metadata['authorization'] = 'Bearer $_apiKey';
    }
    if (_userId != null && _userId!.isNotEmpty) {
      metadata['x-user-id'] = _userId!;
    }
    if (metadata.isEmpty) {
      return CallOptions();
    }
    return CallOptions(metadata: metadata);
  }

  /// Connect to the Hive Server.
  Future<void> connect() async {
    if (_channel != null) {
      return;
    }

    _channel = ClientChannel(
      host,
      port: port,
      options: options,
    );

    _createClients();
  }

  void _createClients() {
    _authClient = AuthClient(_channel!);
    _keysClient = KeysClient(_channel!);
    _connectionsClient = ConnectionsClient(_channel!);
    _sessionsClient = SessionsClient(_channel!);
    _terminalClient = TerminalClient(_channel!);
  }

  /// Shutdown the connection.
  Future<void> shutdown() async {
    if (_channel == null) {
      return;
    }

    await _channel!.shutdown();
    _channel = null;

    _authClient = null;
    _keysClient = null;
    _connectionsClient = null;
    _sessionsClient = null;
    _terminalClient = null;
  }

  /// Auth service client for API key validation.
  AuthClient get auth {
    _assertConnected();
    return _authClient!;
  }

  /// Keys service client for SSH key management.
  KeysClient get keys {
    _assertConnected();
    return _keysClient!;
  }

  /// Connections service client for connection config CRUD.
  ConnectionsClient get connections {
    _assertConnected();
    return _connectionsClient!;
  }

  /// Sessions service client for session management.
  SessionsClient get sessions {
    _assertConnected();
    return _sessionsClient!;
  }

  /// Terminal service client for bidirectional streaming.
  TerminalClient get terminal {
    _assertConnected();
    return _terminalClient!;
  }

  void _assertConnected() {
    if (_channel == null) {
      throw StateError('HiveClient is not connected. Call connect() first.');
    }
  }
}
