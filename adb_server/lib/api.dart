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
    router.get('/api/sessions/<id>/log', _sessionLog);

    return router;
  }

  Response _json(Object? body, {int status = 200}) => Response(
        status,
        body: const JsonEncoder.withIndent('  ').convert(body),
        headers: {'content-type': 'application/json'},
      );

  Future<Response> _statusPage(Request request) async {
    final sessionIds = (await sessionStore.listSessionIds()).reversed.take(20);
    final sessions = <SessionStatus>[];
    for (final id in sessionIds) {
      final s = await sessionStore.readStatus(id);
      if (s != null) sessions.add(s);
    }

    final html = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html><head><title>adb_server</title>')
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
      ..writeln('</style></head><body>')
      ..writeln('<h1>adb_server</h1>')
      ..writeln(
          '<p>DUT: <code>${config.dutAddress}</code> | Busy: <strong>${Runner.isBusy}</strong></p>');

    html.writeln(
        '<form action="/api/sessions/discover" method="POST" style="margin-bottom: 1rem;">');
    html.writeln('<button type="submit">Discover New Sessions</button>');
    html.writeln('</form>');

    if (Runner.isBusy && Runner.statusMessage != null) {
      html.writeln('<p>Current state: <em>${Runner.statusMessage}</em></p>');
    }

    html.writeln('<h2>Recent Sessions</h2>');
    html.writeln(
        '<table><thead><tr><th>ID</th><th>State</th><th>Progress</th><th>Updated</th><th>Actions</th></tr></thead><tbody>');

    for (final s in sessions) {
      html.writeln('<tr>');
      html.writeln(
          '<td><a href="/api/sessions/${s.sessionId}">${s.sessionId}</a></td>');
      html.writeln('<td class="state-${s.state.name}">${s.state.name}</td>');
      html.writeln('<td>${s.roundsCompleted}/${s.roundsPlanned} rounds</td>');
      html.writeln('<td>${s.updatedAt.toLocal()}</td>');
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
        '<button type="submit" ${Runner.isBusy ? 'disabled' : ''}>Start Next Queued Session</button>');
    html.writeln('</form>');
    html.writeln('</body></html>');

    return Response.ok(html.toString(), headers: {'content-type': 'text/html'});
  }

  Response _health(Request request) => _json({
        'status': 'ok',
        'uptime_seconds':
            DateTime.now().toUtc().difference(startedAt).inSeconds,
        'busy': Runner.isBusy,
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

    final linesParam = request.url.queryParameters['lines'];
    final linesCount = int.tryParse(linesParam ?? '') ?? 100;

    final lines = await logFile.readAsLines();
    final start = (lines.length - linesCount).clamp(0, lines.length);
    final tail = lines.sublist(start).join('\n');

    return Response.ok(tail, headers: {'content-type': 'text/plain'});
  }
}
