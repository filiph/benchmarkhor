import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'adb.dart';
import 'config.dart';
import 'device_probe.dart';
import 'models.dart';
import 'runner.dart';
import 'session_store.dart';

/// Builds the shelf [Router] exposing the HTTP API described in
/// `REQUIREMENTS.md` §5.
///
/// Only the read-only, "beginnings" surface is implemented so far:
/// `/health` and `GET /api/sessions`(`/<id>`). Session submission, cancellation,
/// `/api/queue/next`, the device probe, and the status page are not
/// implemented yet -- see `REQUIREMENTS.md` for their full specification.
class Api {
  final Config config;
  final SessionStore sessionStore;
  final Runner runner;
  final DateTime startedAt = DateTime.now().toUtc();

  Api({
    required this.config,
    required this.sessionStore,
    required this.runner,
  });

  Router get router {
    final router = Router();

    router.get('/', _statusPage);
    router.get('/health', _health);
    router.get('/api/sessions', _listSessions);
    router.post('/api/sessions', _submitSession);
    router.post('/api/sessions/discover', _discoverSessions);
    router.get('/api/sessions/<id>', _sessionDetail);
    router.post('/api/sessions/<id>/cancel', _cancelSession);
    router.post('/api/sessions/<id>/requeue', _requeueSession);
    router.post('/api/queue/next', _queueNext);
    router.get('/api/device', _deviceProbe);
    router.get(
        '/api/sessions/<id>/trials/<trial>/results/<file>', _serveResult);
    router.get(
        '/api/sessions/<id>/trials/<trial>/adb.log', _serveTrialArtifact);
    router.get(
        '/api/sessions/<id>/trials/<trial>/logcat.txt', _serveTrialArtifact);
    router.get(
        '/api/sessions/<id>/trials/<trial>/trial.json', _serveTrialArtifact);
    router.get('/api/sessions/<id>/log', _sessionLog);
    router.get('/sessions/<id>', _sessionDetailPage);

    return router;
  }

  Response _json(Object? body, {int status = 200}) => Response(
        status,
        body: const JsonEncoder.withIndent('  ').convert(body),
        headers: {'content-type': 'application/json'},
      );

