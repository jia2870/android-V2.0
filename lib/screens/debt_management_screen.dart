import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/financial_provider.dart';
import '../services/debt_service.dart';
import '../services/financial_service.dart';
import '../services/supabase_service.dart';
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

  // 底部导航索引
  int _currentIndex = 3; // Profile

  final List<String> debtTypes = const [
    'Car Loan',
    'PTPTN',
    'Personal Loan',
    'Credit Card',
    'House Loan',
    'Other'
  ];

  // ============================================================
  // 底部导航切换
  // ============================================================
  void _onTabTapped(int index) {
    if (index == 0) {
      // Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else if (index == 1) {
      // AI
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
      // Saved
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
      // Profile
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

        // 计算总 commitments
        double totalCommitments = _debts.fold(0, (sum, d) => sum + d.monthlyPayment);

        // 更新 FinancialProvider - 使用 recalculate 方法
        final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
        financialProvider.commitments = totalCommitments;
        // 使用公开的 recalculate 方法
        financialProvider.recalculate();

        // 同时更新数据库中的 financial_profile
        await _updateFinancialProfileCommitments(userId, totalCommitments);
      } catch (e) {
        debugPrint('Load debts error: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // 更新 Financial Profile 中的 commitments
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
    if (double.tryParse(value) == null) {
      return "Please enter a valid number";
    }
    if (double.parse(value) < 0) {
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
      totalAmount: double.parse(_totalAmountController.text),
      monthlyPayment: double.parse(_monthlyPaymentController.text),
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
      builder: (context) => _buildDebtDialog(isEdit: false),
    );
  }

  void _showEditDebtDialog(int index) {
    final debt = _debts[index];
    _selectedDebtType = debt.type;
    _nameController.text = debt.type == 'Other' ? debt.name : '';
    _totalAmountController.text = debt.totalAmount.toString();
    _monthlyPaymentController.text = debt.monthlyPayment.toString();
    _interestRateController.text = debt.interestRate.toString();
    _remainingMonthsController.text = debt.remainingMonths.toString();
    showDialog(
      context: context,
      builder: (context) => _buildDebtDialog(isEdit: true, index: index),
    );
  }

  Widget _buildDebtDialog({required bool isEdit, int? index}) {
    return AlertDialog(
      title: Text(isEdit ? 'Edit Debt' : 'Add New Debt'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedDebtType,
                decoration: const InputDecoration(labelText: 'Debt Type'),
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
                  decoration: const InputDecoration(labelText: 'Debt Name'),
                  validator: (value) => value!.isEmpty ? 'Please enter debt name' : null,
                ),
              TextFormField(
                controller: _totalAmountController,
                decoration: const InputDecoration(labelText: 'Total Amount (RM)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => _validateNumber(value, "Total Amount"),
              ),
              TextFormField(
                controller: _monthlyPaymentController,
                decoration: const InputDecoration(labelText: 'Monthly Payment (RM)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => _validateNumber(value, "Monthly Payment"),
              ),
              TextFormField(
                controller: _interestRateController,
                decoration: const InputDecoration(labelText: 'Interest Rate (%)'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                validator: (value) => _validateNumber(value, "Interest Rate"),
              ),
              TextFormField(
                controller: _remainingMonthsController,
                decoration: const InputDecoration(labelText: 'Remaining Months'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => _validateNumber(value, "Remaining Months"),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _saveDebt(isEdit: isEdit, index: index),
          child: Text(isEdit ? 'Update' : 'Add'),
        ),
      ],
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
      // ============================================================
      // 底部导航栏
      // ============================================================
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