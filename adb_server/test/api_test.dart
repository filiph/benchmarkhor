import 'dart:convert';
import 'dart:io';

import 'package:adb_server/api.dart';
import 'package:adb_server/config.dart';
import 'package:adb_server/models.dart';
import 'package:adb_server/runner.dart';
import 'package:adb_server/session_store.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late SessionStore store;
  late Config config;
  late Runner runner;
  late Api api;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('adb_api_test_');
    store = SessionStore(tempDir.path);
    config = Config(
      dutAddress: '127.0.0.1:5555',
      dataDir: tempDir.path,
      port: 8080,
      adbPath: 'adb',
      pollIntervalSeconds: 15,
      defaultTrialTimeoutSeconds: 1800,
      thermalGateCelsius: null,
      thermalGateTimeoutSeconds: 300,
      deviceProfileFile: null,
      deviceResetFile: null,
      profilesDir: p.join(tempDir.path, 'profiles'),
      precompilePackage: true,
      logLevel: 'info',
      gitCommit: 'abdabdabd',
    );
    runner = Runner(config: config, sessionStore: store);
    api = Api(config: config, sessionStore: store, runner: runner);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('POST /api/sessions creates a new session', () async {
    final spec = {
      'name': 'API Test',
      'variants': {
        'default': {'apk': 'app.apk', 'test_apk': 'test.apk'},
      },
      'package': 'com.example.api',
      'device_result_dir': '/sdcard/api',
      'rounds': 3,
    };

    final request = Request(
      'POST',
      Uri.parse('http://localhost/api/sessions'),
      body: jsonEncode(spec),
    );

    final response = await api.router.call(request);
    expect(response.statusCode, 201);

    final body = jsonDecode(await response.readAsString());
    final sessionId = body['session_id'] as String;
    expect(sessionId, contains('api-test'));

    final status = await store.readStatus(sessionId);
    expect(status, isNotNull);
    expect(status!.state, SessionState.queued);
    expect(status.roundsPlanned, 3);
  });

  test('GET / returns HTML status page', () async {
    final request = Request('GET', Uri.parse('http://localhost/'));
    final response = await api.router.call(request);
    expect(response.statusCode, 200);
    expect(response.headers['content-type'], 'text/html');

    final body = await response.readAsString();
    expect(body, contains('<h1>adb_server</h1>'));
    expect(body, contains('DUT: <strong>127.0.0.1:5555</strong>'));
    expect(body, contains('Discover New Sessions'));
  });

  test('POST /api/queue/next enforces mutual exclusion', () async {
    // 1. Setup a queued session
    final sessionId = '20260810-120000Z__exclusion-test';
    final sessionDir = store.sessionDir(sessionId)..createSync(recursive: true);
    final specFile = store.sessionSpecFile(sessionId);
    specFile.writeAsStringSync(
      jsonEncode({
        'name': 'Exclusion Test',
        'variants': {
          'v1': {'apk': 'a.apk', 'test_apk': 'at.apk'},
        },
        'package': 'com.example.exclusion',
        'device_result_dir': '/sdcard/exclusion',
        'rounds': 1,
      }),
    );
    await store.discoverNewSessions();

    // 2. Mock a long-running startNext by making it async
    // In the real Runner, startNext kicks off _run asynchronously.
    // We can just call it twice.

    final req1 = Request('POST', Uri.parse('http://localhost/api/queue/next'));
    final req2 = Request('POST', Uri.parse('http://localhost/api/queue/next'));

    // We use Future.wait but req1 will definitely start first in the event loop
    // if we await them in sequence or even in parallel because shelf_router
    // handles them one by one.
    // However, the requirement is about the mutual exclusion.

    final res1 = await api.router.call(req1);
    final res2 = await api.router.call(req2);

    expect(res1.statusCode, 202);
    expect(res2.statusCode, 409);

    final body1 = jsonDecode(await res1.readAsString());
    expect(body1['started'], sessionId);

    final body2 = jsonDecode(await res2.readAsString());
    expect(body2['error'], contains('already running'));
  });

  test('POST /api/sessions/discover finds new sessions on disk', () async {
    // 1. Manually create a session directory with a session.json but no status.json
    final sessionId = '20260810-120000Z__manual-session';
    final sessionDir = store.sessionDir(sessionId)..createSync(recursive: true);
    final specFile = store.sessionSpecFile(sessionId);
    specFile.writeAsStringSync(
      jsonEncode({
        'name': 'Manual Session',
        'variants': {
          'v1': {'apk': 'a.apk', 'test_apk': 'at.apk'},
        },
        'package': 'com.example.manual',
        'device_result_dir': '/sdcard/manual',
        'rounds': 5,
      }),
    );

    // 2. Call discovery via API
    final request = Request(
      'POST',
      Uri.parse('http://localhost/api/sessions/discover'),
    );
    final response = await api.router.call(request);
    expect(response.statusCode, 200);

    // 3. Verify the session is now discovered
    final status = await store.readStatus(sessionId);
    expect(status, isNotNull);
    expect(status!.state, SessionState.queued);
    expect(status.roundsPlanned, 5);
  });

  test(
    'POST /api/sessions/discover redirects to / for HTML requests',
    () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/api/sessions/discover'),
        headers: {'accept': 'text/html'},
      );
      final response = await api.router.call(request);
      expect(response.statusCode, 303); // seeOther
      expect(response.headers['location'], '/');
    },
  );

  test(
    'GET /sessions/<id> displays trial details including thermal throttling',
    () async {
      final sessionId = '20260810-120000Z__detail-test';
      final sessionDir = store.sessionDir(sessionId)
        ..createSync(recursive: true);
      final status = SessionStatus(
        sessionId: sessionId,
        state: SessionState.done,
        roundsPlanned: 1,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await store.writeStatus(status);

      final trialDir = store.trialDir(sessionId, 'trial-001')
        ..createSync(recursive: true);
      final trialMetadata = TrialMetadata(
        sessionId: sessionId,
        variantName: 'v1',
        trialId: 'trial-001',
        startedAt: DateTime.now().toUtc(),
        finishedAt: DateTime.now().toUtc(),
        thermalThrottled: true,
        maxThermalStatus: 2,
      );
      final metaFile = store.trialMetadataFile(sessionId, 'trial-001');
      metaFile.writeAsStringSync(jsonEncode(trialMetadata.toJson()));

      final request = Request(
        'GET',
        Uri.parse('http://localhost/sessions/$sessionId'),
      );
      final response = await api.router.call(request);
      expect(response.statusCode, 200);

      final body = await response.readAsString();
      expect(body, contains('Session: $sessionId'));
      expect(body, contains('Throttled (status: 2)'));
    },
  );
}
