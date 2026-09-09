import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/env.dart';
import '../models/property_model.dart';
import '../models/recommendation_model.dart';
import '../utils/affordability_context.dart';

class AIRecommendationService {
  AIRecommendationService._();

  static const String _apiUrl = '${Env.openAiBaseUrl}/chat/completions';
  static const int _targetCount = 5;
  static const Duration _timeout = Duration(seconds: 55);

  static const Map<String, List<String>> _featureKeywords = {
    'Near LRT/MRT': ['lrt', 'mrt', 'ktm', 'station', 'transit', 'monorail'],
    'Parking': ['parking', 'car park', 'carpark', 'garage'],
    'Swimming Pool': ['pool', 'swimming'],
    'Gym': ['gym', 'fitness'],
    'Security': ['security', 'guard', 'cctv', 'gated', '24-hour', '24 hour'],
    'Near School': ['school', 'college', 'university', 'kindergarten'],
    'High Floor': ['high floor', 'upper floor', 'top floor'],
    'Garden': ['garden', 'playground', 'landscaped', 'park'],
    'Sea View': ['sea view', 'seaview', 'ocean view', 'beachfront'],
    'Balcony': ['balcony'],
    'Furnished': ['furnished'],
    'Pet Friendly': ['pet'],
  };

  static Future<RecommendationResult> recommend({
    required RecommendationRequest request,
    required List<PropertyModel> properties,
  }) async {
    if (properties.isEmpty) {
      return RecommendationResult(
        recommendations: const [],
        summary: 'No listings are available in the database right now.',
        advice: 'Please try again later, or browse the Home tab to see what '
            'has been published.',
        isFallback: true,
        financialSnapshot: request.affordability,
        request: request,
      );
    }

    final eligible = _filterExcluded(properties, request.excludedLocations);
    if (eligible.isEmpty) {
      final excluded = request.excludedLocations.join(', ');
      return RecommendationResult(
        recommendations: const [],
        summary: excluded.isEmpty
            ? 'No listings are available in the database right now.'
            : 'No listings match your preferences after excluding $excluded.',
        advice: excluded.isEmpty
            ? 'Please try again later, or browse the Home tab to see what '
                'has been published.'
            : 'Try relaxing other preferences or removing an area exclusion.',
        isFallback: true,
        financialSnapshot: request.affordability,
        request: request,
      );
    }

    final locationFiltered = _filterPreferredLocations(eligible, request.locations);
    if (request.locations.isNotEmpty && locationFiltered.isEmpty) {
      return RecommendationResult(
        recommendations: const [],
        summary: 'No listings found in ${request.locations.join(', ')} '
            'that match your current criteria.',
        advice: 'Try widening your budget, picking another property type, '
            'or adding a nearby area in quick setup.',
        isFallback: true,
        financialSnapshot: request.affordability,
        request: request,
      );
    }

    final pool = request.locations.isNotEmpty ? locationFiltered : eligible;
    final scored = _rankLocally(request, pool);
    final buckets = _buildCandidateBuckets(scored, request);
    final candidates = buckets.allUnique;

    if (!_hasApiKey) {
      return _localResult(
        request,
        candidates,
        note: 'OpenAI API key is not configured, so these matches were '
            'ranked by the built-in scoring rules.',
      );
    }

    try {
      final result = await _askOpenAI(request, buckets);
      if (result != null && !result.isEmpty) return result;
    } catch (e) {
      debugPrint('AI recommendation error: $e');
    }

    return _localResult(
      request,
      candidates,
      note: 'The AI service could not be reached, so these matches were '
          'ranked by the built-in scoring rules.',
    );
  }

  static bool get _hasApiKey =>
      Env.openAiApiKey.isNotEmpty &&
      Env.openAiApiKey != 'YOUR_OPENAI_API_KEY_HERE';


