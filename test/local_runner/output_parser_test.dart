import 'package:benchmarkhor/src/local_runner/output_parser.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  group('BenchmarkOutputParser', () {
    test('parses single matching line correctly', () {
      final records = <LogRecord>[];
      final logger = Logger('test_parser')..onRecord.listen(records.add);
      final parser = BenchmarkOutputParser(logger: logger);

      const stdout = '''
Starting benchmark...
Warmup finished.
Template(RunTime): 0.005620051244379949 us.
Completed run.
''';

      final result = parser.parse(stdout);
      expect(result.hasDuration, isTrue);
      expect(result.durationUs, equals(0.005620051244379949));
      expect(result.matchCount, equals(1));
      expect(result.warnings, isEmpty);
      expect(records, isEmpty);
    });

    test('parses scientific notation and integer numbers', () {
      final parser = BenchmarkOutputParser();

      final res1 = parser.parse('Benchmark(RunTime): 1234 us');
      expect(res1.durationUs, equals(1234));

      final res2 = parser.parse('(RunTime): 1.5e-3 us');
      expect(res2.durationUs, closeTo(0.0015, 1e-6));

      final res3 = parser.parse('(RunTime): 2.5E+4 us');
      expect(res3.durationUs, equals(25000));
    });

    test('handles multiple matches by selecting last and emitting SEVERE log', () {
      final records = <LogRecord>[];
      final logger = Logger('test_parser')..onRecord.listen(records.add);
      final parser = BenchmarkOutputParser(logger: logger);

      const stdout = '''
Iteration 1 (RunTime): 100 us
Iteration 2 (RunTime): 50 us
Iteration 3 (RunTime): 25.5 us
''';

      final result = parser.parse(stdout);
      expect(result.hasDuration, isTrue);
      expect(result.durationUs, equals(25.5));
      expect(result.matchCount, equals(3));
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first, contains('Found 3 matches'));

      expect(records.length, equals(1));
      expect(records.first.level, equals(Level.SEVERE));
      expect(records.first.message, contains('Found 3 matches'));
    });

    test('handles zero matches by returning null and emitting SEVERE log', () {
      final records = <LogRecord>[];
      final logger = Logger('test_parser')..onRecord.listen(records.add);
      final parser = BenchmarkOutputParser(logger: logger);

      const stdout = '''
Hello world!
No runtime metric reported here.
Exiting.
''';

      final result = parser.parse(stdout);
      expect(result.hasDuration, isFalse);
      expect(result.durationUs, isNull);
      expect(result.matchCount, equals(0));
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first, contains('No line matching'));

      expect(records.length, equals(1));
      expect(records.first.level, equals(Level.SEVERE));
    });
  });
}
