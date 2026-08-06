import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/property_model.dart';
import '../providers/auth_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/theme_provider.dart';
import '../services/financial_service.dart';
import '../services/property_preference_service.dart';
import '../services/supabase_service.dart';
import '../services/ai_service.dart';
import 'dashboard_screen.dart';
import 'saved_properties_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class AIAdvisorScreen extends StatefulWidget {
  final PropertyModel? property;
  const AIAdvisorScreen({super.key, this.property});

  @override
  State<AIAdvisorScreen> createState() => _AIAdvisorScreenState();
}

class _AIAdvisorScreenState extends State<AIAdvisorScreen> {
  // ============================================================
  // Step 1: Financial Assessment
  // ============================================================
  final _financialFormKey = GlobalKey<FormState>();
  final _monthlySalaryController = TextEditingController();
  final _otherIncomeController = TextEditingController();
  final _commitmentsController = TextEditingController();
  final _savingsController = TextEditingController();
  final _downPaymentController = TextEditingController();
  bool _isLoadingFinancial = false;
  bool _financialDataLoaded = false;

  double _originalSalary = 0;
  double _originalOtherIncome = 0;
  double _originalCommitments = 0;
  double _originalSavings = 0;
  double _originalDownPayment = 0;

  // ============================================================
  // Step 2: Property Preferences
  // ============================================================
  String _purpose = "Own Stay";
  List<String> _selectedPropertyTypes = ['Apartment'];
  String _priceRange = "RM200k-300k";
  int _bedrooms = 3;
  String _state = "Selangor";
  List<String> _selectedFactors = [];
  bool _isLoadingPreferences = false;

  String _originalPurpose = "Own Stay";
  List<String> _originalPropertyTypes = ['Apartment'];
  String _originalPriceRange = "RM200k-300k";
  int _originalBedrooms = 3;
  String _originalState = "Selangor";
  List<String> _originalFactors = [];

  // ============================================================
  // Step 3: AI Analysis
  // ============================================================
  bool _isAnalyzing = false;
  String _analysisResult = '';
  Map<String, dynamic>? _matchDetails;
  bool _hasExistingData = false;

  bool _isFinancialFormDirty = false;
  bool _isPreferenceFormDirty = false;

  static const int _currentIndex = 1;

  final List<String> _purposes = ['Own Stay', 'Investment', 'Both'];
  final List<String> _propertyTypes = [
    'Apartment', 'Condominium', 'Terrace', 'Semi-D', 'Bungalow'
  ];
  final List<String> _priceRanges = [
    'RM100k-200k', 'RM200k-300k', 'RM300k-500k',
    'RM500k-800k', 'RM800k-1M', 'RM1M-1.5M', 'RM1.5M+'
  ];
  final List<int> _bedroomOptions = [1, 2, 3, 4, 5];
  final List<String> _states = [
    'Johor', 'Kedah', 'Kelantan', 'Melaka', 'Negeri Sembilan',
    'Pahang', 'Penang', 'Perak', 'Perlis', 'Selangor',
    'Terengganu', 'Sabah', 'Sarawak', 'Kuala Lumpur', 'Labuan', 'Putrajaya'
  ];
  final List<Map<String, dynamic>> _factors = [
    {'label': 'Safety', 'icon': Icons.security},
    {'label': 'Schools', 'icon': Icons.school},
    {'label': 'Hospitals', 'icon': Icons.local_hospital},
    {'label': 'Public Transport', 'icon': Icons.directions_bus},
    {'label': 'Mall Access', 'icon': Icons.shopping_bag},
  ];

  final FinancialService _financialService = FinancialService();
  final PropertyPreferenceService _preferenceService = PropertyPreferenceService();

  @override
  void initState() {
    super.initState();
    _loadExistingData();
    _monthlySalaryController.addListener(_checkFinancialFormDirty);
    _otherIncomeController.addListener(_checkFinancialFormDirty);
    _commitmentsController.addListener(_checkFinancialFormDirty);
    _savingsController.addListener(_checkFinancialFormDirty);
    _downPaymentController.addListener(_checkFinancialFormDirty);
  }

