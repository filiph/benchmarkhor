import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:benchmarkhor/src/plot/dat_parser.dart';
import 'package:benchmarkhor/src/plot/labels.dart';
import 'package:benchmarkhor/src/plot/line/line_data.dart';
import 'package:benchmarkhor/src/plot/line/line_renderer.dart';

class LineCommand extends Command<void> {
  @override
  final String name = 'line';

  @override
  final String description =
      'Render one or more .dat files as a line plot SVG, one polyline per '
      'file, overlaid on shared axes.';

  LineCommand() {
    argParser.addFlag(
      'remove-common-prefix',
      help: 'Find and remove common prefix (split on _) from labels.',
      defaultsTo: true,
      negatable: true,
    );
  }

  @override
  void run() {
    final inputs = argResults!.rest;
    final removeCommonPrefix =
        argResults!['remove-common-prefix'] as bool? ?? true;

    if (inputs.isEmpty) {
      usageException('At least one .dat file is required.');
    }

    final labels = computeLabels(
      inputs,
      removeCommonPrefix: removeCommonPrefix,
    );

    final lines = <LineData>[];
    for (var i = 0; i < inputs.length; i++) {
      final path = inputs[i];
      final values = parseDat(path);
      final label = labels[i];
      lines.add(LineData.compute(label, values));
    }

    final svg = buildLineSvg(lines);
    stdout.write(svg);
  }
}
