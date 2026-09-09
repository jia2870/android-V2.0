import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/env.dart';
import '../models/recommendation_model.dart';
import '../services/ai_advisor_chat_service.dart';
import '../services/property_preference_service.dart';
import '../services/supabase_service.dart';
import '../utils/affordability_context.dart';

const String kExcludeLocationPrefix = 'exclude:';

class ExtractedPreferences {
  const ExtractedPreferences({
    required this.purpose,
    required this.propertyTypes,
    required this.priceRange,
    required this.bedrooms,
    required this.locations,
    required this.mustHaveFeatures,
    this.excludedLocations = const [],
    this.summary = '',
    this.confidence = 0.5,
    this.missingFields = const [],
  });

  final String purpose;
  final List<String> propertyTypes;
  final String priceRange;
  final int bedrooms;
  final List<String> locations;
  final List<String> mustHaveFeatures;
  final List<String> excludedLocations;
  final String summary;
  final double confidence;
  final List<String> missingFields;

  factory ExtractedPreferences.fromModel(PropertyPreferenceModel model) {
    final types = model.propertyType
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final locations = model.preferredState
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final rawFactors = model.importantFactors;
    final excluded = rawFactors
        .where((f) => f.toLowerCase().startsWith(kExcludeLocationPrefix))
        .map((f) => f.substring(kExcludeLocationPrefix.length).trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final features = rawFactors
        .where((f) => !f.toLowerCase().startsWith(kExcludeLocationPrefix))
        .toList();
    return ExtractedPreferences(
      purpose: model.purpose,
      propertyTypes: types.isEmpty ? ['Apartment'] : types,
      priceRange: model.priceRange.replaceAll('–', '-'),
      bedrooms: model.bedrooms,
      locations: locations,
      mustHaveFeatures: features,
      excludedLocations: excluded,
      summary: _summaryFromFields(
        purpose: model.purpose,
        types: types,
        priceRange: model.priceRange,
        bedrooms: model.bedrooms,
        locations: locations,
        excludedLocations: excluded,
      ),
      confidence: 0.8,
    );
  }

  RecommendationRequest toRequest({
    required double monthlyIncome,
    required double commitments,
    required double savings,
    required double recommendedBudget,
  }) {
    return RecommendationRequest(
      purpose: purpose,
      propertyTypes: propertyTypes,
      priceRange: priceRange,
      bedrooms: bedrooms,
      locations: locations,
      mustHaveFeatures: mustHaveFeatures,
      excludedLocations: excludedLocations,
      monthlyIncome: monthlyIncome,
      commitments: commitments,
      savings: savings,
      recommendedBudget: recommendedBudget,
    );
  }

  static String summaryFromFields({
    required String purpose,
    required List<String> types,
    required String priceRange,
    required int bedrooms,
    required List<String> locations,
    List<String> excludedLocations = const [],
  }) =>
      _summaryFromFields(
        purpose: purpose,
        types: types,
        priceRange: priceRange,
        bedrooms: bedrooms,
        locations: locations,
        excludedLocations: excludedLocations,
      );

  static String _summaryFromFields({
    required String purpose,
    required List<String> types,
    required String priceRange,
    required int bedrooms,
    required List<String> locations,
    List<String> excludedLocations = const [],
  }) {
    final typeStr = types.isEmpty ? 'property' : types.join(', ');
    final locStr = locations.isEmpty ? 'any area' : locations.join(', ');
    final excludeStr = excludedLocations.isEmpty
        ? ''
        : ' · excluding ${excludedLocations.join(', ')}';
    return '$purpose · $typeStr · $bedrooms bed · $priceRange · $locStr$excludeStr';
  }
}

class PreferenceExtractionService {
  PreferenceExtractionService._();

  static const String _apiUrl = '${Env.openAiBaseUrl}/chat/completions';
  static const Duration _timeout = Duration(seconds: 45);

  static const List<String> priceRangeLabels = [
    'RM100k-200k',
    'RM200k-300k',
    'RM300k-500k',
    'RM500k-800k',
    'RM800k-1M',
    'RM1M-1.5M',
    'RM1.5M+',
  ];

