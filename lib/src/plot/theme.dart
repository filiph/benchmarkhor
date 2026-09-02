/// Visual presentation scheme for plots.
enum PlotTheme {
  dark(
    axisLine: '#ccc',
    gridLine: '#333',
    zeroLine: '#eee',
    primaryText: '#eee',
    secondaryText: '#ccc',
    mutedText: '#aaa',
    boxPlot: 'white',
  ),
  light(
    axisLine: '#333',
    gridLine: '#e0e0e0',
    zeroLine: '#111',
    primaryText: '#111',
    secondaryText: '#444',
    mutedText: '#777',
    boxPlot: 'black',
  );

  final String axisLine;
  final String gridLine;
  final String zeroLine;
  final String primaryText;
  final String secondaryText;
  final String mutedText;
  final String boxPlot;

  const PlotTheme({
    required this.axisLine,
    required this.gridLine,
    required this.zeroLine,
    required this.primaryText,
    required this.secondaryText,
    required this.mutedText,
    required this.boxPlot,
  });

  static PlotTheme fromName(String name) {
    return switch (name.toLowerCase()) {
      'light' => PlotTheme.light,
      'dark' => PlotTheme.dark,
      _ => throw ArgumentError.value(name, 'theme', 'Unknown plot theme: $name'),
    };
  }
}
