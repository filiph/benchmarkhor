import 'dart:convert';
import 'dart:typed_data';

import 'package:lzma/lzma.dart';

class BenchmarkResult {
  static const String _preamble = 'benchmarkhor format>';
  static final _preambleBytes = Uint8List.fromList(ascii.encode(_preamble));
  static const int currentFormatVersion = 1;
  static final _currentFormatVersionBytes =
      Uint16List.fromList([currentFormatVersion]);
  static const flutterProfileType = 'flutter-profile ';
  static const _typeStringLength = 16;

  /// User-provided label for the benchmark result. Can be empty.
  final String label;

  /// User-provided timestamp of the result. Must be in UTC.
  ///
  /// Generally, this is [DateTime.now().toUtc()] at the point of benchmark
  /// creation.
  final DateTime timestamp;

  /// The measurement series contained in the benchmark.
  ///
  /// For example, a single benchmark can have one set of data for CPU usage,
  /// and another set of data for GPU usage, or memory usage.
  ///
  /// By having these data points together in one benchmark, users can more
  /// easily see the whole picture.
  final List<MeasurementSeries> series;

  /// The type of the benchmark.
  ///
  /// In general, it only makes sense to compare two benchmarks of the same
  /// type. They should be gathered with the same methodology, and have
  /// the same [series].
  ///
  /// Currently, the only type is [flutterProfileType], and the value
  /// is ignored.
  ///
  /// Type *must* be 16 ASCII characters long. Feel free to pad by spaces.
  final String type;

  BenchmarkResult({
    required this.label,
    required this.timestamp,
    required this.series,
    this.type = flutterProfileType,
  })  : assert(timestamp.isUtc, 'Timestamp must be in UTC'),
        assert(
            type.length == _typeStringLength,
            'Type must be exactly $_typeStringLength characters long. '
            'Feel free to pad with spaces') {
    if (series.isEmpty) {
      throw Exception('BenchmarkResult cannot be created with zero series');
    }
  }

  factory BenchmarkResult.fromBytes(Uint8List bytes) {
    var offset = 0;

    final preambleBytes = bytes.buffer.asUint8List(0, _preambleBytes.length);
    final preamble = ascii.decode(preambleBytes);
    if (preamble != _preamble) {
      throw LoadException(
          "The file doesn't start with the correct preamble: $_preamble");
    }
    offset += preambleBytes.lengthInBytes;

    final version = bytes.buffer.asUint16List(offset, 1).single;
    if (version != currentFormatVersion) {
      // TODO: Support loading old versions when we have such a thing.
      throw LoadException(
          'The file is saved in an unsupported version format: $version. '
          "This program's supported version: $currentFormatVersion");
    }
    offset += Uint16List.bytesPerElement;

    final type =
        ascii.decode(bytes.buffer.asUint8List(offset, _typeStringLength));
    offset += _typeStringLength;

    // The data isn't 16-bit aligned, so we need to first create a copy
    // of the list that is just bytes, and then look at its buffer
    // as a 16-bit list.
    final labelLength = Uint8List.fromList(
            bytes.buffer.asUint8List(offset, Uint16List.bytesPerElement))
        .buffer
        .asUint16List()
        .single;
    offset += Uint16List.bytesPerElement;

    final labelBytes =
        Uint8List.fromList(bytes.buffer.asUint8List(offset, labelLength))
            .buffer
            .asUint16List();
    offset += labelBytes.lengthInBytes;
    final label = String.fromCharCodes(labelBytes);

    final timestampMilliseconds = Uint8List.fromList(
            bytes.buffer.asUint8List(offset, Uint64List.bytesPerElement))
        .buffer
        .asUint64List()
        .single;
    offset += Uint64List.bytesPerElement;
    final timestamp =
        DateTime.fromMillisecondsSinceEpoch(timestampMilliseconds, isUtc: true);

    final seriesCount = Uint8List.fromList(
            bytes.buffer.asUint8List(offset, Uint32List.bytesPerElement))
        .buffer
        .asUint32List()
        .single;
    offset += Uint32List.bytesPerElement;

    final seriesLengthsBytes = Uint8List.fromList(bytes.buffer
            .asUint8List(offset, seriesCount * Uint64List.bytesPerElement))
        .buffer
        .asUint64List();
    offset += seriesLengthsBytes.lengthInBytes;

    final series = List<MeasurementSeries>.generate(seriesCount, (index) {
      final seriesBytes = Uint8List.fromList(
              bytes.buffer.asUint8List(offset, seriesLengthsBytes[index]))
          .buffer
          .asUint8List();
      offset += seriesBytes.lengthInBytes;
      return MeasurementSeries.fromBytes(seriesBytes);
    }, growable: false);

    return BenchmarkResult(
      label: label,
      timestamp: timestamp,
      series: series,
      type: type,
    );
  }

