import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/financial_provider.dart';

class AssetManagementScreen extends StatefulWidget {
  const AssetManagementScreen({super.key});

  @override
  State<AssetManagementScreen> createState() => _AssetManagementScreenState();
}

class _AssetManagementScreenState extends State<AssetManagementScreen> {
  final _savingsController = TextEditingController();
  final _downPaymentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<FinancialProvider>(context, listen: false);
    _savingsController.text = provider.totalSavings > 0 ? provider.totalSavings.toString() : "";
    _downPaymentController.text = provider.downPaymentBudget > 0 ? provider.downPaymentBudget.toString() : "";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asset Management')),
      body: Consumer<FinancialProvider>(
        builder: (context, provider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Assets',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Savings',
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                'RM ${provider.totalSavings.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Down Payment Budget',
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                'RM ${provider.downPaymentBudget.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Update Assets',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _savingsController,
                    decoration: const InputDecoration(
                      labelText: 'Total Savings (RM)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.savings),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) => _validateNumber(value, "Savings"),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _downPaymentController,
                    decoration: const InputDecoration(
                      labelText: 'Down Payment Budget (RM)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) => _validateNumber(value, "Down Payment"),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final savings = double.tryParse(_savingsController.text) ?? 0;
                          final downPayment = double.tryParse(_downPaymentController.text) ?? 0;

                          provider.updateSavings(savings);
                          provider.updateDownPayment(downPayment);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Assets updated!')),
                          );
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}