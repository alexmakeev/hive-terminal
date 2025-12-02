import 'package:flutter_test/flutter_test.dart';
import 'package:hive_terminal/core/hive/hive_connections_service.dart';
import 'package:hive_terminal/features/connection/connection_config.dart';
import 'package:hive_terminal/src/generated/hive.pbgrpc.dart';

void main() {
  group('HiveConnectionsService', () {
    group('toProtoConnection', () {
      test('converts ConnectionConfig to proto Connection', () {
        final config = ConnectionConfig(
          id: 'test-id',
          name: 'Test Server',
          host: 'example.com',
          port: 2222,
          username: 'admin',
          startupCommand: 'tmux attach',
        );

        final proto = HiveConnectionsService.toProtoConnection(config);

        expect(proto.id, 'test-id');
        expect(proto.name, 'Test Server');
        expect(proto.host, 'example.com');
        expect(proto.port, 2222);
        expect(proto.username, 'admin');
        expect(proto.startupCommand, 'tmux attach');
      });

      test('handles null optional fields', () {
        final config = ConnectionConfig(
          id: 'test-id',
          name: 'Test',
          host: 'localhost',
          username: 'user',
        );

        final proto = HiveConnectionsService.toProtoConnection(config);

        expect(proto.id, 'test-id');
        expect(proto.port, 22); // default port
        expect(proto.hasStartupCommand(), isFalse);
      });
    });

    group('fromProtoConnection', () {
      test('converts proto Connection to ConnectionConfig', () {
        final proto = Connection(
          id: 'proto-id',
          name: 'Proto Server',
          host: 'proto.example.com',
          port: 3333,
          username: 'protouser',
          sshKeyId: 'key-123',
          startupCommand: 'htop',
          createdAt: '2024-01-01T00:00:00Z',
        );

        final config = HiveConnectionsService.fromProtoConnection(proto);

        expect(config.id, 'proto-id');
        expect(config.name, 'Proto Server');
        expect(config.host, 'proto.example.com');
        expect(config.port, 3333);
        expect(config.username, 'protouser');
        expect(config.startupCommand, 'htop');
      });

      test('handles empty optional fields', () {
        final proto = Connection(
          id: 'proto-id',
          name: 'Minimal',
          host: 'localhost',
          port: 22,
          username: 'user',
        );

        final config = HiveConnectionsService.fromProtoConnection(proto);

        expect(config.id, 'proto-id');
        expect(config.startupCommand, isNull);
      });

      test('handles zero port as default 22', () {
        final proto = Connection(
          id: 'test',
          name: 'Test',
          host: 'localhost',
          port: 0, // protobuf default for int32
          username: 'user',
        );

        final config = HiveConnectionsService.fromProtoConnection(proto);

        expect(config.port, 22);
      });
    });

    group('toCreateRequest', () {
      test('creates CreateConnectionRequest from ConnectionConfig', () {
        final config = ConnectionConfig(
          id: 'ignored-id', // id is ignored for create
          name: 'New Server',
          host: 'new.example.com',
          port: 4444,
          username: 'newuser',
          startupCommand: 'bash',
        );

        final request = HiveConnectionsService.toCreateRequest(config);

        expect(request.name, 'New Server');
        expect(request.host, 'new.example.com');
        expect(request.port, 4444);
        expect(request.username, 'newuser');
        expect(request.startupCommand, 'bash');
        // id is not in CreateConnectionRequest - server generates it
      });
    });

    group('toUpdateRequest', () {
      test('creates UpdateConnectionRequest from ConnectionConfig', () {
        final config = ConnectionConfig(
          id: 'update-id',
          name: 'Updated Server',
          host: 'updated.example.com',
          port: 5555,
          username: 'updateduser',
          startupCommand: 'zsh',
        );

        final request = HiveConnectionsService.toUpdateRequest(config);

        expect(request.id, 'update-id');
        expect(request.name, 'Updated Server');
        expect(request.host, 'updated.example.com');
        expect(request.port, 5555);
        expect(request.username, 'updateduser');
        expect(request.startupCommand, 'zsh');
      });
    });
  });
}
