import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/property_model.dart';
import '../services/property_service.dart';
import '../providers/auth_provider.dart';
import '../providers/saved_provider.dart';
import '../widgets/offline_banner.dart';
import '../widgets/adaptive_nav_scaffold.dart';
import '../widgets/property_filter_dialog.dart';
import '../utils/device_layout.dart';
import 'property_detail_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PropertyService _propertyService = PropertyService();
  final TextEditingController _searchController = TextEditingController();

  List<PropertyModel> _properties = [];
  List<PropertyModel> _filteredProperties = [];
  bool _isLoading = true;
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

  bool get _hasActiveFilters =>
      _selectedState != null ||
          _selectedDistrict != null ||
          _selectedPropertyType != null ||
          _selectedTenure != null ||
          _selectedBedrooms != null ||
          _minPrice != null ||
          _maxPrice != null ||
          _searchController.text.trim().isNotEmpty;

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search error: $e')));
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
      _errorMessage = null;
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
    });
    _searchProperties();
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
          content: Text(
            isNowSaved ? 'Added to favorites' : 'Removed from favorites',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
      setState(() {});
    }
  }

  void _onTabTapped(int index) {
    if (index == AppNavIndex.home) return;
    handleAppNavigation(context, index);
  }

  @override
  Widget build(BuildContext context) {
    final saved = Provider.of<SavedProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final compactHeight = MediaQuery.sizeOf(context).height < 500;
    final tabletMode = isTabletUiActive(context);
    final wideLandscape =
        tabletMode &&
            MediaQuery.orientationOf(context) == Orientation.landscape;

    return AdaptiveNavScaffold(
      currentIndex: AppNavIndex.home,
      onTap: _onTabTapped,
      appBar: AppBar(
        title: const Text('Search Properties'),
        actions: [
          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Filtered',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              _hasActiveFilters ? Icons.tune_rounded : Icons.tune_outlined,
            ),
            onPressed: _showFilterDialog,
            tooltip: 'Open filters',
          ),
        ],
      ),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          const SliverToBoxAdapter(child: OfflineBanner()),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                tabletMode ? 20 : 16,
                compactHeight ? 8 : 14,
                tabletMode ? 20 : 16,
                compactHeight ? 4 : 8,
              ),
              child: Material(
                elevation: isDark ? 0 : 1,
                shadowColor: Colors.black26,
                color: isDark ? theme.cardColor : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? theme.dividerColor : Colors.grey.shade200,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(compactHeight ? 10 : 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by title, address...',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF4F7FB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded),
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
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _searchProperties,
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text('Search'),
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: compactHeight ? 12 : 18,
                            vertical: compactHeight ? 12 : 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                tabletMode ? 20 : 16,
                4,
                tabletMode ? 20 : 16,
                8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        Icon(
                          Icons.home_work_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${_filteredProperties.length} properties found',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hasActiveFilters)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(
                        Icons.filter_alt_off_outlined,
                        size: 16,
                      ),
                      label: const Text('Clear All'),
                    ),
                ],
              ),
            ),
          ),
          if (_errorMessage != null)
            SliverToBoxAdapter(
              child: Padding(
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
            ),
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredProperties.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                ),
              ),
            )
          else if (tabletMode)
            SliverToBoxAdapter(child: _buildTabletPropertyGrid(saved))
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final property = _filteredProperties[index];
                    final isSaved = saved.isSaved(property.listingId);
                    return _buildPropertyCard(property, isSaved);
                  },
                  childCount: _filteredProperties.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabletPropertyGrid(SavedProvider saved) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        const horizontalPadding = 20.0;
        final usableWidth = (constraints.maxWidth - horizontalPadding * 2)
            .clamp(0.0, double.infinity);
        final crossAxisCount = usableWidth >= 900
            ? 3
            : usableWidth >= 500
            ? 2
            : 1;
        final itemWidth =
            (usableWidth - gap * (crossAxisCount - 1)) / crossAxisCount;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final property in _filteredProperties)
                SizedBox(
                  width: itemWidth,
                  child: _buildPropertyCard(
                    property,
                    saved.isSaved(property.listingId),
                    compact: true,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPropertyCard(
      PropertyModel property,
      bool isSaved, {
        bool compact = false,
      }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final photoList = property.photoUrlList;
    final displayPrice = property.price != null
        ? property.formattedPrice
        : 'Price on Request';
    final location = property.fullAddress != null
        ? property.fullAddress!.split(',').first
        : property.state ?? 'Property for Sale';

    return Card(
      margin: EdgeInsets.only(bottom: compact ? 0 : 14),
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? theme.dividerColor : Colors.grey.shade100,
        ),
      ),
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
            Stack(
              children: [
                Container(
                  height: compact ? 150 : 190,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade200,
                    image: photoList.isNotEmpty
                        ? DecorationImage(
                      image: NetworkImage(photoList.first),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: photoList.isEmpty
                      ? Center(
                    child: Icon(
                      Icons.home_rounded,
                      size: compact ? 48 : 60,
                      color: Colors.grey.shade400,
                    ),
                  )
                      : null,
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      displayPrice,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _toggleSave(property.listingId),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          isSaved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 20,
                          color: isSaved ? Colors.red : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 12 : 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.shortAddress,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        if (property.bedrooms != null) ...[
                          Icon(
                            Icons.bed_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text('${property.bedrooms}'),
                          const SizedBox(width: 12),
                        ],
                        if (property.bathrooms != null) ...[
                          Icon(
                            Icons.bathtub_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text('${property.bathrooms}'),
                          const SizedBox(width: 12),
                        ],
                        if (property.builtUp != null &&
                            property.builtUp!.isNotEmpty) ...[
                          Icon(
                            Icons.square_foot_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              property.builtUp!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      property.propertyType ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
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
