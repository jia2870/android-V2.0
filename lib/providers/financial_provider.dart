import 'package:flutter/material.dart';

class FinancialProvider extends ChangeNotifier {
  // Financial Data
  double monthlySalary = 0;
  double otherIncome = 0;
  double commitments = 0;
  double savings = 0;
  double downPayment = 0;

  // Debt details
  List<Debt> debts = [];

  // Asset details
  double totalSavings = 0;
  double downPaymentBudget = 0;

  double affordabilityScore = 0;
  double recommendedBudget = 0;
  String riskLevel = "Low";

  // Preference Match
  double preferenceMatchScore = 0;
  String matchLevel = "Medium";

  // Property Preferences
  String purpose = "Own Stay";
  String propertyType = "Apartment";
  String priceRange = "RM200k–300k";
  int bedrooms = 3;
  String preferredState = "Selangor";
  List<String> importantFactors = [];

  // ============================================
  // Public Methods
  // ============================================

  void updateFinancialData({
    required double salary,
    required double otherIncome,
    required double commitments,
    required double savings,
    required double downPayment,
  }) {
    this.monthlySalary = salary;
    this.otherIncome = otherIncome;
    this.commitments = commitments;
    this.savings = savings;
    this.downPayment = downPayment;
    _calculateAffordability();
    _calculatePreferenceMatch();
    notifyListeners();
  }

  // ============================================
  // Debt Management
  // ============================================

  void addDebt(Debt debt) {
    debts.add(debt);
    _recalculateCommitments();
    _calculateAffordability();
    _calculatePreferenceMatch();
    notifyListeners();
  }

  void removeDebt(int index) {
    debts.removeAt(index);
    _recalculateCommitments();
    _calculateAffordability();
    _calculatePreferenceMatch();
    notifyListeners();
  }

  void updateDebt(int index, Debt debt) {
    debts[index] = debt;
    _recalculateCommitments();
    _calculateAffordability();
    _calculatePreferenceMatch();
    notifyListeners();
  }

  void _recalculateCommitments() {
    commitments = debts.fold(0, (sum, debt) => sum + debt.monthlyPayment);
  }

  // ============================================
  // Asset Management
  // ============================================

  void updateSavings(double amount) {
    totalSavings = amount;
    savings = amount;
    _calculateAffordability();
    _calculatePreferenceMatch();
    notifyListeners();
  }

  void updateDownPayment(double amount) {
    downPaymentBudget = amount;
    downPayment = amount;
    _calculateAffordability();
    _calculatePreferenceMatch();
    notifyListeners();
  }

  // ============================================
  // Property Preferences
  // ============================================

  void updatePreferences({
    required String purpose,
    required String propertyType,
    required String priceRange,
    required int bedrooms,
    required String state,
    required List<String> factors,
  }) {
    this.purpose = purpose;
    this.propertyType = propertyType;
    this.priceRange = priceRange;
    this.bedrooms = bedrooms;
    this.preferredState = state;
    this.importantFactors = factors;
    _calculatePreferenceMatch();
    notifyListeners();
  }

  // ============================================
  // Private Calculation Methods
  // ============================================

  void _calculateAffordability() {
    double totalIncome = monthlySalary + otherIncome;
    if (totalIncome <= 0) {
      affordabilityScore = 0;
      recommendedBudget = 0;
      riskLevel = "Low";
      return;
    }

    double debtRatio = commitments / totalIncome;
    double score = (100 - (debtRatio * 100)).clamp(30.0, 95.0);
    affordabilityScore = score;

    double maxMonthlyPayment = (totalIncome * 0.55) - commitments;
    recommendedBudget = maxMonthlyPayment * 12 * 30 * 0.75 + savings * 0.6;

    if (debtRatio < 0.3) {
      riskLevel = "Low";
    } else if (debtRatio < 0.5) {
      riskLevel = "Medium";
    } else {
      riskLevel = "High";
    }
  }

  void _calculatePreferenceMatch() {
    if (recommendedBudget <= 0) {
      preferenceMatchScore = 0;
      matchLevel = "Low";
      return;
    }

    double score = 0;

    // 1. 价格范围匹配（权重 40%）
    double priceScore = _getPriceRangeScore();
    score += priceScore * 0.4;

    // 2. 卧室数匹配（权重 30%）
    double bedroomScore = _getBedroomScore();
    score += bedroomScore * 0.3;

    // 3. 房产类型匹配（权重 20%）
    double typeScore = _getPropertyTypeScore();
    score += typeScore * 0.2;

    // 4. 地区匹配（权重 10%）
    double stateScore = _getStateScore();
    score += stateScore * 0.1;

    preferenceMatchScore = score * 100;

    if (preferenceMatchScore >= 70) {
      matchLevel = "High";
    } else if (preferenceMatchScore >= 40) {
      matchLevel = "Medium";
    } else {
      matchLevel = "Low";
    }
  }

  // ============================================
  // Helper Methods for Preference Match
  // ============================================

