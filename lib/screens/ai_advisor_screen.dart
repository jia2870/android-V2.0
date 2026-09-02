import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/property_model.dart';
import '../providers/auth_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ai_advisor_chat_service.dart';
import '../services/ai_recommendation_service.dart';
import '../services/ai_service.dart';
import '../services/financial_service.dart';
import '../services/preference_extraction_service.dart';
import '../services/property_preference_service.dart';
import '../services/property_service.dart';
import '../services/saved_property_service.dart';
import '../utils/affordability_context.dart';
import '../utils/money_format.dart';
import '../models/quick_setup_draft.dart';
import '../widgets/adaptive_nav_scaffold.dart';
import '../widgets/ai_quick_setup_card.dart';
import 'ai_recommendation_result_screen.dart';
import 'financial_assessment_screen.dart';

class AIAdvisorScreen extends StatefulWidget {
  final PropertyModel? property;
  const AIAdvisorScreen({super.key, this.property});

  @override
  State<AIAdvisorScreen> createState() => _AIAdvisorScreenState();
}

class _ChatLine {
  const _ChatLine({required this.isUser, required this.text});
  final bool isUser;
  final String text;
}

class _AIAdvisorScreenState extends State<AIAdvisorScreen> {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();

  final FinancialService _financialService = FinancialService();
  final PropertyPreferenceService _preferenceService = PropertyPreferenceService();
  final PropertyService _propertyService = PropertyService();
  final SavedPropertyService _savedPropertyService = SavedPropertyService();

  final List<_ChatLine> _messages = [];
  final List<AdvisorChatMessage> _apiHistory = [];

  ExtractedPreferences? _savedPrefs;
  ExtractedPreferences? _guidedPrefs;
  bool _showQuickSetup = true;
  bool _quickSetupComplete = false;
  bool _skippedQuickSetup = false;
  bool _isLoadingProfile = true;
  bool _isProfileReady = false;
  bool _chatSending = false;
  bool _isRecommending = false;
  bool _isAnalyzing = false;
  bool _hasCompletedRecommendation = false;
  String _analysisResult = '';

  static const _suggestions = [
    '3-bed condo in KLCC for own stay, near MRT',
    'Investment terrace under RM500k in Johor',
    'Family home in Penang with 4 bedrooms',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      final profile = await _financialService.getProfileByUserId(userId);
      if (profile != null && mounted) {
        final financialProvider =
            Provider.of<FinancialProvider>(context, listen: false);
        financialProvider.updateFinancialData(
          salary: profile.monthlySalary,
          otherIncome: profile.otherIncome,
          commitments: profile.commitments,
          savings: profile.savings,
          downPayment: profile.downPayment,
        );
        _isProfileReady = profile.monthlySalary > 0;
      }
    } catch (e) {
      debugPrint('Load financial error: $e');
    }

