import 'dart:convert';
import 'dart:io';

import 'package:adb_server/job_store.dart';
import 'package:adb_server/models.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late JobStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('adb_server_test_');
    store = JobStore(tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<void> writeJobSpec(String jobId, Map<String, dynamic> json) async {
    final dir = Directory(p.join(store.jobsDir.path, jobId));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'job.json')).writeAsString(jsonEncode(json));
  }

  group('discoverNewJobs', () {
    test('creates a queued status.json for a valid new job', () async {
      await writeJobSpec('job-a', {
        'name': 'demo',
        'package': 'com.example.demo',
        'activity': '.MainActivity',
        'device_result_dir': '/sdcard/demo',
        'repetitions': 2,
      });

      await store.discoverNewJobs();

      final status = await store.readStatus('job-a');
      expect(status, isNotNull);
      expect(status!.state, JobState.queued);
      expect(status.runsPlanned, 2);
    });

    test('marks a job with malformed job.json as invalid', () async {
      await writeJobSpec('job-b', {'name': 'incomplete'});

      await store.discoverNewJobs();

      final status = await store.readStatus('job-b');
      expect(status, isNotNull);
      expect(status!.state, JobState.invalid);
      expect(status.error, isNotNull);
    });

    test('does not touch jobs that already have a status.json', () async {
      await writeJobSpec('job-c', {
        'name': 'demo',
        'package': 'com.example.demo',
        'activity': '.MainActivity',
        'device_result_dir': '/sdcard/demo',
      });
      final existing = JobStatus(
        jobId: 'job-c',
        state: JobState.done,
        createdAt: DateTime.utc(2020),
        updatedAt: DateTime.utc(2020),
        runsPlanned: 1,
        runsCompleted: 1,
      );
      await store.writeStatus(existing);

      await store.discoverNewJobs();

      final status = await store.readStatus('job-c');
      expect(status!.state, JobState.done);
    });
  });

  group('recoverInterruptedJobs', () {
    test('transitions a stale running job to interrupted', () async {
      await writeJobSpec('job-d', {
        'name': 'demo',
        'package': 'com.example.demo',
        'activity': '.MainActivity',
        'device_result_dir': '/sdcard/demo',
      });
      final now = DateTime.now().toUtc();
      await store.writeStatus(JobStatus(
        jobId: 'job-d',
        state: JobState.running,
        createdAt: now,
        updatedAt: now,
        runsPlanned: 1,
      ));

      await store.recoverInterruptedJobs();

      final status = await store.readStatus('job-d');
      expect(status!.state, JobState.interrupted);
      expect(status.history, isNotEmpty);
    });

    test('leaves non-running jobs untouched', () async {
      await writeJobSpec('job-e', {
        'name': 'demo',
        'package': 'com.example.demo',
        'activity': '.MainActivity',
        'device_result_dir': '/sdcard/demo',
      });
      final now = DateTime.now().toUtc();
      await store.writeStatus(JobStatus(
        jobId: 'job-e',
        state: JobState.queued,
        createdAt: now,
        updatedAt: now,
        runsPlanned: 1,
      ));

      await store.recoverInterruptedJobs();

      final status = await store.readStatus('job-e');
      expect(status!.state, JobState.queued);
    });
  });

  group('listJobIds', () {
    test('returns job ids in lexicographic order', () async {
      await writeJobSpec('2026-01-02__b', {
        'name': 'demo',
        'package': 'com.example.demo',
        'activity': '.MainActivity',
        'device_result_dir': '/sdcard/demo',
      });
      await writeJobSpec('2026-01-01__a', {
        'name': 'demo',
        'package': 'com.example.demo',
        'activity': '.MainActivity',
        'device_result_dir': '/sdcard/demo',
      });

      final ids = await store.listJobIds();

      expect(ids, ['2026-01-01__a', '2026-01-02__b']);
    });
  });
}
