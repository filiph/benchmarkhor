import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config.dart';
import 'job_store.dart';
import 'models.dart';

/// Builds the shelf [Router] exposing the HTTP API described in
/// `REQUIREMENTS.md` §5.
///
/// Only the read-only, "beginnings" surface is implemented so far:
/// `/health` and `GET /api/jobs`(`/<id>`). Job submission, cancellation,
/// `/api/queue/next`, the device probe, and the status page are not
/// implemented yet -- see `REQUIREMENTS.md` for their full specification.
class Api {
  final Config config;
  final JobStore jobStore;
  final DateTime startedAt = DateTime.now().toUtc();

  Api({required this.config, required this.jobStore});

  Router get router {
    final router = Router();

    router.get('/health', _health);
    router.get('/api/jobs', _listJobs);
    router.get('/api/jobs/<id>', _jobDetail);

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
        // A single run is never in flight yet in this early version, since
        // the runner (REQUIREMENTS.md §6) is not implemented.
        'busy': false,
        'config': config.toJson(),
      });

  Future<Response> _listJobs(Request request) async {
    await jobStore.discoverNewJobs();

    final stateFilter = request.url.queryParameters['state'];
    final jobIds = (await jobStore.listJobIds()).reversed;

    final summaries = <Map<String, dynamic>>[];
    for (final jobId in jobIds) {
      final status = await jobStore.readStatus(jobId);
      if (status == null) continue;
      if (stateFilter != null && status.state.name != stateFilter) continue;
      summaries.add(status.toJson());
    }

    return _json({'jobs': summaries});
  }

  Future<Response> _jobDetail(Request request, String id) async {
    final status = await jobStore.readStatus(id);
    if (status == null) {
      return _json({'error': 'Job "$id" not found'}, status: 404);
    }

    Map<String, dynamic>? spec;
    try {
      spec = (await jobStore.readJobSpec(id)).toJson();
    } on FormatException catch (e) {
      spec = null;
      // Fall through: an invalid job.json is still reported via status.
      assert(status.state == JobState.invalid || e.message.isNotEmpty);
    }

    return _json({
      'job': spec,
      'status': status.toJson(),
    });
  }
}
