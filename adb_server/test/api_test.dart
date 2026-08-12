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
        'default': {'apk': 'app.apk', 'test_apk': 'test.apk'}
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
    expect(body, contains('DUT: <code>127.0.0.1:5555</code>'));
    expect(body, contains('Discover New Sessions'));
  });

  test('POST /api/sessions/discover finds new sessions on disk', () async {
    // 1. Manually create a session directory with a session.json but no status.json
    final sessionId = '20260810-120000Z__manual-session';
    final sessionDir = store.sessionDir(sessionId)..createSync(recursive: true);
    final specFile = store.sessionSpecFile(sessionId);
    specFile.writeAsStringSync(jsonEncode({
      'name': 'Manual Session',
      'variants': {
        'v1': {'apk': 'a.apk', 'test_apk': 'at.apk'}
      },
      'package': 'com.example.manual',
      'device_result_dir': '/sdcard/manual',
      'rounds': 5,
    }));

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

  test('POST /api/sessions/discover redirects to / for HTML requests',
      () async {
    final request = Request(
      'POST',
      Uri.parse('http://localhost/api/sessions/discover'),
      headers: {'accept': 'text/html'},
    );
    final response = await api.router.call(request);
    expect(response.statusCode, 303); // seeOther
    expect(response.headers['location'], '/');
  });

  test('GET /sessions/<id> displays trial details including thermal throttling',
      () async {
    final sessionId = '20260810-120000Z__detail-test';
    final sessionDir = store.sessionDir(sessionId)..createSync(recursive: true);
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
  });
}
