import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/property_model.dart';
import '../providers/auth_provider.dart';
import '../providers/saved_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/device_layout.dart';
import '../services/neighbourhood_insight_service.dart';
import '../widgets/adaptive_nav_scaffold.dart';
import 'login_screen.dart';
import 'ai_advisor_screen.dart';
import 'loan_calculator_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  final PropertyModel property;
  const PropertyDetailScreen({super.key, required this.property});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  int _selectedImageIndex = 0;
  bool _isSaved = false;
  PageController? _photoPageController;
  final NeighbourhoodInsightService _insightService = NeighbourhoodInsightService();
  late Future<NeighbourhoodInsight> _insightFuture;

  @override
  void initState() {
    super.initState();
    _photoPageController = PageController(initialPage: 0);
    _checkSavedStatus();
    _insightFuture = _insightService.getInsightForProperty(widget.property);
  }

  @override
  void dispose() {
    _photoPageController?.dispose();
    super.dispose();
  }

  Future<void> _checkSavedStatus() async {
    final saved = Provider.of<SavedProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isLoggedIn && auth.userId != null) {
      await saved.init(auth.userId!);
      setState(() {
        _isSaved = saved.isSaved(widget.property.listingId);
      });
    }
  }

  Future<void> _toggleSave() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final saved = Provider.of<SavedProvider>(context, listen: false);

    if (!auth.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final isNowSaved = await saved.toggleSave(widget.property.listingId);
    setState(() {
      _isSaved = isNowSaved;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNowSaved ? 'Added to favorites' : 'Removed from favorites'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _copyLinkToClipboard(String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onTabTapped(int index) {
    handleAppNavigation(context, index);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final tabletMode = isTabletUiActive(context);
    final isDark = themeProvider.isDarkMode;
    final property = widget.property;
    final photoList = property.photoUrlList;
    final facilityList = property.facilityList;
    final displayPrice = property.price != null
        ? property.formattedPrice
        : 'Price on Request';

    return AdaptiveNavScaffold(
      currentIndex: AppNavIndex.home,
      onTap: _onTabTapped,
      automaticallyImplyLeading: true,
      appBar: AppBar(
        title: Text(property.shortAddress),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.favorite : Icons.favorite_border,
              color: _isSaved ? Colors.red : Colors.white,
            ),
            onPressed: _toggleSave,
          ),
        ],
      ),
      body: tabletMode
          ? _buildTabletBody(
              property,
              photoList,
              facilityList,
              displayPrice,
              isDark,
            )
          : _buildPhoneBody(
              property,
              photoList,
              facilityList,
              displayPrice,
              isDark,
            ),
    );
  }

  Widget _buildPhoneBody(
    PropertyModel property,
    List<String> photoList,
    List<String> facilityList,
    String displayPrice,
    bool isDark,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageCarousel(property, photoList),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildDetailsColumn(
              property,
              facilityList,
              displayPrice,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletBody(
    PropertyModel property,
    List<String> photoList,
    List<String> facilityList,
    String displayPrice,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildImageCarousel(property, photoList, height: 360),
                if (photoList.length > 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photoList.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final selected = index == _selectedImageIndex;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedImageIndex = index);
                            _photoPageController?.jumpToPage(index);
                          },
                          child: Container(
                            width: 96,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? Colors.blue
                                    : Colors.transparent,
                                width: 2,
                              ),
                              image: DecorationImage(
                                image: NetworkImage(photoList[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 16, 20, 24),
            child: _buildDetailsColumn(
              property,
              facilityList,
              displayPrice,
              isDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsColumn(
    PropertyModel property,
    List<String> facilityList,
    String displayPrice,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayPrice,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.blue[300] : Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          property.mainTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                property.shortAddress,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
        if (property.district != null || property.state != null)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              '${property.district ?? ''}${property.district != null && property.state != null ? ', ' : ''}${property.state ?? ''}',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 16),
        _buildSpecSection(property, isDark),
        const SizedBox(height: 16),
        if (property.tenure != null && property.tenure!.isNotEmpty)
          _buildInfoRow('Tenure', property.tenure!, isDark),
        const SizedBox(height: 16),
        if (property.description != null && property.description!.isNotEmpty)
          _buildDescriptionSection(property, isDark),
        const SizedBox(height: 16),
        if (facilityList.isNotEmpty)
          _buildFacilitiesSection(facilityList, isDark),
        const SizedBox(height: 16),
        _buildAIScore(property),
        const SizedBox(height: 16),
        if (property.agentName != null && property.agentName!.isNotEmpty)
          _buildAgentSection(property, isDark),
        if (property.listingUrl != null && property.listingUrl!.isNotEmpty)
          _buildShareableLinkSection(property, isDark),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LoanCalculatorScreen(
                    propertyPrice: property.price?.toDouble(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Loan Calculator'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AIAdvisorScreen(property: property),
                ),
              );
            },
            icon: const Icon(Icons.smart_toy),
            label: const Text('AI Advisor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildImageCarousel(
    PropertyModel property,
    List<String> photoList, {
    double height = 300,
  }) {
    final hasImages = photoList.isNotEmpty;
    final multi = hasImages && photoList.length > 1;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.grey[200]!,
            child: hasImages
                ? PageView.builder(
                    itemCount: photoList.length,
                    controller: _photoPageController,
                    onPageChanged: (index) {
                      setState(() => _selectedImageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return Image.network(
                        photoList[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: height,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.error,
                              size: 40,
                              color: Colors.grey,
                            ),
                          );
                        },
                      );
                    },
                  )
                : const Center(
                    child: Icon(Icons.home, size: 60, color: Colors.grey),
                  ),
          ),
          if (hasImages)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  photoList.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selectedImageIndex == index
                          ? Colors.white
                          : Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
          if (multi)
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      final next =
                          (_selectedImageIndex - 1 + photoList.length) %
                              photoList.length;
                      _photoPageController?.animateToPage(
                        next,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                ),
              ),
            ),
          if (multi)
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      final next =
                          (_selectedImageIndex + 1) % photoList.length;
                      _photoPageController?.animateToPage(
                        next,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecSection(PropertyModel property, bool isDark) {
    final specs = <Widget>[];

    if (property.propertyType != null && property.propertyType!.isNotEmpty) {
      specs.add(_buildSpecItem(Icons.home, 'Type', property.propertyType!, isDark));
    }
    if (property.bedrooms != null) {
      specs.add(_buildSpecItem(Icons.bed, 'Bedrooms', '${property.bedrooms}', isDark));
    }
    if (property.bathrooms != null) {
      specs.add(_buildSpecItem(Icons.bathtub, 'Bathrooms', '${property.bathrooms}', isDark));
    }
    if (property.builtUp != null && property.builtUp!.isNotEmpty) {
      specs.add(_buildSpecItem(Icons.photo_size_select_actual, 'Built Up', property.builtUp!, isDark));
    }

    if (specs.isEmpty) return const SizedBox.shrink();

    return Card(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Property Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: specs,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String label, String value, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.blue),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(PropertyModel property, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              property.description ?? '',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitiesSection(List<String> facilities, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Facilities',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: facilities.map((facility) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A3E) : Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.blue[300]! : Colors.blue[100]!),
                  ),
                  child: Text(
                    facility,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIScore(PropertyModel property) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return FutureBuilder<NeighbourhoodInsight>(
      future: _insightFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final insight = snapshot.data ?? NeighbourhoodInsight.empty();

        return Card(
          color: isDark ? Colors.grey[900] : Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insights, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Neighbourhood Insights',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    if (isLoading) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Source: data.gov.my',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildScoreItem(
                        'Population',
                        isLoading ? '...' : insight.populationDisplay,
                        isDark,
                      ),
                    ),
                    Expanded(
                      child: _buildScoreItem(
                        'Crime',
                        isLoading ? '...' : insight.crimeDisplay,
                        isDark,
                      ),
                    ),
                    Expanded(
                      child: _buildScoreItem(
                        'Water Usage',
                        isLoading ? '...' : insight.waterDisplay,
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildScoreItem(
                        'Income',
                        isLoading ? '...' : insight.incomeDisplay,
                        isDark,
                      ),
                    ),
                    Expanded(
                      child: _buildScoreItem(
                        'Expenditure',
                        isLoading ? '...' : insight.expenditureDisplay,
                        isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildScoreItem(
                        'Schools',
                        isLoading ? '...' : insight.schoolsDisplay,
                        isDark,
                      ),
                    ),
                    Expanded(
                      child: _buildScoreItem(
                        'Hospital Beds',
                        isLoading ? '...' : insight.hospitalBedsDisplay,
                        isDark,
                      ),
                    ),
                  ],
                ),
                if (!isLoading && insight.fallbackNote != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    insight.fallbackNote!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoreItem(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 3,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.blue[700],
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAgentSection(PropertyModel property, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agent Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    property.agentName!,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareableLinkSection(PropertyModel property, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shareable Link',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _copyLinkToClipboard(property.listingUrl!),
              child: Row(
                children: [
                  const Icon(Icons.link, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      property.listingUrl!,
                      style: TextStyle(
                        color: isDark ? Colors.blue[300] : Colors.blue,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.copy,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.grey[600],
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