  Future<Response> _statusPage(Request request) async {
    final adb = Adb(adbPath: config.adbPath, deviceAddress: config.dutAddress);
    final deviceState = await adb.getState() ?? 'offline';
    final probe = DeviceProbe(adb);
    final temp = deviceState == 'device' ? await probe.getSocTemp() : null;

    final sessionIds = (await sessionStore.listSessionIds()).reversed.take(20);
    final sessions = <SessionStatus>[];
    for (final id in sessionIds) {
      final s = await sessionStore.readStatus(id);
      if (s != null) sessions.add(s);
    }

    final gitCommit = config.gitCommit;

    final html = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html><head><title>adb_server</title>')
      ..writeln(
          '<meta http-equiv="refresh" content="${runner.isBusy ? '5' : '30'}">')
      ..writeln(
          '<style>body { font-family: sans-serif; margin: 2rem; line-height: 1.5; }')
      ..writeln(
          'table { border-collapse: collapse; width: 100%; margin-top: 1rem; }')
      ..writeln(
          'th, td { text-align: left; padding: 0.5rem; border-bottom: 1px solid #ccc; }')
      ..writeln('.state-queued { color: #666; }')
      ..writeln('.state-running { color: #007bff; font-weight: bold; }')
      ..writeln('.state-done { color: #28a745; }')
      ..writeln('.state-failed { color: #dc3545; }')
      ..writeln(
          '.footer { margin-top: 3rem; color: #666; font-size: 0.85rem; border-top: 1px solid #eee; padding-top: 1rem; }')
      ..writeln('.device-status { padding: 0.5rem; border-radius: 4px; }')
      ..writeln('.status-online { background: #d4edda; color: #155724; }')
      ..writeln('.status-offline { background: #f8d7da; color: #721c24; }')
      ..writeln('</style></head><body>')
      ..writeln('<h1>adb_server</h1>')
      ..writeln('<div style="margin-bottom: 2rem;">')
      ..writeln(
          '<span class="device-status ${deviceState == 'device' ? 'status-online' : 'status-offline'}">')
      ..writeln(
          'DUT: <strong>${config.dutAddress}</strong> is <strong>$deviceState</strong>')
      ..writeln(
          '${temp != null ? ' | Temp: <strong>${temp.toStringAsFixed(1)}°C</strong>' : ''}')
      ..writeln('</span>')
      ..writeln(' | Busy: <strong>${runner.isBusy}</strong>');

    if (runner.isBusy) {
      html.writeln(
          ' | Session: <strong><a href="/sessions/${runner.runningSessionId}">${runner.runningSessionId}</a></strong>');
    }
    html.writeln('</div>');

    html.writeln(
        '<form action="/api/sessions/discover" method="POST" style="margin-bottom: 1rem;">');
    html.writeln('<button type="submit">Discover New Sessions</button>');
    html.writeln('</form>');

    if (runner.isBusy && runner.statusMessage != null) {
      html.writeln('<p>Current state: <em>${runner.statusMessage}</em></p>');
    }

    html.writeln('<h2>Recent Sessions</h2>');
    html.writeln(
        '<table><thead><tr><th>ID</th><th>State</th><th>Progress</th><th>Timestamp</th><th>Actions</th></tr></thead><tbody>');

    for (final s in sessions) {
      final tsValue = s.timestampValue.toLocal();
      final tsLabel = s.timestampLabel;

      html.writeln('<tr>');
      html.writeln(
          '<td><a href="/sessions/${s.sessionId}">${s.sessionId}</a></td>');
      html.writeln('<td class="state-${s.state.name}">${s.state.name}</td>');
      html.writeln('<td>${s.roundsCompleted}/${s.roundsPlanned} rounds</td>');
      html.writeln(
          '<td><span title="$tsLabel">${tsValue.toString().split('.').first}</span></td>');
      html.writeln('<td>');
      if (s.state == SessionState.running) {
        html.writeln(
            '<form action="/api/sessions/${s.sessionId}/cancel" method="POST" style="display:inline;">');
        html.writeln('<button type="submit">Stop</button>');
        html.writeln('</form>');
      } else if (s.state != SessionState.queued) {
        html.writeln(
            '<form action="/api/sessions/${s.sessionId}/requeue" method="POST" style="display:inline;">');
        html.writeln('<button type="submit">Re-queue</button>');
        html.writeln('</form>');
      }
      html.writeln('</td>');
      html.writeln('</tr>');
    }

    html.writeln('</tbody></table>');
    html.writeln(
        '<form action="/api/queue/next" method="POST" style="margin-top: 2rem;">');
    html.writeln(
        '<button type="submit" ${runner.isBusy ? 'disabled' : ''}>Start Next Queued Session</button>');
    html.writeln('</form>');

    html.writeln('<div class="footer">Version: $gitCommit</div>');

    html.writeln('</body></html>');

    return Response.ok(html.toString(), headers: {'content-type': 'text/html'});
  }

  Response _health(Request request) => _json({
        'status': 'ok',
        'uptime_seconds':
            DateTime.now().toUtc().difference(startedAt).inSeconds,
        'busy': runner.isBusy,
        'config': config.toJson(),
      });

  Future<Response> _listSessions(Request request) async {
    await sessionStore.discoverNewSessions();

    final stateFilter = request.url.queryParameters['state'];
    final sessionIds = (await sessionStore.listSessionIds()).reversed;

    final summaries = <Map<String, dynamic>>[];
    for (final sessionId in sessionIds) {
      final status = await sessionStore.readStatus(sessionId);
      if (status == null) continue;
      if (stateFilter != null && status.state.name != stateFilter) continue;
      summaries.add(status.toJson());
    }

    return _json({'sessions': summaries});
  }

  Future<Response> _discoverSessions(Request request) async {
    await sessionStore.discoverNewSessions();
    if (request.headers['accept']?.contains('text/html') ?? false) {
      return Response.seeOther('/');
    }
    return _json({'status': 'ok'});
  }

  Future<Response> _submitSession(Request request) async {
    final raw = await request.readAsString();
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      return _json({'error': 'Invalid JSON body'}, status: 400);
    }

    final SessionSpec spec;
    try {
      spec = SessionSpec.fromJson(json);
    } on FormatException catch (e) {
      return _json({'error': e.message}, status: 400);
    }

    final now = DateTime.now().toUtc();
    final timestamp = now
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-')
        .replaceFirst('Z', 'Z');
    // More compact timestamp: 2026-08-09T07-00-00Z
    final compactTimestamp =
        '${timestamp.substring(0, 19).replaceAll(':', '-')}Z';

    final slug = spec.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    final sessionId = '${compactTimestamp}__$slug';

    final sessionDir = sessionStore.sessionDir(sessionId);
    if (await sessionDir.exists()) {
      return _json({'error': 'Session ID collision: $sessionId'}, status: 409);
    }

