import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:benchmarkhor/src/plot/dat_parser.dart';
import 'package:benchmarkhor/src/plot/line/line_data.dart';
import 'package:benchmarkhor/src/plot/line/line_renderer.dart';

class LineCommand extends Command<void> {
  @override
  final String name = 'line';

  @override
  final String description =
      'Render one or more .dat files as a line plot SVG, one polyline per '
      'file, overlaid on shared axes.';

  @override
  void run() {
    final inputs = argResults!.rest;

    if (inputs.isEmpty) {
      usageException('At least one .dat file is required.');
    }

    final lines = <LineData>[];
    for (final path in inputs) {
      final values = parseDat(path);
      // Use the filename (without extension) as the label
      final label = path.split(Platform.pathSeparator).last.replaceAll(
            RegExp(r'\.dat$', caseSensitive: false),
            '',
          );
      lines.add(LineData.compute(label, values));
    }

    final svg = buildLineSvg(lines);
    stdout.write(svg);
  }
}
