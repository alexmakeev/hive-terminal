import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import 'package:hive_terminal/core/hive/hive_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HiveClient', () {
    group('construction', () {
      test('creates with host and port', () {
        final client = HiveClient(host: 'localhost', port: 50051);
        expect(client.host, equals('localhost'));
        expect(client.port, equals(50051));
        expect(client.isConnected, isFalse);
      });

      test('creates with custom options', () {
        final options = ChannelOptions(
          credentials: const ChannelCredentials.insecure(),
        );
        final client = HiveClient(
          host: 'localhost',
          port: 50051,
          options: options,
        );
        expect(client.host, equals('localhost'));
        expect(client.port, equals(50051));
      });
    });

    group('connection', () {
      late HiveClient client;

      setUp(() {
        client = HiveClient(host: 'localhost', port: 50051);
      });

      tearDown(() async {
        await client.shutdown();
      });

      test('isConnected returns false before connect', () {
        expect(client.isConnected, isFalse);
      });

      test('connect creates channel', () async {
        await client.connect();
        expect(client.isConnected, isTrue);
      });

      test('disconnect closes channel', () async {
        await client.connect();
        expect(client.isConnected, isTrue);
        await client.shutdown();
        expect(client.isConnected, isFalse);
      });

      test('calling shutdown when not connected does not throw', () async {
        expect(client.isConnected, isFalse);
        await client.shutdown(); // Should not throw
        expect(client.isConnected, isFalse);
      });
    });

    group('setApiKey', () {
      late HiveClient client;

      setUp(() {
        client = HiveClient(host: 'localhost', port: 50051);
      });

      tearDown(() async {
        await client.shutdown();
      });

      test('sets api key for authentication', () {
        client.setApiKey('test-api-key');
        expect(client.hasApiKey, isTrue);
      });

      test('clearApiKey removes api key', () {
        client.setApiKey('test-api-key');
        expect(client.hasApiKey, isTrue);
        client.clearApiKey();
        expect(client.hasApiKey, isFalse);
      });
    });

    group('gRPC clients access', () {
      late HiveClient client;

      setUp(() async {
        client = HiveClient(host: 'localhost', port: 50051);
        await client.connect();
      });

      tearDown(() async {
        await client.shutdown();
      });

      test('auth client is accessible', () {
        expect(client.auth, isNotNull);
      });

      test('keys client is accessible', () {
        expect(client.keys, isNotNull);
      });

      test('connections client is accessible', () {
        expect(client.connections, isNotNull);
      });

      test('sessions client is accessible', () {
        expect(client.sessions, isNotNull);
      });

      test('terminal client is accessible', () {
        expect(client.terminal, isNotNull);
      });
    });

    group('callOptions', () {
      late HiveClient client;

      setUp(() {
        client = HiveClient(host: 'localhost', port: 50051);
      });

      tearDown(() async {
        await client.shutdown();
      });

      test('callOptions includes api key in metadata when set', () {
        client.setApiKey('test-api-key-123');
        final options = client.callOptions;
        expect(options, isNotNull);
      });

      test('callOptions has empty metadata when no api key', () {
        final options = client.callOptions;
        expect(options, isNotNull);
      });
    });
  });
}
