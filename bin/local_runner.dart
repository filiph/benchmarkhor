import 'dart:io';

import 'package:args/args.dart';
import 'package:benchmarkhor/src/local_runner/models.dart';
import 'package:benchmarkhor/src/local_runner/runner.dart';
import 'package:benchmarkhor/src/local_runner/session_store.dart';
import 'package:logging/logging.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'timeout',
      abbr: 't',
      help: 'Trial timeout in seconds (overrides session.json).',
    )
    ..addFlag(
      'clean',
      abbr: 'c',
      help: 'Wipe existing trials and restart the session from round 1.',
      defaultsTo: false,
      negatable: false,
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Enable verbose debug logging.',
      defaultsTo: false,
      negatable: false,
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help.');

  final ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    print(parser.usage);
    exit(1);
  }

  if (argResults.flag('help') || argResults.rest.isEmpty) {
    print('Usage: dart bin/local_runner.dart <session-dir> [options]');
    print(parser.usage);
    exit(argResults.flag('help') ? 0 : 1);
  }

  if (argResults.flag('verbose')) {
    Logger.root.level = Level.ALL;
  } else {
    Logger.root.level = Level.INFO;
  }

  Logger.root.onRecord.listen((record) {
    final strBuf = StringBuffer();
    if (record.level != Level.INFO) {
      strBuf.write('${record.level.name}: ');
    }
    strBuf.write(record.message);
    if (record.level >= Level.SEVERE) {
      stderr.writeln(strBuf.toString());
    } else {
      stdout.writeln(strBuf.toString());
    }
  });

  final sessionDirPath = argResults.rest.first;
  final sessionDir = Directory(sessionDirPath);
  if (!sessionDir.existsSync()) {
    stderr.writeln('Error: session directory "$sessionDirPath" does not exist.');
    exit(1);
  }

  final store = LocalSessionStore(sessionDir.path);
  if (!store.sessionSpecFile.existsSync()) {
    stderr.writeln(
      'Error: session.json not found in directory "${sessionDir.path}".',
    );
    exit(1);
  }

  Duration? timeoutOverride;
  if (argResults['timeout'] != null) {
    final parsedSec = int.tryParse(argResults['timeout'] as String);
    if (parsedSec == null || parsedSec <= 0) {
      stderr.writeln('Error: --timeout must be a positive integer.');
      exit(1);
    }
    timeoutOverride = Duration(seconds: parsedSec);
  }

  final runner = LocalSessionRunner(
    store: store,
    timeoutOverride: timeoutOverride,
  );

  try {
    final status = await runner.run(clean: argResults.flag('clean'));
    if (status.state != LocalSessionState.completed) {
      exit(1);
    }
  } catch (e) {
    stderr.writeln('Error running local benchmark session: $e');
    exit(1);
  }
}