  @override
  void dispose() {
    _monthlySalaryController.removeListener(_checkFinancialFormDirty);
    _otherIncomeController.removeListener(_checkFinancialFormDirty);
    _commitmentsController.removeListener(_checkFinancialFormDirty);
    _savingsController.removeListener(_checkFinancialFormDirty);
    _downPaymentController.removeListener(_checkFinancialFormDirty);
    super.dispose();
  }

  void _checkFinancialFormDirty() {
    final currentSalary = double.tryParse(_monthlySalaryController.text) ?? 0;
    final currentOtherIncome = double.tryParse(_otherIncomeController.text) ?? 0;
    final currentCommitments = double.tryParse(_commitmentsController.text) ?? 0;
    final currentSavings = double.tryParse(_savingsController.text) ?? 0;
    final currentDownPayment = double.tryParse(_downPaymentController.text) ?? 0;

    final isDirty = currentSalary != _originalSalary ||
        currentOtherIncome != _originalOtherIncome ||
        currentCommitments != _originalCommitments ||
        currentSavings != _originalSavings ||
        currentDownPayment != _originalDownPayment;

    if (_isFinancialFormDirty != isDirty) {
      setState(() {
        _isFinancialFormDirty = isDirty;
      });
    }
  }

  void _checkPreferenceFormDirty() {
    final isDirty =
        _purpose != _originalPurpose ||
            _selectedPropertyTypes.toString() != _originalPropertyTypes.toString() ||
            _priceRange != _originalPriceRange ||
            _bedrooms != _originalBedrooms ||
            _state != _originalState ||
            _selectedFactors.toString() != _originalFactors.toString();

    if (_isPreferenceFormDirty != isDirty) {
      setState(() {
        _isPreferenceFormDirty = isDirty;
      });
    }
  }

  Future<void> _loadExistingData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.getCurrentUserId();

    if (userId == null || userId.isEmpty) return;

    bool hasData = false;

    try {
      final profile = await _financialService.getProfileByUserId(userId);
      if (profile != null) {
        setState(() {
          _monthlySalaryController.text = profile.monthlySalary > 0 ? profile.monthlySalary.toString() : "";
          _otherIncomeController.text = profile.otherIncome > 0 ? profile.otherIncome.toString() : "";
          _commitmentsController.text = profile.commitments > 0 ? profile.commitments.toString() : "";
          _savingsController.text = profile.savings > 0 ? profile.savings.toString() : "";
          _downPaymentController.text = profile.downPayment > 0 ? profile.downPayment.toString() : "";
          _financialDataLoaded = true;
          hasData = true;
          _originalSalary = profile.monthlySalary;
          _originalOtherIncome = profile.otherIncome;
          _originalCommitments = profile.commitments;
          _originalSavings = profile.savings;
          _originalDownPayment = profile.downPayment;
        });
      }
    } catch (e) {
      debugPrint('Load financial error: $e');
    }

    try {
      final preference = await _preferenceService.getPreferenceByUserId(userId);
      if (preference != null) {
        setState(() {
          _purpose = preference.purpose;
          _selectedPropertyTypes = preference.propertyType.split(',').map((s) => s.trim()).toList();
          if (_selectedPropertyTypes.isEmpty) _selectedPropertyTypes = ['Apartment'];
          _priceRange = preference.priceRange;
          _bedrooms = preference.bedrooms;
          _state = preference.preferredState;
          _selectedFactors = preference.importantFactors;
          hasData = true;
          _originalPurpose = preference.purpose;
          _originalPropertyTypes = _selectedPropertyTypes.toList();
          _originalPriceRange = preference.priceRange;
          _originalBedrooms = preference.bedrooms;
          _originalState = preference.preferredState;
          _originalFactors = _selectedFactors.toList();
        });
      }
    } catch (e) {
      debugPrint('Load preference error: $e');
    }