  static const List<String> _priceRangeLabels = priceRangeLabels;

  static const List<String> _validPurposes = ['Own Stay', 'Investment', 'Both'];
  static const List<String> _validTypes = [
    'Apartment',
    'Condominium',
    'Terrace',
    'Semi-D',
    'Bungalow',
  ];
  static const List<String> _validFeatures = [
    'Near LRT/MRT',
    'Parking',
    'Swimming Pool',
    'Gym',
    'Security',
    'Near School',
    'High Floor',
    'Garden',
    'Sea View',
  ];

  static bool get _hasApiKey =>
      Env.openAiApiKey.isNotEmpty &&
      Env.openAiApiKey != 'YOUR_OPENAI_API_KEY_HERE';

  static Future<ExtractedPreferences> extract({
    required List<AdvisorChatMessage> conversation,
    required BuyerAffordabilitySnapshot affordability,
    ExtractedPreferences? existing,
    List<String> savedPropertyHints = const [],
  }) async {
    if (_hasApiKey && conversation.any((m) => m.role == 'user')) {
      try {
        final parsed = await _extractWithOpenAI(
          conversation: conversation,
          affordability: affordability,
          existing: existing,
          savedPropertyHints: savedPropertyHints,
        );
        if (parsed != null) return parsed;
      } catch (e) {
        debugPrint('Preference extraction error: $e');
      }
    }

    return _fallbackExtract(
      conversation: conversation,
      affordability: affordability,
      existing: existing,
    );
  }

  static Future<ExtractedPreferences> extractAndSave({
    required String userId,
    required List<AdvisorChatMessage> conversation,
    required BuyerAffordabilitySnapshot affordability,
    ExtractedPreferences? existing,
    List<String> savedPropertyHints = const [],
  }) async {
    final extracted = await extract(
      conversation: conversation,
      affordability: affordability,
      existing: existing,
      savedPropertyHints: savedPropertyHints,
    );

    final service = PropertyPreferenceService();
    final model = PropertyPreferenceModel(
      id: '',
      userId: userId,
      purpose: extracted.purpose,
      propertyType: extracted.propertyTypes.join(', '),
      priceRange: extracted.priceRange,
      bedrooms: extracted.bedrooms,
      preferredState: extracted.locations.join(', '),
      importantFactors: [
        ...extracted.mustHaveFeatures,
        ...extracted.excludedLocations
            .map((e) => '$kExcludeLocationPrefix$e'),
      ],
    );
    await service.saveOrUpdatePreference(model);
    return extracted;
  }

  static Future<ExtractedPreferences?> _extractWithOpenAI({
    required List<AdvisorChatMessage> conversation,
    required BuyerAffordabilitySnapshot affordability,
    ExtractedPreferences? existing,
    required List<String> savedPropertyHints,
  }) async {
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
            'temperature': 0.2,
            'max_tokens': 800,
            'messages': [
              {'role': 'system', 'content': _systemPrompt},
              {
                'role': 'user',
                'content': _buildUserPrompt(
                  conversation: conversation,
                  affordability: affordability,
                  existing: existing,
                  savedPropertyHints: savedPropertyHints,
                ),
              },
            ],
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) return null;

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final content = body['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.trim().isEmpty) return null;

    return _parseJson(content, affordability, existing);
  }

  static const String _systemPrompt = '''
Extract property search preferences from a conversation with a Malaysian buyer.
Return JSON only:
{
  "purpose": "Own Stay" | "Investment" | "Both",
  "property_types": ["Apartment", ...],
  "price_range": "RM200k-300k" style label,
  "bedrooms": 3,
  "locations": ["KLCC", "Penang", ...],
  "excluded_locations": ["Putrajaya", ...],
  "must_have_features": ["Near LRT/MRT", ...],
  "summary": "one sentence describing what they want",
  "confidence": 0.0 to 1.0,
  "missing_fields": ["location", ...]
}
Use only allowed property types and feature labels from the user message.
If budget not stated, pick the closest range from recommended budget hint.
If the user says they do NOT want an area (e.g. "don't want Putrajaya", "no Putrajaya", "avoid Johor"), put it in excluded_locations, NOT in locations.
excluded_locations are hard constraints — never list them under locations.
''';

