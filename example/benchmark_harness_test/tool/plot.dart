#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';

class ChartGenerator {
  final List<List<double>> data = [];
  final Map<int, String> titles = {};
  final Map<int, String> colors = {
    1: "#0072B2",
    2: "#F0E442",
    3: "#009E73",
    4: "#CC79A7",
    5: "#D55E00",
    6: "#eeeeee"
  };

  final int chartWidth = 320;
  final int legendWidth = 300;
  final int height = 120;
  final int xMargin = 0;
  final int yMargin = 5;
  final int gutter = 30;
  final int fontSize = 15;
  final int lineHeight = 20;

  bool hasTitle(List<String> fields) {
    for (var field in fields) {
      if (!RegExp(r'^[-0-9.]+$').hasMatch(field)) {
        return true;
      }
    }
    return false;
  }

  int amax(Map<int, double> values) {
    int maxIndex = -1;
    double maxValue = double.negativeInfinity;

    values.forEach((index, value) {
      if (maxIndex == -1 || value > maxValue) {
        maxIndex = index;
        maxValue = value;
      }
    });

    return maxIndex;
  }

  void normalize() {
    Map<int, double> maxValues = {};
    Map<int, double> minValues = {};
    Map<int, double> deltas = {};

    for (int i = 0; i < data[0].length; i++) {
      maxValues[i] = double.negativeInfinity;
      minValues[i] = double.infinity;

      for (int j = 0; j < data.length; j++) {
        maxValues[i] = max(maxValues[i]!, data[j][i]);
        minValues[i] = min(minValues[i]!, data[j][i]);
      }

      deltas[i] = maxValues[i]! - minValues[i]!;

      for (int j = 0; j < data.length; j++) {
        data[j][i] -= minValues[i]!;
        if (deltas[i]! > 0) {
          data[j][i] /= deltas[i]!;
        }
      }
    }

    // Rescale to center around 0 (optional, not implemented here)

    // Squish data slightly in descending order of deltas
    int k = 0;
    double? prevDelta;

    while (deltas.isNotEmpty) {
      int i = amax(deltas);

      if (prevDelta != null &&
          prevDelta.toStringAsFixed(3) != deltas[i]!.toStringAsFixed(3)) {
        k++;
      }

      double scale = (data[0].length + 2 - k) / (data[0].length + 2);

      if (scale != 1) {
        for (int j = 0; j < data.length; j++) {
          data[j][i] *= scale;
        }
      }

      prevDelta = deltas[i];
      deltas.remove(i);
    }
  }

  String point(double x, double y) {
    double svgX = x * (chartWidth - 2 * xMargin) + xMargin;
    double svgY = (height - 2 * yMargin) - y * (height - 2 * yMargin) + yMargin;
    return "${svgX.round()},${svgY.round()}";
  }

  String line(int i) {
    StringBuffer buffer = StringBuffer();
    buffer.write(
        "  <polyline stroke='${colors[i]}ff' stroke-width='1.5' fill='none' points='");

    for (int j = 0; j < data.length; j++) {
      buffer.write("${point((j) / data.length, data[j][i])} ");
    }

    buffer.write("'/>");
    return buffer.toString();
  }

  String circles(int i) {
    StringBuffer buffer = StringBuffer();

    for (int j = 0; j < data.length; j++) {
      String p = point((j) / data.length, data[j][i]);
      List<String> q = p.split(",");
      buffer.write(
          "  <circle cx='${q[0]}' cy='${q[1]}' r='1.2' fill='${colors[i]}ff' stroke='${colors[i]}ff'/>\n");
    }

    return buffer.toString();
  }

  String legendText(int i, String title, double min, double max) {
    StringBuffer buffer = StringBuffer();
    buffer.write(
        "  <g transform='translate(${chartWidth + gutter}, ${i * lineHeight})'>\n");
    buffer.write(
        "    <circle cx='-10' cy='${-lineHeight ~/ 2 + 5}' r='3.5' fill='${colors[i]}' stroke='${colors[i]}'/>\n");
    buffer.write(
        "    <text style='fill: #eeeeee; font-size: ${fontSize}px; font-family: mono' xml:space='preserve'>");
    buffer.write(
        "$title [${min.toStringAsFixed(3)}, ${max.toStringAsFixed(3)}]</text>\n");
    buffer.write("  </g>\n");
    return buffer.toString();
  }

  void display() {
    print("<?xml version='1.0'?>");
    print(
        "<svg xmlns='http://www.w3.org/2000/svg' width='${chartWidth + gutter + legendWidth}' height='$height' version='1.1'>");

    int titleWidth =
        titles.values.fold(0, (prev, element) => max(prev, element.length));

    for (int i = 0; i < data[0].length; i++) {
      print(circles(i));
    }

    if (titles.isNotEmpty) {
      for (int i = 0; i < data[0].length; i++) {
        print(legendText(i, titles[i] ?? "", 0, 1)); // Adjust min/max as needed
      }
    }

    print("</svg>");
  }

  void processInput(List<String> lines) {
    bool firstLine = true;

    for (var line in lines) {
      List<String> fields = line.split(RegExp(r'\s+'));

      if (firstLine) {
        firstLine = false;
        if (hasTitle(fields)) {
          for (int i = 0; i < fields.length; i++) {
            titles[i] = fields[i];
          }
          continue;
        }
      }

      List<double> row = fields.map((e) => double.tryParse(e) ?? 0.0).toList();
      data.add(row);
    }
  }
}

void main() async {
  ChartGenerator generator = ChartGenerator();
  final List<String> inputLines;
  if (false) {
    inputLines = await stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .toList();
  } else {
    inputLines = File('test_data.txt').readAsLinesSync();
  }
  generator.processInput(inputLines);
  generator.normalize();
  generator.display();
}