  static Future<RecommendationResult?> _askOpenAI(
    RecommendationRequest request,
    _CandidateBuckets buckets,
  ) async {
    final response = await http
        .post(
          Uri.parse(_apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${Env.openAiApiKey}',
          },
          body: jsonEncode({
            'model': Env.gptModel,
            'response_format': {'type': 'json_object'},
            'temperature': 0.4,
            'max_tokens': 2200,
            'messages': [
              {'role': 'system', 'content': _systemPrompt},
              {
                'role': 'user',
                'content': _buildUserPrompt(request, buckets),
              },
            ],
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      debugPrint('OpenAI ${response.statusCode}: ${response.body}');
      return null;
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final content = body['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.trim().isEmpty) return null;

    return _parseResult(content, buckets.allUnique, request);
  }

  static const String _systemPrompt = '''
You are a Malaysian property advisor. You are given a buyer profile, loan/DSR
estimates per listing, and grouped candidate listings. Act as a financial advisor,
not a search filter.

Rules:
- Recommend 3 to 5 listings, ordered best first.
- Only use listing_id values from the provided lists. Never invent a listing.
- Every recommendation reason MUST mention affordability (DSR, monthly installment,
  or budget fit) AND at least one preference (purpose, location, type, bedrooms).
- Do not merely restate that a listing matches a filter; explain trade-offs.
- NEVER recommend listings in excluded areas. These are hard constraints.
- When preferred locations are specified, ONLY recommend listings in those areas.
  All provided candidates are already in the buyer's preferred areas.
- A listing slightly above budget is allowed when worth it. Mark "over_budget": true.
- If too few listings match type or budget, relax those preferences and explain in relaxed_note.
  Do NOT relax location when preferred locations are specified.
- Include 1-2 near_misses: high-potential listings that almost fit but have one gap.
- Write advisor_summary about the buyer's financial position (2-3 sentences).
- List trade_offs as bullet strings (what you prioritized vs sacrificed).
- Use rejected_note to explain why strong local matches were skipped, if any.
- Write in English, keep each reason under 50 words.

Reply with JSON only:
{
  "advisor_summary": "2-3 sentences on buyer finances",
  "summary": "one or two sentences about the shortlist",
  "trade_offs": ["string", "string"],
  "rejected_note": "string or null",
  "relaxed_note": "string or null",
  "advice": "string or null",
  "near_misses": [
    {
      "listing_id": "string",
      "gap": "what is missing",
      "worth_considering": true
    }
  ],
  "recommendations": [
    {
      "listing_id": "string",
      "match_score": 0,
      "over_budget": false,
      "reason": "why this fits this buyer",
      "highlights": ["short tag", "short tag"]
    }
  ]
}
''';

  static String _buildUserPrompt(
    RecommendationRequest request,
    _CandidateBuckets buckets,
  ) {
    final budget = request.budget;
    final buyer = request.affordability;

    final buffer = StringBuffer()
      ..writeln('BUYER PROFILE')
      ..writeln('- Purpose of purchase: ${request.purpose}')
      ..writeln('- Budget range: ${request.priceRange} '
          '(min RM${budget.min ?? 0}, '
          'max ${budget.max == null ? 'no upper limit' : 'RM${budget.max}'})')
      ..writeln('- Preferred property types: ${_orAny(request.propertyTypes)}')
      ..writeln('- Preferred bedrooms: ${request.bedrooms}')
      ..writeln('- Preferred locations: ${_orAny(request.locations)}')
      ..writeln('- Excluded locations (NEVER recommend): ${_orAny(request.excludedLocations)}')
      ..writeln('- Must-have features: ${_orAny(request.mustHaveFeatures)}');

    if (request.monthlyIncome > 0) {
      buffer.writeln(buyer.formatForPrompt());
    }

    void writeBucket(String title, List<_ScoredProperty> items) {
      if (items.isEmpty) return;
      buffer
        ..writeln()
        ..writeln('$title (${items.length}):')
        ..writeln(jsonEncode(
          items.map((c) => c.toPromptJson(buyer)).toList(),
        ));
    }

    writeBucket('STRONG MATCH (top local scores)', buckets.strongMatch);
    writeBucket('SLIGHTLY OVER BUDGET (may still be worth it)', buckets.overBudget);
    if (request.locations.isEmpty) {
      writeBucket('LOCATION RELAXED (outside preferred area)', buckets.locationRelaxed);
    }
    writeBucket('NEAR MISSES (high score but one gap)', buckets.nearMiss);

    buffer
      ..writeln()
      ..writeln('Pick the best 3 to $_targetCount listings for this buyer. '
          'Explain cross-bucket trade-offs and return the JSON from the system message.');

    return buffer.toString();
  }

  static String _orAny(List<String> values) =>
      values.isEmpty ? 'No preference' : values.join(', ');

  static RecommendationResult? _parseResult(
    String content,
    List<_ScoredProperty> candidates,
    RecommendationRequest request,
  ) {
    final decoded = jsonDecode(_stripCodeFence(content));
    if (decoded is! Map<String, dynamic>) return null;

    final byId = {for (final c in candidates) c.property.listingId: c.property};
    final items = decoded['recommendations'];
    if (items is! List) return null;

    final recommendations = <PropertyRecommendation>[];
    for (final item in items) {
      if (item is! Map) continue;

      final property = byId[item['listing_id']?.toString()];
      if (property == null) continue;
      if (_matchesExcludedArea(property, request.excludedLocations)) continue;
      if (!_matchesPreferredArea(property, request.locations)) continue;

      final reason = item['reason']?.toString().trim() ?? '';
      recommendations.add(PropertyRecommendation(
        property: property,
        reason: reason.isEmpty
            ? 'Recommended as one of the closest matches to your preferences.'
            : reason,
        matchScore: _asScore(item['match_score']),
        highlights: item['highlights'] is List
            ? (item['highlights'] as List)
                .map((h) => h.toString().trim())
                .where((h) => h.isNotEmpty)
                .take(4)
                .toList()
            : const [],
        overBudget: item['over_budget'] == true,
      ));
    }

    if (recommendations.isEmpty) return null;

    final nearMisses = <NearMissRecommendation>[];
    final nearItems = decoded['near_misses'];
    if (nearItems is List) {
      for (final item in nearItems) {
        if (item is! Map) continue;
        final property = byId[item['listing_id']?.toString()];
        if (property == null) continue;
        if (_matchesExcludedArea(property, request.excludedLocations)) continue;
        if (!_matchesPreferredArea(property, request.locations)) continue;
        nearMisses.add(NearMissRecommendation(
          property: property,
          gap: item['gap']?.toString().trim() ?? 'Does not fully match',
          worthConsidering: item['worth_considering'] == true,
        ));
      }
    }

    final tradeOffs = decoded['trade_offs'] is List
        ? (decoded['trade_offs'] as List)
            .map((t) => t.toString().trim())
            .where((t) => t.isNotEmpty)
            .toList()
        : const <String>[];

    return RecommendationResult(
      recommendations: recommendations,
      summary: decoded['summary']?.toString().trim() ?? '',
      advisorSummary: _nullableText(decoded['advisor_summary']),
      relaxedNote: _nullableText(decoded['relaxed_note']),
      rejectedNote: _nullableText(decoded['rejected_note']),
      advice: _nullableText(decoded['advice']),
      tradeOffs: tradeOffs,
      nearMisses: nearMisses,
      financialSnapshot: request.affordability,
      request: request,
    );
  }

  static String _stripCodeFence(String content) {
    final trimmed = content.trim();
    if (!trimmed.startsWith('```')) return trimmed;

    final start = trimmed.indexOf('\n');
    final end = trimmed.lastIndexOf('```');
    if (start == -1 || end <= start) return trimmed;
    return trimmed.substring(start + 1, end).trim();
  }

  static int? _asScore(dynamic value) {
    final score = value is num ? value.toInt() : int.tryParse('$value');
    if (score == null) return null;
    return score.clamp(0, 100);
  }

  static String? _nullableText(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }


  static List<PropertyModel> _filterPreferredLocations(
    List<PropertyModel> properties,
    List<String> preferred,
  ) {
    if (preferred.isEmpty) return properties;
    return properties
        .where((p) => _matchesPreferredArea(p, preferred))
        .toList();
  }

  static const Map<String, List<String>> _locationKeywords = {
    'klcc': ['klcc', 'kuala lumpur city centre', 'bukit bintang'],
    'mont kiara': ['mont kiara', 'montkiara', 'kiara'],
    'penang': ['penang', 'george town', 'georgetown', 'bayan lepas'],
    'johor bahru': ['johor bahru', 'johor', 'jb', 'iskandar'],
    'shah alam': ['shah alam', 'seksyen'],
    'subang jaya': ['subang jaya', 'subang', 'ss15', 'ss16', 'usj'],
    'cheras': ['cheras', 'balakong', 'taman midah'],
    'puchong': ['puchong', 'bandar puteri', 'kinrara'],
    'petaling jaya': ['petaling jaya', 'pj ', ' damansara', 'kelana jaya'],
    'putrajaya': ['putrajaya', 'presint'],
  };

  static bool _matchesPreferredArea(
    PropertyModel property,
    List<String> preferred,
  ) {
    if (preferred.isEmpty) return true;

    final haystack = [
      property.fullAddress,
      property.district,
      property.state,
    ].whereType<String>().join(' ').toLowerCase();
    if (haystack.isEmpty) return false;

    return preferred.any((area) => _areaMatchesHaystack(area, haystack));
  }

  static bool _areaMatchesHaystack(String area, String haystack) {
    final label = area.trim().toLowerCase();
    if (label.isEmpty) return false;

    final needles = <String>[label, ...?_locationKeywords[label]];
    return needles.any((needle) => needle.isNotEmpty && haystack.contains(needle));
  }

  static List<PropertyModel> _filterExcluded(
    List<PropertyModel> properties,
    List<String> excluded,
  ) {
    if (excluded.isEmpty) return properties;
    return properties
        .where((p) => !_matchesExcludedArea(p, excluded))
        .toList();
  }

  static bool _matchesExcludedArea(
    PropertyModel property,
    List<String> excluded,
  ) {
    if (excluded.isEmpty) return false;

    final haystack = [
      property.fullAddress,
      property.district,
      property.state,
    ].whereType<String>().join(' ').toLowerCase();
    if (haystack.isEmpty) return false;

    return excluded.any((area) => _areaMatchesHaystack(area, haystack));
  }

  static List<_ScoredProperty> _rankLocally(
    RecommendationRequest request,
    List<PropertyModel> properties,
  ) {
    final scored = properties
        .map((p) => _ScoredProperty.evaluate(p, request))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  static RecommendationResult _localResult(
    RecommendationRequest request,
    List<_ScoredProperty> candidates, {
    required String note,
  }) {
    final picks = candidates
        .where((c) => !_matchesExcludedArea(c.property, request.excludedLocations))
        .take(_targetCount)
        .toList();
    final buyer = request.affordability;

    if (picks.isEmpty) {
      return RecommendationResult(
        recommendations: const [],
        summary: note,
        advisorSummary: buyer.monthlyIncome > 0
            ? 'Based on your income of RM${buyer.monthlyIncome.round()} and '
                'current DSR of ${buyer.currentDsrPercent.toStringAsFixed(1)}%, '
                'we could not find suitable listings in the database.'
            : null,
        advice: 'Try widening your budget range or selecting more areas.',
        isFallback: true,
        financialSnapshot: buyer,
        request: request,
      );
    }

    final budget = request.budget;
    final anyRelaxed = picks.any((p) => p.missedPreferences.isNotEmpty);

    final nearMisses = candidates
        .where((c) =>
            !picks.contains(c) &&
            !_matchesExcludedArea(c.property, request.excludedLocations) &&
            c.score >= 0.55 &&
            c.missedPreferences.length == 1)
        .take(2)
        .map((c) => NearMissRecommendation(
              property: c.property,
              gap: 'Trade-off on ${c.missedPreferences.join(' and ')}',
              worthConsidering: c.score >= 0.65,
            ))
        .toList();

    return RecommendationResult(
      recommendations: picks
          .map((p) {
            final afford = PropertyAffordability.forPrice(
              price: p.property.price,
              buyer: buyer,
            );
            final highlights = <String>[
              ...p.matchedFeatures.take(2),
              if (afford.monthlyInstallment > 0)
                'Est. RM${afford.monthlyInstallment.round()}/mo',
              if (afford.dsrPercent > 0)
                'DSR ${afford.dsrPercent.toStringAsFixed(0)}%',
            ];
            return PropertyRecommendation(
              property: p.property,
              reason: p.buildReason(request, buyer),
              matchScore: (p.score * 100).round(),
              highlights: highlights.take(4).toList(),
              overBudget:
                  budget.max != null && (p.property.price ?? 0) > budget.max!,
            );
          })
          .toList(),
      summary: note,
      advisorSummary: buyer.monthlyIncome > 0
          ? 'Your monthly income is RM${buyer.monthlyIncome.round()} with '
              '${buyer.currentDsrPercent.toStringAsFixed(1)}% DSR before a new loan. '
              'Recommended budget: RM${buyer.recommendedBudget.round()}.'
          : null,
      tradeOffs: anyRelaxed
          ? [
              'Prioritized listings closest to your stated budget and area',
              'Some picks relax location, type, or features where needed',
            ]
          : const [],
      relaxedNote: anyRelaxed
          ? 'Not every listing ticks all your boxes, so the closest options '
              'are shown and the gaps are called out in each reason.'
          : null,
      nearMisses: nearMisses,
      isFallback: true,
      financialSnapshot: buyer,
      request: request,
    );
  }

  static _CandidateBuckets _buildCandidateBuckets(
    List<_ScoredProperty> scored,
    RecommendationRequest request,
  ) {
    final budget = request.budget;
    final seen = <String>{};

    bool take(_ScoredProperty item) => seen.add(item.property.listingId);

    final strongMatch = <_ScoredProperty>[];
    final overBudget = <_ScoredProperty>[];
    final locationRelaxed = <_ScoredProperty>[];
    final nearMiss = <_ScoredProperty>[];

    for (final item in scored) {
      if (strongMatch.length >= 15) break;
      if (item.missedPreferences.isEmpty ||
          (item.missedPreferences.length == 1 &&
              item.missedPreferences.first == 'features')) {
        if (take(item)) strongMatch.add(item);
      }
    }

    for (final item in scored) {
      if (overBudget.length >= 5) break;
      final price = item.property.price;
      if (budget.max != null &&
          price != null &&
          price > budget.max! &&
          item.score >= 0.45 &&
          take(item)) {
        overBudget.add(item);
      }
    }

    for (final item in scored) {
      if (locationRelaxed.length >= 5) break;
      if (request.locations.isEmpty &&
          !item.locationMatched &&
          item.score >= 0.5 &&
          take(item)) {
        locationRelaxed.add(item);
      }
    }

    for (final item in scored) {
      if (nearMiss.length >= 5) break;
      if (item.missedPreferences.length == 1 &&
          item.score >= 0.55 &&
          take(item)) {
        nearMiss.add(item);
      }
    }

    for (final item in scored) {
      if (strongMatch.length >= 15) break;
      if (take(item)) strongMatch.add(item);
    }

    return _CandidateBuckets(
      strongMatch: strongMatch,
      overBudget: overBudget,
      locationRelaxed: locationRelaxed,
      nearMiss: nearMiss,
    );
  }
}

class _CandidateBuckets {
  _CandidateBuckets({
    required this.strongMatch,
    required this.overBudget,
    required this.locationRelaxed,
    required this.nearMiss,
  });

  final List<_ScoredProperty> strongMatch;
  final List<_ScoredProperty> overBudget;
  final List<_ScoredProperty> locationRelaxed;
  final List<_ScoredProperty> nearMiss;

  List<_ScoredProperty> get allUnique => [
        ...strongMatch,
        ...overBudget,
        ...locationRelaxed,
        ...nearMiss,
      ];
}

class _ScoredProperty {
  _ScoredProperty({
    required this.property,
    required this.score,
    required this.matchedFeatures,
    required this.missedPreferences,
    required this.locationMatched,
    required this.typeMatched,
  });

  final PropertyModel property;
  final double score;
  final List<String> matchedFeatures;
  final List<String> missedPreferences;
  final bool locationMatched;
  final bool typeMatched;

  factory _ScoredProperty.evaluate(
    PropertyModel property,
    RecommendationRequest request,
  ) {
    final missed = <String>[];

    final priceScore = _priceScore(property.price, request.budget);
    if (priceScore < 0.6) missed.add('budget');

    final typeMatched = _matchesType(property, request.propertyTypes);
    final typeScore = request.propertyTypes.isEmpty
        ? 0.6
        : (typeMatched ? 1.0 : 0.2);
    if (request.propertyTypes.isNotEmpty && !typeMatched) missed.add('type');

    final locationMatched =
        AIRecommendationService._matchesPreferredArea(property, request.locations);
    final locationScore = request.locations.isEmpty
        ? 0.6
        : (locationMatched ? 1.0 : 0.15);
    if (request.locations.isNotEmpty && !locationMatched) missed.add('area');

    final bedroomScore = _bedroomScore(property.bedrooms, request.bedrooms);

    final matchedFeatures =
        _matchedFeatures(property, request.mustHaveFeatures);
    final featureScore = request.mustHaveFeatures.isEmpty
        ? 0.6
        : matchedFeatures.length / request.mustHaveFeatures.length;
    if (request.mustHaveFeatures.isNotEmpty &&
        matchedFeatures.length < request.mustHaveFeatures.length) {
      missed.add('features');
    }

    final score = priceScore * 0.35 +
        locationScore * 0.25 +
        typeScore * 0.20 +
        bedroomScore * 0.10 +
        featureScore * 0.10;

    return _ScoredProperty(
      property: property,
      score: score,
      matchedFeatures: matchedFeatures,
      missedPreferences: missed,
      locationMatched: locationMatched,
      typeMatched: typeMatched,
    );
  }

  static double _priceScore(int? price, BudgetRange budget) {
    if (price == null || price <= 0) return 0.3;

    final min = budget.min;
    final max = budget.max;
    if (max == null) return price >= (min ?? 0) ? 1.0 : 0.5;
    if (price > max) {
      final overshoot = price / max;
      if (overshoot <= 1.1) return 0.75;
      if (overshoot <= 1.25) return 0.5;
      if (overshoot <= 1.5) return 0.3;
      return 0.05;
    }
    if (min != null && price < min) return price >= min * 0.7 ? 0.8 : 0.55;
    return 1.0;
  }

  static double _bedroomScore(int? bedrooms, int preferred) {
    if (bedrooms == null || bedrooms <= 0) return 0.5;

    final diff = (bedrooms - preferred).abs();
    if (diff == 0) return 1.0;
    if (diff == 1) return 0.75;
    if (diff == 2) return 0.45;
    return 0.2;
  }

  static bool _matchesType(PropertyModel property, List<String> preferred) {
    final type = property.propertyType?.toLowerCase() ?? '';
    if (type.isEmpty) return false;

    for (final wanted in preferred) {
      final needle = wanted.toLowerCase();
      if (type.contains(needle)) return true;
      if (needle == 'apartment' && type.contains('condo')) return true;
      if (needle == 'condominium' && type.contains('apartment')) return true;
      if (needle == 'semi-d' && type.contains('semi')) return true;
    }
    return false;
  }

  static List<String> _matchedFeatures(
    PropertyModel property,
    List<String> wanted,
  ) {
    if (wanted.isEmpty) return const [];

    final haystack = [
      property.facilities,
      property.description,
      property.propertyType,
    ].whereType<String>().join(' ').toLowerCase();
    if (haystack.isEmpty) return const [];

    return wanted.where((feature) {
      final keywords = AIRecommendationService._featureKeywords[feature] ??
          [feature.toLowerCase()];
      return keywords.any(haystack.contains);
    }).toList();
  }

  Map<String, dynamic> toPromptJson(BuyerAffordabilitySnapshot buyer) {
    final afford = PropertyAffordability.forPrice(
      price: property.price,
      buyer: buyer,
    );
    return {
      'listing_id': property.listingId,
      'price': property.price,
      'type': property.propertyType,
      'beds': property.bedrooms,
      'baths': property.bathrooms,
      'size': property.builtUp,
      'address': _truncate(property.fullAddress, 90),
      'district': property.district,
      'state': property.state,
      'tenure': property.tenure,
      'facilities': _truncate(property.facilities?.replaceAll('|', ', '), 140),
      'local_score': double.parse((score * 100).toStringAsFixed(0)),
      'missed_preferences': missedPreferences,
      ...afford.toPromptJson(),
    }..removeWhere((_, value) => value == null);
  }

  static String? _truncate(String? text, int max) {
    if (text == null || text.isEmpty) return null;
    return text.length <= max ? text : '${text.substring(0, max)}…';
  }

  String buildReason(
    RecommendationRequest request,
    BuyerAffordabilitySnapshot buyer,
  ) {
    final parts = <String>[];
    final price = property.price;
    final budget = request.budget;
    final afford = PropertyAffordability.forPrice(price: price, buyer: buyer);

    if (afford.monthlyInstallment > 0) {
      parts.add(
        'estimated monthly installment RM${afford.monthlyInstallment.round()} '
        '(DSR ${afford.dsrPercent.toStringAsFixed(0)}%)',
      );
    }
    if (price != null && price > 0) {
      if (budget.max != null && price > budget.max!) {
        final over = price - budget.max!;
        parts.add('RM$over above your ${request.priceRange} range');
      } else if (afford.withinRecommendedBudget) {
        parts.add('within your recommended budget');
      }
    }
    if (typeMatched && property.propertyType != null) {
      parts.add('a ${property.propertyType} for your ${request.purpose} goal');
    }
    if (locationMatched) {
      parts.add('in your preferred area (${property.shortAddress})');
    }
    if (property.bedrooms != null) {
      parts.add('${property.bedrooms} bedrooms vs ${request.bedrooms} preferred');
    }
    if (matchedFeatures.isNotEmpty) {
      parts.add('offers ${matchedFeatures.join(', ')}');
    }
    if (missedPreferences.isNotEmpty) {
      parts.add('trade-off on ${missedPreferences.join(' and ')}');
    }

    if (parts.isEmpty) {
      return 'One of the closest listings to your preferences currently available.';
    }
    final sentence = parts.join('; ');
    return '${sentence[0].toUpperCase()}${sentence.substring(1)}.';
  }
}
