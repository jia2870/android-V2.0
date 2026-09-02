import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/property_model.dart';
import '../services/saved_property_service.dart';
import '../services/property_service.dart';
import '../providers/auth_provider.dart';
import '../utils/device_layout.dart';
import '../utils/money_format.dart';
import '../widgets/money_form_field.dart';
import '../widgets/adaptive_nav_scaffold.dart';
import '../widgets/property_filter_dialog.dart';
import 'property_detail_screen.dart';
import 'login_screen.dart';

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
    'Apartment',
    'Condominium',
    'Terrace',
    'Semi-D',
    'Bungalow',
  ];
  final List<String> _tenureTypes = const ['Freehold', 'Leasehold'];
  final List<int> _bedroomOptions = const [1, 2, 3, 4, 5];

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
          _errorMessage =
              'No saved properties yet.\nStart exploring and save your favorites!';
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

      if (_selectedBedrooms != null &&
          (property.bedrooms ?? 0) < _selectedBedrooms!)
        return false;

      if (_selectedPropertyType != null && _selectedPropertyType!.isNotEmpty) {
        if (!(property.propertyType?.contains(_selectedPropertyType!) ?? false))
          return false;
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
        _errorMessage =
            'No saved properties yet.\nStart exploring and save your favorites!';
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

  Future<void> _showFilterDialog() async {
    final selection = await showDialog<PropertyFilterSelection>(
      context: context,
      builder: (_) => PropertyFilterDialog(
        states: _states,
        initialDistricts: _districts,
        propertyTypes: _propertyTypes,
        tenureTypes: _tenureTypes,
        bedroomOptions: _bedroomOptions,
        loadDistricts: _propertyService.getDistrictsByState,
        initialState: _selectedState,
        initialDistrict: _selectedDistrict,
        initialPropertyType: _selectedPropertyType,
        initialTenure: _selectedTenure,
        initialBedrooms: _selectedBedrooms,
        initialMinPrice: _minPrice,
        initialMaxPrice: _maxPrice,
      ),
    );
    if (!mounted || selection == null) return;

    if (selection.clearAll) {
      _clearFilters();
      return;
    }

    setState(() {
      _selectedState = selection.state;
      _selectedDistrict = selection.district;
      _selectedPropertyType = selection.propertyType;
      _selectedTenure = selection.tenure;
      _selectedBedrooms = selection.bedrooms;
      _minPrice = selection.minPrice;
      _maxPrice = selection.maxPrice;
      _districts = selection.districts;
      _minPriceController.text = selection.minPrice == null
          ? ''
          : MoneyFormat.toField(selection.minPrice!.toDouble());
      _maxPriceController.text = selection.maxPrice == null
          ? ''
          : MoneyFormat.toField(selection.maxPrice!.toDouble());
      _showFilters = false;
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
          _errorMessage =
              'No saved properties yet.\nStart exploring and save your favorites!';
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Removed from favorites')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _onTabTapped(int index) {
    if (index == AppNavIndex.saved) return;
    handleAppNavigation(context, index);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.isLoggedIn) {
      return AdaptiveNavScaffold(
        currentIndex: AppNavIndex.saved,
        onTap: _onTabTapped,
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
      );
    }

    final compactHeight = MediaQuery.sizeOf(context).height < 500;
    final tabletMode = isTabletUiActive(context);
    final wideLandscape =
        tabletMode &&
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return AdaptiveNavScaffold(
      currentIndex: AppNavIndex.saved,
      onTap: _onTabTapped,
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
            icon: Icon(
              wideLandscape
                  ? Icons.filter_list
                  : (_showFilters ? Icons.filter_list : Icons.filter_list_off),
            ),
            onPressed: () {
              if (wideLandscape) {
                _showFilterDialog();
              } else {
                setState(() => _showFilters = !_showFilters);
              }
            },
            tooltip: wideLandscape ? 'Open filters' : 'Show or hide filters',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compactHeight ? 8 : 16,
            ),
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

          if (_showFilters && !wideLandscape) _buildFilters(),

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

          if (_errorMessage != null)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(compactHeight ? 12 : 16),
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
                        size: compactHeight ? 32 : 40,
                      ),
                      SizedBox(height: compactHeight ? 4 : 8),
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
                        SizedBox(height: compactHeight ? 6 : 12),
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
            ),

          if (_errorMessage == null)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredProperties.isEmpty && _properties.isEmpty
                  ? const SizedBox()
                  : tabletMode
                  ? _buildTabletPropertyGrid()
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
    );
  }

  Widget _buildTabletPropertyGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        const horizontalPadding = 32.0;
        final usableWidth = (constraints.maxWidth - horizontalPadding).clamp(
          0.0,
          double.infinity,
        );
        final crossAxisCount = usableWidth >= 900 ? 3 : 2;
        final itemWidth =
            (usableWidth - gap * (crossAxisCount - 1)) / crossAxisCount;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final property in _filteredProperties)
                SizedBox(
                  width: itemWidth,
                  child: _buildPropertyCard(property, compact: true),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    final panel = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
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
              ..._districts.map(
                (d) => DropdownMenuItem(value: d, child: Text(d)),
              ),
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
              ..._propertyTypes.map(
                (t) => DropdownMenuItem(value: t, child: Text(t)),
              ),
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
              ..._tenureTypes.map(
                (t) => DropdownMenuItem(value: t, child: Text(t)),
              ),
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
              ..._bedroomOptions.map(
                (b) => DropdownMenuItem(value: b, child: Text('$b+')),
              ),
            ],
            onChanged: (value) => setState(() => _selectedBedrooms = value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: MoneyFormField(
                  controller: _minPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Min Price (RM)',
                    border: OutlineInputBorder(),
                    prefixText: 'RM ',
                  ),
                  onChanged: (value) {
                    _minPrice = MoneyFormat.parse(value)?.round();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MoneyFormField(
                  controller: _maxPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Max Price (RM)',
                    border: OutlineInputBorder(),
                    prefixText: 'RM ',
                  ),
                  onChanged: (value) {
                    _maxPrice = MoneyFormat.parse(value)?.round();
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

    if (MediaQuery.sizeOf(context).height < 500) {
      final height = (MediaQuery.sizeOf(context).height * 0.35).clamp(
        100.0,
        180.0,
      );
      return SizedBox(
        height: height,
        child: SingleChildScrollView(child: panel),
      );
    }

    return panel;
  }

  Widget _buildPropertyCard(PropertyModel property, {bool compact = false}) {
    final photoList = property.photoUrlList;
    final displayPrice = property.price != null
        ? property.formattedPrice
        : 'Price on Request';

    return Card(
      margin: EdgeInsets.only(bottom: compact ? 0 : 16),
      clipBehavior: Clip.antiAlias,
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: compact ? 140 : 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                image: photoList.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(photoList.first),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Colors.grey[200],
              ),
              child: photoList.isEmpty
                  ? Icon(
                      Icons.home,
                      size: compact ? 48 : 60,
                      color: Colors.grey,
                    )
                  : null,
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 10 : 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                      if (property.builtUp != null &&
                          property.builtUp!.isNotEmpty) ...[
                        const Icon(
                          Icons.photo_size_select_actual,
                          size: 16,
                          color: Colors.grey,
                        ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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
                              content: const Text(
                                'Are you sure you want to remove this property from your favorites?',
                              ),
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
