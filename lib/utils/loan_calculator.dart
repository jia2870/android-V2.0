class LoanCalculator {
  LoanCalculator._();

  static const double defaultAnnualRatePercent = 3.8;
  static const int defaultTenureYears = 30;
  static const double defaultLtvRatio = 0.9;

  static double monthlyInstallment({
    required double principal,
    required double annualRatePercent,
    required int tenureYears,
  }) {
    if (principal <= 0 || tenureYears <= 0) return 0;
    final months = tenureYears * 12;
    if (annualRatePercent <= 0) return principal / months;

    final r = annualRatePercent / 100 / 12;
    final factor = _pow(1 + r, months);
    return principal * r * factor / (factor - 1);
  }

  static double totalPayment({
    required double principal,
    required double annualRatePercent,
    required int tenureYears,
  }) {
    final monthly = monthlyInstallment(
      principal: principal,
      annualRatePercent: annualRatePercent,
      tenureYears: tenureYears,
    );
    if (monthly <= 0) return 0;
    return monthly * tenureYears * 12;
  }

  static double totalInterest({
    required double principal,
    required double annualRatePercent,
    required int tenureYears,
  }) {
    final total = totalPayment(
      principal: principal,
      annualRatePercent: annualRatePercent,
      tenureYears: tenureYears,
    );
    if (total <= 0) return 0;
    return (total - principal).clamp(0, double.infinity);
  }

  static double suggestedLoanAmount(double propertyPrice) {
    if (propertyPrice <= 0) return 0;
    return propertyPrice * defaultLtvRatio;
  }

  static double _pow(double base, int exp) {
    var result = 1.0;
    for (var i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }
}

class LoanCalculationResult {
  const LoanCalculationResult({
    required this.monthlyInstallment,
    required this.totalPayment,
    required this.totalInterest,
    required this.principal,
    required this.annualRatePercent,
    required this.tenureYears,
  });

  final double monthlyInstallment;
  final double totalPayment;
  final double totalInterest;
  final double principal;
  final double annualRatePercent;
  final int tenureYears;

  factory LoanCalculationResult.compute({
    required double principal,
    required double annualRatePercent,
    required int tenureYears,
  }) {
    return LoanCalculationResult(
      monthlyInstallment: LoanCalculator.monthlyInstallment(
        principal: principal,
        annualRatePercent: annualRatePercent,
        tenureYears: tenureYears,
      ),
      totalPayment: LoanCalculator.totalPayment(
        principal: principal,
        annualRatePercent: annualRatePercent,
        tenureYears: tenureYears,
      ),
      totalInterest: LoanCalculator.totalInterest(
        principal: principal,
        annualRatePercent: annualRatePercent,
        tenureYears: tenureYears,
      ),
      principal: principal,
      annualRatePercent: annualRatePercent,
      tenureYears: tenureYears,
    );
  }
}
