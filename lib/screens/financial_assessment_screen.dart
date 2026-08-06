import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/financial_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/financial_service.dart';
import '../../services/supabase_service.dart';
import 'debt_management_screen.dart';
import 'dashboard_screen.dart';
import 'saved_properties_screen.dart';
import 'profile_screen.dart';
import 'ai_advisor_screen.dart';

class FinancialAssessmentScreen extends StatefulWidget {
  const FinancialAssessmentScreen({super.key});

  @override
  State<FinancialAssessmentScreen> createState() => _FinancialAssessmentScreenState();
}

class _FinancialAssessmentScreenState extends State<FinancialAssessmentScreen> {
  final _monthlySalaryController = TextEditingController();
  final _otherIncomeController = TextEditingController();
  final _commitmentsController = TextEditingController();
  final _savingsController = TextEditingController();
  final _downPaymentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final FinancialService _financialService = FinancialService();
  bool _isSaving = false;

  static const int _currentIndex = 1;

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  @override
  void dispose() {
    _monthlySalaryController.dispose();
    _otherIncomeController.dispose();
    _commitmentsController.dispose();
    _savingsController.dispose();
    _downPaymentController.dispose();
    super.dispose();
  }

  Future<void> _loadFinancialData() async {
    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.getCurrentUserId();

    if (userId != null && userId.isNotEmpty) {
      try {
        final profile = await _financialService.getProfileByUserId(userId);
        if (mounted) {
          if (profile != null) {
            setState(() {
              _monthlySalaryController.text = profile.monthlySalary > 0
                  ? profile.monthlySalary.toString()
                  : "";
              _otherIncomeController.text = profile.otherIncome > 0
                  ? profile.otherIncome.toString()
                  : "";
              _commitmentsController.text = profile.commitments > 0
                  ? profile.commitments.toString()
                  : "";
              _savingsController.text = profile.savings > 0
                  ? profile.savings.toString()
                  : "";
              _downPaymentController.text = profile.downPayment > 0
                  ? profile.downPayment.toString()
                  : "";
            });

            final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
            financialProvider.updateFinancialData(
              salary: profile.monthlySalary,
              otherIncome: profile.otherIncome,
              commitments: profile.commitments,
              savings: profile.savings,
              downPayment: profile.downPayment,
            );
          } else {
            setState(() {
              _monthlySalaryController.text = "";
              _otherIncomeController.text = "";
              _commitmentsController.text = "";
              _savingsController.text = "";
              _downPaymentController.text = "";
            });
          }
        }
      } catch (e) {
        debugPrint('Load financial data error: $e');
      }
    }
  }

  String? _validateNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) return null;
    if (double.tryParse(value) == null) {
      return "Please enter a valid number";
    }
    if (double.parse(value) < 0) {
      return "Amount cannot be negative";
    }
    return null;
  }

  Future<void> _saveFinancialData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

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
      setState(() => _isSaving = false);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Financial data saved to cloud!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving: ${e.toString()}")),
        );
      }
      debugPrint('Save error: $e');
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  void _onTabTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else if (index == 1) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final financial = Provider.of<FinancialProvider>(context, listen: false);
      if (!auth.isLoggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first')),
        );
        return;
      }
      if (financial.monthlySalary <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete your financial assessment first')),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AIAdvisorScreen(property: null),
        ),
      );
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
    final financialProvider = Provider.of<FinancialProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(title: const Text("Financial Assessment")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ============================================
                // Summary Card - ✅ Fixed: Dark background with white text in dark mode
                // ============================================
                Card(
                  color: isDark ? Colors.grey[900] : Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "💰 Financial Summary",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem(
                              "Total Income",
                              "RM ${financialProvider.totalMonthlyIncome.toStringAsFixed(0)}",
                              Colors.green,
                              isDark,
                            ),
                            _buildSummaryItem(
                              "Total Debt",
                              "RM ${financialProvider.totalDebt.toStringAsFixed(0)}",
                              Colors.red,
                              isDark,
                            ),
                            _buildSummaryItem(
                              "Total Assets",
                              "RM ${(financialProvider.savings + financialProvider.downPayment).toStringAsFixed(0)}",
                              Colors.blue,
                              isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ============================================
                // Basic Information
                // ============================================
                Text(
                  "Basic Information",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
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
                  validator: (value) => _validateNumber(value, "Monthly Salary"),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
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
                  validator: (value) => _validateNumber(value, "Other Income"),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 12),

                // ============================================
                // Monthly Commitments - with white border in dark mode
                // ============================================
                TextFormField(
                  controller: _commitmentsController,
                  decoration: InputDecoration(
                    labelText: "Monthly Commitments (RM)",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.credit_card),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DebtManagementScreen(),
                          ),
                        ).then((_) {
                          _loadFinancialData();
                        });
                      },
                      tooltip: 'Manage Debts',
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white54 : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  readOnly: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DebtManagementScreen(),
                      ),
                    ).then((_) {
                      _loadFinancialData();
                    });
                  },
                  validator: (value) => _validateNumber(value, "Monthly Commitments"),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
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
                  validator: (value) => _validateNumber(value, "Savings"),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _downPaymentController,
                  decoration: const InputDecoration(
                    labelText: "Down Payment (RM)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) => _validateNumber(value, "Down Payment"),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 8),

                // ============================================
                // Manage Debts Button - White border in dark mode
                // ============================================
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DebtManagementScreen(),
                        ),
                      ).then((_) {
                        _loadFinancialData();
                      });
                    },
                    icon: const Icon(Icons.credit_card),
                    label: const Text('Manage Debts'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? Colors.white : Colors.blue,
                      ),
                      foregroundColor: isDark ? Colors.white : Colors.blue,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // ============================================
                // Save Button - White border in dark mode
                // ============================================
                SizedBox(
                  width: double.infinity,
                  child: _isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                    onPressed: _saveFinancialData,
                    style: ElevatedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? Colors.white : Colors.transparent,
                      ),
                    ),
                    child: const Text("Save & Calculate Affordability"),
                  ),
                ),

                // ============================================
                // Affordability Assessment - ✅ Fixed: Dark background with white text in dark mode
                // ============================================
                if (financialProvider.affordabilityScore > 0) ...[
                  const SizedBox(height: 30),
                  Card(
                    color: financialProvider.riskLevel == 'Low'
                        ? (isDark ? Colors.grey[900] : Colors.green[50])
                        : financialProvider.riskLevel == 'Medium'
                        ? (isDark ? Colors.grey[900] : Colors.orange[50])
                        : (isDark ? Colors.grey[900] : Colors.red[50]),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            "Affordability Assessment",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    "${financialProvider.affordabilityScore.toStringAsFixed(0)}%",
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: financialProvider.riskLevel == 'Low'
                                          ? Colors.green
                                          : financialProvider.riskLevel == 'Medium'
                                          ? Colors.orange
                                          : Colors.red,
                                    ),
                                  ),
                                  Text(
                                    "Score",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    "RM ${financialProvider.recommendedBudget.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.blue[300] : Colors.blue,
                                    ),
                                  ),
                                  Text(
                                    "Budget",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    financialProvider.riskLevel,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: financialProvider.riskLevel == 'Low'
                                          ? Colors.green
                                          : financialProvider.riskLevel == 'Medium'
                                          ? Colors.orange
                                          : Colors.red,
                                    ),
                                  ),
                                  Text(
                                    "Risk Level",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: "AI"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Saved"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
        onTap: _onTabTapped,
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}