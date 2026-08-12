import 'package:adb_server/device_probe.dart';
import 'package:test/test.dart';

void main() {
  group('ThermalServiceStatus', () {
    test('parses IsThrottling: true and Thermal Status level', () {
      final output = '''
IsThrottling: true
Thermal Status: 2
''';
      final status = ThermalServiceStatus.parse(output);
      expect(status.isThrottling, isTrue);
      expect(status.statusLevel, equals(2));
      expect(status.rawOutput, equals(output));
    });

    test('parses IsThrottling: false and Thermal Status: 0', () {
      final output = '''
IsThrottling: false
Thermal Status: 0
''';
      final status = ThermalServiceStatus.parse(output);
      expect(status.isThrottling, isFalse);
      expect(status.statusLevel, equals(0));
    });

    test('parses HAL Status when Thermal Status is absent', () {
      final output = '''
HAL Status: 1
''';
      final status = ThermalServiceStatus.parse(output);
      expect(status.isThrottling, isTrue);
      expect(status.statusLevel, equals(1));
    });

    test('defaults to false throttling when output is empty', () {
      final status = ThermalServiceStatus.parse('');
      expect(status.isThrottling, isFalse);
      expect(status.statusLevel, isNull);
    });

    test('serializes to json correctly', () {
      final status = ThermalServiceStatus(
        isThrottling: true,
        statusLevel: 3,
        rawOutput: 'Thermal Status: 3',
      );
      final json = status.toJson();
      expect(json['is_throttling'], isTrue);
      expect(json['status_level'], equals(3));
      expect(json['raw'], equals('Thermal Status: 3'));
    });
  });
}
