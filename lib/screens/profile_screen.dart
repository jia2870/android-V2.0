import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/money_format.dart';
import '../widgets/editable_avatar.dart';
import '../widgets/adaptive_nav_scaffold.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'financial_assessment_screen.dart';
import 'loan_calculator_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _onTabTapped(int index) {
    if (index == AppNavIndex.profile) return;
    handleAppNavigation(context, index);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final financial = Provider.of<FinancialProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return AdaptiveNavScaffold(
      currentIndex: AppNavIndex.profile,
      onTap: _onTabTapped,
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    EditableAvatar(
                      photoUrl: auth.profilePhoto,
                      editable: auth.isLoggedIn,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      auth.isLoggedIn ? auth.userName : "Guest User",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (auth.isLoggedIn) ...[
                      Text(
                        auth.email,
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
                      ),
                      Text(
                        "Phone: ${auth.phoneNumber}",
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
                      ),
                      Text(
                        "📍 ${auth.selectedState}",
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue, width: 1.5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        "Please login to view your profile",
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 30),

              if (auth.isLoggedIn) ...[
                Card(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "💰 Financial Summary",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const FinancialAssessmentScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (financial.monthlySalary > 0) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  child: _buildSummaryItem(
                                    'Income',
                                    'RM ${MoneyFormat.display(financial.totalMonthlyIncome)}',
                                    Colors.green,
                                    isDark,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  child: _buildSummaryItem(
                                    'Commitments',
                                    'RM ${MoneyFormat.display(financial.commitments)}',
                                    Colors.red,
                                    isDark,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  child: _buildSummaryItem(
                                    'Savings',
                                    'RM ${MoneyFormat.display(financial.savings)}',
                                    Colors.blue,
                                    isDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  child: _buildSummaryItem(
                                    'Score',
                                    '${financial.affordabilityScore.toStringAsFixed(0)}%',
                                    financial.riskLevel == 'Low'
                                        ? Colors.green
                                        : financial.riskLevel == 'Medium'
                                        ? Colors.orange
                                        : Colors.red,
                                    isDark,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  child: _buildSummaryItem(
                                    'Budget',
                                    'RM ${MoneyFormat.display(financial.recommendedBudget)}',
                                    Colors.purple,
                                    isDark,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  child: _buildSummaryItem(
                                    'Risk',
                                    financial.riskLevel,
                                    financial.riskLevel == 'Low'
                                        ? Colors.green
                                        : financial.riskLevel == 'Medium'
                                        ? Colors.orange
                                        : Colors.red,
                                    isDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            'No financial data yet. Click Edit to add your financial information.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                  child: ListTile(
                    leading: Icon(
                      Icons.calculate_outlined,
                      color: Colors.blue[400],
                    ),
                    title: Text(
                      'Loan Calculator',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'Estimate monthly installments',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoanCalculatorScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await auth.logoutWithAuth();
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Logout'),
                  ),
                ),
              ],

              if (!auth.isLoggedIn) ...[
                Card(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 60,
                          color: isDark ? Colors.white70 : Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Login to access all features',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create an account to save your preferences,'
                              ' get personalized recommendations, and more!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            ),
                            child: const Text('Login / Register'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white70 : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
