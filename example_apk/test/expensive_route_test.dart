import 'package:example_apk/expensive_route.dart';
import 'package:example_apk/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Expensive route opens at every multiple of the threshold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
    }

    // Nine taps is not enough.
    expect(find.byType(ExpensiveRoute), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byType(ExpensiveRoute), findsOneWidget);

    // Going back to the counter and tapping to twenty opens it again.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ExpensiveRoute), findsNothing);

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(ExpensiveRoute), findsOneWidget);
  });
}
