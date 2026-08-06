import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/env.dart';  // 添加这行
import '../models/property_model.dart';

class AIService {
  // 使用 Env 中的配置
  static const String _apiKey = Env.openAiApiKey;
  static const String _apiUrl = '${Env.openAiBaseUrl}/chat/completions';
  static const String _model = Env.gptModel;

  static Future<String> analyzePropertyMatch({
    required PropertyModel property,
    required double matchScore,
    required bool isAffordable,
    required Map<String, dynamic> matchDetails,
    required double monthlyIncome,
    required double commitments,
    required double savings,
    required String purpose,
    required int preferredBedrooms,
    required String preferredState,
    required List<String> importantFactors,
  }) async {
    // 检查 API Key 是否配置
    if (_apiKey == 'YOUR_OPENAI_API_KEY_HERE' || _apiKey.isEmpty) {
      return _generateFallbackAnalysis(
        property: property,
        matchScore: matchScore,
        isAffordable: isAffordable,
        matchDetails: matchDetails,
        monthlyIncome: monthlyIncome,
        commitments: commitments,
        savings: savings,
        purpose: purpose,
        preferredBedrooms: preferredBedrooms,
        preferredState: preferredState,
        importantFactors: importantFactors,
      );
    }

    try {
      final prompt = _buildPrompt(
        property: property,
        matchScore: matchScore,
        isAffordable: isAffordable,
        matchDetails: matchDetails,
        monthlyIncome: monthlyIncome,
        commitments: commitments,
        savings: savings,
        purpose: purpose,
        preferredBedrooms: preferredBedrooms,
        preferredState: preferredState,
        importantFactors: importantFactors,
      );

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': '''
You are a professional property advisor AI assistant. Your task is to analyze whether a property matches a user's financial situation and preferences.

Provide a comprehensive analysis with:
1. A clear summary statement
2. Percentage match score interpretation
3. Affordability assessment (is it within budget? If not, by how much?)
4. Key matching factors (what matches well, what doesn't)
5. A clear recommendation (Should they consider this property? Why or why not?)
6. Specific action items or advice

Keep your response concise, professional, and actionable. Use bullet points for readability.
'''
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'max_tokens': 800,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ??
            'Unable to generate analysis.';
      } else {
        // API 调用失败，使用备用分析
        return _generateFallbackAnalysis(
          property: property,
          matchScore: matchScore,
          isAffordable: isAffordable,
          matchDetails: matchDetails,
          monthlyIncome: monthlyIncome,
          commitments: commitments,
          savings: savings,
          purpose: purpose,
          preferredBedrooms: preferredBedrooms,
          preferredState: preferredState,
          importantFactors: importantFactors,
        );
      }
    } catch (e) {
      return _generateFallbackAnalysis(
        property: property,
        matchScore: matchScore,
        isAffordable: isAffordable,
        matchDetails: matchDetails,
        monthlyIncome: monthlyIncome,
        commitments: commitments,
        savings: savings,
        purpose: purpose,
        preferredBedrooms: preferredBedrooms,
        preferredState: preferredState,
        importantFactors: importantFactors,
      );
    }
  }

  // ============================================================
  // 备用分析（当 OpenAI API 不可用时）
  // ============================================================
  static String _generateFallbackAnalysis({
    required PropertyModel property,
    required double matchScore,
    required bool isAffordable,
    required Map<String, dynamic> matchDetails,
    required double monthlyIncome,
    required double commitments,
    required double savings,
    required String purpose,
    required int preferredBedrooms,
    required String preferredState,
    required List<String> importantFactors,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('🏠 **Property Match Analysis**\n');

    // 匹配分数
    buffer.writeln('📊 **Match Score: ${matchScore.toStringAsFixed(0)}%**');
    if (matchScore >= 70) {
      buffer.writeln('✅ This property is a great match for you!');
    } else if (matchScore >= 40) {
      buffer.writeln('⚠️ This property partially matches your preferences.');
    } else {
      buffer.writeln('❌ This property may not be suitable for your needs.');
    }
    buffer.writeln('');

    // 可负担性
    buffer.writeln('💰 **Affordability Assessment**');
    if (isAffordable) {
      buffer.writeln('✅ This property is within your budget range.');
    } else {
      final diff = (property.price ?? 0) - (monthlyIncome * 12 * 0.3);
      buffer.writeln('⚠️ This property is RM ${diff.toStringAsFixed(0)} above your recommended budget.');
    }
    buffer.writeln('');

    // 详细匹配
    buffer.writeln('📋 **Match Details**');
    buffer.writeln('• Price Match: ${(matchDetails['priceMatch'] * 100).toStringAsFixed(0)}%');
    buffer.writeln('• Bedroom Match: ${(matchDetails['bedroomMatch'] * 100).toStringAsFixed(0)}%');
    buffer.writeln('• Type Match: ${(matchDetails['typeMatch'] * 100).toStringAsFixed(0)}%');
    buffer.writeln('• Location Match: ${(matchDetails['stateMatch'] * 100).toStringAsFixed(0)}%');
    buffer.writeln('');

    // 建议
    buffer.writeln('💡 **Recommendation**');
    if (matchScore >= 70 && isAffordable) {
      buffer.writeln('This property is highly recommended! Consider scheduling a viewing.');
    } else if (matchScore >= 40 && isAffordable) {
      buffer.writeln('This property has potential. Consider if you can compromise on some preferences.');
    } else {
      buffer.writeln('You may want to explore other properties that better match your criteria.');
    }

    return buffer.toString();
  }

  static String _buildPrompt({
    required PropertyModel property,
    required double matchScore,
    required bool isAffordable,
    required Map<String, dynamic> matchDetails,
    required double monthlyIncome,
    required double commitments,
    required double savings,
    required String purpose,
    required int preferredBedrooms,
    required String preferredState,
    required List<String> importantFactors,
  }) {
    final propertyPrice = property.price ?? 0;
    final propertyAddress = property.fullAddress ?? property.state ?? 'Unknown location';
    final propertyType = property.propertyType ?? 'Unknown';
    final bedrooms = property.bedrooms ?? 0;
    final bathrooms = property.bathrooms ?? 0;
    final builtUp = property.builtUp ?? 'Unknown';

    return '''
Please analyze this property match:

PROPERTY DETAILS:
- Address: $propertyAddress
- Price: RM ${propertyPrice.toStringAsFixed(0)}
- Type: $propertyType
- Bedrooms: $bedrooms
- Bathrooms: $bathrooms
- Built-up: $builtUp

USER'S FINANCIAL SITUATION:
- Monthly Income: RM ${monthlyIncome.toStringAsFixed(0)}
- Monthly Commitments: RM ${commitments.toStringAsFixed(0)}
- Savings: RM ${savings.toStringAsFixed(0)}
- Purpose: $purpose

USER'S PREFERENCES:
- Preferred Bedrooms: $preferredBedrooms
- Preferred State: $preferredState
- Important Factors: ${importantFactors.join(', ')}

MATCH ANALYSIS RESULTS:
- Overall Match Score: ${matchScore.toStringAsFixed(0)}%
- Price Match: ${(matchDetails['priceMatch'] * 100).toStringAsFixed(0)}%
- Bedroom Match: ${(matchDetails['bedroomMatch'] * 100).toStringAsFixed(0)}%
- Type Match: ${(matchDetails['typeMatch'] * 100).toStringAsFixed(0)}%
- Location Match: ${(matchDetails['stateMatch'] * 100).toStringAsFixed(0)}%
- Is Affordable: ${isAffordable ? 'Yes' : 'No'}

Based on this information, provide a professional analysis and recommendation for the user.
''';
  }
}