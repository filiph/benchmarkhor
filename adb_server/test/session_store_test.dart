import 'dart:convert';
import 'dart:io';

import 'package:adb_server/models.dart';
import 'package:adb_server/session_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late SessionStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('adb_server_test_');
    store = SessionStore(tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<void> writeSessionSpec(
    String sessionId,
    Map<String, dynamic> json,
  ) async {
    final dir = Directory(p.join(store.sessionsDir.path, sessionId));
    await dir.create(recursive: true);
    await File(
      p.join(dir.path, 'session.json'),
    ).writeAsString(jsonEncode(json));
  }

  group('discoverNewSessions', () {
    test('creates a queued status.json for a valid new session', () async {
      await writeSessionSpec('session-a', {
        'name': 'demo',
        'variants': {
          'baseline': {'apk': 'baseline.apk', 'test_apk': 'test.apk'},
        },
        'package': 'com.example.demo',
        'device_result_dir': '/sdcard/demo',
        'rounds': 2,
      });

      await store.discoverNewSessions();

      final status = await store.readStatus('session-a');
      expect(status, isNotNull);
      expect(status!.state, SessionState.queued);
      expect(status.roundsPlanned, 2);
    });

    test('marks a session with malformed session.json as invalid', () async {
      await writeSessionSpec('session-b', {'name': 'incomplete'});

      await store.discoverNewSessions();

      final status = await store.readStatus('session-b');
      expect(status, isNotNull);
      expect(status!.state, SessionState.invalid);
      expect(status.error, isNotNull);
    });

    test('does not touch sessions that already have a status.json', () async {
      await writeSessionSpec('session-c', {
        'name': 'demo',
        'variants': {
          'baseline': {'apk': 'baseline.apk', 'test_apk': 'test.apk'},
        },
        'package': 'com.example.demo',
        'device_result_dir': '/sdcard/demo',
      });
      final existing = SessionStatus(
        sessionId: 'session-c',
        state: SessionState.done,
        createdAt: DateTime.utc(2020),
        updatedAt: DateTime.utc(2020),
        roundsPlanned: 1,
        roundsCompleted: 1,
      );
      await store.writeStatus(existing);

      await store.discoverNewSessions();

      final status = await store.readStatus('session-c');
      expect(status!.state, SessionState.done);
    });
  });

  group('recoverInterruptedSessions', () {
    test('transitions a stale running session to interrupted', () async {
      await writeSessionSpec('session-d', {
        'name': 'demo',
        'variants': {
          'baseline': {'apk': 'baseline.apk', 'test_apk': 'test.apk'},
        },
        'package': 'com.example.demo',
        'device_result_dir': '/sdcard/demo',
      });
      final now = DateTime.now().toUtc();
      await store.writeStatus(
        SessionStatus(
          sessionId: 'session-d',
          state: SessionState.running,
          createdAt: now,
          updatedAt: now,
          roundsPlanned: 1,
        ),
      );

      await store.recoverInterruptedSessions();

      final status = await store.readStatus('session-d');
      expect(status!.state, SessionState.interrupted);
      expect(status.history, isNotEmpty);
    });

    test('leaves non-running sessions untouched', () async {
      await writeSessionSpec('session-e', {
        'name': 'demo',
        'variants': {
          'baseline': {'apk': 'baseline.apk', 'test_apk': 'test.apk'},
        },
        'package': 'com.example.demo',
        'device_result_dir': '/sdcard/demo',
      });
      final now = DateTime.now().toUtc();
      await store.writeStatus(
        SessionStatus(
          sessionId: 'session-e',
          state: SessionState.queued,
          createdAt: now,
          updatedAt: now,
          roundsPlanned: 1,
        ),
      );

      await store.recoverInterruptedSessions();

      final status = await store.readStatus('session-e');
      expect(status!.state, SessionState.queued);
    });
  });

  group('writeAtomic', () {
    test('writes content successfully', () async {
      final file = File(p.join(tempDir.path, 'atomic.txt'));
      await store.writeAtomic(file, 'hello world');
      expect(await file.readAsString(), 'hello world');
    });

    test('replaces existing file', () async {
      final file = File(p.join(tempDir.path, 'atomic.txt'));
      await file.writeAsString('old');
      await store.writeAtomic(file, 'new');
      expect(await file.readAsString(), 'new');
    });

    test('does not leave tmp file on success', () async {
      final file = File(p.join(tempDir.path, 'atomic.txt'));
      await store.writeAtomic(file, 'data');
      final tmpFile = File('${file.path}.tmp');
      expect(await tmpFile.exists(), isFalse);
    });
  });

  group('listSessionIds', () {
    test('returns session ids in lexicographic order', () async {
      await writeSessionSpec('2026-01-02__b', {
        'name': 'demo',
        'variants': {
          'baseline': {'apk': 'baseline.apk', 'test_apk': 'test.apk'},
        },
        'package': 'com.example.demo',
        'device_result_dir': '/sdcard/demo',
      });
      await writeSessionSpec('2026-01-01__a', {
        'name': 'demo',
        'variants': {
          'baseline': {'apk': 'baseline.apk', 'test_apk': 'test.apk'},
        },
        'package': 'com.example.demo',
        'device_result_dir': '/sdcard/demo',
      });

      final ids = await store.listSessionIds();

      expect(ids, ['2026-01-01__a', '2026-01-02__b']);
    });
  });
}