  Uint8List toBytes() {
    // The format starts with a preamble and the version. See below
    // where all the bytes are stringed together.

    final typeBytes = ascii.encode(type);

    final labelBytes = Uint16List.fromList(label.codeUnits);
    final labelLengthBytes = Uint16List.fromList([labelBytes.lengthInBytes]);

    final timestampBytes =
        Uint64List.fromList([timestamp.millisecondsSinceEpoch]);

    final seriesCountBytes = Uint32List.fromList([series.length]);

    final seriesDataRanges = <Uint8List>[
      for (final s in series) s.toBytes(),
    ];

    final seriesLengthsBytes = Uint64List.fromList([
      for (final range in seriesDataRanges) range.lengthInBytes,
    ]);

    var buffer = _preambleBytes +
        _currentFormatVersionBytes.buffer.asUint8List() +
        typeBytes +
        labelLengthBytes.buffer.asUint8List() +
        labelBytes.buffer.asUint8List() +
        timestampBytes.buffer.asUint8List() +
        seriesCountBytes.buffer.asUint8List() +
        seriesLengthsBytes.buffer.asUint8List();

    for (final range in seriesDataRanges) {
      buffer += range.buffer.asUint8List();
    }

    return Uint8List.fromList(buffer);
  }
}

class LoadException implements Exception {
  final String message;

  const LoadException(this.message);
}

class MeasurementSeries {
  final String label;

  final List<int> measurements;

  MeasurementSeries(this.label, this.measurements) {
    if (measurements.isEmpty) {
      throw Exception('List of measurements in "$label" series is empty');
    }
  }

  factory MeasurementSeries.fromBytes(Uint8List bytes) {
    var offset = 0;

    final labelLength = bytes.buffer.asUint16List(offset, 1).single;
    offset += Uint16List.bytesPerElement;

    // The data isn't 16-bit aligned, so we need to first create a copy
    // of the list that is just bytes, and then look at its buffer
    // as a 16-bit list.
    final labelBytes =
        Uint8List.fromList(bytes.buffer.asUint8List(offset, labelLength))
            .buffer
            .asUint16List();
    final label = String.fromCharCodes(labelBytes);
    offset += labelBytes.lengthInBytes;

    final measurementLength = Uint8List.fromList(
            bytes.buffer.asUint8List(offset, Uint64List.bytesPerElement))
        .buffer
        .asUint64List()
        .single;
    offset += Uint64List.bytesPerElement;

    final measurementZippedBytes =
        bytes.buffer.asUint8List(offset, measurementLength);
    final measurementUnzippedBytes = lzma.decode(measurementZippedBytes);
    final measurements =
        Uint8List.fromList(measurementUnzippedBytes).buffer.asInt64List();

    assert(
        bytes.lengthInBytes ==
            Uint16List.bytesPerElement +
                labelLength +
                Uint64List.bytesPerElement +
                measurementLength,
        'The data length of $bytes is not equivalent to the sum of its parts');

    return MeasurementSeries(label, measurements);
  }

  Uint8List toBytes() {
    final labelBytes = Uint16List.fromList(label.codeUnits);
    final labelLengthBytes = Uint16List.fromList([labelBytes.lengthInBytes]);
    final measurementBytes =
        Int64List.fromList(measurements).buffer.asUint8List();
    final measurementZipped = Uint8List.fromList(lzma.encode(measurementBytes));
    final measurementLengthBytes =
        Uint64List.fromList([measurementZipped.lengthInBytes]);

    final buffer = Uint8List.fromList(labelLengthBytes.buffer.asUint8List() +
        labelBytes.buffer.asUint8List() +
        measurementLengthBytes.buffer.asUint8List() +
        measurementZipped);
    return buffer;
  }
}