  double _getPriceRangeScore() {
    if (priceRange.isEmpty) return 0.5;

    final numbers = priceRange
        .replaceAll('RM', '')
        .replaceAll('k', '000')
        .replaceAll('K', '000')
        .replaceAll('+', '');
    final parts = numbers.split('–');

    if (parts.length == 2) {
      final minPrice = _parsePriceString(parts[0]);
      final maxPrice = _parsePriceString(parts[1]);

      if (recommendedBudget >= minPrice && recommendedBudget <= maxPrice) {
        return 1.0;
      } else if (recommendedBudget < minPrice) {
        return 0.5;
      } else {
        return 0.7;
      }
    } else if (priceRange.contains('+')) {
      final minPrice = _parsePriceString(priceRange.replaceAll('+', ''));
      if (recommendedBudget >= minPrice) {
        return 1.0;
      } else {
        return 0.4;
      }
    }

    return 0.5;
  }

  double _parsePriceString(String value) {
    value = value.trim().replaceAll(',', '');
    if (value.contains('M')) {
      return double.parse(value.replaceAll('M', '')) * 1000000;
    }
    return double.tryParse(value) ?? 0;
  }

  double _getBedroomScore() {
    if (bedrooms <= 0) return 0.5;

    int affordableBedrooms = 1;
    if (recommendedBudget >= 200000) affordableBedrooms = 2;
    if (recommendedBudget >= 400000) affordableBedrooms = 3;
    if (recommendedBudget >= 700000) affordableBedrooms = 4;
    if (recommendedBudget >= 1000000) affordableBedrooms = 5;

    if (bedrooms <= affordableBedrooms) {
      return 1.0;
    } else if (bedrooms <= affordableBedrooms + 1) {
      return 0.7;
    } else {
      return 0.3;
    }
  }

  double _getPropertyTypeScore() {
    if (propertyType.isEmpty) return 0.5;

    final type = propertyType.toLowerCase();
    double budget = recommendedBudget;

    if (budget < 300000) {
      return type.contains('apartment') || type.contains('condo') ? 1.0 : 0.3;
    } else if (budget < 500000) {
      return type.contains('apartment') || type.contains('condo') || type.contains('terrace') ? 1.0 : 0.5;
    } else if (budget < 800000) {
      return type.contains('terrace') || type.contains('semi-d') ? 1.0 : 0.6;
    } else {
      return type.contains('bungalow') || type.contains('semi-d') ? 1.0 : 0.7;
    }
  }

  double _getStateScore() {
    if (preferredState.isEmpty) return 0.5;

    double budget = recommendedBudget;
    final state = preferredState.toLowerCase();

    if (state.contains('kuala lumpur') || state.contains('selangor') || state.contains('penang')) {
      if (budget >= 400000) {
        return 1.0;
      } else {
        return 0.4;
      }
    } else if (state.contains('johor') || state.contains('negeri sembilan')) {
      if (budget >= 300000) {
        return 1.0;
      } else {
        return 0.6;
      }
    } else {
      if (budget >= 200000) {
        return 1.0;
      } else {
        return 0.7;
      }
    }
  }

  // ============================================
  // Getter Properties
  // ============================================

  double get totalMonthlyIncome => monthlySalary + otherIncome;
  double get debtToIncomeRatio => totalMonthlyIncome > 0 ? commitments / totalMonthlyIncome : 0;
  List<Debt> get debtList => debts;

  double get totalDebt => debts.fold(0, (sum, d) => sum + d.totalAmount);
  double get totalAssets => savings + downPayment;

  // 获取匹配等级的颜色
  Color get matchColor {
    switch (matchLevel) {
      case 'High':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  // 获取匹配等级的图标
  IconData get matchIcon {
    switch (matchLevel) {
      case 'High':
        return Icons.check_circle;
      case 'Medium':
        return Icons.warning;
      default:
        return Icons.cancel;
    }
  }

  // ============================================
  // Clear Data
  // ============================================

  void clearAllData() {
    monthlySalary = 0;
    otherIncome = 0;
    commitments = 0;
    savings = 0;
    downPayment = 0;
    totalSavings = 0;
    downPaymentBudget = 0;
    affordabilityScore = 0;
    recommendedBudget = 0;
    riskLevel = "Low";
    preferenceMatchScore = 0;
    matchLevel = "Medium";
    debts = [];
    purpose = "Own Stay";
    propertyType = "Apartment";
    priceRange = "RM200k–300k";
    bedrooms = 3;
    preferredState = "Selangor";
    importantFactors = [];
    notifyListeners();
  }

  // ============================================
  // Recalculate Method (for external calls)
  // ============================================

  void recalculate() {
    _calculateAffordability();
    _calculatePreferenceMatch();
    notifyListeners();
  }
}

// ============================================
// Debt Model
// ============================================

class Debt {
  final String type;
  final String name;
  final double totalAmount;
  final double monthlyPayment;
  final double interestRate;
  final int remainingMonths;

  Debt({
    required this.type,
    required this.name,
    required this.totalAmount,
    required this.monthlyPayment,
    required this.interestRate,
    required this.remainingMonths,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'totalAmount': totalAmount,
    'monthlyPayment': monthlyPayment,
    'interestRate': interestRate,
    'remainingMonths': remainingMonths,
  };

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
    type: json['type'],
    name: json['name'],
    totalAmount: json['totalAmount'],
    monthlyPayment: json['monthlyPayment'],
    interestRate: json['interestRate'],
    remainingMonths: json['remainingMonths'],
  );
}