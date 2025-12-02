import 'package:flutter_test/flutter_test.dart';
import 'package:hive_terminal/core/hive/hive_terminal_service.dart';
import 'package:hive_terminal/src/generated/hive.pbgrpc.dart';

void main() {
  group('HiveTerminalService', () {
    group('TerminalInput creation', () {
      test('createDataInput creates input with session id and data', () {
        final input = HiveTerminalService.createDataInput(
          sessionId: 'sess-123',
          data: [65, 66, 67], // "ABC"
        );

        expect(input.sessionId, 'sess-123');
        expect(input.data, [65, 66, 67]);
        expect(input.whichPayload(), TerminalInput_Payload.data);
      });

      test('createResizeInput creates input with dimensions', () {
        final input = HiveTerminalService.createResizeInput(
          sessionId: 'sess-456',
          cols: 120,
          rows: 40,
        );

        expect(input.sessionId, 'sess-456');
        expect(input.resize.cols, 120);
        expect(input.resize.rows, 40);
        expect(input.whichPayload(), TerminalInput_Payload.resize);
      });
    });

    group('TerminalOutput parsing', () {
      test('isData returns true for data output', () {
        final output = TerminalOutput(data: [72, 101, 108, 108, 111]); // "Hello"

        expect(HiveTerminalService.isData(output), isTrue);
        expect(HiveTerminalService.isScrollback(output), isFalse);
        expect(HiveTerminalService.isError(output), isFalse);
        expect(HiveTerminalService.isClosed(output), isFalse);
      });

      test('isScrollback returns true for scrollback output', () {
        final output = TerminalOutput(scrollback: [27, 91, 72]); // ESC[H

        expect(HiveTerminalService.isScrollback(output), isTrue);
        expect(HiveTerminalService.isData(output), isFalse);
      });

      test('isError returns true for error output', () {
        final output = TerminalOutput(
          error: Error(code: 'AUTH_FAILED', message: 'Invalid key'),
        );

        expect(HiveTerminalService.isError(output), isTrue);
        expect(HiveTerminalService.isData(output), isFalse);
      });

      test('isClosed returns true for closed output', () {
        final output = TerminalOutput(
          closed: SessionClosed(sessionId: 'sess-123', reason: 'User exit'),
        );

        expect(HiveTerminalService.isClosed(output), isTrue);
        expect(HiveTerminalService.isData(output), isFalse);
      });
    });
  });
}