    try {
      final preference = await _preferenceService.getPreferenceByUserId(userId);
      if (preference != null && mounted) {
        _savedPrefs = ExtractedPreferences.fromModel(preference);
      }
    } catch (e) {
      debugPrint('Load preference error: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingProfile = false;
        if (_messages.isEmpty) _seedWelcome();
      });
    }
  }

  void _seedWelcome() {
    final financial = Provider.of<FinancialProvider>(context, listen: false);
    final buffer = StringBuffer(
      'Hi! I\'m your property advisor. Answer the quick setup below — '
      'purpose, area, type, bedrooms, and budget — like a real agent would.\n\n'
      'Then we can fine-tune in chat, or skip and describe everything yourself.',
    );

    if (financial.recommendedBudget > 0) {
      buffer.write(
        '\n\nYour recommended budget is about '
        '${MoneyFormat.display(financial.recommendedBudget)}.',
      );
    }

    if (widget.property != null) {
      buffer.write(
        '\n\nYou opened a specific listing — describe your goals, then tap '
        'Analyze this property, or search again for other matches.',
      );
    }

    _messages.add(_ChatLine(isUser: false, text: buffer.toString()));
  }

  void _completeQuickSetup(QuickSetupDraft draft) {
    final prefs = draft.toPreferences(_buyerSnapshot());
    final userMsg = draft.toConversationMessage();
    final assistantReply = _buildSetupAcknowledgment(prefs);

    setState(() {
      _guidedPrefs = prefs;
      _savedPrefs = prefs;
      _quickSetupComplete = true;
      _showQuickSetup = false;
      _messages.add(_ChatLine(isUser: true, text: userMsg));
      _messages.add(_ChatLine(isUser: false, text: assistantReply));
      _apiHistory.add(AdvisorChatMessage(role: 'user', content: userMsg));
      _apiHistory.add(
        AdvisorChatMessage(role: 'assistant', content: assistantReply),
      );
    });
    _scrollToBottom();
  }

  String _buildSetupAcknowledgment(ExtractedPreferences prefs) {
    return 'Perfect — I have your basics:\n${prefs.summary}.\n\n'
        'Anything else that matters? For example near MRT, parking, high floor, '
        'or areas to avoid.\n\n'
        'Tell me below, then say ok when you are ready to search — '
        'or tap Search now anytime.';
  }

  void _scheduleAutoRecommend({
    Duration delay = const Duration(milliseconds: 800),
  }) {
    if (!_canAutoRecommend) return;
    Future.delayed(delay, () {
      if (!mounted || _isRecommending || _chatSending) return;
      _runAIRecommendation();
    });
  }

  bool get _canAutoRecommend => widget.property == null;

  void _skipQuickSetup() {
    setState(() {
      _skippedQuickSetup = true;
      _showQuickSetup = false;
    });
  }

  List<String> _optionalMissingFields() {
    if (_guidedPrefs == null) return const [];
    if (_guidedPrefs!.mustHaveFeatures.isEmpty) {
      return const ['must-have features (optional)'];
    }
    return const [];
  }

  BuyerAffordabilitySnapshot _buyerSnapshot() {
    final financial = Provider.of<FinancialProvider>(context, listen: false);
    return BuyerAffordabilitySnapshot(
      monthlyIncome: financial.totalMonthlyIncome,
      commitments: financial.commitments,
      savings: financial.savings,
      recommendedBudget: financial.recommendedBudget,
    );
  }

  Future<List<String>> _savedPropertyHints(String userId) async {
    try {
      final saved = await _savedPropertyService.getSavedProperties(userId);
      return saved.take(5).map((p) {
        return '${p.propertyType ?? 'Property'} ${p.shortAddress} RM${p.price ?? 0}';
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _sendChat([String? preset]) async {
    final text = (preset ?? _chatController.text).trim();
    if (text.isEmpty || _chatSending) return;

    setState(() {
      if (!_quickSetupComplete) {
        _skippedQuickSetup = true;
        _showQuickSetup = false;
      }
      _messages.add(_ChatLine(isUser: true, text: text));
      _chatSending = true;
      _chatController.clear();
    });
    _scrollToBottom();

    final result = await AIAdvisorChatService.discover(
      snapshot: _buyerSnapshot(),
      history: _apiHistory,
      userMessage: text,
      collectedPreferencesSummary: _guidedPrefs?.summary,
      missingFields: _optionalMissingFields(),
    );

    if (!mounted) return;

    setState(() {
      _apiHistory.add(AdvisorChatMessage(role: 'user', content: text));
      _apiHistory.add(AdvisorChatMessage(role: 'assistant', content: result.reply));
      _messages.add(_ChatLine(isUser: false, text: result.reply));
      _chatSending = false;
    });
    _scrollToBottom();

    if (result.readyForRecommendations) {
      _scheduleAutoRecommend(delay: const Duration(milliseconds: 500));
    }
  }

  Future<ExtractedPreferences?> _resolvePreferences(String userId) async {
    final hints = await _savedPropertyHints(userId);
    return PreferenceExtractionService.extractAndSave(
      userId: userId,
      conversation: _apiHistory,
      affordability: _buyerSnapshot(),
      existing: _guidedPrefs,
      savedPropertyHints: hints,
    );
  }

  bool get _hasUserInput =>
      _quickSetupComplete ||
      _apiHistory.any((m) => m.role == 'user' && m.content.trim().isNotEmpty);

  bool get _shouldShowQuickSetup =>
      _showQuickSetup && !_quickSetupComplete && !_skippedQuickSetup;

  Future<void> _runAIRecommendation() async {
    if (!_isProfileReady) {
      _openFinancialSettings();
      return;
    }

    if (!_hasUserInput) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tell me what you\'re looking for first — type a message or tap a suggestion.',
          ),
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    setState(() => _isRecommending = true);

    try {
      final extracted = await _resolvePreferences(userId);
      if (!mounted) return;
      if (extracted == null) throw Exception('Could not understand your preferences');

      _savedPrefs = extracted;
      _guidedPrefs = extracted;
      final financial = Provider.of<FinancialProvider>(context, listen: false);
      final request = extracted.toRequest(
        monthlyIncome: financial.totalMonthlyIncome,
        commitments: financial.commitments,
        savings: financial.savings,
        recommendedBudget: financial.recommendedBudget,
      );

      final properties = await _propertyService.getAllProperties();
      final result = await AIRecommendationService.recommend(
        request: request,
        properties: properties,
      );

      if (!mounted) return;
      setState(() => _isRecommending = false);
      _hasCompletedRecommendation = true;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AIRecommendationResultScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRecommending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate recommendations: $e')),
      );
    }
  }

  Future<void> _proceedToAnalysis() async {
    if (widget.property == null || !_isProfileReady) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.getCurrentUserId();
    if (userId == null) return;

    setState(() {
      _isAnalyzing = true;
      _analysisResult = '';
    });

    try {
      if (_apiHistory.where((m) => m.role == 'user').isNotEmpty || _savedPrefs == null) {
        _savedPrefs = await _resolvePreferences(userId);
      }

      if (!mounted) return;
      final prefs = _savedPrefs!;
      final financial = Provider.of<FinancialProvider>(context, listen: false);
      final property = widget.property!;

      final monthlyIncome = financial.totalMonthlyIncome;
      final commitments = financial.commitments;
      final savings = financial.savings;
      final recommendedBudget = financial.recommendedBudget;

      final propertyPrice = property.price ?? 0;
      final details = <String, dynamic>{};

      final priceScore = _calculatePriceScore(propertyPrice, recommendedBudget);
      details['priceMatch'] = priceScore;

      final bedroomScore =
          _calculateBedroomScore(property.bedrooms ?? 0, prefs.bedrooms);
      details['bedroomMatch'] = bedroomScore;

      final typeScore =
          _calculateTypeScore(property.propertyType ?? '', prefs.propertyTypes);
      details['typeMatch'] = typeScore;

      final stateScore = _calculateStateScore(
        property.state ?? '',
        prefs.locations.join(', '),
      );
      details['stateMatch'] = stateScore;

      final matchPercentage = ((priceScore * 0.4 +
                  bedroomScore * 0.3 +
                  typeScore * 0.2 +
                  stateScore * 0.1) *
              100)
          .clamp(0.0, 100.0);
      details['matchPercentage'] = matchPercentage;

      final isAffordable = propertyPrice <= recommendedBudget * 1.2;
      details['isAffordable'] = isAffordable;
      details['propertyPrice'] = propertyPrice;
      details['recommendedBudget'] = recommendedBudget;
      details['monthlyIncome'] = monthlyIncome;
      details['priceToIncomeRatio'] =
          monthlyIncome > 0 ? propertyPrice / (monthlyIncome * 12) : 0;

      if (!mounted) return;

      final result = await AIService.analyzePropertyMatch(
        property: property,
        matchScore: matchPercentage,
        isAffordable: isAffordable,
        matchDetails: details,
        monthlyIncome: monthlyIncome,
        commitments: commitments,
        savings: savings,
        recommendedBudget: recommendedBudget,
        purpose: prefs.purpose,
        preferredBedrooms: prefs.bedrooms,
        preferredState: prefs.locations.join(', '),
        importantFactors: prefs.mustHaveFeatures,
      );

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e')),
        );
      }
    }
  }

  void _openFinancialSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FinancialAssessmentScreen()),
    ).then((_) => _loadProfile());
  }

  void _onTabTapped(int index) {
    if (index == AppNavIndex.ai) {
      if (_analysisResult.isNotEmpty) {
        setState(() => _analysisResult = '');
      }
      return;
    }
    handleAppNavigation(context, index);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  double _calculatePriceScore(int propertyPrice, double recommendedBudget) {
    if (propertyPrice <= 0 || recommendedBudget <= 0) return 0.5;
    final ratio = propertyPrice / recommendedBudget;
    if (ratio <= 0.9) return 1.0;
    if (ratio <= 1.2) return 0.8;
    if (ratio <= 1.5) return 0.6;
    return 0.3;
  }

  double _calculateBedroomScore(int propertyBedrooms, int preferredBedrooms) {
    if (propertyBedrooms <= 0) return 0.5;
    final diff = (propertyBedrooms - preferredBedrooms).abs();
    if (diff == 0) return 1.0;
    if (diff <= 1) return 0.8;
    return 0.5;
  }

  double _calculateTypeScore(String propertyType, List<String> preferredTypes) {
    if (propertyType.isEmpty || preferredTypes.isEmpty) return 0.5;
    final type = propertyType.toLowerCase();
    for (final preferred in preferredTypes) {
      if (type.contains(preferred.toLowerCase())) return 1.0;
    }
    return 0.4;
  }

  double _calculateStateScore(String propertyState, String preferredState) {
    if (propertyState.isEmpty || preferredState.isEmpty) return 0.5;
    final state = propertyState.toLowerCase();
    final preferred = preferredState.toLowerCase();
    if (state.contains(preferred) || preferred.contains(state)) return 1.0;
    return 0.4;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return AdaptiveNavScaffold(
      currentIndex: AppNavIndex.ai,
      onTap: _onTabTapped,
      appBar: AppBar(
        title: Text(widget.property != null ? 'AI Property Analysis' : 'AI Advisor'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Update financial profile',
            onPressed: _openFinancialSettings,
          ),
        ],
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : !_isProfileReady
              ? _buildFinancialRequired(isDark)
              : _isAnalyzing
                  ? const Center(child: CircularProgressIndicator())
                  : _analysisResult.isNotEmpty
                      ? _buildAnalysisResult(isDark)
                      : _buildConversation(isDark),
    );
  }

  Widget _buildFinancialRequired(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 56, color: isDark ? Colors.blue[200] : Colors.blue),
            const SizedBox(height: 16),
            Text(
              'Complete your financial profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'I need your income and commitments to estimate loan affordability before recommending properties.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openFinancialSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: const Text('Set up financial profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation(bool isDark) {
    final financial = Provider.of<FinancialProvider>(context);
    final busy = _chatSending || _isRecommending;
    final compactHeight = MediaQuery.sizeOf(context).height < 500;

    return Column(
      children: [
        if (financial.totalMonthlyIncome > 0)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compactHeight ? 4 : 10,
            ),
            color: isDark ? const Color(0xFF1E1E2E) : Colors.blue[50],
            child: Text(
              'Income ${MoneyFormat.display(financial.totalMonthlyIncome)} · '
              'Budget ${MoneyFormat.display(financial.recommendedBudget)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.blue[900],
              ),
            ),
          ),
        if (_guidedPrefs != null) _buildPreferenceSummary(isDark),
        if (widget.property != null) _buildPropertyBanner(isDark),
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: EdgeInsets.all(compactHeight ? 8 : 16),
            children: [
              if (compactHeight && _shouldShowQuickSetup && !_chatSending) ...[
                AIQuickSetupCard(
                  isDark: isDark,
                  recommendedBudget: financial.recommendedBudget,
                  onComplete: _completeQuickSetup,
                  onSkip: _skipQuickSetup,
                ),
                const SizedBox(height: 8),
              ],
              for (final msg in _messages) ...[
                _MessageBubble(message: msg, isDark: isDark),
                const SizedBox(height: 10),
              ],
              if (!compactHeight &&
                  _shouldShowQuickSetup &&
                  !_chatSending) ...[
                AIQuickSetupCard(
                  isDark: isDark,
                  recommendedBudget: financial.recommendedBudget,
                  onComplete: _completeQuickSetup,
                  onSkip: _skipQuickSetup,
                ),
                const SizedBox(height: 12),
              ],
              if (!_shouldShowQuickSetup &&
                  _messages.length <= 1 &&
                  !_chatSending &&
                  _skippedQuickSetup) ...[
                Text(
                  'Try saying:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions
                      .map(
                        (s) => ActionChip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          onPressed: busy ? null : () => _sendChat(s),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (_chatSending || _isRecommending)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isRecommending
                            ? 'Finding matches…'
                            : 'Thinking…',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, compactHeight ? 4 : 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        enabled: !busy,
                        decoration: InputDecoration(
                          hintText: _quickSetupComplete
                              ? 'Add extras (MRT, parking…) or say ok'
                              : 'Describe your ideal property…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: busy ? null : (_) => _sendChat(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: busy ? null : () => _sendChat(),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
                SizedBox(height: compactHeight ? 3 : 8),
                if (widget.property != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : _proceedToAnalysis,
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('Analyze this property'),
                    ),
                  ),
                if (widget.property != null) const SizedBox(height: 8),
                if (_quickSetupComplete &&
                    !_isRecommending &&
                    !compactHeight &&
                    widget.property == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Add details in chat and say ok when ready — or tap Search now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ),
                if (_hasUserInput && widget.property == null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : _runAIRecommendation,
                      icon: _isRecommending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(
                        _isRecommending
                            ? 'Finding matches…'
                            : (_hasCompletedRecommendation
                                ? 'Search again'
                                : 'Search now'),
                      ),
                    ),
                  )
                else if (_hasUserInput && widget.property != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: busy ? null : _runAIRecommendation,
                      icon: _isRecommending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _isRecommending
                            ? 'Finding matches…'
                            : 'Search other matches',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: compactHeight ? 2 : 8,
                    ),
                    child: Text(
                      _shouldShowQuickSetup
                          ? 'Complete quick setup above, or skip and type below.'
                          : 'Describe your needs above — recommendations unlock after you send a message.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compactHeight ? 10 : 12,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceSummary(bool isDark) {
    final prefs = _guidedPrefs!;
    return Material(
      color: isDark ? const Color(0xFF252536) : const Color(0xFFE8F0FE),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.checklist_rtl, size: 16, color: Colors.blue[400]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                prefs.summary,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: isDark ? Colors.white70 : Colors.blue[900],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyBanner(bool isDark) {
    final property = widget.property!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            property.mainTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            property.formattedPrice,
            style: TextStyle(color: isDark ? Colors.blue[200] : Colors.blue[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResult(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.property != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.property!.mainTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(widget.property!.formattedPrice),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Analysis Report',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  ..._analysisResult.split('\n').map(
                        (line) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(line, style: const TextStyle(height: 1.6)),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _proceedToAnalysis,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Re-analyze'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _analysisResult = ''),
                  icon: const Icon(Icons.chat),
                  label: const Text('Back to chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isDark});

  final _ChatLine message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = message.isUser
        ? Colors.blue
        : (isDark ? const Color(0xFF1E1E2E) : Colors.grey[100]!);
    final textColor = message.isUser
        ? Colors.white
        : (isDark ? Colors.white70 : Colors.black87);

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: textColor, height: 1.45),
        ),
      ),
    );
  }
}
