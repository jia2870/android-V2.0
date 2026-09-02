import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_asg/utils/loan_calculator.dart';

void main() {
  group('LoanCalculator', () {
    test('monthly installment matches amortization for known inputs', () {
      final monthly = LoanCalculator.monthlyInstallment(
        principal: 693000,
        annualRatePercent: 3.8,
        tenureYears: 30,
      );
      expect(monthly, greaterThan(3200));
      expect(monthly, lessThan(3300));
    });

    test('zero interest splits principal evenly', () {
      final monthly = LoanCalculator.monthlyInstallment(
        principal: 120000,
        annualRatePercent: 0,
        tenureYears: 10,
      );
      expect(monthly, closeTo(1000, 0.01));
    });

    test('suggested loan uses 90% LTV', () {
      expect(LoanCalculator.suggestedLoanAmount(770000), 693000);
    });

    test('invalid inputs return zero', () {
      expect(
        LoanCalculator.monthlyInstallment(
          principal: 0,
          annualRatePercent: 3.8,
          tenureYears: 30,
        ),
        0,
      );
      expect(
        LoanCalculator.monthlyInstallment(
          principal: 100000,
          annualRatePercent: 3.8,
          tenureYears: 0,
        ),
        0,
      );
    });
  });
}