    setState(() {
      _hasExistingData = hasData;
      _isFinancialFormDirty = false;
      _isPreferenceFormDirty = false;
    });
  }

  void _clearFinancialForm() {
    setState(() {
      _monthlySalaryController.clear();
      _otherIncomeController.clear();
      _commitmentsController.clear();
      _savingsController.clear();
      _downPaymentController.clear();
      _isFinancialFormDirty = true;
    });
  }

  void _clearPreferenceForm() {
    setState(() {
      _purpose = "Own Stay";
      _selectedPropertyTypes = ['Apartment'];
      _priceRange = "RM200k-300k";
      _bedrooms = 3;
      _state = "Selangor";
      _selectedFactors = [];
      _isPreferenceFormDirty = true;
    });
  }

  Future<void> _saveFinancialData() async {
    if (_financialFormKey.currentState == null ||
        !_financialFormKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields correctly')),
      );
      return;
    }

    setState(() => _isLoadingFinancial = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    String? userId = auth.getCurrentUserId();

    if (userId == null || userId.isEmpty) {
      final session = SupabaseService().client.auth.currentSession;
      if (session != null) {
        userId = session.user.id;
      }
    }

    if (userId == null || userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please login first")),
        );
      }
      setState(() => _isLoadingFinancial = false);
      return;
    }

    final salary = double.tryParse(_monthlySalaryController.text) ?? 0;
    final otherIncome = double.tryParse(_otherIncomeController.text) ?? 0;
    final commitments = double.tryParse(_commitmentsController.text) ?? 0;
    final savings = double.tryParse(_savingsController.text) ?? 0;
    final downPayment = double.tryParse(_downPaymentController.text) ?? 0;

    final totalIncome = salary + otherIncome;
    double score = 0;
    double budget = 0;
    String riskLevel = "Low";

    if (totalIncome > 0) {
      final debtRatio = commitments / totalIncome;
      score = (100 - (debtRatio * 100)).clamp(30.0, 95.0);
      budget = totalIncome * 55 + savings * 0.6;
      if (debtRatio < 0.3) {
        riskLevel = "Low";
      } else if (debtRatio < 0.5) {
        riskLevel = "Medium";
      } else {
        riskLevel = "High";
      }
    }

    final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
    financialProvider.updateFinancialData(
      salary: salary,
      otherIncome: otherIncome,
      commitments: commitments,
      savings: savings,
      downPayment: downPayment,
    );

    final profile = FinancialProfileModel(
      id: '',
      userId: userId,
      monthlySalary: salary,
      otherIncome: otherIncome,
      commitments: commitments,
      savings: savings,
      downPayment: downPayment,
      affordabilityScore: score,
      recommendedBudget: budget,
      riskLevel: riskLevel,
    );

    try {
      await _financialService.saveOrUpdateProfile(profile);
      if (mounted) {
        setState(() {
          _isLoadingFinancial = false;
          _originalSalary = salary;
          _originalOtherIncome = otherIncome;
          _originalCommitments = commitments;
          _originalSavings = savings;
          _originalDownPayment = downPayment;
          _isFinancialFormDirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Financial data saved!")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFinancial = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving: $e")),
        );
      }
    }
  }

  Future<void> _savePreferenceData() async {
    setState(() => _isLoadingPreferences = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    String? userId = auth.getCurrentUserId();

    if (userId == null || userId.isEmpty) {
      final session = SupabaseService().client.auth.currentSession;
      if (session != null) {
        userId = session.user.id;
      }
    }

    if (userId == null || userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please login first")),
        );
      }
      setState(() => _isLoadingPreferences = false);
      return;
    }

    final propertyTypeString = _selectedPropertyTypes.join(',');

    final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
    financialProvider.updatePreferences(
      purpose: _purpose,
      propertyType: propertyTypeString,
      priceRange: _priceRange,
      bedrooms: _bedrooms,
      state: _state,
      factors: _selectedFactors,
    );

    final preference = PropertyPreferenceModel(
      id: '',
      userId: userId,
      purpose: _purpose,
      propertyType: propertyTypeString,
      priceRange: _priceRange,
      bedrooms: _bedrooms,
      preferredState: _state,
      importantFactors: _selectedFactors,
    );

    try {
      await _preferenceService.saveOrUpdatePreference(preference);
      if (mounted) {
        setState(() {
          _isLoadingPreferences = false;
          _originalPurpose = _purpose;
          _originalPropertyTypes = _selectedPropertyTypes.toList();
          _originalPriceRange = _priceRange;
          _originalBedrooms = _bedrooms;
          _originalState = _state;
          _originalFactors = _selectedFactors.toList();
          _isPreferenceFormDirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Preferences saved!")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPreferences = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving: $e")),
        );
      }
    }
  }

  Map<String, dynamic> _getCurrentFinancialData() {
    final salary = double.tryParse(_monthlySalaryController.text) ?? 0;
    final otherIncome = double.tryParse(_otherIncomeController.text) ?? 0;
    final commitments = double.tryParse(_commitmentsController.text) ?? 0;
    final savings = double.tryParse(_savingsController.text) ?? 0;

    return {
      'salary': salary,
      'otherIncome': otherIncome,
      'commitments': commitments,
      'savings': savings,
    };
  }

  Map<String, dynamic> _getCurrentPreferenceData() {
    return {
      'purpose': _purpose,
      'propertyTypes': _selectedPropertyTypes,
      'priceRange': _priceRange,
      'bedrooms': _bedrooms,
      'state': _state,
      'factors': _selectedFactors,
    };
  }

  bool _canProceed() {
    final salary = double.tryParse(_monthlySalaryController.text) ?? 0;
    if (salary <= 0) return false;
    if (_selectedPropertyTypes.isEmpty) return false;
    return true;
  }

  Future<void> _runAIAnalysis() async {
    if (widget.property == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No property selected for analysis')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = '';
      _matchDetails = null;
    });

    final financialData = _getCurrentFinancialData();
    final preferenceData = _getCurrentPreferenceData();
    final property = widget.property!;

    final monthlyIncome = financialData['salary'] + financialData['otherIncome'];
    final commitments = financialData['commitments'];
    final savings = financialData['savings'];

    double recommendedBudget = 0;
    if (monthlyIncome > 0) {
      recommendedBudget = (monthlyIncome * 0.55 - commitments) * 12 * 30 * 0.75 + savings * 0.6;
      if (recommendedBudget < 0) recommendedBudget = 0;
    }

    double score = 0;
    final details = <String, dynamic>{};

    final propertyPrice = property.price ?? 0;
    double priceScore = _calculatePriceScore(propertyPrice, recommendedBudget);
    score += priceScore * 0.4;
    details['priceMatch'] = priceScore;

    final preferredBedrooms = preferenceData['bedrooms'];
    double bedroomScore = _calculateBedroomScore(property.bedrooms ?? 0, preferredBedrooms);
    score += bedroomScore * 0.3;
    details['bedroomMatch'] = bedroomScore;

    final propertyType = property.propertyType ?? '';
    final selectedTypes = preferenceData['propertyTypes'] as List<String>;
    double typeScore = _calculateTypeScore(propertyType, selectedTypes);
    score += typeScore * 0.2;
    details['typeMatch'] = typeScore;

    final propertyState = property.state ?? '';
    final preferredState = preferenceData['state'];
    double stateScore = _calculateStateScore(propertyState, preferredState);
    score += stateScore * 0.1;
    details['stateMatch'] = stateScore;

    final matchPercentage = (score * 100).clamp(0.0, 100.0);
    details['matchPercentage'] = matchPercentage;

    final isAffordable = propertyPrice <= recommendedBudget * 1.2;
    details['isAffordable'] = isAffordable;

    details['propertyPrice'] = propertyPrice;
    details['recommendedBudget'] = recommendedBudget;
    details['monthlyIncome'] = monthlyIncome;
    details['priceToIncomeRatio'] = monthlyIncome > 0 ? propertyPrice / (monthlyIncome * 12) : 0;

    if (!mounted) return;

    final result = await AIService.analyzePropertyMatch(
      property: property,
      matchScore: matchPercentage,
      isAffordable: isAffordable,
      matchDetails: details,
      monthlyIncome: monthlyIncome,
      commitments: commitments,
      savings: savings,
      purpose: preferenceData['purpose'],
      preferredBedrooms: preferredBedrooms,
      preferredState: preferredState,
      importantFactors: preferenceData['factors'],
    );

    if (mounted) {
      setState(() {
        _matchDetails = details;
        _analysisResult = result;
        _isAnalyzing = false;
      });
    }
  }

  double _calculatePriceScore(int propertyPrice, double recommendedBudget) {
    if (propertyPrice <= 0 || recommendedBudget <= 0) return 0.5;

    final ratio = propertyPrice / recommendedBudget;
    if (ratio <= 0.7) return 0.9;
    if (ratio <= 0.9) return 1.0;
    if (ratio <= 1.0) return 1.0;
    if (ratio <= 1.2) return 0.8;
    if (ratio <= 1.5) return 0.6;
    if (ratio <= 2.0) return 0.4;
    return 0.2;
  }

  double _calculateBedroomScore(int propertyBedrooms, int preferredBedrooms) {
    if (propertyBedrooms <= 0) return 0.5;

    final diff = (propertyBedrooms - preferredBedrooms).abs();
    if (diff == 0) return 1.0;
    if (diff <= 1) return 0.8;
    if (diff <= 2) return 0.5;
    return 0.3;
  }

  double _calculateTypeScore(String propertyType, List<String> preferredTypes) {
    if (propertyType.isEmpty || preferredTypes.isEmpty) return 0.5;

    final type = propertyType.toLowerCase();
    for (final preferred in preferredTypes) {
      if (type.contains(preferred.toLowerCase())) {
        return 1.0;
      }
    }
    for (final preferred in preferredTypes) {
      if (preferred.toLowerCase() == 'apartment') {
        if (type.contains('condo') || type.contains('condominium')) return 0.8;
      }
      if (preferred.toLowerCase() == 'terrace') {
        if (type.contains('semi')) return 0.8;
      }
    }
    return 0.4;
  }

  double _calculateStateScore(String propertyState, String preferredState) {
    if (propertyState.isEmpty || preferredState.isEmpty) return 0.5;

    final state = propertyState.toLowerCase();
    final preferred = preferredState.toLowerCase();

    if (state.contains(preferred) || preferred.contains(state)) {
      return 1.0;
    }
    if (state.contains('kuala lumpur') || state.contains('selangor') || state.contains('penang')) {
      return 0.7;
    }
    if (state.contains('johor') || state.contains('negeri sembilan')) {
      return 0.6;
    }
    return 0.4;
  }

  Future<void> _proceedToAnalysis() async {
    if (_financialFormKey.currentState == null ||
        !_financialFormKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all financial fields correctly')),
      );
      return;
    }

    final salary = double.tryParse(_monthlySalaryController.text) ?? 0;
    if (salary <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your monthly salary')),
      );
      return;
    }

    await _runAIAnalysis();
  }

  void _onTabTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else if (index == 1) {
      if (_analysisResult.isNotEmpty) {
        setState(() {
          _analysisResult = '';
          _matchDetails = null;
        });
      }
    } else if (index == 2) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.isLoggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first')),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SavedPropertiesScreen()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final canProceed = _canProceed();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Advisor'),
        backgroundColor: Colors.blue, // ✅ Changed to blue
        foregroundColor: Colors.white,
        actions: [
          if (_hasExistingData)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[700],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Saved Data Found',
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isAnalyzing
          ? const Center(child: CircularProgressIndicator())
          : _analysisResult.isNotEmpty
          ? _buildAnalysisResult()
          : DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.blue, // ✅ Changed to blue
              tabs: [
                Tab(text: 'Financial Assessment'),
                Tab(text: 'Property Preferences'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildFinancialAssessment(),
                  _buildPropertyPreferences(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingFinancial || _isLoadingPreferences
                              ? null
                              : _clearFinancialForm,
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear Form'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_isLoadingFinancial || _isLoadingPreferences)
                              ? null
                              : () async {
                            await _saveFinancialData();
                            await _savePreferenceData();
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_isLoadingFinancial || _isLoadingPreferences)
                                ? Colors.grey
                                : Colors.blue, // ✅ Changed to blue
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canProceed && !_isLoadingFinancial && !_isLoadingPreferences
                          ? _proceedToAnalysis
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canProceed && !_isLoadingFinancial && !_isLoadingPreferences
                            ? Colors.blue // ✅ Changed to blue
                            : Colors.grey,
                        foregroundColor: canProceed && !_isLoadingFinancial && !_isLoadingPreferences
                            ? Colors.white
                            : Colors.grey[400],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Continue to Analysis',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue, // ✅ Changed to blue
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy),
            label: "AI",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: "Saved",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
        onTap: _onTabTapped,
      ),
    );
  }

  // ============================================================
  // Financial Assessment Tab
  // ============================================================
  Widget _buildFinancialAssessment() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _financialFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_financialDataLoaded)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: isDark ? Colors.orange[300] : Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No saved financial data found. Fill in the form below.',
                        style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: isDark ? Colors.green[300] : Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Existing data loaded. Click "Save" to update your profile.',
                        style: TextStyle(color: isDark ? Colors.green[300] : Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _monthlySalaryController,
              decoration: const InputDecoration(
                labelText: "Monthly Salary (RM)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please enter your monthly salary";
                }
                if (double.tryParse(value) == null) {
                  return "Enter a valid number";
                }
                if (double.parse(value) < 0) {
                  return "Salary cannot be negative";
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _otherIncomeController,
              decoration: const InputDecoration(
                labelText: "Other Income (RM)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                if (double.tryParse(value) == null) return "Enter a valid number";
                if (double.parse(value) < 0) return "Income cannot be negative";
                return null;
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _commitmentsController,
              decoration: const InputDecoration(
                labelText: "Monthly Commitments (RM)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                if (double.tryParse(value) == null) return "Enter a valid number";
                if (double.parse(value) < 0) return "Commitments cannot be negative";
                return null;
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _savingsController,
              decoration: const InputDecoration(
                labelText: "Savings (RM)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.savings),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                if (double.tryParse(value) == null) return "Enter a valid number";
                if (double.parse(value) < 0) return "Savings cannot be negative";
                return null;
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _downPaymentController,
              decoration: const InputDecoration(
                labelText: "Down Payment Budget (RM)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                if (double.tryParse(value) == null) return "Enter a valid number";
                if (double.parse(value) < 0) return "Down payment cannot be negative";
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Property Preferences Tab
  // ============================================================
  Widget _buildPropertyPreferences() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Purpose of Purchase",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _purposes.map((p) {
              final isSelected = _purpose == p;
              return ChoiceChip(
                label: Text(p),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _purpose = p;
                      _checkPreferenceFormDirty();
                    });
                  }
                },
                selectedColor: Colors.blue, // ✅ Blue when selected
                backgroundColor: isDark ? Colors.white : Colors.grey[200], // ✅ White when not selected in dark mode
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.black : Colors.black87),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          const Text(
            "Preferred Property Types (Select all that apply)",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _propertyTypes.map((type) {
              final isSelected = _selectedPropertyTypes.contains(type);
              return FilterChip(
                label: Text(type),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedPropertyTypes.add(type);
                    } else {
                      _selectedPropertyTypes.remove(type);
                    }
                    _checkPreferenceFormDirty();
                  });
                },
                selectedColor: Colors.blue, // ✅ Blue when selected
                backgroundColor: isDark ? Colors.white : Colors.grey[200], // ✅ White when not selected in dark mode
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.black : Colors.black87),
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
          if (_selectedPropertyTypes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Selected: ${_selectedPropertyTypes.join(', ')}",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.blue[700],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          const Text(
            "Budget Range",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _priceRanges.map((range) {
              final isSelected = _priceRange == range;
              return ChoiceChip(
                label: Text(range),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _priceRange = range;
                      _checkPreferenceFormDirty();
                    });
                  }
                },
                selectedColor: Colors.blue, // ✅ Blue when selected
                backgroundColor: isDark ? Colors.white : Colors.grey[200], // ✅ White when not selected in dark mode
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.black : Colors.black87),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          const Text(
            "Number of Bedrooms",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _bedroomOptions.map((b) {
              final isSelected = _bedrooms == b;
              return ChoiceChip(
                label: Text(b >= 4 ? "$b+" : "$b"),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _bedrooms = b;
                      _checkPreferenceFormDirty();
                    });
                  }
                },
                selectedColor: Colors.blue, // ✅ Blue when selected
                backgroundColor: isDark ? Colors.white : Colors.grey[200], // ✅ White when not selected in dark mode
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.black : Colors.black87),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          const Text(
            "Preferred State",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _state,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                items: _states.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _state = value!;
                    _checkPreferenceFormDirty();
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            "Most Important Factors (Select all that apply)",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _factors.map((factor) {
              final isSelected = _selectedFactors.contains(factor["label"]);
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      factor["icon"],
                      size: 16,
                      color: isSelected ? Colors.white : (isDark ? Colors.blue[300] : Colors.grey[600]),
                    ),
                    const SizedBox(width: 4),
                    Text(factor["label"]),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedFactors.add(factor["label"]);
                    } else {
                      _selectedFactors.remove(factor["label"]);
                    }
                    _checkPreferenceFormDirty();
                  });
                },
                selectedColor: Colors.blue, // ✅ Blue when selected
                backgroundColor: isDark ? Colors.white : Colors.grey[200], // ✅ White when not selected in dark mode
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.black : Colors.black87),
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
          if (_selectedFactors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: isDark ? Colors.white70 : Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Selected: ${_selectedFactors.join(', ')}",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // AI Analysis Result
  // ============================================================
  Widget _buildAnalysisResult() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.property != null)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.property!.mainTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.property!.formattedPrice,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.blue[300] : Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.property!.shortAddress,
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          Card(
            elevation: 2,
            color: isDark ? const Color(0xFF1E1E2E) : Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.smart_toy, color: isDark ? Colors.blue[300] : Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'AI Analysis Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  ..._analysisResult.split('\n').map((line) {
                    if (line.trim().isEmpty) return const SizedBox(height: 4);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        line,
                        style: TextStyle(
                          height: 1.6,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_matchDetails != null)
            Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: (_matchDetails!['matchPercentage'] ?? 0) / 100,
                          strokeWidth: 16,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            (_matchDetails!['matchPercentage'] ?? 0) >= 70
                                ? Colors.green
                                : (_matchDetails!['matchPercentage'] ?? 0) >= 40
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${(_matchDetails!['matchPercentage'] ?? 0).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Match Score',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildMatchDetailRow(
                          'Price Match',
                          (_matchDetails!['priceMatch'] * 100).toStringAsFixed(0),
                          isDark,
                        ),
                        _buildMatchDetailRow(
                          'Bedroom Match',
                          (_matchDetails!['bedroomMatch'] * 100).toStringAsFixed(0),
                          isDark,
                        ),
                        _buildMatchDetailRow(
                          'Type Match',
                          (_matchDetails!['typeMatch'] * 100).toStringAsFixed(0),
                          isDark,
                        ),
                        _buildMatchDetailRow(
                          'Location Match',
                          (_matchDetails!['stateMatch'] * 100).toStringAsFixed(0),
                          isDark,
                        ),
                        const Divider(),
                        _buildMatchDetailRow(
                          'Price-to-Income Ratio',
                          _matchDetails!['priceToIncomeRatio'] != null
                              ? '${(_matchDetails!['priceToIncomeRatio']).toStringAsFixed(1)}x'
                              : 'N/A',
                          isDark,
                          isHighlight: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          if (_matchDetails != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_matchDetails!['isAffordable'] ?? false)
                    ? (isDark ? const Color(0xFF1E1E2E) : Colors.green[50])
                    : (isDark ? const Color(0xFF1E1E2E) : Colors.red[50]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_matchDetails!['isAffordable'] ?? false)
                      ? Colors.green
                      : Colors.red,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    (_matchDetails!['isAffordable'] ?? false)
                        ? Icons.check_circle
                        : Icons.warning,
                    color: (_matchDetails!['isAffordable'] ?? false)
                        ? Colors.green
                        : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (_matchDetails!['isAffordable'] ?? false)
                          ? '✅ This property is within your budget'
                          : '⚠️ This property exceeds your recommended budget',
                      style: TextStyle(
                        color: (_matchDetails!['isAffordable'] ?? false)
                            ? (isDark ? Colors.green[300] : Colors.green[800])
                            : (isDark ? Colors.red[300] : Colors.red[800]),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _analysisResult = '';
                      _matchDetails = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Re-analyze'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // ✅ Changed to blue
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

  Widget _buildMatchDetailRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isHighlight ? 14 : 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white70 : Colors.grey[700]),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 16 : 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? Colors.blue : (isDark ? Colors.white : Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }
}