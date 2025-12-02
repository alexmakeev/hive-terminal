import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../src/generated/hive.pb.dart';
import 'hive_client.dart';

/// Abstract interface for secure storage (allows testing)
abstract class SecureStorage {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

/// Real implementation using FlutterSecureStorage
class FlutterSecureStorageAdapter implements SecureStorage {
  final FlutterSecureStorage _storage;

  FlutterSecureStorageAdapter([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

/// In-memory implementation for testing
class InMemorySecureStorage implements SecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({required String key}) async => _storage[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _storage.remove(key);
  }
}

/// Service for managing Hive Server connection and authentication.
///
/// Stores server configuration in SharedPreferences and API key
/// securely in flutter_secure_storage.
class HiveServerService extends ChangeNotifier {
  static const String _serverHostKey = 'hive_server_host';
  static const String _serverPortKey = 'hive_server_port';
  static const String _apiKeyStorageKey = 'hive_api_key';

  final SecureStorage _secureStorage;

  String? _serverHost;
  int? _serverPort;
  bool _hasApiKey = false;
  bool _loaded = false;

  HiveClient? _client;

  HiveServerService({SecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? FlutterSecureStorageAdapter();

  /// Server host (e.g., "localhost" or "hive.example.com")
  String? get serverHost => _serverHost;

  /// Server port (e.g., 50051)
  int? get serverPort => _serverPort;

  /// Whether server configuration is complete (host and port are set)
  bool get isConfigured => _serverHost != null && _serverPort != null;

  /// Whether an API key is stored
  bool get hasApiKey => _hasApiKey;

  /// Whether settings have been loaded
  bool get isLoaded => _loaded;

  /// Whether connected to the server
  bool get isConnected => _client?.isConnected ?? false;

  /// Whether authenticated (connected and has valid API key)
  bool get isAuthenticated => isConnected && _hasApiKey;

  /// The underlying HiveClient
  HiveClient? get client => _client;

  /// Load settings from storage
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _serverHost = prefs.getString(_serverHostKey);
    _serverPort = prefs.getInt(_serverPortKey);

    // Check if API key exists
    final apiKey = await _secureStorage.read(key: _apiKeyStorageKey);
    _hasApiKey = apiKey != null && apiKey.isNotEmpty;

    _loaded = true;
    notifyListeners();
  }

  /// Set server configuration
  Future<void> setServerConfig(String host, int port) async {
    _serverHost = host;
    _serverPort = port;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverHostKey, host);
    await prefs.setInt(_serverPortKey, port);

    notifyListeners();
  }

  /// Clear server configuration
  Future<void> clearServerConfig() async {
    _serverHost = null;
    _serverPort = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverHostKey);
    await prefs.remove(_serverPortKey);

    await disconnect();
    notifyListeners();
  }

  /// Set API key (stored securely)
  Future<void> setApiKey(String apiKey) async {
    await _secureStorage.write(key: _apiKeyStorageKey, value: apiKey);
    _hasApiKey = true;

    // Update client if connected
    _client?.setApiKey(apiKey);

    notifyListeners();
  }

  /// Clear API key
  Future<void> clearApiKey() async {
    await _secureStorage.delete(key: _apiKeyStorageKey);
    _hasApiKey = false;

    _client?.clearApiKey();

    notifyListeners();
  }

  /// Get the stored API key (for internal use)
  Future<String?> getApiKey() async {
    return await _secureStorage.read(key: _apiKeyStorageKey);
  }

  /// Connect to the Hive Server
  Future<void> connect() async {
    if (!isConfigured) {
      throw StateError('Server is not configured. Call setServerConfig first.');
    }

    await disconnect();

    _client = HiveClient(
      host: _serverHost!,
      port: _serverPort!,
    );

    await _client!.connect();

    // Set API key if available
    if (_hasApiKey) {
      final apiKey = await getApiKey();
      if (apiKey != null) {
        _client!.setApiKey(apiKey);
      }
    }

    notifyListeners();
  }

  /// Disconnect from the server
  Future<void> disconnect() async {
    if (_client != null) {
      await _client!.shutdown();
      _client = null;
      notifyListeners();
    }
  }

  /// Validate API key with the server
  Future<bool> validateApiKey(String apiKey) async {
    if (!isConnected) {
      throw StateError('Not connected to server. Call connect first.');
    }

    try {
      final request = ApiKeyRequest()..apiKey = apiKey;
      final response = await _client!.auth.validateApiKey(
        request,
        options: _client!.callOptions,
      );
      return response.valid;
    } catch (e) {
      debugPrint('Failed to validate API key: $e');
      return false;
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
