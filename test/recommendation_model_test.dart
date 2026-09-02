import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_asg/models/recommendation_model.dart';

void main() {
  group('BudgetRange.parse', () {
    test('reads a plain thousands range', () {
      final range = BudgetRange.parse('RM100k-200k');
      expect(range.min, 100000);
      expect(range.max, 200000);
    });

    test('reads a mixed thousands and millions range', () {
      final range = BudgetRange.parse('RM800k-1M');
      expect(range.min, 800000);
      expect(range.max, 1000000);
    });

    test('reads a fractional millions range', () {
      final range = BudgetRange.parse('RM1M-1.5M');
      expect(range.min, 1000000);
      expect(range.max, 1500000);
    });

    test('leaves the upper bound open for a "+" range', () {
      final range = BudgetRange.parse('RM1.5M+');
      expect(range.min, 1500000);
      expect(range.max, isNull);
    });

    test('accepts the en dash used by older saved rows', () {
      final range = BudgetRange.parse('RM200k–300k');
      expect(range.min, 200000);
      expect(range.max, 300000);
    });

    test('returns no bounds for an unrecognised label', () {
      final range = BudgetRange.parse('Any');
      expect(range.min, isNull);
      expect(range.max, isNull);
    });
  });
}
