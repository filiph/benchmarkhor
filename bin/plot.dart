import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:benchmarkhor/src/plot/commands/line_command.dart';
import 'package:benchmarkhor/src/plot/commands/violin_command.dart';

void main(List<String> arguments) async {
  final runner =
      CommandRunner<void>('plot', 'Render benchmark .dat files as SVG charts.')
        ..addCommand(ViolinCommand())
        ..addCommand(LineCommand());

  try {
    final topLevelResults = runner.parse(arguments);
    if (topLevelResults.command == null) {
      throw UsageException('Missing subcommand for "plot".', runner.usage);
    }
    await runner.runCommand(topLevelResults);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
