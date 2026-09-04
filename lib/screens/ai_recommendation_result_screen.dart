import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/property_model.dart';
import '../models/recommendation_model.dart';
import '../providers/theme_provider.dart';
import '../utils/affordability_context.dart';
import '../utils/money_format.dart';
import 'ai_advisor_chat_screen.dart';
import 'property_detail_screen.dart';

class AIRecommendationResultScreen extends StatelessWidget {
  const AIRecommendationResultScreen({super.key, required this.result});

  final RecommendationResult result;

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Recommendations'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (result.isFallback) ...[
            _buildNotice(
              icon: Icons.info_outline,
              color: Colors.orange,
              title: 'Rule-based ranking',
              message: 'Ranked by built-in rules; AI explanation was unavailable. '
                  'Results still reflect your budget and preferences.',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
          ],
          if (result.financialSnapshot != null &&
              result.financialSnapshot!.monthlyIncome > 0) ...[
            _buildFinancialSnapshot(result.financialSnapshot!, isDark),
            const SizedBox(height: 12),
          ],
          _buildSummary(isDark),
          if (result.advisorSummary != null &&
              result.advisorSummary!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildNotice(
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.teal,
              title: 'Advisor view',
              message: result.advisorSummary!,
              isDark: isDark,
            ),
          ],
          if (result.tradeOffs.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTradeOffs(result.tradeOffs, isDark),
          ],
          if (result.rejectedNote != null) ...[
            const SizedBox(height: 12),
            _buildNotice(
              icon: Icons.filter_alt_off,
              color: Colors.blueGrey,
              title: 'Why some listings were skipped',
              message: result.rejectedNote!,
              isDark: isDark,
            ),
          ],
          if (result.relaxedNote != null) ...[
            const SizedBox(height: 12),
            _buildNotice(
              icon: Icons.tune,
              color: Colors.orange,
              title: 'Criteria relaxed',
              message: result.relaxedNote!,
              isDark: isDark,
            ),
          ],
          const SizedBox(height: 20),
          if (result.isEmpty)
            _buildEmptyState(isDark)
          else ...[
            Text(
              '${result.recommendations.length} properties picked for you',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < result.recommendations.length; i++) ...[
              _RecommendationCard(
                rank: i + 1,
                recommendation: result.recommendations[i],
                isDark: isDark,
              ),
              const SizedBox(height: 16),
            ],
          ],
          if (result.nearMisses.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Almost fit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            for (final miss in result.nearMisses)
              _NearMissTile(miss: miss, isDark: isDark),
          ],
          if (result.advice != null) ...[
            const SizedBox(height: 4),
            _buildNotice(
              icon: Icons.lightbulb_outline,
              color: Colors.blue,
              title: 'What you could try next',
              message: result.advice!,
              isDark: isDark,
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AIAdvisorChatScreen(result: result),
                ),
              );
            },
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Ask follow-up questions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.edit),
            label: const Text('Back to AI Advisor'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSnapshot(
    BuyerAffordabilitySnapshot snap,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.teal[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined,
                  color: isDark ? Colors.teal[200] : Colors.teal[700]),
              const SizedBox(width: 8),
              Text(
                'Your financial snapshot',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.teal[200] : Colors.teal[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _snapshotRow('Monthly income', MoneyFormat.displayCalculated(snap.monthlyIncome), isDark),
          _snapshotRow('Commitments', MoneyFormat.display(snap.commitments), isDark),
          _snapshotRow('Disposable', MoneyFormat.display(snap.disposableIncome), isDark),
          _snapshotRow(
            'Current DSR',
            '${snap.currentDsrPercent.toStringAsFixed(1)}%',
            isDark,
          ),
          _snapshotRow(
            'Recommended budget',
            MoneyFormat.displayCalculated(snap.recommendedBudget),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _snapshotRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeOffs(List<String> tradeOffs, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.purple[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trade-offs considered',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.purple[200] : Colors.purple[900],
            ),
          ),
          const SizedBox(height: 8),
          for (final item in tradeOffs)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy, color: isDark ? Colors.blue[300] : Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.isFallback ? 'Smart Match' : 'AI Advisor',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
          if (result.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              result.summary,
              style: TextStyle(
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotice({
    required IconData icon,
    required MaterialColor color,
    required String title,
    required String message,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : color[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: isDark ? color[300] : color[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? color[300] : color[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.search_off, size: 56, color: Colors.grey[500]),
          const SizedBox(height: 12),
          Text(
            'No suitable properties found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.rank,
    required this.recommendation,
    required this.isDark,
  });

  final int rank;
  final PropertyRecommendation recommendation;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final property = recommendation.property;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PropertyDetailScreen(property: property),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCover(property),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.mainTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.shortAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _price(property),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blue[300] : Colors.blue[700],
                        ),
                      ),
                      if (recommendation.overBudget) ...[
                        const SizedBox(width: 8),
                        _tag('Over budget', Colors.orange),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (property.propertyType != null &&
                          property.propertyType!.isNotEmpty)
                        _fact(Icons.home_work_outlined, property.propertyType!),
                      if (property.bedrooms != null)
                        _fact(Icons.bed_outlined, '${property.bedrooms} beds'),
                      if (property.bathrooms != null)
                        _fact(Icons.bathtub_outlined,
                            '${property.bathrooms} baths'),
                      if (property.builtUp != null &&
                          property.builtUp!.isNotEmpty)
                        _fact(Icons.straighten, property.builtUp!),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildReason(),
                  if (recommendation.highlights.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: recommendation.highlights
                          .map((h) => _tag(h, Colors.blue))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(PropertyModel property) {
    final photos = property.photoUrlList;

    return Stack(
      children: [
        SizedBox(
          height: 150,
          width: double.infinity,
          child: photos.isEmpty
              ? Container(
                  color: isDark ? Colors.grey[850] : Colors.grey[200],
                  child: Icon(property.propertyTypeIcon,
                      size: 48, color: Colors.grey[500]),
                )
              : Image.network(
                  photos.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: isDark ? Colors.grey[850] : Colors.grey[200],
                    child: Icon(property.propertyTypeIcon,
                        size: 48, color: Colors.grey[500]),
                  ),
                ),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        if (recommendation.matchScore != null)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _scoreColor(recommendation.matchScore!),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${recommendation.matchScore}% match',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReason() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15151F) : Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  size: 16, color: isDark ? Colors.blue[300] : Colors.blue[700]),
              const SizedBox(width: 6),
              Text(
                'Why this fits you',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blue[300] : Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            recommendation.reason,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fact(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDark ? Colors.white60 : Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? color[200] : color[800],
        ),
      ),
    );
  }

  String _price(PropertyModel property) {
    final price = property.price;
    if (price == null || price <= 0) return 'Price on request';
    return 'RM ${MoneyFormat.groupInteger('$price')}';
  }

  Color _scoreColor(int score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.redAccent;
  }
}

class _NearMissTile extends StatelessWidget {
  const _NearMissTile({required this.miss, required this.isDark});

  final NearMissRecommendation miss;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[50],
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PropertyDetailScreen(property: miss.property),
          ),
        ),
        leading: Icon(
          miss.worthConsidering ? Icons.thumb_up_outlined : Icons.info_outline,
          color: miss.worthConsidering ? Colors.green : Colors.orange,
        ),
        title: Text(
          miss.property.mainTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          miss.gap,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.grey[700],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
