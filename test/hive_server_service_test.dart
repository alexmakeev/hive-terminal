import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hive_terminal/core/hive/hive_server_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HiveServerService', () {
    late HiveServerService service;
    late InMemorySecureStorage secureStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      secureStorage = InMemorySecureStorage();
      service = HiveServerService(secureStorage: secureStorage);
    });

    tearDown(() async {
      await service.disconnect();
    });

    group('configuration', () {
      test('default values are null', () async {
        await service.load();
        expect(service.serverHost, isNull);
        expect(service.serverPort, isNull);
        expect(service.isConfigured, isFalse);
      });

      test('setServerConfig saves host and port', () async {
        await service.load();
        await service.setServerConfig('example.com', 50051);
        expect(service.serverHost, equals('example.com'));
        expect(service.serverPort, equals(50051));
        expect(service.isConfigured, isTrue);
      });

      test('clearServerConfig removes host and port', () async {
        await service.load();
        await service.setServerConfig('example.com', 50051);
        expect(service.isConfigured, isTrue);
        await service.clearServerConfig();
        expect(service.serverHost, isNull);
        expect(service.serverPort, isNull);
        expect(service.isConfigured, isFalse);
      });

      test('configuration persists across instances', () async {
        await service.load();
        await service.setServerConfig('myserver.local', 9000);

        // Create new instance with same secure storage
        final service2 = HiveServerService(secureStorage: secureStorage);
        await service2.load();
        expect(service2.serverHost, equals('myserver.local'));
        expect(service2.serverPort, equals(9000));
      });
    });

    group('connection state', () {
      test('isConnected is false initially', () async {
        await service.load();
        expect(service.isConnected, isFalse);
      });

      test('isAuthenticated is false initially', () async {
        await service.load();
        expect(service.isAuthenticated, isFalse);
      });
    });

    group('api key', () {
      test('hasApiKey is false when not set', () async {
        await service.load();
        expect(service.hasApiKey, isFalse);
      });

      test('hasApiKey is true after setting key', () async {
        await service.load();
        await service.setApiKey('test-api-key-123');
        expect(service.hasApiKey, isTrue);
      });

      test('clearApiKey removes the key', () async {
        await service.load();
        await service.setApiKey('test-api-key');
        expect(service.hasApiKey, isTrue);
        await service.clearApiKey();
        expect(service.hasApiKey, isFalse);
      });
    });

    group('notifyListeners', () {
      test('notifies on config change', () async {
        await service.load();
        var notified = false;
        service.addListener(() => notified = true);
        await service.setServerConfig('test.com', 1234);
        expect(notified, isTrue);
      });

      test('notifies on api key change', () async {
        await service.load();
        var notified = false;
        service.addListener(() => notified = true);
        await service.setApiKey('key');
        expect(notified, isTrue);
      });
    });
  });
}
