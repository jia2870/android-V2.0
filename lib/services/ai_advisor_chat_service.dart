import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/env.dart';
import '../models/recommendation_model.dart';
import '../utils/affordability_context.dart';

class AdvisorChatMessage {
  const AdvisorChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toApiJson() => {'role': role, 'content': content};
}

class DiscoverChatResult {
  const DiscoverChatResult({
    required this.reply,
    required this.readyForRecommendations,
  });

  final String reply;
  final bool readyForRecommendations;
}

class AIAdvisorChatService {
  AIAdvisorChatService._();

  static const String _apiUrl = '${Env.openAiBaseUrl}/chat/completions';
  static const Duration _timeout = Duration(seconds: 40);

  static bool get _hasApiKey =>
      Env.openAiApiKey.isNotEmpty &&
      Env.openAiApiKey != 'YOUR_OPENAI_API_KEY_HERE';

  static Future<String> ask({
    required RecommendationResult result,
    required List<AdvisorChatMessage> history,
    required String userMessage,
  }) async {
    if (!_hasApiKey) {
      return 'AI chat is unavailable because the OpenAI API key is not configured.';
    }

    final system = _buildFollowUpContext(result);
    return _postChat(system: system, history: history, userMessage: userMessage);
  }

  static Future<DiscoverChatResult> discover({
    required BuyerAffordabilitySnapshot snapshot,
    required List<AdvisorChatMessage> history,
    required String userMessage,
    String? savedPreferenceSummary,
    String? collectedPreferencesSummary,
    List<String> missingFields = const [],
  }) async {
    final hasCollectedPrefs =
        collectedPreferencesSummary != null &&
        collectedPreferencesSummary.isNotEmpty;

    if (!_hasApiKey) {
      return _fallbackDiscoverResult(
        userMessage: userMessage,
        preferenceSummary: collectedPreferencesSummary ?? savedPreferenceSummary,
        hasCollectedPrefs: hasCollectedPrefs,
      );
    }

    final system = _buildDiscoverSystemPrompt(
      snapshot: snapshot,
      savedPreferenceSummary: savedPreferenceSummary,
      collectedPreferencesSummary: collectedPreferencesSummary,
      missingFields: missingFields,
    );

    try {
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
              'max_tokens': 700,
              'messages': [
                {'role': 'system', 'content': system},
                ...history.map((m) => m.toApiJson()),
                {'role': 'user', 'content': userMessage},
              ],
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('Advisor chat ${response.statusCode}: ${response.body}');
        return DiscoverChatResult(
          reply: 'Sorry, I could not reach the AI service. Please try again.',
          readyForRecommendations: false,
        );
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final content =
          body['choices']?[0]?['message']?['content']?.toString().trim();
      if (content == null || content.isEmpty) {
        return DiscoverChatResult(
          reply: 'I could not generate a reply.',
          readyForRecommendations: false,
        );
      }

      return _parseDiscoverJson(
        content,
        userMessage: userMessage,
        hasCollectedPrefs: hasCollectedPrefs,
      );
    } catch (e) {
      debugPrint('Advisor chat error: $e');
      return DiscoverChatResult(
        reply: 'Something went wrong. Please try again.',
        readyForRecommendations: false,
      );
    }
  }

  static String _buildDiscoverSystemPrompt({
    required BuyerAffordabilitySnapshot snapshot,
    String? savedPreferenceSummary,
    String? collectedPreferencesSummary,
    List<String> missingFields = const [],
  }) {
    final buffer = StringBuffer()
      ..writeln('You are a friendly Malaysian property advisor in discovery mode.')
      ..writeln('Help the buyer refine what property they want in natural language.')
      ..writeln('Ask at most ONE clarifying question if something important is missing.')
      ..writeln('Keep replies under 80 words, conversational, in English.')
      ..writeln('Never tell the user to tap a button — the app will search automatically.')
      ..writeln()
      ..writeln('Reply with JSON only:')
      ..writeln('{')
      ..writeln('  "reply": "your conversational message",')
      ..writeln('  "ready_for_recommendations": true or false')
      ..writeln('}')
      ..writeln()
      ..writeln('Set ready_for_recommendations to true when:')
      ..writeln('- Core preferences are clear (purpose, area, type, bedrooms, budget), AND')
      ..writeln('- The user confirms they are done (e.g. ok, yes, go ahead, that\'s all, no more, nothing else), OR')
      ..writeln('- Quick setup preferences are already collected and user adds no changes.')
      ..writeln('Set ready_for_recommendations to false when:')
      ..writeln('- Core fields are still missing, OR')
      ..writeln('- User is changing preferences, OR')
      ..writeln('- User asks to wait or has more to add.')
      ..writeln()
      ..writeln('BUYER FINANCES:')
      ..writeln(snapshot.formatForPrompt());

    if (collectedPreferencesSummary != null &&
        collectedPreferencesSummary.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('COLLECTED PREFERENCES (confirmed via quick setup — do NOT re-ask):')
        ..writeln(collectedPreferencesSummary)
        ..writeln(
          'Only ask about optional extras not yet covered (e.g. MRT, parking, '
          'high floor, sea view) unless the user wants to change something.',
        );
      if (missingFields.isNotEmpty) {
        buffer.writeln('Still unknown: ${missingFields.join(', ')}');
      }
    } else if (savedPreferenceSummary != null && savedPreferenceSummary.isNotEmpty) {
      buffer.writeln('LAST SAVED PREFERENCES: $savedPreferenceSummary');
    }

    return buffer.toString();
  }

