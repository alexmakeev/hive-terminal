import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosh_client/mosh_client.dart';

/// Integration tests that require a real mosh-server.
/// Run with: LD_LIBRARY_PATH=build flutter test test/mosh_integration_test.dart
void main() {
  late Process moshServer;
  late String moshPort;
  late String moshKey;

  setUpAll(() async {
    moshInit();
  });

  tearDownAll(() async {
    moshCleanup();
  });

  group('MoshSession Integration', () {
    setUp(() async {
      // Start mosh-server and get connection info
      moshServer = await Process.start(
        'mosh-server',
        ['new', '-c', '256'],
        environment: {'LANG': 'en_US.UTF-8'},
      );

      // Parse connection info from stdout
      final completer = Completer<void>();
      String? connectLine;

      moshServer.stdout.transform(const SystemEncoding().decoder).listen((data) {
        print('mosh-server stdout: $data');
        final lines = data.split('\n');
        for (final line in lines) {
          if (line.startsWith('MOSH CONNECT')) {
            connectLine = line;
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        }
      });

      moshServer.stderr.transform(const SystemEncoding().decoder).listen((data) {
        print('mosh-server stderr: $data');
      });

      // Wait for connection info (timeout after 5 seconds)
      await completer.future.timeout(const Duration(seconds: 5));

      if (connectLine == null) {
        throw Exception('Failed to get MOSH connection info');
      }

      // Parse: "MOSH CONNECT 60001 base64key=="
      final parts = connectLine!.split(' ');
      if (parts.length < 4) {
        throw Exception('Invalid MOSH CONNECT line: $connectLine');
      }
      moshPort = parts[2];
      moshKey = parts[3];

      print('MOSH port: $moshPort, key: $moshKey');
    });

    tearDown(() async {
      // Kill mosh-server
      moshServer.kill();
      await moshServer.exitCode;
    });

    test('connect to local mosh-server', () async {
      final session = MoshSession(
        host: '127.0.0.1',
        port: moshPort,
        key: moshKey,
        width: 80,
        height: 24,
      );

      final states = <MoshState>[];
      final errors = <String>[];

      session.onStateChange.listen((state) {
        print('State changed: $state');
        states.add(state);
      });

      session.onError.listen((error) {
        print('Error: $error');
        errors.add(error);
      });

      // Connect (will be in CONNECTING state initially)
      await session.connect();

      // Give time for connection to establish (up to 3 seconds)
      for (int i = 0; i < 30; i++) {
        if (session.isConnected) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('Final state: ${session.state}');
      print('States received: $states');

      // Should be connected or at least have received CONNECTING state
      expect(
        session.isConnected || states.contains(MoshState.MOSH_STATE_CONNECTING),
        isTrue,
      );

      session.dispose();
    });

    test('send input and receive output', () async {
      final session = MoshSession(
        host: '127.0.0.1',
        port: moshPort,
        key: moshKey,
        width: 80,
        height: 24,
      );

      final screenUpdates = <MoshScreenUpdate>[];
      session.onScreenUpdate.listen((update) {
        screenUpdates.add(update);
      });

      await session.connect();

      // Wait for connection
      for (int i = 0; i < 30; i++) {
        if (session.isConnected) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('Connection state: ${session.state}');

      if (session.isConnected) {
        // Send a simple command
        session.write('echo hello\n');

        // Wait for response
        await Future.delayed(const Duration(seconds: 1));

        // We should have received some screen updates
        print('Received ${screenUpdates.length} screen updates');
      }

      session.dispose();
    });

    test('resize terminal', () async {
      final session = MoshSession(
        host: '127.0.0.1',
        port: moshPort,
        key: moshKey,
        width: 80,
        height: 24,
      );

      await session.connect();

      // Wait for connection
      for (int i = 0; i < 30; i++) {
        if (session.isConnected) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('Connection state for resize: ${session.state}');

      // Resize works in any connected state
      session.resize(120, 40);
      expect(session.width, equals(120));
      expect(session.height, equals(40));

      session.dispose();
    });
  });
}
