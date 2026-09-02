import 'package:flutter/material.dart';

import '../screens/financial_assessment_screen.dart';

Future<void> showCompleteFinancialAssessmentPrompt(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        icon: const Icon(Icons.smart_toy_outlined, color: Colors.blue, size: 36),
        title: const Text('Complete your profile'),
        content: const Text(
          'Set up your financial profile once to unlock AI recommendations. You can update it anytime from Profile or AI settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FinancialAssessmentScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Go to Assessment'),
          ),
        ],
      );
    },
  );
}
