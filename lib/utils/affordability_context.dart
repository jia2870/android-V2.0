import 'loan_calculator.dart';

class BuyerAffordabilitySnapshot {
  const BuyerAffordabilitySnapshot({
    required this.monthlyIncome,
    required this.commitments,
    required this.savings,
    required this.recommendedBudget,
  });

  final double monthlyIncome;
  final double commitments;
  final double savings;
  final double recommendedBudget;

  double get disposableIncome =>
      (monthlyIncome - commitments).clamp(0, double.infinity);

  double get currentDsrPercent {
    if (monthlyIncome <= 0) return 0;
    return (commitments / monthlyIncome * 100).clamp(0, 999);
  }

  double dsrWithInstallment(double monthlyInstallment) {
    if (monthlyIncome <= 0) return 0;
    return ((commitments + monthlyInstallment) / monthlyIncome * 100)
        .clamp(0, 999);
  }

  String formatForPrompt() {
    final buffer = StringBuffer()
      ..writeln('- Monthly income: RM${monthlyIncome.round()}')
      ..writeln('- Monthly commitments: RM${commitments.round()}')
      ..writeln('- Disposable income: RM${disposableIncome.round()}')
      ..writeln('- Savings: RM${savings.round()}')
      ..writeln('- Recommended property budget: RM${recommendedBudget.round()}')
      ..writeln(
          '- Current DSR (before new loan): ${currentDsrPercent.toStringAsFixed(1)}%');
    return buffer.toString();
  }
}

class PropertyAffordability {
  const PropertyAffordability({
    required this.loanAmount,
    required this.monthlyInstallment,
    required this.dsrPercent,
    required this.withinRecommendedBudget,
    required this.remainingDisposable,
  });

  final double loanAmount;
  final double monthlyInstallment;
  final double dsrPercent;
  final bool withinRecommendedBudget;
  final double remainingDisposable;

  static PropertyAffordability forPrice({
    required int? price,
    required BuyerAffordabilitySnapshot buyer,
    double annualRatePercent = LoanCalculator.defaultAnnualRatePercent,
    int tenureYears = LoanCalculator.defaultTenureYears,
  }) {
    if (price == null || price <= 0) {
      return const PropertyAffordability(
        loanAmount: 0,
        monthlyInstallment: 0,
        dsrPercent: 0,
        withinRecommendedBudget: false,
        remainingDisposable: 0,
      );
    }

    final loanAmount = LoanCalculator.suggestedLoanAmount(price.toDouble());
    final installment = LoanCalculator.monthlyInstallment(
      principal: loanAmount,
      annualRatePercent: annualRatePercent,
      tenureYears: tenureYears,
    );
    final dsr = buyer.dsrWithInstallment(installment);
    final remaining = buyer.disposableIncome - installment;

    return PropertyAffordability(
      loanAmount: loanAmount,
      monthlyInstallment: installment,
      dsrPercent: dsr,
      withinRecommendedBudget:
          buyer.recommendedBudget <= 0 || price <= buyer.recommendedBudget,
      remainingDisposable: remaining,
    );
  }

  Map<String, dynamic> toPromptJson() => {
        'est_loan_rm': loanAmount.round(),
        'est_monthly_installment_rm': monthlyInstallment.round(),
        'est_dsr_percent': double.parse(dsrPercent.toStringAsFixed(1)),
        'within_recommended_budget': withinRecommendedBudget,
        'remaining_disposable_rm': remainingDisposable.round(),
      };
}
