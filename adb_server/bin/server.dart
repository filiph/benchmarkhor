import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:adb_server/api.dart';
import 'package:adb_server/config.dart';
import 'package:adb_server/logging.dart';
import 'package:adb_server/runner.dart';
import 'package:adb_server/session_store.dart';
import 'package:path/path.dart' as p;

final _log = Logger('adb_server');

Future<void> main(List<String> arguments) async {
  final Config config;
  try {
    config = Config.fromEnvironment(Platform.environment);
  } on StateError catch (e) {
    stderr.writeln('Configuration error: ${e.message}');
    exitCode = 1;
    return;
  }

  final fileLogger = RotatingFileLogger(p.join(config.dataDir, 'server.log'));

  Logger.root.onRecord.listen((record) {
    final message =
        '${record.time.toIso8601String()} '
        '[${record.level.name}] ${record.loggerName}: ${record.message}';
    stderr.writeln(message);
    fileLogger.log(message);
  });
  Logger.root.level = Level.LEVELS.firstWhere(
    (l) => l.name.toLowerCase() == config.logLevel.toLowerCase(),
    orElse: () => Level.INFO,
  );

  final sessionStore = SessionStore(config.dataDir);
  await Directory(sessionStore.sessionsDir.path).create(recursive: true);

  _log.info('Recovering interrupted sessions (if any)...');
  await sessionStore.recoverInterruptedSessions();

  _log.info('Discovering sessions dropped directly onto the filesystem...');
  await sessionStore.discoverNewSessions();

  final runner = Runner(config: config, sessionStore: sessionStore);

  final api = Api(config: config, sessionStore: sessionStore, runner: runner);
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(api.router.call);

  final server = await shelf_io.serve(handler, '0.0.0.0', config.port);
  _log.info(
    'adb_server listening on ${server.address.host}:${server.port} '
    '(DUT: ${config.dutAddress}, data dir: ${config.dataDir})',
  );
}
