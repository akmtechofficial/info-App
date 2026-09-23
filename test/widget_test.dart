import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:info_app/theme/app_theme.dart';

void main() {
  testWidgets('App Theme smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Center(child: Text('NumInfo Test')),
        ),
      ),
    );

    expect(find.text('NumInfo Test'), findsOneWidget);
  });
}
