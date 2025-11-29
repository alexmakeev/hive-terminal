import 'package:flutter_test/flutter_test.dart';

import 'package:hive_terminal/main.dart';

void main() {
  testWidgets('App shows title and version', (WidgetTester tester) async {
    await tester.pumpWidget(const HiveTerminalApp());

    expect(find.text('Hive Terminal'), findsOneWidget);
    expect(find.text('v$appVersion'), findsOneWidget);
  });

  testWidgets('App shows feature list', (WidgetTester tester) async {
    await tester.pumpWidget(const HiveTerminalApp());

    expect(find.text('MCP Protocol'), findsOneWidget);
    expect(find.text('Voice Control'), findsOneWidget);
    expect(find.text('10+ Sessions'), findsOneWidget);
    expect(find.text('Swipe Navigation'), findsOneWidget);
  });

  testWidgets('Check for updates button exists', (WidgetTester tester) async {
    await tester.pumpWidget(const HiveTerminalApp());

    expect(find.text('Check for Updates'), findsOneWidget);
  });
}