  static String _buildUserPrompt({
    required List<AdvisorChatMessage> conversation,
    required BuyerAffordabilitySnapshot affordability,
    ExtractedPreferences? existing,
    required List<String> savedPropertyHints,
  }) {
    final buffer = StringBuffer()
      ..writeln('FINANCIAL CONTEXT:')
      ..writeln(affordability.formatForPrompt())
      ..writeln('Suggested budget range if unstated: ${budgetToRange(affordability.recommendedBudget)}');

    if (existing != null) {
      buffer.writeln('PREVIOUS SAVED PREFERENCES: ${existing.summary}');
    }
    if (savedPropertyHints.isNotEmpty) {
      buffer.writeln('SAVED LISTINGS USER LIKED: ${savedPropertyHints.join('; ')}');
    }

    buffer.writeln('CONVERSATION:');
    for (final msg in conversation) {
      buffer.writeln('${msg.role}: ${msg.content}');
    }
    return buffer.toString();
  }

  static ExtractedPreferences? _parseJson(
    String content,
    BuyerAffordabilitySnapshot affordability,
    ExtractedPreferences? existing,
  ) {
    final decoded = jsonDecode(content.trim());
    if (decoded is! Map<String, dynamic>) return null;

    final types = _stringList(decoded['property_types']);
    final locations = _stringList(decoded['locations']);
    var excluded = _stringList(decoded['excluded_locations']);
    final features = _stringList(decoded['must_have_features'])
        .where(_validFeatures.contains)
        .toList();

    final excludedLower = excluded.map((e) => e.toLowerCase()).toSet();
    final filteredLocations = locations
        .where((l) => !excludedLower.contains(l.toLowerCase()))
        .toList();
    if (excluded.isEmpty) excluded = existing?.excludedLocations ?? [];

    var purpose = decoded['purpose']?.toString() ?? existing?.purpose ?? 'Own Stay';
    if (!_validPurposes.contains(purpose)) purpose = 'Own Stay';

    var priceRange = decoded['price_range']?.toString().replaceAll('–', '-');
    priceRange ??= existing?.priceRange;
    priceRange ??= budgetToRange(affordability.recommendedBudget);
    if (!_priceRangeLabels.contains(priceRange)) {
      priceRange = budgetToRange(affordability.recommendedBudget);
    }

    final bedrooms = _asInt(decoded['bedrooms']) ?? existing?.bedrooms ?? 3;

    return ExtractedPreferences(
      purpose: purpose,
      propertyTypes: types.isEmpty
          ? (existing?.propertyTypes ?? ['Apartment'])
          : types,
      priceRange: priceRange,
      bedrooms: bedrooms.clamp(1, 5),
      locations: filteredLocations.isEmpty
          ? (existing?.locations ?? [])
          : filteredLocations,
      mustHaveFeatures: features.isEmpty ? (existing?.mustHaveFeatures ?? []) : features,
      excludedLocations: excluded,
      summary: decoded['summary']?.toString().trim() ??
          ExtractedPreferences._summaryFromFields(
            purpose: purpose,
            types: types.isEmpty ? ['Apartment'] : types,
            priceRange: priceRange,
            bedrooms: bedrooms,
            locations: filteredLocations.isEmpty ? (existing?.locations ?? []) : filteredLocations,
            excludedLocations: excluded,
          ),
      confidence: (decoded['confidence'] is num)
          ? (decoded['confidence'] as num).toDouble().clamp(0, 1)
          : 0.7,
      missingFields: _stringList(decoded['missing_fields']),
    );
  }

