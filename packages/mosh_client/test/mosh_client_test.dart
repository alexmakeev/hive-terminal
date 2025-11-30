import 'package:flutter_test/flutter_test.dart';
import 'package:mosh_client/mosh_client.dart';

void main() {
  group('MOSH Library', () {
    test('isMoshAvailable returns boolean', () {
      final available = isMoshAvailable;
      expect(available, isA<bool>());
    });

    test('moshVersion returns non-empty string', () {
      final version = moshVersion;
      expect(version, isA<String>());
      expect(version, isNotEmpty);
      print('MOSH version: $version');
    });

    test('moshInit succeeds', () {
      expect(() => moshInit(), returnsNormally);
    });

    test('moshCleanup succeeds', () {
      expect(() => moshCleanup(), returnsNormally);
    });

    test('multiple init/cleanup cycles work', () {
      for (var i = 0; i < 3; i++) {
        moshInit();
        moshCleanup();
      }
    });
  });

  group('MoshSession', () {
    setUp(() {
      moshInit();
    });

    tearDown(() {
      moshCleanup();
    });

    test('creation with valid parameters', () {
      final session = MoshSession(
        host: 'localhost',
        port: '60001',
        key: 'dGVzdGtleQ==', // base64 "testkey"
        width: 80,
        height: 24,
      );

      expect(session.host, equals('localhost'));
      expect(session.port, equals('60001'));
      expect(session.key, equals('dGVzdGtleQ=='));
      expect(session.width, equals(80));
      expect(session.height, equals(24));
      expect(session.state, equals(MoshState.MOSH_STATE_DISCONNECTED));
      expect(session.isConnected, isFalse);

      session.dispose();
    });

    test('default width and height', () {
      final session = MoshSession(
        host: 'localhost',
        port: '60001',
        key: 'dGVzdGtleQ==',
      );

      expect(session.width, equals(80));
      expect(session.height, equals(24));

      session.dispose();
    });

    test('state is disconnected before connect', () {
      final session = MoshSession(
        host: 'localhost',
        port: '60001',
        key: 'dGVzdGtleQ==',
      );

      expect(session.state, equals(MoshState.MOSH_STATE_DISCONNECTED));
      expect(session.isConnected, isFalse);

      session.dispose();
    });

    test('write throws when not connected', () {
      final session = MoshSession(
        host: 'localhost',
        port: '60001',
        key: 'dGVzdGtleQ==',
      );

      expect(
        () => session.write('test'),
        throwsA(isA<MoshException>()),
      );

      session.dispose();
    });

    test('resize updates dimensions', () {
      final session = MoshSession(
        host: 'localhost',
        port: '60001',
        key: 'dGVzdGtleQ==',
      );

      session.resize(120, 40);
      expect(session.width, equals(120));
      expect(session.height, equals(40));

      session.dispose();
    });

    test('multiple dispose calls are safe', () {
      final session = MoshSession(
        host: 'localhost',
        port: '60001',
        key: 'dGVzdGtleQ==',
      );

      session.dispose();
      session.dispose(); // Should not throw
    });

    test('streams are accessible', () {
      final session = MoshSession(
        host: 'localhost',
        port: '60001',
        key: 'dGVzdGtleQ==',
      );

      expect(session.onScreenUpdate, isA<Stream<MoshScreenUpdate>>());
      expect(session.onError, isA<Stream<String>>());
      expect(session.onStateChange, isA<Stream<MoshState>>());

      session.dispose();
    });
  });

  group('MoshException', () {
    test('message only constructor', () {
      final exception = MoshException('Test error');
      expect(exception.message, equals('Test error'));
      expect(exception.errorCode, isNull);
      expect(exception.toString(), equals('MoshException: Test error'));
    });

    test('message with error code constructor', () {
      final exception = MoshException(
        'Network error',
        MoshResult.MOSH_ERROR_NETWORK,
      );
      expect(exception.message, equals('Network error'));
      expect(exception.errorCode, equals(MoshResult.MOSH_ERROR_NETWORK));
      expect(
        exception.toString(),
        equals('MoshException: Network error (MOSH_ERROR_NETWORK)'),
      );
    });
  });

  group('MoshCellData', () {
    test('creation and character getter', () {
      final cell = MoshCellData(
        codepoint: 65, // 'A'
        foreground: 7,
        background: 0,
        bold: true,
        underline: false,
        blink: false,
        inverse: false,
      );

      expect(cell.codepoint, equals(65));
      expect(cell.character, equals('A'));
      expect(cell.foreground, equals(7));
      expect(cell.background, equals(0));
      expect(cell.bold, isTrue);
      expect(cell.underline, isFalse);
      expect(cell.blink, isFalse);
      expect(cell.inverse, isFalse);
    });

    test('unicode character support', () {
      final cell = MoshCellData(
        codepoint: 0x1F600, // emoji
        foreground: 7,
        background: 0,
        bold: false,
        underline: false,
        blink: false,
        inverse: false,
      );

      expect(cell.character, equals('\u{1F600}'));
    });
  });

  group('MoshScreenUpdate', () {
    test('creation with cells', () {
      final cells = <List<MoshCellData>>[
        [
          MoshCellData(
            codepoint: 65,
            foreground: 7,
            background: 0,
            bold: false,
            underline: false,
            blink: false,
            inverse: false,
          ),
        ],
      ];

      final update = MoshScreenUpdate(
        cells: cells,
        width: 80,
        height: 24,
        cursorX: 0,
        cursorY: 0,
      );

      expect(update.width, equals(80));
      expect(update.height, equals(24));
      expect(update.cursorX, equals(0));
      expect(update.cursorY, equals(0));
      expect(update.cells.length, equals(1));
      expect(update.cells[0].length, equals(1));
      expect(update.cells[0][0].character, equals('A'));
    });
  });

  group('MoshState enum', () {
    test('has all expected values', () {
      expect(MoshState.values.length, equals(4));
      expect(MoshState.MOSH_STATE_DISCONNECTED.value, equals(0));
      expect(MoshState.MOSH_STATE_CONNECTING.value, equals(1));
      expect(MoshState.MOSH_STATE_CONNECTED.value, equals(2));
      expect(MoshState.MOSH_STATE_ERROR.value, equals(3));
    });

    test('fromValue works correctly', () {
      expect(MoshState.fromValue(0), equals(MoshState.MOSH_STATE_DISCONNECTED));
      expect(MoshState.fromValue(1), equals(MoshState.MOSH_STATE_CONNECTING));
      expect(MoshState.fromValue(2), equals(MoshState.MOSH_STATE_CONNECTED));
      expect(MoshState.fromValue(3), equals(MoshState.MOSH_STATE_ERROR));
    });

    test('fromValue throws on invalid value', () {
      expect(() => MoshState.fromValue(99), throwsArgumentError);
    });
  });

  group('MoshResult enum', () {
    test('has all expected values', () {
      expect(MoshResult.values.length, equals(7));
      expect(MoshResult.MOSH_OK.value, equals(0));
      expect(MoshResult.MOSH_ERROR_INVALID_PARAMS.value, equals(-1));
      expect(MoshResult.MOSH_ERROR_CONNECT_FAILED.value, equals(-2));
      expect(MoshResult.MOSH_ERROR_NOT_CONNECTED.value, equals(-3));
      expect(MoshResult.MOSH_ERROR_CRYPTO.value, equals(-4));
      expect(MoshResult.MOSH_ERROR_NETWORK.value, equals(-5));
      expect(MoshResult.MOSH_ERROR_MEMORY.value, equals(-6));
    });

    test('fromValue works correctly', () {
      expect(MoshResult.fromValue(0), equals(MoshResult.MOSH_OK));
      expect(
        MoshResult.fromValue(-1),
        equals(MoshResult.MOSH_ERROR_INVALID_PARAMS),
      );
      expect(
        MoshResult.fromValue(-2),
        equals(MoshResult.MOSH_ERROR_CONNECT_FAILED),
      );
      expect(
        MoshResult.fromValue(-3),
        equals(MoshResult.MOSH_ERROR_NOT_CONNECTED),
      );
      expect(MoshResult.fromValue(-4), equals(MoshResult.MOSH_ERROR_CRYPTO));
      expect(MoshResult.fromValue(-5), equals(MoshResult.MOSH_ERROR_NETWORK));
      expect(MoshResult.fromValue(-6), equals(MoshResult.MOSH_ERROR_MEMORY));
    });

    test('fromValue throws on invalid value', () {
      expect(() => MoshResult.fromValue(99), throwsArgumentError);
    });
  });
}
