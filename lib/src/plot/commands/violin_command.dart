import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:benchmarkhor/src/plot/dat_parser.dart';
import 'package:benchmarkhor/src/plot/labels.dart';
import 'package:benchmarkhor/src/plot/violin/violin_data.dart';
import 'package:benchmarkhor/src/plot/violin/violin_renderer.dart';

class ViolinCommand extends Command<void> {
  @override
  final String name = 'violin';

  @override
  final String description =
      'Render one or more .dat files as a violin/box plot SVG.';

  ViolinCommand() {
    argParser
      ..addOption(
        'max-outlier-coefficient',
        help: 'How many IQRs above the median to set the y-axis limit.',
        defaultsTo: '3.0',
      )
      ..addFlag(
        'remove-common-prefix',
        help: 'Find and remove common prefix (split on _) from labels.',
        defaultsTo: true,
        negatable: true,
      );
  }

  @override
  void run() {
    final inputs = argResults!.rest;
    final maxOutlierCoefficient =
        double.tryParse(argResults!['max-outlier-coefficient'] as String) ??
        3.0;
    final removeCommonPrefix =
        argResults!['remove-common-prefix'] as bool? ?? true;

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

    final svg = buildViolinSvg(violins);
    stdout.write(svg);
  }
}
