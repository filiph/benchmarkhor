import 'package:args/command_runner.dart';
import 'package:benchmarkhor/src/plot/layout.dart';
import 'package:benchmarkhor/src/plot/theme.dart';

/// Base command for all plotting subcommands.
abstract class PlotCommand extends Command<void> {
  PlotCommand() {
    argParser
      ..addOption(
        'width',
        help: 'Width of the output SVG chart.',
        defaultsTo: '900',
      )
      ..addOption(
        'height',
        help: 'Height of the output SVG chart.',
        defaultsTo: '700',
      )
      ..addFlag(
        'remove-common-prefix',
        help: 'Find and remove common prefix (split on _) from labels.',
        defaultsTo: true,
        negatable: true,
      )
      ..addOption(
        'theme',
        help: 'Color theme for the plot.',
        allowed: ['dark', 'light'],
        defaultsTo: 'dark',
      );
  }

  /// Parses and validates the layout configuration from command line options.
  PlotLayout get layout {
    final widthStr = argResults!['width'] as String;
    final width = double.tryParse(widthStr);
    if (width == null || width <= 0) {
      usageException('--width must be a positive number, got "$widthStr".');
    }

    final heightStr = argResults!['height'] as String;
    final height = double.tryParse(heightStr);
    if (height == null || height <= 0) {
      usageException('--height must be a positive number, got "$heightStr".');
    }

    return PlotLayout(width: width, height: height);
  }

  /// The selected color theme for the plot.
  PlotTheme get theme {
    final themeName = argResults!['theme'] as String? ?? 'dark';
    return PlotTheme.fromName(themeName);
  }

  /// Whether to remove common prefix from labels.
  bool get removeCommonPrefix {
    return argResults!['remove-common-prefix'] as bool? ?? true;
  }
}
