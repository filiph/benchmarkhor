import 'dart:convert';
import 'dart:io';

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart' hide Request, Response;
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'adb.dart';
import 'config.dart';
import 'device_probe.dart';
import 'logging.dart';
import 'models.dart';
import 'runner.dart';
import 'session_store.dart';
import 'web/app.dart';

/// Builds the shelf [Router] exposing the HTTP API described in
/// `REQUIREMENTS.md` §5.
class Api {
  final Config config;
  final SessionStore sessionStore;
  final Runner runner;
  final DateTime startedAt = DateTime.now().toUtc();

  Api({required this.config, required this.sessionStore, required this.runner});

  Handler get handler {
    final jasprHandler = serveApp((request, render) {
      return render(
        AppDataProvider(
          data: AppData(
            config: config,
            sessionStore: sessionStore,
            runner: runner,
          ),
          child: Document(
            title: 'adb_server',
            styles: [
              css.import('/css/reset.css'),
              css('body').styles(
                fontFamily: FontFamilies.sansSerif,
                margin: .all(2.rem),
                lineHeight: 1.5.em,
              ),
              css('table').styles(
                width: 100.percent,
                margin: .only(top: 1.rem),
                raw: {'border-collapse': 'collapse'},
              ),
              css('th, td').styles(
                textAlign: TextAlign.left,
                padding: .all(0.5.rem),
                border: .only(
                  bottom: .solid(color: const Color('#ccc'), width: 1.px),
                ),
              ),
              css('.state-queued').styles(color: const Color('#666')),
              css('.state-running').styles(
                color: const Color('#007bff'),
                fontWeight: FontWeight.bold,
              ),
              css('.state-done').styles(color: const Color('#28a745')),
              css('.state-failed').styles(color: const Color('#dc3545')),
              css('.footer').styles(
                margin: .only(top: 3.rem),
                color: const Color('#666'),
                fontSize: 0.85.rem,
                border: .only(
                  top: .solid(color: const Color('#eee'), width: 1.px),
                ),
                padding: .only(top: 1.rem),
              ),
              css(
                '.device-status',
              ).styles(padding: .all(0.5.rem), radius: .all(.circular(4.px))),
              css('.status-online').styles(
                backgroundColor: const Color('#d4edda'),
                color: const Color('#155724'),
              ),
              css('.status-offline').styles(
                backgroundColor: const Color('#f8d7da'),
                color: const Color('#721c24'),
              ),
              css('a').styles(
                color: const Color('#007bff'),
                textDecoration: const TextDecoration(
                  line: TextDecorationLine.none,
                ),
              ),
              css('a:hover').styles(
                textDecoration: const TextDecoration(
                  line: TextDecorationLine.underline,
                ),
              ),
            ],
            body: const App(),
          ),
        ),
      );
    });

    return Cascade().add(router.call).add(jasprHandler).handler;
  }

  Router get router {
    final router = Router();

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
      '/api/sessions/<id>/trials/<trial>/results/<file>',
      _serveResult,
    );
    router.get(
      '/api/sessions/<id>/trials/<trial>/adb.log',
      _serveTrialArtifact,
    );
    router.get(
      '/api/sessions/<id>/trials/<trial>/logcat.txt',
      _serveTrialArtifact,
    );
    router.get(
      '/api/sessions/<id>/trials/<trial>/trial.json',
      _serveTrialArtifact,
    );
    router.get('/api/sessions/<id>/log', _sessionLog);
    router.get('/api/logs/server.log', _serverLog);

