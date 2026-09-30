import 'dart:io';

import 'package:benchmarkhor/src/local_runner/host_probe.dart';
import 'package:test/test.dart';

void main() {
  group('MacHostProbe helpers', () {
    test('parseThermalPressure parses notifyutil output', () {
      expect(
        MacHostProbe.parseThermalPressure('com.apple.system.thermalpressurelevel 0'),
        equals('0'),
      );
      expect(
        MacHostProbe.parseThermalPressure('com.apple.system.thermalpressurelevel 2\n'),
        equals('2'),
      );
      expect(MacHostProbe.parseThermalPressure('3'), equals('3'));
      expect(MacHostProbe.parseThermalPressure(''), equals('unknown'));
    });

    test('parseSwVers parses macOS product and version info', () {
      const swVersOut = '''
ProductName:		macOS
ProductVersion:		15.1
BuildVersion:		24B83
''';
      expect(
        MacHostProbe.parseSwVers(swVersOut),
        equals('macOS 15.1 (24B83)'),
      );
    });

    test('parseLoadAvg parses uptime output', () {
      const uptime = '20:42  up 11 days,  8:43, 1 user, load averages: 2.80 2.88 2.85';
      expect(MacHostProbe.parseLoadAvg(uptime), equals('2.80 2.88 2.85'));
    });

    test('probe with mocked commands returns complete telemetry', () async {
      final probe = MacHostProbe(
        commandExecutor: (executable, args) async {
          if (executable == 'notifyutil') {
            return ProcessResult(1, 0, 'com.apple.system.thermalpressurelevel 0\n', '');
          }
          if (executable == 'sysctl' && args.contains('hw.model')) {
            return ProcessResult(2, 0, 'MacBookPro18,1\n', '');
          }
          if (executable == 'sysctl' && args.contains('machdep.cpu.brand_string')) {
            return ProcessResult(3, 0, 'Apple M1 Pro\n', '');
          }
          if (executable == 'sw_vers') {
            return ProcessResult(
              4,
              0,
              'ProductName:\tmacOS\nProductVersion:\t15.1\nBuildVersion:\t24B83\n',
              '',
            );
          }
          if (executable == 'uptime') {
            return ProcessResult(
              5,
              0,
              '10:00  up 1 day, 2 users, load averages: 1.50 1.25 1.10\n',
              '',
            );
          }
          return ProcessResult(99, 1, '', 'Unknown command');
        },
      );

      final telemetry = await probe.probe();
      expect(telemetry['thermal_pressure'], equals('0'));
      expect(telemetry['model'], equals('MacBookPro18,1'));
      expect(telemetry['cpu_brand'], equals('Apple M1 Pro'));
      expect(telemetry['os_version'], equals('macOS 15.1 (24B83)'));
      expect(telemetry['loadavg'], equals('1.50 1.25 1.10'));
      expect(telemetry['uptime'], contains('up 1 day'));
    });

    test('probe handles command failures gracefully', () async {
      final probe = MacHostProbe(
        commandExecutor: (executable, args) async {
          throw const ProcessException('fake', [], 'command not found');
        },
      );

      final telemetry = await probe.probe();
      expect(telemetry['thermal_pressure'], equals('unknown'));
      expect(telemetry['model'], equals('unknown'));
      expect(telemetry['os_version'], equals('macOS'));
      expect(telemetry['cpu_brand'], equals('unknown'));
    });

    test('probe on local host produces valid metadata on macOS', () async {
      if (!Platform.isMacOS) return;
      final probe = MacHostProbe();
      final telemetry = await probe.probe();
      expect(telemetry['thermal_pressure'], isNotNull);
      expect(telemetry['model'], isNotNull);
      expect(telemetry['os_version'], isNotNull);
    });
  });
}
