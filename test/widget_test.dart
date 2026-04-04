import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test scaffold shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('widget test smoke'))),
    );

    expect(find.text('widget test smoke'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
