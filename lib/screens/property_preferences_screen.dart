import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/theme_provider.dart';
import '../services/property_preference_service.dart';
import '../services/supabase_service.dart';
import 'dashboard_screen.dart';
import 'saved_properties_screen.dart';
import 'profile_screen.dart';
import 'ai_advisor_screen.dart';

class PropertyPreferencesScreen extends StatefulWidget {
  const PropertyPreferencesScreen({super.key});

  @override
  State<PropertyPreferencesScreen> createState() => _PropertyPreferencesScreenState();
}

class _PropertyPreferencesScreenState extends State<PropertyPreferencesScreen> {
  String _purpose = 'Own Stay';
  List<String> _selectedPropertyTypes = ['Apartment'];
  String _priceRange = 'RM200k-300k';
  int _bedrooms = 3;
  String _state = 'Selangor';
  List<String> _selectedFactors = [];

  bool _isLoading = true;
  bool _isSaving = false;

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

  final PropertyPreferenceService _preferenceService = PropertyPreferenceService();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
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
        final preference = await _preferenceService.getPreferenceByUserId(userId);
        if (preference != null && mounted) {
          setState(() {
            _purpose = preference.purpose;
            _selectedPropertyTypes = preference.propertyType.split(',').map((s) => s.trim()).toList();
            if (_selectedPropertyTypes.isEmpty) {
              _selectedPropertyTypes = ['Apartment'];
            }
            _priceRange = preference.priceRange;
            _bedrooms = preference.bedrooms;
            _state = preference.preferredState;
            _selectedFactors = preference.importantFactors;
          });
          final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
          final propertyTypeString = _selectedPropertyTypes.join(', ');
          financialProvider.updatePreferences(
            purpose: _purpose,
            propertyType: propertyTypeString,
            priceRange: _priceRange,
            bedrooms: _bedrooms,
            state: _state,
            factors: _selectedFactors,
          );
        }
      } catch (e) {
        debugPrint('Load preferences error: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    if (!mounted) return;
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

    final propertyTypeString = _selectedPropertyTypes.join(', ');

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Preferences saved to cloud!")),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Property Preferences")),
        body: const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: _buildBottomNavBar(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Property Preferences"),
        actions: [
          if (_selectedPropertyTypes.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_selectedPropertyTypes.length} types',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Purpose
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
                      if (selected) setState(() => _purpose = p);
                    },
                    selectedColor: Colors.blue,
                    backgroundColor: isDark ? Colors.white : Colors.grey[200],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.black : Colors.black87),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Property Types
              const Text(
                "Preferred Property Types (Select all that apply)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "Select all that apply",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
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
                      });
                    },
                    selectedColor: Colors.blue,
                    backgroundColor: isDark ? Colors.white : Colors.grey[200],
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: isDark ? Colors.white70 : Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Selected: ${_selectedPropertyTypes.join(', ')}",
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
              const SizedBox(height: 20),

              // Budget Range
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
                      if (selected) setState(() => _priceRange = range);
                    },
                    selectedColor: Colors.blue,
                    backgroundColor: isDark ? Colors.white : Colors.grey[200],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.black : Colors.black87),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Number of Bedrooms
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
                      if (selected) setState(() => _bedrooms = b);
                    },
                    selectedColor: Colors.blue,
                    backgroundColor: isDark ? Colors.white : Colors.grey[200],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.black : Colors.black87),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Preferred State
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
                    onChanged: (value) => setState(() => _state = value!),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Important Factors
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
                          size: 18,
                          color: isSelected ? Colors.white : (isDark ? Colors.blue[300] : Colors.blue[700]),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          factor["label"],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
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
                      });
                    },
                    selectedColor: Colors.blue,
                    backgroundColor: isDark ? Colors.white : Colors.grey[200],
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? Colors.blue : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        width: 1,
                      ),
                    ),
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
                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.blue[200]!),
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
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: _isSaving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _savePreferences,
                  child: const Text("Save Preferences"),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.search), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: "AI"),
        BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Saved"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
      onTap: _onTabTapped,
    );
  }
}