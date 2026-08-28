import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../utils/loan_calculator.dart';
import '../utils/money_format.dart';
import '../widgets/money_form_field.dart';

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key, this.propertyPrice});

  final double? propertyPrice;

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final _priceController = TextEditingController();
  final _loanController = TextEditingController();
  final _rateController = TextEditingController();
  final _tenureController = TextEditingController();

  LoanCalculationResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    final price = widget.propertyPrice;
    if (price != null && price > 0) {
      _priceController.text = MoneyFormat.display(price);
      _loanController.text =
          MoneyFormat.display(LoanCalculator.suggestedLoanAmount(price));
    }
    _rateController.text =
        LoanCalculator.defaultAnnualRatePercent.toStringAsFixed(1);
    _tenureController.text = '${LoanCalculator.defaultTenureYears}';

    if (price != null && price > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculate());
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _loanController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  bool get _isBestRateApplied {
    final rate = double.tryParse(_rateController.text.trim());
    return rate != null &&
        (rate - LoanCalculator.defaultAnnualRatePercent).abs() < 0.001;
  }

  void _onPropertyPriceChanged(String _) {
    final price = MoneyFormat.parseOrZero(_priceController.text);
    if (price <= 0) return;
    final suggested = LoanCalculator.suggestedLoanAmount(price);
    _loanController.text = MoneyFormat.display(suggested);
  }

  void _calculate() {
    final loan = MoneyFormat.parseOrZero(_loanController.text);
    final rate = double.tryParse(_rateController.text.trim()) ?? -1;
    final tenure = int.tryParse(_tenureController.text.trim()) ?? 0;

    if (loan <= 0) {
      setState(() {
        _error = 'Enter a valid loan amount';
        _result = null;
      });
      return;
    }
    if (rate < 0 || rate > 100) {
      setState(() {
        _error = 'Enter a valid interest rate (0–100%)';
        _result = null;
      });
      return;
    }
    if (tenure < 1 || tenure > 50) {
      setState(() {
        _error = 'Enter a valid loan tenure (1–50 years)';
        _result = null;
      });
      return;
    }

    setState(() {
      _error = null;
      _result = LoanCalculationResult.compute(
        principal: loan,
        annualRatePercent: rate,
        tenureYears: tenure,
      );
    });
  }

  InputDecoration _fieldDecoration({
    required String unit,
    required bool isDark,
    bool unitAsPrefix = false,
  }) {
    return InputDecoration(
      prefixText: unitAsPrefix ? '$unit ' : null,
      suffixText: unitAsPrefix ? null : unit,
      filled: true,
      fillColor: isDark ? Colors.grey[850] : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      appBar: AppBar(title: const Text('Loan Calculator')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'Property Price',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            MoneyFormField(
              controller: _priceController,
              decoration: _fieldDecoration(
                unit: 'RM',
                isDark: isDark,
                unitAsPrefix: true,
              ).copyWith(hintText: '0.00'),
              onChanged: _onPropertyPriceChanged,
            ),
            const SizedBox(height: 16),
            Text(
              'Loan Amount',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            MoneyFormField(
              controller: _loanController,
              decoration: _fieldDecoration(
                unit: 'RM',
                isDark: isDark,
                unitAsPrefix: true,
              ).copyWith(hintText: '0.00'),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interest Rate',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d{0,2}(\.\d{0,2})?$'),
                          ),
                        ],
                        decoration: _fieldDecoration(
                          unit: '%',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loan Tenure',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _tenureController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        decoration: _fieldDecoration(
                          unit: 'Yrs',
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isBestRateApplied) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: Colors.green[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Best rate applied',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 20),
              _ResultCard(result: _result!, isDark: isDark),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _calculate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  side: BorderSide(
                    color: isDark ? Colors.white70 : Colors.black87,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  _result == null ? 'Calculate' : 'Calculate again',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.isDark});

  final LoanCalculationResult result;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly installment',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'RM ${MoneyFormat.display(result.monthlyInstallment)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blue[300] : Colors.blue[800],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _miniStat(
                    'Total payment',
                    'RM ${MoneyFormat.display(result.totalPayment)}',
                  ),
                ),
                Expanded(
                  child: _miniStat(
                    'Total interest',
                    'RM ${MoneyFormat.display(result.totalInterest)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
