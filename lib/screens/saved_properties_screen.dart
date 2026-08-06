import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/property_model.dart';
import '../services/saved_property_service.dart';
import '../services/property_service.dart';
import '../providers/auth_provider.dart';
import '../providers/financial_provider.dart';
import 'property_detail_screen.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'ai_advisor_screen.dart';

class SavedPropertiesScreen extends StatefulWidget {
  const SavedPropertiesScreen({super.key});

  @override
  State<SavedPropertiesScreen> createState() => _SavedPropertiesScreenState();
}

class _SavedPropertiesScreenState extends State<SavedPropertiesScreen> {
  final SavedPropertyService _savedService = SavedPropertyService();
  final PropertyService _propertyService = PropertyService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  List<PropertyModel> _properties = [];
  List<PropertyModel> _filteredProperties = [];
  bool _isLoading = true;
  bool _showFilters = false;
  String? _errorMessage;

  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedPropertyType;
  String? _selectedTenure;
  int? _minPrice;
  int? _maxPrice;
  int? _selectedBedrooms;

  List<String> _states = [];
  List<String> _districts = [];
  final List<String> _propertyTypes = const [
    'Apartment', 'Condominium', 'Terrace', 'Semi-D', 'Bungalow'
  ];
  final List<String> _tenureTypes = const [
    'Freehold', 'Leasehold'
  ];
  final List<int> _bedroomOptions = const [1, 2, 3, 4, 5];

  // 底部导航索引
  static const int _currentIndex = 2; // Saved

  @override
  void initState() {
    super.initState();
    _loadSavedProperties();
    _loadStates();
  }

