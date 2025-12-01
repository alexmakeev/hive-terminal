import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ssh_session.dart';

/// Repository for managing saved connections
class ConnectionRepository extends ChangeNotifier {
  static const String _connectionsKey = 'saved_connections';
  static const String _orderKey = 'connections_order';

  final FlutterSecureStorage _secureStorage;
  List<ConnectionConfig> _connections = [];
  bool _loaded = false;

  ConnectionRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  List<ConnectionConfig> get connections => List.unmodifiable(_connections);
  bool get isLoaded => _loaded;

  /// Load all saved connections
  Future<void> load() async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load connection order
      final orderJson = prefs.getStringList(_orderKey) ?? [];

      // Load connection configs
      final connectionsJson = prefs.getString(_connectionsKey);
      if (connectionsJson != null) {
        final List<dynamic> list = json.decode(connectionsJson);
        final loadedConnections = <ConnectionConfig>[];

        for (final item in list) {
          try {
            final config = ConnectionConfig.fromJson(item as Map<String, dynamic>);
            // Load secure credentials
            final configWithCreds = await _loadCredentials(config);
            loadedConnections.add(configWithCreds);
          } catch (e) {
            debugPrint('Failed to load connection: $e');
          }
        }

        // Sort by saved order
        if (orderJson.isNotEmpty) {
          loadedConnections.sort((a, b) {
            final aIndex = orderJson.indexOf(a.id);
            final bIndex = orderJson.indexOf(b.id);
            if (aIndex == -1 && bIndex == -1) return 0;
            if (aIndex == -1) return 1;
            if (bIndex == -1) return -1;
            return aIndex.compareTo(bIndex);
          });
        }

        _connections = loadedConnections;
      }

      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading connections: $e');
      _loaded = true;
    }
  }

  /// Save a new connection or update existing
  Future<void> save(ConnectionConfig config) async {
    final existingIndex = _connections.indexWhere((c) => c.id == config.id);

    if (existingIndex >= 0) {
      _connections[existingIndex] = config;
    } else {
      _connections.add(config);
    }

    await _persist();
    await _saveCredentials(config);
    notifyListeners();
  }

  /// Delete a connection
  Future<void> delete(String id) async {
    _connections.removeWhere((c) => c.id == id);
    await _deleteCredentials(id);
    await _persist();
    notifyListeners();
  }

  /// Reorder connections (for drag-and-drop)
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _connections.removeAt(oldIndex);
    _connections.insert(newIndex, item);
    await _persist();
    notifyListeners();
  }

  /// Get connection by ID
  ConnectionConfig? getById(String id) {
    try {
      return _connections.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Persist connections to storage
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();

    // Save configs (without sensitive data)
    final connectionsJson = json.encode(
      _connections.map((c) => c.toJson()).toList(),
    );
    await prefs.setString(_connectionsKey, connectionsJson);

    // Save order
    await prefs.setStringList(
      _orderKey,
      _connections.map((c) => c.id).toList(),
    );
  }

  /// Load credentials from secure storage
  Future<ConnectionConfig> _loadCredentials(ConnectionConfig config) async {
    String? password;
    String? privateKey;
    String? passphrase;

    debugPrint('[LOAD] Loading credentials for ${config.name} (${config.id})');

    try {
      password = await _secureStorage.read(key: '${config.id}_password');
      debugPrint('[LOAD] password=${password != null ? "${password.length}ch" : "null"}');

      privateKey = await _secureStorage.read(key: '${config.id}_privateKey');
      debugPrint('[LOAD] privateKey=${privateKey != null ? "${privateKey.length}ch" : "null"}');

      passphrase = await _secureStorage.read(key: '${config.id}_passphrase');
      debugPrint('[LOAD] passphrase=${passphrase != null ? "set" : "null"}');
    } catch (e, stack) {
      debugPrint('[LOAD] ERROR: $e');
      debugPrint('[LOAD] Stack: $stack');
    }

    return ConnectionConfig(
      id: config.id,
      name: config.name,
      host: config.host,
      port: config.port,
      username: config.username,
      password: password,
      privateKey: privateKey,
      passphrase: passphrase,
      startupCommand: config.startupCommand,
      useDefaultKeys: config.useDefaultKeys,
      protocol: config.protocol,
    );
  }

  /// Save credentials to secure storage
  Future<void> _saveCredentials(ConnectionConfig config) async {
    debugPrint('[SAVE] ${config.name} (${config.id}): '
        'password=${config.password != null ? "${config.password!.length}ch" : "null"}, '
        'privateKey=${config.privateKey != null ? "${config.privateKey!.length}ch" : "null"}, '
        'passphrase=${config.passphrase != null ? "set" : "null"}');

    try {
      if (config.password != null) {
        await _secureStorage.write(
          key: '${config.id}_password',
          value: config.password,
        );
        debugPrint('[SAVE] password written');
      } else {
        await _secureStorage.delete(key: '${config.id}_password');
      }

      if (config.privateKey != null) {
        await _secureStorage.write(
          key: '${config.id}_privateKey',
          value: config.privateKey,
        );
        debugPrint('[SAVE] privateKey written');
      } else {
        await _secureStorage.delete(key: '${config.id}_privateKey');
      }

      if (config.passphrase != null) {
        await _secureStorage.write(
          key: '${config.id}_passphrase',
          value: config.passphrase,
        );
        debugPrint('[SAVE] passphrase written');
      } else {
        await _secureStorage.delete(key: '${config.id}_passphrase');
      }

      // Verify save by reading back
      final verifyKey = await _secureStorage.read(key: '${config.id}_privateKey');
      debugPrint('[SAVE] verify: privateKey=${verifyKey != null ? "${verifyKey.length}ch" : "null"}');
    } catch (e, stack) {
      debugPrint('[SAVE] ERROR: $e');
      debugPrint('[SAVE] Stack: $stack');
    }
  }

  /// Delete credentials from secure storage
  Future<void> _deleteCredentials(String id) async {
    try {
      await _secureStorage.delete(key: '${id}_password');
      await _secureStorage.delete(key: '${id}_privateKey');
      await _secureStorage.delete(key: '${id}_passphrase');
    } catch (e) {
      debugPrint('Failed to delete credentials: $e');
    }
  }
}
