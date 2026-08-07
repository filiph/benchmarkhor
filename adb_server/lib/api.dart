import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'models.dart';
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
  final DateTime startedAt = DateTime.now().toUtc();

  Api({required this.config, required this.sessionStore});

  Router get router {
    final router = Router();

    router.get('/health', _health);
    router.get('/api/sessions', _listSessions);
    router.get('/api/sessions/<id>', _sessionDetail);

    return router;
  }

  Response _json(Object? body, {int status = 200}) => Response(
        status,
        body: const JsonEncoder.withIndent('  ').convert(body),
        headers: {'content-type': 'application/json'},
      );

  Response _health(Request request) => _json({
        'status': 'ok',
        'uptime_seconds':
            DateTime.now().toUtc().difference(startedAt).inSeconds,
        // A single trial is never in flight yet in this early version, since
        // the runner (REQUIREMENTS.md §6) is not implemented.
        'busy': false,
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
}