    await sessionDir.create(recursive: true);
    await sessionStore.writeAtomic(
      sessionStore.sessionSpecFile(sessionId),
      const JsonEncoder.withIndent('  ').convert(spec.toJson()),
    );

    await sessionStore.discoverNewSessions();
    final status = await sessionStore.readStatus(sessionId);

    return _json({
      'session_id': sessionId,
      'status': status?.toJson(),
    }, status: 201);
  }

  Future<Response> _sessionDetail(Request request, String id) async {
    final status = await sessionStore.readStatus(id);
    if (status == null) {
      return _json({'error': 'Session "$id" not found'}, status: 404);
    }

    Map<String, dynamic>? spec;
    try {
      spec = (await sessionStore.readSessionSpec(id)).toJson();
    } on FormatException catch (e) {
      spec = null;
      // Fall through: an invalid session.json is still reported via status.
      assert(status.state == SessionState.invalid || e.message.isNotEmpty);
    }

    return _json({
      'session': spec,
      'status': status.toJson(),
    });
  }

  Future<Response> _queueNext(Request request) async {
    try {
      final sessionId = await runner.startNext();
      if (sessionId == null) {
        return _json({'started': null}, status: 200);
      }
      return _json({'started': sessionId}, status: 202);
    } on StateError catch (e) {
      return _json({'error': e.message}, status: 409);
    }
  }

  Future<Response> _cancelSession(Request request, String id) async {
    final status = await sessionStore.readStatus(id);
    if (status == null) {
      return _json({'error': 'Session "$id" not found'}, status: 404);
    }

    if (status.state == SessionState.done ||
        status.state == SessionState.failed ||
        status.state == SessionState.cancelled ||
        status.state == SessionState.invalid ||
        status.state == SessionState.interrupted) {
      return _json({
        'error': 'Session is already in terminal state ${status.state.name}'
      }, status: 409);
    }

    await sessionStore.writeStatus(status.transitionTo(
      SessionState.cancelled,
      reason: 'Cancelled via API.',
    ));

    return _json({'status': 'cancelling'}, status: 202);
  }

  Future<Response> _requeueSession(Request request, String id) async {
    final status = await sessionStore.readStatus(id);
    if (status == null) {
      return _json({'error': 'Session "$id" not found'}, status: 404);
    }

    await sessionStore.writeStatus(status.transitionTo(
      SessionState.queued,
      roundsCompleted: 0,
    ));

    return _json({'status': 'queued'}, status: 200);
  }

  Future<Response> _deviceProbe(Request request) async {
    final adb = Adb(adbPath: config.adbPath, deviceAddress: config.dutAddress);
    if (!await adb.connect()) {
      return _json(
          {'error': 'Failed to connect to device at ${config.dutAddress}'},
          status: 503);
    }
    final probe = DeviceProbe(adb);
    final snapshot = await probe.probe();

    await sessionStore.deviceDir.create(recursive: true);
    await sessionStore.writeAtomic(
      sessionStore.lastSnapshotFile(),
      const JsonEncoder.withIndent('  ').convert(snapshot),
    );

    return _json(snapshot);
  }

  Future<Response> _serveResult(
      Request request, String id, String trial, String file) async {
    // Basic path validation to prevent traversal
    if (file.contains('..') || file.contains('/')) {
      return Response.forbidden('Invalid filename');
    }

    final resultsDir = sessionStore.trialResultsDir(id, trial);
    final resultFile = File(p.join(resultsDir.path, file));

    if (!await resultFile.exists()) {
      return _json({'error': 'Result file not found'}, status: 404);
    }

    return Response.ok(resultFile.openRead(),
        headers: {'content-type': 'text/plain'});
  }

  Future<Response> _sessionLog(Request request, String id) async {
    final logFile = sessionStore.sessionLogFile(id);
    if (!await logFile.exists()) {
      return _json({'error': 'Log not found'}, status: 404);
    }

    return Response.ok(logFile.openRead(),
        headers: {'content-type': 'text/plain'});
  }

  Future<Response> _sessionDetailPage(Request request, String id) async {
    final status = await sessionStore.readStatus(id);
    if (status == null) {
      return Response.notFound('Session not found');
    }

    final trialsDir = sessionStore.trialsDir(id);
    final trials = <TrialMetadata>[];
    if (await trialsDir.exists()) {
      final entities = await trialsDir.list().toList();
      entities.sort((a, b) => a.path.compareTo(b.path));
      for (final entity in entities) {
        if (entity is Directory) {
          final trialId = p.basename(entity.path);
          final metadataFile = sessionStore.trialMetadataFile(id, trialId);
          if (await metadataFile.exists()) {
            try {
              final json = jsonDecode(await metadataFile.readAsString())
                  as Map<String, dynamic>;
              trials.add(TrialMetadata.fromJson(json));
            } catch (_) {
              // Skip malformed trial metadata
            }
          }
        }
      }
    }

    final html = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html><head><title>Session $id</title>')
      ..writeln(
          '<style>body { font-family: sans-serif; margin: 2rem; line-height: 1.5; }')
      ..writeln(
          'table { border-collapse: collapse; width: 100%; margin-top: 1rem; }')
      ..writeln(
          'th, td { text-align: left; padding: 0.5rem; border-bottom: 1px solid #ccc; }')
      ..writeln('a { text-decoration: none; color: #007bff; }')
      ..writeln('a:hover { text-decoration: underline; }')
      ..writeln('</style></head><body>')
      ..writeln('<h1>Session: $id</h1>')
      ..writeln(
          '<p><a href="/">&larr; Back to Dashboard</a> | <a href="/api/sessions/$id/log" target="_blank">Session Log</a></p>')
      ..writeln('<h2>Trials</h2>')
      ..writeln(
          '<table><thead><tr><th>Trial</th><th>Variant</th><th>Started</th><th>Finished</th><th>Temp / Throttled</th><th>Artifacts</th></tr></thead><tbody>');

    for (final trial in trials) {
      final beforeTemp = _getSocThermal(trial.deviceBefore);
      final afterTemp = _getSocThermal(trial.deviceAfter);
      var tempStr = (beforeTemp != null && afterTemp != null)
          ? '${beforeTemp.toStringAsFixed(1)}°C &rarr; ${afterTemp.toStringAsFixed(1)}°C'
          : 'N/A';
      if (trial.thermalThrottled) {
        final statusSuffix = trial.maxThermalStatus != null
            ? ' (status: ${trial.maxThermalStatus})'
            : '';
        tempStr +=
            ' | <span style="color: red; font-weight: bold;">Throttled$statusSuffix</span>';
      } else {
        tempStr += ' | Normal';
      }

      html.writeln('<tr>');
      html.writeln('<td>${trial.trialId}</td>');
      html.writeln('<td>${trial.variantName}</td>');
      html.writeln(
          '<td>${trial.startedAt.toLocal().toString().split('.').first}</td>');
      html.writeln(
          '<td>${trial.finishedAt.toLocal().toString().split('.').first}</td>');
      html.writeln('<td>$tempStr</td>');
      html.writeln('<td>');
      html.writeln(
          '<a href="/api/sessions/$id/trials/${trial.trialId}/adb.log" target="_blank">adb.log</a> | ');
      html.writeln(
          '<a href="/api/sessions/$id/trials/${trial.trialId}/logcat.txt" target="_blank">logcat.txt</a> | ');
      html.writeln(
          '<a href="/api/sessions/$id/trials/${trial.trialId}/trial.json" target="_blank">trial.json</a>');
      html.writeln('</td>');
      html.writeln('</tr>');
    }

    html.writeln('</tbody></table>');
    html.writeln('</body></html>');

    return Response.ok(html.toString(), headers: {'content-type': 'text/html'});
  }

  double? _getSocThermal(Map<String, dynamic> deviceData) {
    final temps = deviceData['temperatures'] as List?;
    if (temps == null) return null;
    for (final t in temps) {
      if (t is Map && t['type'] == 'soc-thermal') {
        final val = double.tryParse(t['temp']?.toString() ?? '');
        if (val != null) return val / 1000.0;
      }
    }
    return null;
  }

  Future<Response> _serveTrialArtifact(
      Request request, String id, String trial) async {
    final segments = request.url.pathSegments;
    final fileName = segments.last;

    if (!['adb.log', 'logcat.txt', 'trial.json'].contains(fileName)) {
      return Response.notFound('Not a trial artifact');
    }

    final trialDir = sessionStore.trialDir(id, trial);
    final file = File(p.join(trialDir.path, fileName));

    if (!await file.exists()) {
      return _json({'error': 'File not found'}, status: 404);
    }

    final contentType =
        fileName.endsWith('.json') ? 'application/json' : 'text/plain';
    return Response.ok(file.openRead(), headers: {'content-type': contentType});
  }
}
