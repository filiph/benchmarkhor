import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:adb_server/api.dart';
import 'package:adb_server/config.dart';
import 'package:adb_server/job_store.dart';

final _log = Logger('adb_server');

Future<void> main(List<String> arguments) async {
  Logger.root.onRecord.listen((record) {
    stderr.writeln(
      '${record.time.toIso8601String()} '
      '[${record.level.name}] ${record.loggerName}: ${record.message}',
    );
  });

  final Config config;
  try {
    config = Config.fromEnvironment(Platform.environment);
  } on StateError catch (e) {
    stderr.writeln('Configuration error: ${e.message}');
    exitCode = 1;
    return;
  }
  Logger.root.level = Level.LEVELS.firstWhere(
    (l) => l.name.toLowerCase() == config.logLevel.toLowerCase(),
    orElse: () => Level.INFO,
  );

  final jobStore = JobStore(config.dataDir);
  await Directory(jobStore.jobsDir.path).create(recursive: true);

  _log.info('Recovering interrupted jobs (if any)...');
  await jobStore.recoverInterruptedJobs();

  _log.info('Discovering jobs dropped directly onto the filesystem...');
  await jobStore.discoverNewJobs();

  final api = Api(config: config, jobStore: jobStore);
  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(api.router.call);

  final server = await shelf_io.serve(handler, '0.0.0.0', config.port);
  _log.info(
    'adb_server listening on ${server.address.host}:${server.port} '
    '(DUT: ${config.dutAddress}, data dir: ${config.dataDir})',
  );
}
