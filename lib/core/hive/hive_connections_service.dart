import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';

import '../../features/connection/connection_config.dart';
import '../../src/generated/hive.pbgrpc.dart';
import 'hive_client.dart';

/// Service for managing connections via Hive Server gRPC.
///
/// Provides CRUD operations for server-stored connections.
/// This complements [ConnectionRepository] which stores local-only connections.
class HiveConnectionsService extends ChangeNotifier {
  final HiveClient _client;

  List<ConnectionConfig> _connections = [];
  bool _loaded = false;
  String? _error;

  HiveConnectionsService({required HiveClient client}) : _client = client;

  List<ConnectionConfig> get connections => List.unmodifiable(_connections);
  bool get isLoaded => _loaded;
  String? get error => _error;

  /// Load all connections from server.
  Future<void> load() async {
    if (!_client.isConnected) {
      _error = 'Not connected to server';
      return;
    }

    try {
      _error = null;
      final response = await _client.connections.list(
        Empty(),
        options: _client.callOptions,
      );

      _connections = response.connections
          .map((conn) => fromProtoConnection(conn))
          .toList();
      _loaded = true;
      notifyListeners();
    } on GrpcError catch (e) {
      _error = 'gRPC error: ${e.message}';
      debugPrint('Failed to load connections: $e');
    } catch (e) {
      _error = 'Error: $e';
      debugPrint('Failed to load connections: $e');
    }
  }

  /// Create a new connection on server.
  Future<ConnectionConfig?> create(ConnectionConfig config) async {
    if (!_client.isConnected) {
      _error = 'Not connected to server';
      return null;
    }

    try {
      _error = null;
      final response = await _client.connections.create(
        toCreateRequest(config),
        options: _client.callOptions,
      );

      final created = fromProtoConnection(response);
      _connections.add(created);
      notifyListeners();
      return created;
    } on GrpcError catch (e) {
      _error = 'gRPC error: ${e.message}';
      debugPrint('Failed to create connection: $e');
      return null;
    } catch (e) {
      _error = 'Error: $e';
      debugPrint('Failed to create connection: $e');
      return null;
    }
  }

  /// Update an existing connection on server.
  Future<ConnectionConfig?> update(ConnectionConfig config) async {
    if (!_client.isConnected) {
      _error = 'Not connected to server';
      return null;
    }

    try {
      _error = null;
      final response = await _client.connections.update(
        toUpdateRequest(config),
        options: _client.callOptions,
      );

      final updated = fromProtoConnection(response);
      final index = _connections.indexWhere((c) => c.id == updated.id);
      if (index >= 0) {
        _connections[index] = updated;
      }
      notifyListeners();
      return updated;
    } on GrpcError catch (e) {
      _error = 'gRPC error: ${e.message}';
      debugPrint('Failed to update connection: $e');
      return null;
    } catch (e) {
      _error = 'Error: $e';
      debugPrint('Failed to update connection: $e');
      return null;
    }
  }

  /// Delete a connection from server.
  Future<bool> delete(String id) async {
    if (!_client.isConnected) {
      _error = 'Not connected to server';
      return false;
    }

    try {
      _error = null;
      await _client.connections.delete(
        DeleteConnectionRequest(id: id),
        options: _client.callOptions,
      );

      _connections.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } on GrpcError catch (e) {
      _error = 'gRPC error: ${e.message}';
      debugPrint('Failed to delete connection: $e');
      return false;
    } catch (e) {
      _error = 'Error: $e';
      debugPrint('Failed to delete connection: $e');
      return false;
    }
  }

  /// Get connection by ID.
  ConnectionConfig? getById(String id) {
    try {
      return _connections.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Convert local ConnectionConfig to proto Connection.
  static Connection toProtoConnection(ConnectionConfig config) {
    final conn = Connection(
      id: config.id,
      name: config.name,
      host: config.host,
      port: config.port,
      username: config.username,
    );

    if (config.startupCommand != null) {
      conn.startupCommand = config.startupCommand!;
    }

    return conn;
  }

  /// Convert proto Connection to local ConnectionConfig.
  static ConnectionConfig fromProtoConnection(Connection proto) {
    return ConnectionConfig(
      id: proto.id,
      name: proto.name,
      host: proto.host,
      port: proto.port == 0 ? 22 : proto.port,
      username: proto.username,
      startupCommand: proto.hasStartupCommand() && proto.startupCommand.isNotEmpty
          ? proto.startupCommand
          : null,
    );
  }

  /// Create proto CreateConnectionRequest from ConnectionConfig.
  static CreateConnectionRequest toCreateRequest(ConnectionConfig config) {
    final request = CreateConnectionRequest(
      name: config.name,
      host: config.host,
      port: config.port,
      username: config.username,
    );

    if (config.startupCommand != null) {
      request.startupCommand = config.startupCommand!;
    }

    return request;
  }

  /// Create proto UpdateConnectionRequest from ConnectionConfig.
  static UpdateConnectionRequest toUpdateRequest(ConnectionConfig config) {
    final request = UpdateConnectionRequest(
      id: config.id,
      name: config.name,
      host: config.host,
      port: config.port,
      username: config.username,
    );

    if (config.startupCommand != null) {
      request.startupCommand = config.startupCommand!;
    }

    return request;
  }
}