  static DiscoverChatResult _parseDiscoverJson(
    String content, {
    required String userMessage,
    required bool hasCollectedPrefs,
  }) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) throw FormatException('not a map');

      final reply = decoded['reply']?.toString().trim();
      if (reply == null || reply.isEmpty) throw FormatException('empty reply');

      var ready = decoded['ready_for_recommendations'] == true;
      if (!ready && hasCollectedPrefs && looksReadyToRecommend(userMessage)) {
        ready = true;
      }

      return DiscoverChatResult(reply: reply, readyForRecommendations: ready);
    } catch (e) {
      debugPrint('Discover JSON parse error: $e');
      final ready = hasCollectedPrefs && looksReadyToRecommend(userMessage);
      return DiscoverChatResult(
        reply: content.length > 300 ? '${content.substring(0, 300)}…' : content,
        readyForRecommendations: ready,
      );
    }
  }

  static DiscoverChatResult _fallbackDiscoverResult({
    required String userMessage,
    String? preferenceSummary,
    required bool hasCollectedPrefs,
  }) {
    if (userMessage.trim().isEmpty) {
      return const DiscoverChatResult(
        reply: 'Tell me what you are looking for — area, property type, bedrooms, '
            'and whether it is for own stay or investment.',
        readyForRecommendations: false,
      );
    }

    final ready = hasCollectedPrefs && looksReadyToRecommend(userMessage);
    if (ready) {
      return DiscoverChatResult(
        reply: 'Got it — I will search for properties that match your preferences.',
        readyForRecommendations: true,
      );
    }

    if (preferenceSummary != null && preferenceSummary.isNotEmpty) {
      return DiscoverChatResult(
        reply: 'Noted: "$userMessage". Your preferences so far: $preferenceSummary. '
            'Anything else, or say ok when ready to search.',
        readyForRecommendations: false,
      );
    }

    return DiscoverChatResult(
      reply: 'Thanks — I noted: "$userMessage". Tell me more about area, type, '
          'and bedrooms, or say ok when ready to search.',
      readyForRecommendations: false,
    );
  }

  static bool looksReadyToRecommend(String userMessage) {
    final text = userMessage.trim().toLowerCase();
    if (text.isEmpty) return false;

    if (_looksLikePreferenceChange(text)) return false;

    const confirmations = [
      'ok',
      'okay',
      'yes',
      'yep',
      'yeah',
      'sure',
      'go',
      'go ahead',
      'find',
      'search',
      'ready',
      'that\'s all',
      'thats all',
      'that all',
      'no more',
      'nothing else',
      'no addition',
      'no additional',
      '没有了',
      '可以',
      '好的',
      '行',
      '开始',
      '找吧',
    ];
    if (confirmations.any((c) => text == c || text.startsWith('$c ') || text.endsWith(' $c'))) {
      return true;
    }

    return RegExp(
      r"^(that('?s| is)? all|no(thing)? (else|more|addition)|i'?m (good|done|ready))\.?$",
    ).hasMatch(text);
  }

  static bool _looksLikePreferenceChange(String text) {
    const changeSignals = [
      'actually',
      'wait',
      'change',
      'instead',
      'rather',
      'but ',
      'except',
      'don\'t want',
      'dont want',
      'no putrajaya',
      'exclude',
      'prefer',
      'want ',
      'need ',
      'looking for',
      '改成',
      '等等',
      '不要',
    ];
    return changeSignals.any(text.contains);
  }

  static Future<String> _postChat({
    required String system,
    required List<AdvisorChatMessage> history,
    required String userMessage,
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
      ...history.map((m) => m.toApiJson()),
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${Env.openAiApiKey}',
            },
            body: jsonEncode({
              'model': Env.gptModel,
              'temperature': 0.5,
              'max_tokens': 700,
              'messages': messages,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('Advisor chat ${response.statusCode}: ${response.body}');
        return 'Sorry, I could not reach the AI service. Please try again.';
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body['choices']?[0]?['message']?['content']?.toString().trim() ??
          'I could not generate a reply.';
    } catch (e) {
      debugPrint('Advisor chat error: $e');
      return 'Something went wrong. Please try again.';
    }
  }

  static String _buildFollowUpContext(RecommendationResult result) {
    final buffer = StringBuffer()
      ..writeln('You are a Malaysian property advisor. The user just received '
          'property recommendations. Answer follow-up questions using ONLY the '
          'context below. Reference listing ranks (#1, #2) or addresses when helpful.')
      ..writeln();

    final snap = result.financialSnapshot;
    if (snap != null) {
      buffer.writeln('FINANCIAL SNAPSHOT:');
      buffer.writeln(snap.formatForPrompt());
    }

    if (result.advisorSummary != null) {
      buffer.writeln('ADVISOR SUMMARY: ${result.advisorSummary}');
    }
    if (result.summary.isNotEmpty) {
      buffer.writeln('SHORTLIST SUMMARY: ${result.summary}');
    }
    if (result.tradeOffs.isNotEmpty) {
      buffer.writeln('TRADE-OFFS: ${result.tradeOffs.join('; ')}');
    }

    buffer.writeln('RECOMMENDED LISTINGS:');
    for (var i = 0; i < result.recommendations.length; i++) {
      final rec = result.recommendations[i];
      final p = rec.property;
      buffer.writeln(
        '#${i + 1} id=${p.listingId} price=${p.price} type=${p.propertyType} '
        'beds=${p.bedrooms} area=${p.shortAddress} reason=${rec.reason}',
      );
    }

    if (result.nearMisses.isNotEmpty) {
      buffer.writeln('NEAR MISSES:');
      for (final miss in result.nearMisses) {
        buffer.writeln(
          'id=${miss.property.listingId} gap=${miss.gap} '
          'worth=${miss.worthConsidering}',
        );
      }
    }

    buffer.writeln(
      'Keep answers concise (under 120 words), actionable, and in English.',
    );
    return buffer.toString();
  }
}
