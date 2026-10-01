import 'dart:io';

import 'package:benchmarkhor/src/plot/commands/plot_command.dart';
import 'package:benchmarkhor/src/plot/dat_parser.dart';
import 'package:benchmarkhor/src/plot/labels.dart';
import 'package:benchmarkhor/src/plot/violin/violin_data.dart';
import 'package:benchmarkhor/src/plot/violin/violin_renderer.dart';

class ViolinCommand extends PlotCommand {
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
    final maxOutlierCoefficient =
        double.tryParse(argResults!['max-outlier-coefficient'] as String) ??
        3.0;

    if (inputs.isEmpty) {
      usageException('At least one .dat file is required.');
    }

    final labels = computeLabels(
      inputs,
      removeCommonPrefix: removeCommonPrefix,
    );

    final violins = <ViolinData>[];
    for (var i = 0; i < inputs.length; i++) {
      final path = inputs[i];
      final values = parseDat(path);
      final label = labels[i];
      violins.add(
        ViolinData.compute(
          label,
          values,
          maxOutlierCoefficient: maxOutlierCoefficient,
        ),
      );
    }

    final svg = buildViolinSvg(violins, theme: theme, layout: layout);
    stdout.write(svg);
  }
}