    return router;
  }

  Response _json(Object? body, {int status = 200}) => Response(
    status,
    body: const JsonEncoder.withIndent('  ').convert(body),
    headers: {'content-type': 'application/json'},
  );

  Response _health(Request request) => _json({
    'status': 'ok',
    'uptime_seconds': DateTime.now().toUtc().difference(startedAt).inSeconds,
    'busy': runner.isBusy,
    'config': config.toJson(),
  });

  Future<Response> _serverLog(Request request) async {
    final linesParam = request.url.queryParameters['lines'];
    final n = int.tryParse(linesParam ?? '5000') ?? 5000;

    final logFiles = <File>[];
    for (var i = defaultMaxFiles - 1; i >= 1; i--) {
      final f = File(path.join(config.dataDir, 'server.log.$i'));
      if (f.existsSync()) logFiles.add(f);
    }
    final current = File(path.join(config.dataDir, 'server.log'));
    if (current.existsSync()) logFiles.add(current);

    final allLines = <String>[];
    for (final file in logFiles) {
      try {
        final lines = await file.readAsLines();
        allLines.addAll(lines);
      } catch (_) {}
    }

    final tail = n >= allLines.length
        ? allLines
        : allLines.sublist(allLines.length - n);
    return Response.ok(
      tail.join('\n'),
      headers: {'content-type': 'text/plain'},
    );
  }

  Future<Response> _listSessions(Request request) async {
    final ids = await sessionStore.listSessionIds();
    final summaries = <Map<String, dynamic>>[];
    for (final id in ids) {
      final status = await sessionStore.readStatus(id);
      if (status != null) {
        summaries.add(status.toJson());
      }
    }
    return _json(summaries);
  }

  Future<Response> _submitSession(Request request) async {
    final String raw;
    try {
      raw = await request.readAsString();
    } catch (e) {
      return _json({'error': 'Failed to read request body: $e'}, status: 400);
    }

    if (raw.trim().isEmpty) {
      return _json({'error': 'Request body must not be empty'}, status: 400);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      return _json({'error': 'Invalid JSON: $e'}, status: 400);
    }

    if (decoded is! Map<String, dynamic>) {
      return _json({
        'error': 'session.json must be a JSON object',
      }, status: 400);
    }

    final SessionSpec spec;
    try {
      spec = SessionSpec.fromJson(decoded);
    } on FormatException catch (e) {
      return _json({'error': e.message}, status: 400);
    }

    final now = DateTime.now().toUtc();
    final timestamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}Z';

    final slug = spec.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final sessionId = '${timestamp}__$slug';

    final sessionDir = sessionStore.sessionDir(sessionId);
    await sessionDir.create(recursive: true);

    await sessionStore.writeAtomic(
      sessionStore.sessionSpecFile(sessionId),
      const JsonEncoder.withIndent('  ').convert(spec.toJson()),
    );

    final status = SessionStatus.initial(
      sessionId: sessionId,
      roundsPlanned: spec.rounds,
    );
    await sessionStore.writeStatus(status);

    return _json({
      'session_id': sessionId,
      'status': status.toJson(),
    }, status: 201);
  }

  Future<Response> _discoverSessions(Request request) async {
    await sessionStore.discoverNewSessions();

    final accept = request.headers['accept'] ?? '';
    if (accept.contains('text/html')) {
      return Response.seeOther(Uri.parse('/'));
    }

    return _json({'status': 'ok'});
  }

  Future<Response> _sessionDetail(Request request, String id) async {
    final status = await sessionStore.readStatus(id);
    if (status == null) {
      return _json({'error': 'Session "$id" not found'}, status: 404);
    }

    Map<String, dynamic> spec;
    try {
      spec = (await sessionStore.readSessionSpec(id)).toJson();
    } catch (_) {
      spec = {};
    }

    return _json({'session': spec, 'status': status.toJson()});
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
        'error': 'Session is already in terminal state ${status.state.name}',
      }, status: 409);
    }

    await sessionStore.writeStatus(
      status.transitionTo(SessionState.cancelled, reason: 'Cancelled via API.'),
    );

    return _json({'status': 'cancelling'}, status: 202);
  }

  Future<Response> _requeueSession(Request request, String id) async {
    final status = await sessionStore.readStatus(id);
    if (status == null) {
      return _json({'error': 'Session "$id" not found'}, status: 404);
    }

    await sessionStore.writeStatus(
      status.transitionTo(SessionState.queued, roundsCompleted: 0),
    );

    return _json({'status': 'queued'}, status: 200);
  }

  Future<Response> _deviceProbe(Request request) async {
    final adb = Adb(adbPath: config.adbPath, deviceAddress: config.dutAddress);
    if (!await adb.connect()) {
      return _json({
        'error': 'Failed to connect to device at ${config.dutAddress}',
      }, status: 503);
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
    Request request,
    String id,
    String trial,
    String file,
  ) async {
    if (file.contains('..') || file.contains('/')) {
      return Response.forbidden('Invalid filename');
    }

    final resultsDir = sessionStore.trialResultsDir(id, trial);
    final resultFile = File(path.join(resultsDir.path, file));

    if (!await resultFile.exists()) {
      return _json({'error': 'Result file not found'}, status: 404);
    }

    return Response.ok(
      resultFile.openRead(),
      headers: {'content-type': 'text/plain'},
    );
  }

  Future<Response> _sessionLog(Request request, String id) async {
    final logFile = sessionStore.sessionLogFile(id);
    if (!await logFile.exists()) {
      return _json({'error': 'Log not found'}, status: 404);
    }

    return Response.ok(
      logFile.openRead(),
      headers: {'content-type': 'text/plain'},
    );
  }

  Future<Response> _serveTrialArtifact(
    Request request,
    String id,
    String trial,
  ) async {
    final segments = request.url.pathSegments;
    final fileName = segments.last;

    if (!['adb.log', 'logcat.txt', 'trial.json'].contains(fileName)) {
      return Response.notFound('Not a trial artifact');
    }

    final trialDir = sessionStore.trialDir(id, trial);
    final file = File(path.join(trialDir.path, fileName));

    if (!await file.exists()) {
      return _json({'error': 'File not found'}, status: 404);
    }

    final contentType = fileName.endsWith('.json')
        ? 'application/json'
        : 'text/plain';
    return Response.ok(file.openRead(), headers: {'content-type': contentType});
  }
}
