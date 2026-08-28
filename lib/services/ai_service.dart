import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/env.dart';
import '../models/property_model.dart';
import '../utils/affordability_context.dart';
import '../utils/loan_calculator.dart';
import '../utils/money_format.dart';

class AIService {
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
    required double recommendedBudget,
    required String purpose,
    required int preferredBedrooms,
    required String preferredState,
    required List<String> importantFactors,
  }) async {
    final buyer = BuyerAffordabilitySnapshot(
      monthlyIncome: monthlyIncome,
      commitments: commitments,
      savings: savings,
      recommendedBudget: recommendedBudget,
    );
    final afford = PropertyAffordability.forPrice(
      price: property.price,
      buyer: buyer,
    );

    if (_apiKey == 'YOUR_OPENAI_API_KEY_HERE' || _apiKey.isEmpty) {
      return _generateFallbackAnalysis(
        property: property,
        afford: afford,
        buyer: buyer,
        isAffordable: isAffordable,
        matchDetails: matchDetails,
        purpose: purpose,
        preferredBedrooms: preferredBedrooms,
        preferredState: preferredState,
        importantFactors: importantFactors,
      );
    }

    try {
      final prompt = _buildPrompt(
        property: property,
        afford: afford,
        buyer: buyer,
        matchScore: matchScore,
        isAffordable: isAffordable,
        matchDetails: matchDetails,
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
You are a Malaysian property advisor. Analyze whether this property suits the buyer.

Structure your response:
1. **Loan & DSR first** — estimated monthly installment, total DSR after this loan, whether it fits Malaysian banking norms (~70% DSR guideline).
2. **Budget fit** — compare price to recommended budget and savings for down payment.
3. **Preference fit** — bedrooms, location, purpose ($purpose), important factors. Treat match scores as hints only.
4. **Clear verdict** — should they view this property? What trade-offs?

Do NOT lead with a match percentage. Be concise, use bullet points, under 250 words.
'''
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.6,
          'max_tokens': 900,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ??
            'Unable to generate analysis.';
      }

      return _generateFallbackAnalysis(
        property: property,
        afford: afford,
        buyer: buyer,
        isAffordable: isAffordable,
        matchDetails: matchDetails,
        purpose: purpose,
        preferredBedrooms: preferredBedrooms,
        preferredState: preferredState,
        importantFactors: importantFactors,
      );
    } catch (e) {
      return _generateFallbackAnalysis(
        property: property,
        afford: afford,
        buyer: buyer,
        isAffordable: isAffordable,
        matchDetails: matchDetails,
        purpose: purpose,
        preferredBedrooms: preferredBedrooms,
        preferredState: preferredState,
        importantFactors: importantFactors,
      );
    }
  }

  static String _generateFallbackAnalysis({
    required PropertyModel property,
    required PropertyAffordability afford,
    required BuyerAffordabilitySnapshot buyer,
    required bool isAffordable,
    required Map<String, dynamic> matchDetails,
    required String purpose,
    required int preferredBedrooms,
    required String preferredState,
    required List<String> importantFactors,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('**Loan & DSR Assessment**\n');
    if (afford.monthlyInstallment > 0) {
      buffer.writeln(
        '• Estimated monthly installment: RM ${MoneyFormat.groupInteger('${afford.monthlyInstallment.round()}')} '
        '(${LoanCalculator.defaultLtvRatio * 100}% LTV, ${LoanCalculator.defaultTenureYears} years @ ${LoanCalculator.defaultAnnualRatePercent}%)',
      );
      buffer.writeln(
        '• DSR after this loan: ${afford.dsrPercent.toStringAsFixed(1)}% '
        '(current ${buyer.currentDsrPercent.toStringAsFixed(1)}% before new loan)',
      );
      buffer.writeln(
        '• Remaining disposable income: RM ${afford.remainingDisposable.round()}',
      );
    } else {
      buffer.writeln('• Price unavailable — cannot estimate loan.');
    }
    buffer.writeln('');

    buffer.writeln('**Budget Fit**\n');
    if (isAffordable) {
      buffer.writeln('• Price is within your recommended budget range.');
    } else {
      final price = property.price ?? 0;
      final over = price - buyer.recommendedBudget;
      buffer.writeln(
        '• Price exceeds recommended budget by RM ${over > 0 ? over : 0}.',
      );
    }
    buffer.writeln('');

    buffer.writeln('**Preference Fit** ($purpose)\n');
    buffer.writeln('• Preferred area: $preferredState');
    buffer.writeln('• Bedrooms: ${property.bedrooms ?? '?'} vs $preferredBedrooms preferred');
    if (importantFactors.isNotEmpty) {
      buffer.writeln('• Important factors: ${importantFactors.join(', ')}');
    }
    buffer.writeln('');

    buffer.writeln('**Recommendation**\n');
    if (afford.dsrPercent <= 70 && isAffordable) {
      buffer.writeln('Affordable on paper — worth a viewing if location and layout suit you.');
    } else if (afford.dsrPercent > 70) {
      buffer.writeln('DSR may be high for bank approval. Consider a lower price or longer tenure.');
    } else {
      buffer.writeln('Review other options or adjust your budget before committing.');
    }

    return buffer.toString();
  }

  static String _buildPrompt({
    required PropertyModel property,
    required PropertyAffordability afford,
    required BuyerAffordabilitySnapshot buyer,
    required double matchScore,
    required bool isAffordable,
    required Map<String, dynamic> matchDetails,
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
Analyze this property for the buyer. Lead with loan/DSR, not match scores.

PROPERTY:
- Address: $propertyAddress
- Price: RM ${propertyPrice.toStringAsFixed(0)}
- Type: $propertyType | Beds: $bedrooms | Baths: $bathrooms | Size: $builtUp

BUYER FINANCES:
${buyer.formatForPrompt()}
- Estimated loan (90% LTV): RM ${afford.loanAmount.round()}
- Estimated monthly installment: RM ${afford.monthlyInstallment.round()}
- DSR if purchased: ${afford.dsrPercent.toStringAsFixed(1)}%
- Remaining disposable: RM ${afford.remainingDisposable.round()}

BUYER PREFERENCES:
- Purpose: $purpose
- Preferred bedrooms: $preferredBedrooms
- Preferred state/area: $preferredState
- Important factors: ${importantFactors.join(', ')}

HINTS (do not repeat verbatim as your main conclusion):
- Local match score hint: ${matchScore.toStringAsFixed(0)}%
- Within recommended budget: ${isAffordable ? 'Yes' : 'No'}
- Price/bedroom/type/location hint scores available but secondary to DSR math.

Provide your advisor analysis.
''';
  }
}
