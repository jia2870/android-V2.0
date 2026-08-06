import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/theme_provider.dart';
import 'login_screen.dart';
import 'financial_assessment_screen.dart';
import 'property_preferences_screen.dart';
import 'dashboard_screen.dart';
import 'saved_properties_screen.dart';
import 'ai_advisor_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const int _currentIndex = 3;

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
      // Profile - already here
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final financial = Provider.of<FinancialProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
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
              // User Avatar and Info
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: auth.profilePhoto.isNotEmpty
                              ? AssetImage(auth.profilePhoto)
                              : null,
                          child: auth.profilePhoto.isEmpty
                              ? const Icon(Icons.person, size: 60)
                              : null,
                        ),
                        if (auth.isLoggedIn)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Upload profile photo - Coming soon'),
                                    ),
                                  );
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 30,
                                  minHeight: 30,
                                ),
                              ),
                            ),
                          ),
                      ],
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

              // Financial Summary
              if (auth.isLoggedIn) ...[
                Card(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ FIX: Financial Summary text - white in dark mode
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
                                child: _buildSummaryItem(
                                  'Income',
                                  'RM ${financial.totalMonthlyIncome.toStringAsFixed(0)}',
                                  Colors.green,
                                  isDark,
                                ),
                              ),
                              Expanded(
                                child: _buildSummaryItem(
                                  'Commitments',
                                  'RM ${financial.commitments.toStringAsFixed(0)}',
                                  Colors.red,
                                  isDark,
                                ),
                              ),
                              Expanded(
                                child: _buildSummaryItem(
                                  'Savings',
                                  'RM ${financial.savings.toStringAsFixed(0)}',
                                  Colors.blue,
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
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
                              Expanded(
                                child: _buildSummaryItem(
                                  'Budget',
                                  'RM ${financial.recommendedBudget.toStringAsFixed(0)}',
                                  Colors.purple,
                                  isDark,
                                ),
                              ),
                              Expanded(
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
                const SizedBox(height: 20),
              ],

              // Not logged in
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

              // Property Preferences
              if (auth.isLoggedIn) ...[
                const Text(
                  "Property Preferences",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                _getPropertyTypeIcon(financial.propertyType),
                                color: Colors.orange[700],
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getPropertyTypeDisplay(financial.propertyType),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    softWrap: true,
                                  ),
                                  Text(
                                    '${financial.bedrooms} Bedroom${financial.bedrooms > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white70 : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PropertyPreferencesScreen(),
                                ),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Budget', financial.priceRange, isDark),
                            _buildInfoRow('Purpose', financial.purpose, isDark),
                            _buildInfoRow('State', financial.preferredState, isDark),
                            if (financial.importantFactors.isNotEmpty)
                              _buildInfoRow(
                                'Top Factors',
                                financial.importantFactors.join(', '),
                                isDark,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Logout button
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
            ],
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white70 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getPropertyTypeDisplay(String propertyType) {
    if (propertyType.isEmpty) return 'No type selected';
    if (propertyType.contains(',')) {
      final types = propertyType.split(',').map((s) => s.trim()).toList();
      return types.join(' . ');
    }
    return propertyType;
  }

  IconData _getPropertyTypeIcon(String propertyType) {
    if (propertyType.isEmpty) return Icons.home;
    String firstType = propertyType;
    if (propertyType.contains(',')) {
      firstType = propertyType.split(',').first.trim();
    }
    final type = firstType.toLowerCase();
    if (type.contains('bungalow')) {
      return Icons.villa;
    } else if (type.contains('semi') || type.contains('semi-d')) {
      return Icons.holiday_village;
    } else if (type.contains('terrace')) {
      return Icons.house;
    } else if (type.contains('condo') || type.contains('condominium')) {
      return Icons.apartment;
    } else if (type.contains('apartment')) {
      return Icons.apartment;
    }
    return Icons.home;
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}