  Future<void> _loadSavedProperties() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.getCurrentUserId();

    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Please login to view saved properties";
        });
      }
      return;
    }

    try {
      _properties = await _savedService.getSavedProperties(userId);
      _filteredProperties = _properties;
      if (_properties.isEmpty && mounted) {
        setState(() {
          _errorMessage = 'No saved properties yet.\nStart exploring and save your favorites!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading saved properties: $e';
        });
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStates() async {
    try {
      _states = await _propertyService.getStates();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Load states error: $e');
    }
  }

  void _searchProperties() {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final query = _searchController.text.trim();

    final filtered = _properties.where((property) {
      if (query.isNotEmpty) {
        final searchText = query.toLowerCase();
        final address = property.fullAddress?.toLowerCase() ?? '';
        final state = property.state?.toLowerCase() ?? '';
        final district = property.district?.toLowerCase() ?? '';
        final description = property.description?.toLowerCase() ?? '';
        if (!address.contains(searchText) &&
            !state.contains(searchText) &&
            !district.contains(searchText) &&
            !description.contains(searchText)) {
          return false;
        }
      }

      if (_selectedState != null && _selectedState!.isNotEmpty) {
        if (property.state != _selectedState) return false;
      }

      if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) {
        if (property.district != _selectedDistrict) return false;
      }

      if (_minPrice != null && (property.price ?? 0) < _minPrice!) return false;
      if (_maxPrice != null && (property.price ?? 0) > _maxPrice!) return false;

      if (_selectedBedrooms != null && (property.bedrooms ?? 0) < _selectedBedrooms!) return false;

      if (_selectedPropertyType != null && _selectedPropertyType!.isNotEmpty) {
        if (!(property.propertyType?.contains(_selectedPropertyType!) ?? false)) return false;
      }

      if (_selectedTenure != null && _selectedTenure!.isNotEmpty) {
        if (property.tenure != _selectedTenure) return false;
      }

      return true;
    }).toList();

    setState(() {
      _filteredProperties = filtered;
      _isLoading = false;
      if (filtered.isEmpty && _properties.isNotEmpty) {
        _errorMessage = 'No saved properties match your filters';
      } else if (filtered.isEmpty && _properties.isEmpty) {
        _errorMessage = 'No saved properties yet.\nStart exploring and save your favorites!';
      } else {
        _errorMessage = null;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedState = null;
      _selectedDistrict = null;
      _selectedPropertyType = null;
      _selectedTenure = null;
      _minPrice = null;
      _maxPrice = null;
      _selectedBedrooms = null;
      _districts = [];
      _searchController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
    });
    _searchProperties();
  }

  Future<void> _loadDistricts(String state) async {
    if (state.isEmpty) {
      if (mounted) setState(() => _districts = []);
      return;
    }
    try {
      _districts = await _propertyService.getDistrictsByState(state);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Load districts error: $e');
    }
  }

  Future<void> _removeSaved(String listingId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.getCurrentUserId();
    if (userId == null || userId.isEmpty) return;

    try {
      await _savedService.unsaveProperty(userId, listingId);
      setState(() {
        _properties.removeWhere((p) => p.listingId == listingId);
        _filteredProperties.removeWhere((p) => p.listingId == listingId);
        if (_properties.isEmpty) {
          _errorMessage = 'No saved properties yet.\nStart exploring and save your favorites!';
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from favorites')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

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
      // Saved - 已经是这个页面
    } else if (index == 3) {
      // Profile
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved Properties')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Login to view your saved properties',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 16),
              LoginButton(),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Properties'),
        actions: [
          if (_properties.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${_properties.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_off),
            onPressed: () {
              setState(() => _showFilters = !_showFilters);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search in saved properties...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchProperties();
                        },
                      )
                          : null,
                    ),
                    onSubmitted: (_) => _searchProperties(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchProperties,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),

          // Filters
          if (_showFilters) _buildFilters(),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredProperties.length} saved properties',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (_showFilters)
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear All'),
                  ),
              ],
            ),
          ),

          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _errorMessage!.contains('No saved properties')
                      ? Colors.blue[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _errorMessage!.contains('No saved properties')
                        ? Colors.blue[200]!
                        : Colors.red[200]!,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _errorMessage!.contains('No saved properties')
                          ? Icons.favorite_border
                          : Icons.error_outline,
                      color: _errorMessage!.contains('No saved properties')
                          ? Colors.blue[400]
                          : Colors.red[400],
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _errorMessage!.contains('No saved properties')
                            ? Colors.blue[800]
                            : Colors.red[800],
                      ),
                    ),
                    if (_errorMessage!.contains('No saved properties'))
                      const SizedBox(height: 12),
                    if (_errorMessage!.contains('No saved properties'))
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Browse Properties'),
                      ),
                  ],
                ),
              ),
            ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProperties.isEmpty && _properties.isEmpty
                ? const SizedBox()
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredProperties.length,
              itemBuilder: (context, index) {
                final property = _filteredProperties[index];
                return _buildPropertyCard(property);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
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
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedState,
            decoration: const InputDecoration(
              labelText: 'State',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All States')),
              ..._states.map((s) => DropdownMenuItem(value: s, child: Text(s))),
            ],
            onChanged: (value) {
              setState(() {
                _selectedState = value;
                _selectedDistrict = null;
              });
              if (value != null) {
                _loadDistricts(value);
              } else {
                setState(() => _districts = []);
              }
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedDistrict,
            decoration: const InputDecoration(
              labelText: 'District',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Districts')),
              ..._districts.map((d) => DropdownMenuItem(value: d, child: Text(d))),
            ],
            onChanged: (value) => setState(() => _selectedDistrict = value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedPropertyType,
            decoration: const InputDecoration(
              labelText: 'Property Type',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Types')),
              ..._propertyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))),
            ],
            onChanged: (value) => setState(() => _selectedPropertyType = value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedTenure,
            decoration: const InputDecoration(
              labelText: 'Tenure',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Tenure')),
              ..._tenureTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))),
            ],
            onChanged: (value) => setState(() => _selectedTenure = value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _selectedBedrooms,
            decoration: const InputDecoration(
              labelText: 'Bedrooms',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any')),
              ..._bedroomOptions.map((b) => DropdownMenuItem(value: b, child: Text('$b+'))),
            ],
            onChanged: (value) => setState(() => _selectedBedrooms = value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Min Price (RM)',
                    border: OutlineInputBorder(),
                    prefixText: 'RM ',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    _minPrice = value.isEmpty ? null : int.tryParse(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _maxPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Max Price (RM)',
                    border: OutlineInputBorder(),
                    prefixText: 'RM ',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    _maxPrice = value.isEmpty ? null : int.tryParse(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear Filters'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _searchProperties,
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(PropertyModel property) {
    final photoList = property.photoUrlList;
    final displayPrice = property.price != null
        ? property.formattedPrice
        : 'Price on Request';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyDetailScreen(property: property),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                image: photoList.isNotEmpty
                    ? DecorationImage(
                  image: NetworkImage(photoList.first),
                  fit: BoxFit.cover,
                )
                    : null,
                color: Colors.grey[200],
              ),
              child: photoList.isEmpty
                  ? const Icon(Icons.home, size: 60, color: Colors.grey)
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayPrice,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.fullAddress != null
                        ? property.fullAddress!.split(',').first
                        : property.state ?? 'Property for Sale',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (property.bedrooms != null) ...[
                        const Icon(Icons.bed, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${property.bedrooms}'),
                        const SizedBox(width: 12),
                      ],
                      if (property.bathrooms != null) ...[
                        const Icon(Icons.bathtub, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${property.bathrooms}'),
                        const SizedBox(width: 12),
                      ],
                      if (property.builtUp != null && property.builtUp!.isNotEmpty) ...[
                        const Icon(Icons.photo_size_select_actual, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(property.builtUp!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.shortAddress,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          property.propertyType ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Remove from Favorites'),
                              content: const Text('Are you sure you want to remove this property from your favorites?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _removeSaved(property.listingId);
                                  },
                                  child: const Text('Remove'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 独立的 LoginButton widget
class LoginButton extends StatelessWidget {
  const LoginButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      },
      child: const Text('Login / Register'),
    );
  }
}