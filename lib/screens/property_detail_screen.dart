import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/property_model.dart';
import '../providers/auth_provider.dart';
import '../providers/saved_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/theme_provider.dart';
import '../services/neighbourhood_insight_service.dart';
import 'login_screen.dart';
import 'ai_advisor_screen.dart';
import 'dashboard_screen.dart';
import 'saved_properties_screen.dart';
import 'profile_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  final PropertyModel property;
  const PropertyDetailScreen({super.key, required this.property});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  int _selectedImageIndex = 0;
  bool _isSaved = false;
  final NeighbourhoodInsightService _insightService = NeighbourhoodInsightService();
  late Future<NeighbourhoodInsight> _insightFuture;

  static const int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkSavedStatus();
    _insightFuture = _insightService.getInsightForProperty(widget.property);
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

  // ✅ Copy link to clipboard
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
    final property = widget.property;
    final photoList = property.photoUrlList;
    final facilityList = property.facilityList;
    final displayPrice = property.price != null
        ? property.formattedPrice
        : 'Price on Request';

    return Scaffold(
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel
            _buildImageCarousel(property, photoList),
            const SizedBox(height: 8),

            // Price and Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
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
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                  if (property.district != null || property.state != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Text(
                        '${property.district ?? ''}${property.district != null && property.state != null ? ', ' : ''}${property.state ?? ''}',
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[500], fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Property Specs
                  _buildSpecSection(property, isDark),
                  const SizedBox(height: 16),

                  // Tenure
                  if (property.tenure != null && property.tenure!.isNotEmpty)
                    _buildInfoRow('Tenure', property.tenure!, isDark),
                  const SizedBox(height: 16),

                  // Description
                  if (property.description != null && property.description!.isNotEmpty)
                    _buildDescriptionSection(property, isDark),
                  const SizedBox(height: 16),

                  // Facilities
                  if (facilityList.isNotEmpty)
                    _buildFacilitiesSection(facilityList, isDark),
                  const SizedBox(height: 16),

                  // AI Neighbourhood Insight
                  _buildAIScore(property),
                  const SizedBox(height: 16),

                  // ✅ Agent Info Section (Only Agent Name)
                  if (property.agentName != null && property.agentName!.isNotEmpty)
                    _buildAgentSection(property, isDark),

                  // ✅ Shareable Link Section (Separate)
                  if (property.listingUrl != null && property.listingUrl!.isNotEmpty)
                    _buildShareableLinkSection(property, isDark),

                  const SizedBox(height: 16),

                  // AI Advisor Button
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
              ),
            ),
          ],
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

  // ============================================================
  // Image Carousel
  // ============================================================
  Widget _buildImageCarousel(PropertyModel property, List<String> photoList) {
    final hasImages = photoList.isNotEmpty;
    return Stack(
      children: [
        Container(
          height: 300,
          width: double.infinity,
          color: Colors.grey[200],
          child: hasImages
              ? Image.network(
            photoList[_selectedImageIndex],
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.error, size: 40, color: Colors.grey),
              );
            },
          )
              : const Icon(Icons.home, size: 60, color: Colors.grey),
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
        if (hasImages && photoList.length > 1)
          Positioned(
            right: 8,
            top: MediaQuery.of(context).size.height / 2 - 40,
            child: IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white, size: 40),
              onPressed: () {
                setState(() {
                  _selectedImageIndex = (_selectedImageIndex + 1) % photoList.length;
                });
              },
            ),
          ),
        if (hasImages && photoList.length > 1)
          Positioned(
            left: 8,
            top: MediaQuery.of(context).size.height / 2 - 40,
            child: IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white, size: 40),
              onPressed: () {
                setState(() {
                  _selectedImageIndex = (_selectedImageIndex - 1 + photoList.length) % photoList.length;
                });
              },
            ),
          ),
      ],
    );
  }

  // ============================================================
  // Spec Section
  // ============================================================
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

  // ============================================================
  // Info Row
  // ============================================================
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

  // ============================================================
  // Description Section
  // ============================================================
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

  // ============================================================
  // Facilities Section
  // ============================================================
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

  // ==========================================
  // AI Neighbourhood Insights
  // ==========================================
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
                    const Icon(Icons.psychology, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'AI Neighbourhood Insights',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
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
                const SizedBox(height: 12),
                // Row 1: Population, Crime, Water
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildScoreItem('Population', isLoading ? '...' : insight.populationDisplay, isDark),
                    _buildScoreItem('Crime', isLoading ? '...' : insight.crimeDisplay, isDark),
                    _buildScoreItem('Water Usage', isLoading ? '...' : insight.waterDisplay, isDark),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 2: Income, Expenditure
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildScoreItem('Income', isLoading ? '...' : insight.incomeDisplay, isDark),
                    _buildScoreItem('Expenditure', isLoading ? '...' : insight.expenditureDisplay, isDark),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 3: Schools, Hospital Beds
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildScoreItem('Schools', isLoading ? '...' : insight.schoolsDisplay, isDark),
                    _buildScoreItem('Hospital Beds', isLoading ? '...' : insight.hospitalBedsDisplay, isDark),
                  ],
                ),
                // Fallback note
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
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.blue[700],
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white70 : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ============================================================
  // Agent Section - ✅ Only Agent Name (Removed phone/email)
  // ============================================================
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

  // ============================================================
  // Shareable Link Section - ✅ Separate Section with Copy
  // ============================================================
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