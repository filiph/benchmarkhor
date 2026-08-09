import 'dart:convert';
import 'dart:io';

import 'package:adb_server/api.dart';
import 'package:adb_server/config.dart';
import 'package:adb_server/models.dart';
import 'package:adb_server/runner.dart';
import 'package:adb_server/session_store.dart';
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
      precompilePackage: true,
      logLevel: 'info',
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
  });
}
