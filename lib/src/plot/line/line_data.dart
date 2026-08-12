import 'dart:io';

// ---------------------------------------------------------------------------
// Data for one line
// ---------------------------------------------------------------------------

class LineData {
  final String label;

  /// Values in file order (NOT sorted), unlike [ViolinData].
  final List<num> values;

  LineData({required this.label, required this.values});

  factory LineData.compute(String label, List<num> values) {
    if (values.isEmpty) {
      stderr.writeln('Warning: $label has no data.');
    }
    return LineData(label: label, values: values);
  }
}
