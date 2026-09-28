import 'package:dart_benchmark_harness/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders benchmark harness placeholder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BenchmarkHarnessApp());
    expect(find.text('Running pure-Dart benchmark...'), findsOneWidget);
  });
}
