import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/financial_provider.dart';
import '../services/debt_service.dart';
import '../services/financial_service.dart';
import '../services/supabase_service.dart';
import '../utils/ai_access_prompt.dart';
import '../utils/money_format.dart';
import '../widgets/money_form_field.dart';
import 'dashboard_screen.dart';
import 'saved_properties_screen.dart';
import 'profile_screen.dart';
import 'ai_advisor_screen.dart';
import 'login_screen.dart';
import 'financial_assessment_screen.dart';

class DebtManagementScreen extends StatefulWidget {
  const DebtManagementScreen({super.key});

  @override
  State<DebtManagementScreen> createState() => _DebtManagementScreenState();
}

class _DebtManagementScreenState extends State<DebtManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedDebtType = 'Car Loan';
  final _nameController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _monthlyPaymentController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _remainingMonthsController = TextEditingController();

  final DebtService _debtService = DebtService();
  final FinancialService _financialService = FinancialService();
  List<DebtModel> _debts = [];
  bool _isLoading = true;

  int _currentIndex = 3;

  final List<String> debtTypes = const [
    'Car Loan',
    'PTPTN',
    'Personal Loan',
    'Credit Card',
    'House Loan',
    'Other'
  ];

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
        showCompleteFinancialAssessmentPrompt(context);
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
  void initState() {
    super.initState();
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    String? userId = auth.getCurrentUserId();

    if (userId == null || userId.isEmpty) {
      final session = SupabaseService().client.auth.currentSession;
      if (session != null) {
        userId = session.user.id;
      }
    }

    if (userId != null && userId.isNotEmpty) {
      try {
        _debts = await _debtService.getDebtsByUserId(userId);
        if (!mounted) return;

        double totalCommitments = _debts.fold(0, (sum, d) => sum + d.monthlyPayment);

        final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
        financialProvider.replaceDebts(
          _debts
              .map(
                (debt) => Debt(
                  type: debt.type,
                  name: debt.name,
                  totalAmount: debt.totalAmount,
                  monthlyPayment: debt.monthlyPayment,
                  interestRate: debt.interestRate,
                  remainingMonths: debt.remainingMonths,
                ),
              )
              .toList(),
        );

        await _updateFinancialProfileCommitments(userId, totalCommitments);
      } catch (e) {
        debugPrint('Load debts error: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateFinancialProfileCommitments(String userId, double totalCommitments) async {
    try {
      final existingProfile = await _financialService.getProfileByUserId(userId);

      if (existingProfile != null) {
        final updatedProfile = FinancialProfileModel(
          id: existingProfile.id,
          userId: userId,
          monthlySalary: existingProfile.monthlySalary,
          otherIncome: existingProfile.otherIncome,
          commitments: totalCommitments,
          savings: existingProfile.savings,
          downPayment: existingProfile.downPayment,
          affordabilityScore: existingProfile.affordabilityScore,
          recommendedBudget: existingProfile.recommendedBudget,
          riskLevel: existingProfile.riskLevel,
        );

        await _financialService.updateProfile(updatedProfile);
        debugPrint('Financial profile commitments updated to: $totalCommitments');
      }
    } catch (e) {
      debugPrint('Update financial profile commitments error: $e');
    }
  }

  String? _validateNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) return "Please enter $fieldName";
    final amount = MoneyFormat.parse(value);
    if (amount == null) {
      return "Please enter a valid number";
    }
    if (amount < 0) {
      return "$fieldName cannot be negative";
    }
    return null;
  }

  Future<void> _saveDebt({bool isEdit = false, int? index}) async {
    if (!_formKey.currentState!.validate()) return;

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
          SnackBar(content: Text("Please login first")),
        );
      }
      return;
    }

    final debt = DebtModel(
      id: isEdit && index != null ? _debts[index].id : '',
      userId: userId,
      type: _selectedDebtType,
      name: _selectedDebtType == 'Other' ? _nameController.text : _selectedDebtType,
      totalAmount: MoneyFormat.parseOrZero(_totalAmountController.text),
      monthlyPayment: MoneyFormat.parseOrZero(_monthlyPaymentController.text),
      interestRate: double.parse(_interestRateController.text),
      remainingMonths: int.parse(_remainingMonthsController.text),
    );

    try {
      if (isEdit && index != null) {
        await _debtService.updateDebt(debt);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Debt updated')),
          );
        }
      } else {
        await _debtService.createDebt(debt);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Debt added')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        await _loadDebts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteDebt(String debtId, int index) async {
    try {
      await _debtService.deleteDebt(debtId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Debt removed')),
        );
        await _loadDebts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showAddDebtDialog() {
    _clearControllers();
    _selectedDebtType = debtTypes[0];
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _buildDebtDialog(isEdit: false),
    );
  }

  void _showEditDebtDialog(int index) {
    final debt = _debts[index];
    _selectedDebtType = debt.type;
    _nameController.text = debt.type == 'Other' ? debt.name : '';
    _totalAmountController.text = MoneyFormat.display(debt.totalAmount);
    _monthlyPaymentController.text = MoneyFormat.display(debt.monthlyPayment);
    _interestRateController.text = debt.interestRate.toString();
    _remainingMonthsController.text = debt.remainingMonths.toString();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _buildDebtDialog(isEdit: true, index: index),
    );
  }

  Widget _buildDebtDialog({required bool isEdit, int? index}) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Leave a clear gap above the keyboard; scroll the fields inside.
    final sheetHeight = ((screenHeight - bottomInset) * 0.92).clamp(160.0, screenHeight);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Theme.of(context).dialogTheme.backgroundColor ??
              Theme.of(context).colorScheme.surface,
          elevation: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: double.infinity,
            height: sheetHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    isEdit ? 'Edit Debt' : 'Add New Debt',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedDebtType,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Debt Type',
                            ),
                            items: debtTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedDebtType = value);
                              }
                            },
                          ),
                          if (_selectedDebtType == 'Other')
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Debt Name',
                              ),
                              validator: (value) => value!.isEmpty
                                  ? 'Please enter debt name'
                                  : null,
                            ),
                          MoneyFormField(
                            controller: _totalAmountController,
                            decoration: const InputDecoration(
                              labelText: 'Total Amount (RM)',
                            ),
                            validator: (value) =>
                                _validateNumber(value, 'Total Amount'),
                          ),
                          MoneyFormField(
                            controller: _monthlyPaymentController,
                            decoration: const InputDecoration(
                              labelText: 'Monthly Payment (RM)',
                            ),
                            validator: (value) =>
                                _validateNumber(value, 'Monthly Payment'),
                          ),
                          TextFormField(
                            controller: _interestRateController,
                            decoration: const InputDecoration(
                              labelText: 'Interest Rate (%)',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            validator: (value) =>
                                _validateNumber(value, 'Interest Rate'),
                          ),
                          TextFormField(
                            controller: _remainingMonthsController,
                            decoration: const InputDecoration(
                              labelText: 'Remaining Months',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) =>
                                _validateNumber(value, 'Remaining Months'),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () =>
                              _saveDebt(isEdit: isEdit, index: index),
                          child: Text(isEdit ? 'Update' : 'Add'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearControllers() {
    _nameController.clear();
    _totalAmountController.clear();
    _monthlyPaymentController.clear();
    _interestRateController.clear();
    _remainingMonthsController.clear();
  }

  Widget _buildSummaryCard() {
    double totalDebt = _debts.fold(0, (sum, d) => sum + d.totalAmount);
    double totalMonthly = _debts.fold(0, (sum, d) => sum + d.monthlyPayment);

    final financialProvider = Provider.of<FinancialProvider>(context);
    double totalIncome = financialProvider.totalMonthlyIncome;
    double debtRatio = totalIncome > 0 ? totalMonthly / totalIncome : 0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total Debt', 'RM ${totalDebt.toStringAsFixed(0)}'),
                _buildStat('Monthly Payment', 'RM ${totalMonthly.toStringAsFixed(0)}'),
                _buildStat('DTI Ratio', '${(debtRatio * 100).toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: debtRatio.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              color: debtRatio < 0.3
                  ? Colors.green
                  : debtRatio < 0.5
                  ? Colors.orange
                  : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  IconData _getDebtIcon(String type) {
    switch (type) {
      case 'Car Loan':
        return Icons.directions_car;
      case 'PTPTN':
        return Icons.school;
      case 'Personal Loan':
        return Icons.person;
      case 'Credit Card':
        return Icons.credit_card;
      case 'House Loan':
        return Icons.home;
      default:
        return Icons.attach_money;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Debt Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDebtDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildSummaryCard(),
          Expanded(
            child: _debts.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.credit_card_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No debts added yet'),
                  const SizedBox(height: 8),
                  const Text('Tap + to add a debt commitment'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _showAddDebtDialog,
                    child: const Text('Add Debt'),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _debts.length,
              itemBuilder: (context, index) {
                final debt = _debts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: Icon(_getDebtIcon(debt.type), color: Colors.blue),
                    title: Text(debt.name.isNotEmpty ? debt.name : debt.type),
                    subtitle: Text(
                      'RM ${debt.monthlyPayment.toStringAsFixed(2)}/month • ${debt.remainingMonths} months remaining',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showEditDebtDialog(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Debt'),
                                content: const Text('Are you sure?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteDebt(debt.id, index);
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
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
}
