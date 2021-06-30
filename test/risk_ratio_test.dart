import 'package:benchmarkhor/comparison.dart';
import 'package:test/test.dart';

void main() {
  test('moderate exercise example computes', () {
    // From:
    // https://sphweb.bumc.bu.edu/otlt/mph-modules/bs/bs704_confidence_intervals/bs704_confidence_intervals8.html
    final risk = RiskRatio.fromPrevalence(50, 9, 49, 20);
    expect(risk.ratio, closeTo(0.44, 0.001));
    expect(risk.lower, closeTo(0.2227, 0.01));
    expect(risk.upper, closeTo(0.869331, 0.01));
    expect(risk.isSignificant, isTrue);
  });

  test('pain reliever example computes', () {
    // From the exercise at the bottom of page:
    // https://sphweb.bumc.bu.edu/otlt/mph-modules/bs/bs704_confidence_intervals/bs704_confidence_intervals8.html
    final risk = RiskRatio.fromPrevalence(50, 23, 50, 11);
    expect(risk.ratio, closeTo(2.09, 0.001));
    expect(risk.lower, closeTo(1.14, 0.01));
    expect(risk.upper, closeTo(3.82, 0.01));
    expect(risk.isSignificant, isTrue);
  });

  group('statistical significance', () {
    test('negative (low difference)', () {
      final risk = RiskRatio.fromPrevalence(5000, 42, 5000, 43);
      expect(risk.isSignificant, isFalse);
    });

    test('negative (few data)', () {
      final risk = RiskRatio.fromPrevalence(45, 42, 45, 39);
      expect(risk.isSignificant, isFalse);
    });

    test('positive', () {
      final risk = RiskRatio.fromPrevalence(100, 42, 100, 10);
      expect(risk.isSignificant, isTrue);
    });
  });
}
