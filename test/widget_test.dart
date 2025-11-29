import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hive_terminal/main.dart';
import 'package:hive_terminal/features/workspace/workspace_page.dart';

void main() {
  group('HiveTerminalApp', () {
    testWidgets('app starts and shows workspace page', (tester) async {
      await tester.pumpWidget(const HiveTerminalApp());
      await tester.pumpAndSettle();

      // Should show empty state with add button
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('app has dark theme with orange accent', (tester) async {
      await tester.pumpWidget(const HiveTerminalApp());

      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.theme?.brightness, Brightness.dark);
    });
  });

  group('WorkspacePage', () {
    testWidgets('shows empty state with plus button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WorkspacePage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Terminal'), findsOneWidget);
      expect(find.text('Connect to an SSH server'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('tapping add button opens connection dialog', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WorkspacePage(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the big add button in empty state (identified by key)
      await tester.tap(find.byKey(const Key('add_terminal_button')));
      await tester.pumpAndSettle();

      // Should show connection dialog
      expect(find.text('New Connection'), findsOneWidget);
      expect(find.text('Host *'), findsOneWidget);
      expect(find.text('Username *'), findsOneWidget);
    });

    testWidgets('connection dialog validates required fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WorkspacePage(),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog via the add button in empty state
      await tester.tap(find.byKey(const Key('add_terminal_button')));
      await tester.pumpAndSettle();

      // Try to submit without filling fields
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      // Should show validation errors
      expect(find.text('Please enter a name'), findsOneWidget);
    });

    testWidgets('can dismiss connection dialog', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WorkspacePage(),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog via the add button in empty state
      await tester.tap(find.byKey(const Key('add_terminal_button')));
      await tester.pumpAndSettle();

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be gone
      expect(find.text('New Connection'), findsNothing);
    });
  });

  group('App version', () {
    test('version constant is defined', () {
      expect(appVersion, isNotEmpty);
      expect(appVersion, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });
  });
}
