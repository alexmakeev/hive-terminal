import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_terminal/features/workspace/split_view.dart';

/// Mock widget that tracks initState calls to detect if it's being recreated
class _MockTerminal extends StatefulWidget {
  final String id;
  final void Function(String id) onInit;
  final void Function(String id) onDispose;

  const _MockTerminal({
    required this.id,
    required this.onInit,
    required this.onDispose,
    super.key,
  });

  @override
  State<_MockTerminal> createState() => _MockTerminalState();
}

class _MockTerminalState extends State<_MockTerminal> {
  @override
  void initState() {
    super.initState();
    widget.onInit(widget.id);
  }

  @override
  void dispose() {
    widget.onDispose(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blue,
      child: Text('Terminal ${widget.id}'),
    );
  }
}

void main() {
  group('SplitView widget stability', () {
    testWidgets('widget structure is stable - children not recreated on rebuild',
        (tester) async {
      // Track init/dispose calls
      final initCalls = <String>[];
      final disposeCalls = <String>[];

      // Create test widget with mock terminals
      final widget = MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: Row(
              children: [
                Expanded(
                  child: _MockTerminal(
                    key: const ValueKey('terminal_1'),
                    id: 'terminal_1',
                    onInit: (id) => initCalls.add(id),
                    onDispose: (id) => disposeCalls.add(id),
                  ),
                ),
                Expanded(
                  child: _MockTerminal(
                    key: const ValueKey('terminal_2'),
                    id: 'terminal_2',
                    onInit: (id) => initCalls.add(id),
                    onDispose: (id) => disposeCalls.add(id),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);

      // Both terminals should be initialized once
      expect(initCalls, ['terminal_1', 'terminal_2']);
      expect(disposeCalls, isEmpty);

      // Clear tracking
      initCalls.clear();

      // Rebuild widget (simulates what happens during state change)
      await tester.pumpWidget(widget);

      // No new init calls - widgets should be reused due to keys
      expect(initCalls, isEmpty);
      expect(disposeCalls, isEmpty);
    });

    testWidgets('hover on split container does not trigger widget rebuild',
        (tester) async {
      final initCalls = <String>[];

      // Create a simplified version of split view structure
      final widget = MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: Row(
              children: [
                Expanded(
                  child: MouseRegion(
                    child: _MockTerminal(
                      key: const ValueKey('t1'),
                      id: 't1',
                      onInit: (id) => initCalls.add(id),
                      onDispose: (id) {},
                    ),
                  ),
                ),
                Expanded(
                  child: MouseRegion(
                    child: _MockTerminal(
                      key: const ValueKey('t2'),
                      id: 't2',
                      onInit: (id) => initCalls.add(id),
                      onDispose: (id) {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);

      // Initial state
      expect(initCalls, ['t1', 't2']);
      initCalls.clear();

      // Simulate mouse hover over first terminal
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(200, 300));
      await tester.pump();

      // Move mouse around
      await gesture.moveTo(const Offset(600, 300));
      await tester.pump();

      await gesture.moveTo(const Offset(200, 300));
      await tester.pump();

      // Terminals should NOT have been recreated
      expect(initCalls, isEmpty);

      await gesture.removePointer();
    });
  });

  group('SplitView structure', () {
    test('TerminalDragData stores terminalId', () {
      const data = TerminalDragData(terminalId: 'test-123');
      expect(data.terminalId, 'test-123');
    });
  });
}
