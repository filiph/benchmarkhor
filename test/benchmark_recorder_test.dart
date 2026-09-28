import 'dart:convert';
import 'dart:io';

import 'package:benchmarkhor/benchmark_recorder.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('recorder_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('records iterations with auto-incrementing iteration indices', () async {
    final recorder = BenchmarkRecorder(outputDir: tempDir);

    recorder.recordIteration(durationUs: 1200);
    recorder.recordIteration(durationUs: 1350);
    await recorder.close();

    final file = File(p.join(tempDir.path, 'iterations.jsonl'));
    expect(await file.exists(), isTrue);

    final lines = await file.readAsLines();
    expect(lines, hasLength(2));

    final first = jsonDecode(lines[0]) as Map<String, dynamic>;
    expect(first['iteration'], 1);
    expect(first['durationUs'], 1200);
    expect(first['timestampUs'], isPositive);

    final second = jsonDecode(lines[1]) as Map<String, dynamic>;
    expect(second['iteration'], 2);
    expect(second['durationUs'], 1350);
    expect(second['timestampUs'], isPositive);
  });

  test('allows explicit iteration and timestampUs overrides', () async {
    final recorder = BenchmarkRecorder(outputDir: tempDir);

    recorder.recordIteration(
      durationUs: 500,
      iteration: 42,
      timestampUs: 1711200000000,
    );
    await recorder.close();

    final lines = await File(
      p.join(tempDir.path, 'iterations.jsonl'),
    ).readAsLines();
    final item = jsonDecode(lines.single) as Map<String, dynamic>;
    expect(item['iteration'], 42);
    expect(item['durationUs'], 500);
    expect(item['timestampUs'], 1711200000000);
  });

  test('measure() records duration and returns value', () async {
    final recorder = BenchmarkRecorder(outputDir: tempDir);

    final result = recorder.measure(() {
      sleep(const Duration(milliseconds: 10));
      return 'done_work';
    });
    expect(result, 'done_work');

    await recorder.close();

    final lines = await File(
      p.join(tempDir.path, 'iterations.jsonl'),
    ).readAsLines();
    expect(lines, hasLength(1));
    final item = jsonDecode(lines.first) as Map<String, dynamic>;
    expect(item['iteration'], 1);
    // Should be at least 5000 us (5 ms)
    expect(item['durationUs'], greaterThan(5000));
  });

  test('measureAsync() records duration and returns value', () async {
    final recorder = BenchmarkRecorder(outputDir: tempDir);

    final result = await recorder.measureAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return 123;
    });
    expect(result, 123);

    await recorder.close();

    final lines = await File(
      p.join(tempDir.path, 'iterations.jsonl'),
    ).readAsLines();
    expect(lines, hasLength(1));
    final item = jsonDecode(lines.first) as Map<String, dynamic>;
    expect(item['iteration'], 1);
    expect(item['durationUs'], greaterThan(5000));
  });

  test('complete() flushes and writes DONE sentinel file', () async {
    final recorder = BenchmarkRecorder(outputDir: tempDir);
    recorder.recordIteration(durationUs: 800);

    await recorder.complete();

    expect(recorder.isClosed, isTrue);
    expect(File(p.join(tempDir.path, 'DONE')).existsSync(), isTrue);
    expect(File(p.join(tempDir.path, 'FAILED')).existsSync(), isFalse);

    // Further calls throw StateError
    expect(
      () => recorder.recordIteration(durationUs: 900),
      throwsA(isA<StateError>()),
    );
  });

  test('fail() flushes and writes FAILED sentinel file with reason', () async {
    final recorder = BenchmarkRecorder(outputDir: tempDir);
    recorder.recordIteration(durationUs: 800);

    await recorder.fail('Out of memory');

    expect(recorder.isClosed, isTrue);
    final failedFile = File(p.join(tempDir.path, 'FAILED'));
    expect(failedFile.existsSync(), isTrue);
    expect(await failedFile.readAsString(), 'Out of memory');
    expect(File(p.join(tempDir.path, 'DONE')).existsSync(), isFalse);
  });

  test('defaultDeviceResultDir formats expected Android path', () {
    final dir = BenchmarkRecorder.defaultDeviceResultDir('com.example.bench');
    expect(dir.path, '/sdcard/Android/data/com.example.bench/files');
  });
}
