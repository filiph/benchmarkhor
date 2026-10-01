/// Spatial geometry and dimension specifications for rendering a plot.
class PlotLayout {
  /// The total width of the SVG canvas.
  final double width;

  /// The total height of the SVG canvas.
  final double height;

  /// Creates a plot layout with the given [width] and [height].
  const PlotLayout({this.width = 900, this.height = 700});

  /// The left margin in pixels.
  double get marginLeft => 80;

  /// The right margin in pixels.
  double get marginRight => 40;

  /// The top margin in pixels.
  double get marginTop => 40;

  /// The bottom margin in pixels.
  double get marginBottom => 50;

  /// The width of the inner plot area available for rendering data.
  double get plotWidth => width - marginLeft - marginRight;

  /// The height of the inner plot area available for rendering data.
  double get plotHeight => height - marginTop - marginBottom;

  /// The y coordinate corresponding to the bottom edge of the inner plot area.
  double get plotBottom => marginTop + plotHeight;

  /// The x coordinate corresponding to the right edge of the inner plot area.
  double get plotRight => marginLeft + plotWidth;
}
