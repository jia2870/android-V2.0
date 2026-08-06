import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/property_model.dart';
import '../services/property_service.dart';
import '../providers/auth_provider.dart';
import '../providers/saved_provider.dart';
import '../providers/financial_provider.dart';
import 'property_detail_screen.dart';
import 'login_screen.dart';
import 'saved_properties_screen.dart';
import 'profile_screen.dart';
import 'ai_advisor_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProperties();
    _loadStates();
    _initSavedProvider();
  }

  Future<void> _initSavedProvider() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final saved = Provider.of<SavedProvider>(context, listen: false);
    if (auth.isLoggedIn && auth.userId != null) {
      await saved.init(auth.userId!);
    }
  }

  Future<void> _loadProperties() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _properties = await _propertyService.getAllProperties();
      _filteredProperties = _properties;
      if (_properties.isEmpty && mounted) {
        setState(() {
          _errorMessage = 'No properties found in database.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading properties: $e';
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final query = _searchController.text.trim();

    _propertyService
        .searchProperties(
      query: query.isNotEmpty ? query : null,
      state: _selectedState,
      district: _selectedDistrict,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      bedrooms: _selectedBedrooms,
      propertyType: _selectedPropertyType,
      tenure: _selectedTenure,
    )
        .then((results) {
      if (mounted) {
        setState(() {
          _filteredProperties = results;
          _isLoading = false;
          if (results.isEmpty) {
            _errorMessage = 'No properties found matching your criteria';
          }
        });
      }
    })
        .catchError((e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Search error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
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
      _errorMessage = null;
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

  Future<void> _toggleSave(String listingId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final saved = Provider.of<SavedProvider>(context, listen: false);

    if (!auth.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final isNowSaved = await saved.toggleSave(listingId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNowSaved ? 'Added to favorites' : 'Removed from favorites'),
          duration: const Duration(seconds: 1),
        ),
      );
      setState(() {});
    }
  }

  // ============================================================
  // 底部导航切换
  // ============================================================
  void _onTabTapped(int index) {
    if (index == 0) {
      // Home - 已经是这个页面
      // 如果不在顶部，可以滚动到顶部
      // 不做任何事，或者重置滚动
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
      // 使用 pushReplacement 替换当前页面
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
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final saved = Provider.of<SavedProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Properties'),
        actions: [
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
                      hintText: 'Search by title, address...',
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
                  '${_filteredProperties.length} properties found',
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

          // Error message if any
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProperties.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No properties found',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try adjusting your filters',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredProperties.length,
              itemBuilder: (context, index) {
                final property = _filteredProperties[index];
                final isSaved = saved.isSaved(property.listingId);
                return _buildPropertyCard(property, isSaved);
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
          // State
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

          // District
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

          // Property Type
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

          // Tenure
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

          // Bedrooms
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

          // Price Range
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

  Widget _buildPropertyCard(PropertyModel property, bool isSaved) {
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
            // Image
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
                        icon: Icon(
                          isSaved ? Icons.favorite : Icons.favorite_border,
                          color: isSaved ? Colors.red : null,
                        ),
                        onPressed: () => _toggleSave(property.listingId),
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