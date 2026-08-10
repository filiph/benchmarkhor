import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:benchmarkhor/src/plot/dat_parser.dart';
import 'package:benchmarkhor/src/plot/violin/violin_data.dart';
import 'package:benchmarkhor/src/plot/violin/violin_renderer.dart';

class ViolinCommand extends Command<void> {
  @override
  final String name = 'violin';

  @override
  final String description =
      'Render one or more .dat files as a violin/box plot SVG.';

  ViolinCommand() {
    argParser.addOption(
      'max-outlier-coefficient',
      help: 'How many IQRs above the median to set the y-axis limit.',
      defaultsTo: '3.0',
    );
  }

  @override
  void run() {
    final inputs = argResults!.rest;
    final maxOutlierCoefficient = double.tryParse(
          argResults!['max-outlier-coefficient'] as String,
        ) ??
        3.0;

    if (inputs.isEmpty) {
      usageException('At least one .dat file is required.');
    }

    final violins = <ViolinData>[];
    for (final path in inputs) {
      final values = parseDat(path);
      // Use the filename (without extension) as the label
      final label = path.split(Platform.pathSeparator).last.replaceAll(
            RegExp(r'\.dat$', caseSensitive: false),
            '',
          );
      violins.add(ViolinData.compute(
        label,
        values,
        maxOutlierCoefficient: maxOutlierCoefficient,
      ));
    }

    final svg = buildViolinSvg(violins);
    stdout.write(svg);
  }
}