  static ExtractedPreferences _fallbackExtract({
    required List<AdvisorChatMessage> conversation,
    required BuyerAffordabilitySnapshot affordability,
    ExtractedPreferences? existing,
  }) {
    final text = conversation
        .where((m) => m.role == 'user')
        .map((m) => m.content.toLowerCase())
        .join(' ');

    var purpose = existing?.purpose ?? 'Own Stay';
    if (text.contains('invest')) purpose = 'Investment';
    if (text.contains('both')) purpose = 'Both';

    final types = <String>[...?existing?.propertyTypes];
    for (final type in _validTypes) {
      if (text.contains(type.toLowerCase()) && !types.contains(type)) {
        types.add(type);
      }
    }
    if (text.contains('condo') && !types.contains('Condominium')) {
      types.add('Condominium');
    }
    if (types.isEmpty) types.add('Apartment');

    final locations = <String>[...?existing?.locations];
    const areaKeywords = {
      'klcc': 'KLCC',
      'mont kiara': 'Mont Kiara',
      'penang': 'Penang',
      'johor': 'Johor Bahru',
      'shah alam': 'Shah Alam',
      'subang': 'Subang Jaya',
      'cheras': 'Cheras',
      'puchong': 'Puchong',
      'putrajaya': 'Putrajaya',
    };

    final excluded = <String>[...?existing?.excludedLocations];
    for (final entry in areaKeywords.entries) {
      if (_isExcludedInText(text, entry.key, entry.value)) {
        if (!excluded.contains(entry.value)) excluded.add(entry.value);
        locations.removeWhere(
          (l) => l.toLowerCase() == entry.value.toLowerCase(),
        );
      } else if (text.contains(entry.key) && !locations.contains(entry.value)) {
        locations.add(entry.value);
      }
    }

    final features = <String>[...?existing?.mustHaveFeatures];
    for (final feature in _validFeatures) {
      final key = feature.toLowerCase();
      if ((text.contains('mrt') || text.contains('lrt')) &&
          feature == 'Near LRT/MRT' &&
          !features.contains(feature)) {
        features.add(feature);
      } else if (text.contains(key.split(' ').last) && !features.contains(feature)) {
      }
    }
    if (text.contains('mrt') || text.contains('lrt')) {
      if (!features.contains('Near LRT/MRT')) features.add('Near LRT/MRT');
    }
    if (text.contains('pool') && !features.contains('Swimming Pool')) {
      features.add('Swimming Pool');
    }

    var bedrooms = existing?.bedrooms ?? 3;
    final bedMatch = RegExp(r'(\d)\s*bed').firstMatch(text);
    if (bedMatch != null) {
      bedrooms = int.tryParse(bedMatch.group(1)!) ?? bedrooms;
    }

    final priceRange = existing?.priceRange ??
        budgetToRange(affordability.recommendedBudget);

    return ExtractedPreferences(
      purpose: purpose,
      propertyTypes: types,
      priceRange: priceRange,
      bedrooms: bedrooms.clamp(1, 5),
      locations: locations,
      mustHaveFeatures: features,
      excludedLocations: excluded,
      summary: ExtractedPreferences._summaryFromFields(
        purpose: purpose,
        types: types,
        priceRange: priceRange,
        bedrooms: bedrooms,
        locations: locations,
        excludedLocations: excluded,
      ),
      confidence: text.isEmpty ? 0.4 : 0.55,
      missingFields: text.isEmpty ? ['conversation'] : [],
    );
  }

  static String budgetToRange(double budget) {
    if (budget <= 0) return 'RM200k-300k';
    if (budget < 200000) return 'RM100k-200k';
    if (budget < 300000) return 'RM200k-300k';
    if (budget < 500000) return 'RM300k-500k';
    if (budget < 800000) return 'RM500k-800k';
    if (budget < 1000000) return 'RM800k-1M';
    if (budget < 1500000) return 'RM1M-1.5M';
    return 'RM1.5M+';
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return [];
    return value.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static bool _isExcludedInText(String text, String keyword, String label) {
    final escaped = RegExp.escape(keyword);
    final negativePatterns = [
      RegExp("(?:don'?t|do not|dont)\\s+(?:want\\s+)?$escaped"),
      RegExp('(?:no|avoid|not|exclude|without)\\s+$escaped'),
      RegExp('$escaped\\s+(?:is\\s+)?(?:not|no)\\s+(?:ok|good|wanted)'),
    ];
    return negativePatterns.any((p) => p.hasMatch(text));
  }
}
