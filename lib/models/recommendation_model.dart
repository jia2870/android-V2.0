import 'property_model.dart';
import '../utils/affordability_context.dart';

class RecommendationRequest {
  const RecommendationRequest({
    required this.purpose,
    required this.propertyTypes,
    required this.priceRange,
    required this.bedrooms,
    required this.locations,
    required this.mustHaveFeatures,
    this.excludedLocations = const [],
    this.monthlyIncome = 0,
    this.commitments = 0,
    this.savings = 0,
    this.recommendedBudget = 0,
  });

  final String purpose;
  final List<String> propertyTypes;

  final String priceRange;
  final int bedrooms;
  final List<String> locations;
  final List<String> mustHaveFeatures;
  final List<String> excludedLocations;
  final double monthlyIncome;
  final double commitments;
  final double savings;
  final double recommendedBudget;

  BudgetRange get budget => BudgetRange.parse(priceRange);

  BuyerAffordabilitySnapshot get affordability => BuyerAffordabilitySnapshot(
        monthlyIncome: monthlyIncome,
        commitments: commitments,
        savings: savings,
        recommendedBudget: recommendedBudget,
      );
}

class BudgetRange {
  const BudgetRange({this.min, this.max});

  final int? min;

  final int? max;

  static BudgetRange parse(String label) {
    final cleaned = label
        .replaceAll('RM', '')
        .replaceAll('–', '-')
        .replaceAll(' ', '');
    final isOpenEnded = cleaned.endsWith('+');
    final parts = cleaned.replaceAll('+', '').split('-');

    final min = _amount(parts.first);
    final max = (isOpenEnded || parts.length < 2) ? null : _amount(parts[1]);
    return BudgetRange(min: min, max: max);
  }

  static int? _amount(String token) {
    final match = RegExp(r'^([\d.]+)([kKmM]?)$').firstMatch(token);
    if (match == null) return null;

    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;

    switch (match.group(2)!.toLowerCase()) {
      case 'm':
        return (value * 1000000).round();
      case 'k':
        return (value * 1000).round();
      default:
        return value.round();
    }
  }

  String get label {
    if (min == null && max == null) return 'Any budget';
    if (max == null) return 'RM${min!} and above';
    return 'RM${min ?? 0} - RM$max';
  }
}

class PropertyRecommendation {
  const PropertyRecommendation({
    required this.property,
    required this.reason,
    this.matchScore,
    this.highlights = const [],
    this.overBudget = false,
  });

  final PropertyModel property;
  final String reason;

  final int? matchScore;
  final List<String> highlights;
  final bool overBudget;
}

class NearMissRecommendation {
  const NearMissRecommendation({
    required this.property,
    required this.gap,
    this.worthConsidering = false,
  });

  final PropertyModel property;
  final String gap;
  final bool worthConsidering;
}

class RecommendationResult {
  const RecommendationResult({
    required this.recommendations,
    this.summary = '',
    this.advisorSummary,
    this.relaxedNote,
    this.rejectedNote,
    this.advice,
    this.tradeOffs = const [],
    this.nearMisses = const [],
    this.financialSnapshot,
    this.isFallback = false,
    this.request,
  });

  final List<PropertyRecommendation> recommendations;
  final String summary;

  final String? advisorSummary;

  final String? relaxedNote;

  final String? rejectedNote;

  final String? advice;

  final List<String> tradeOffs;
  final List<NearMissRecommendation> nearMisses;
  final BuyerAffordabilitySnapshot? financialSnapshot;

  final RecommendationRequest? request;

  final bool isFallback;

  bool get isEmpty => recommendations.isEmpty;
}
