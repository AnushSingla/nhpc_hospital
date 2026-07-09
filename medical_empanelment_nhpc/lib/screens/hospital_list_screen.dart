import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/hospital.dart';
import 'package:medical_empanelment_nhpc/services/auth_service.dart';
import '../screens/report_error_screen.dart'; // Import the FAB widget

class HospitalListPage extends StatefulWidget {
  const HospitalListPage({super.key});

  @override
  State<HospitalListPage> createState() => _HospitalListPageState();
}

class _HospitalListPageState extends State<HospitalListPage>
    with TickerProviderStateMixin {
  List<Hospital> allHospitals = [];
  List<Hospital> filteredHospitals = [];
  TextEditingController searchController = TextEditingController();
  String? selectedScheme;
  String? selectedState;
  bool showHindi = false;
  bool isFilterExpanded = false;
  bool isLoading = true;
  Map<String, String> locCodeToState = {};
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;

  // Modern Color Palette
  static const Color primaryBlue = Color(0xFF2E86AB);
  static const Color accentPink = Color(0xFFA23B72);
  static const Color successOrange = Color(0xFFF18F01);
  static const Color backgroundGray = Color(0xFFF8F9FA);
  static const Color darkText = Color(0xFF2C3E50);

  @override
  void initState() {
    super.initState();
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    );
    _loadLocationMapping();
    fetchHospitalData();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  // Text cleaning utility method
  String _cleanText(String text) {
    if (text.isEmpty) return text;

    // Remove leading whitespace and special characters
    String cleaned = text.replaceFirst(RegExp(r'^[^\w\u0900-\u097F]+'), '');

    // Remove trailing whitespace and special characters
    cleaned = cleaned.replaceFirst(RegExp(r'[^\w\u0900-\u097F\s]+$'), '');

    // Trim any remaining whitespace
    return cleaned.trim();
  }

  // Load LOC_CODE to State mapping from CSV
  Future<void> _loadLocationMapping() async {
    try {
      final csvData = await rootBundle.loadString('assets/loc_master.csv');
      final lines = csvData.split('\n');

      for (int i = 1; i < lines.length; i++) {
        // Skip header row
        final fields = lines[i].split(',');
        if (fields.length >= 2) {
          final locCode = fields[0].trim(); // LOC_CODE column
          String stateName = fields[1].trim(); // State Name column

          // Remove quotes if present
          if (stateName.startsWith('"') && stateName.endsWith('"')) {
            stateName = stateName.substring(1, stateName.length - 1);
          }

          // Remove any extra quotes
          stateName = stateName.replaceAll('"', '').trim();

          locCodeToState[locCode] = stateName;
        }
      }

      print('Loaded ${locCodeToState.length} location mappings');
      print(
        'Sample mappings: ${locCodeToState.entries.take(3).toList()}',
      ); // Debug print
    } catch (e) {
      print('Error loading location mapping: $e');
    }
  }

  // Check if any filters are active
  bool get _hasActiveFilters {
    return searchController.text.isNotEmpty ||
        selectedScheme != null ||
        selectedState != null;
  }

  // Group hospitals by state
  Map<String, List<Hospital>> _groupHospitalsByState() {
    final grouped = <String, List<Hospital>>{};

    for (final hospital in filteredHospitals) {
      final stateName = locCodeToState[hospital.LOC_CODE] ?? 'Unknown';
      if (!grouped.containsKey(stateName)) {
        grouped[stateName] = [];
      }
      grouped[stateName]!.add(hospital);
    }

    return grouped;
  }

  // Calculate total items for ListView (states + hospitals)
  int _calculateTotalItems() {
    if (_hasActiveFilters) {
      return filteredHospitals.length;
    } else {
      final grouped = _groupHospitalsByState();
      int totalItems = 0;
      for (final stateHospitals in grouped.values) {
        totalItems += 1; // State header
        totalItems += stateHospitals.length; // Hospitals in that state
      }
      return totalItems;
    }
  }

  Future<void> fetchHospitalData() async {
    setState(() => isLoading = true);
    final url = Uri.parse('http://10.0.2.2:3000/api/hospitals');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final hospitals = data.map((json) => Hospital.fromJson(json)).toList();
        setState(() {
          allHospitals = hospitals.cast<Hospital>();
          filteredHospitals = hospitals.cast<Hospital>();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        print('Failed to load hospitals: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      print('Error fetching hospitals: $e');
    }
  }

  void _onSearchChanged() {
    final query = searchController.text.toLowerCase();
    _filterHospitals(query);
  }

  void _filterHospitals(String query) {
    setState(() {
      filteredHospitals =
          allHospitals.where((hospital) {
            final hospitalName = hospital.Hosp_name.toLowerCase();
            final stateName = (locCodeToState[hospital.LOC_CODE] ?? "").toLowerCase();
            final address = hospital.hosp_add.toLowerCase();
            final scheme = hospital.SCHEME.toLowerCase();
            final matchesSearch = hospitalName.contains(query) || stateName.contains(query) ||     address.contains(query) ||
            scheme.contains(query);
            final matchesScheme =
                selectedScheme == null || hospital.SCHEME == selectedScheme;
            final matchesState =
                selectedState == null ||
                locCodeToState[hospital.LOC_CODE] == selectedState;
            return matchesSearch && matchesScheme && matchesState;
          }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      selectedScheme = null;
      selectedState = null;
      searchController.clear();
      filteredHospitals = allHospitals;
    });
  }

  void _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final schemes = allHospitals.map((h) => h.SCHEME).toSet().toList()..sort();
    final states = locCodeToState.values.toSet().toList()..sort();

    return Scaffold(
      backgroundColor: backgroundGray,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // App Bar - Scrolls away
            SliverAppBar(
              expandedHeight: 80.0,
              collapsedHeight: 0,
              toolbarHeight: 0,
              floating: false,
              pinned: true,
              snap: false,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryBlue, Color(0xFF1e5f7a)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.local_hospital,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'NHPC Medical Directory',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            child: Material(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _logout,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.logout,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Advanced Animated Sticky Search Bar - Stays pinned at top
            SliverPersistentHeader(
              pinned: true,
              delegate: _AdvancedAnimatedStickySearchDelegate(
                searchController: searchController,
                primaryBlue: primaryBlue,
              ),
            ),

            // Filters Section - Scrolls away
            SliverToBoxAdapter(child: _buildFiltersSection(schemes, states)),

            // Language Toggle - Scrolls away
            SliverToBoxAdapter(child: _buildHindiToggle()),
          ];
        },
        body:
            isLoading
                ? _buildLoadingShimmer()
                : RefreshIndicator(
                  onRefresh: fetchHospitalData,
                  child: _buildHospitalList(),
                ),
      ),
      floatingActionButton: ReportErrorFAB(
        onPressed: () {
          Navigator.pushNamed(context, '/reportError');
        },
      ),
    );
  }

  // Filters Section (Scrolls away)
  Widget _buildFiltersSection(List<String> schemes, List<String> states) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            InkWell(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              onTap: () {
                setState(() {
                  isFilterExpanded = !isFilterExpanded;
                  if (isFilterExpanded) {
                    _filterAnimationController.forward();
                  } else {
                    _filterAnimationController.reverse();
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.tune,
                        color: primaryBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Advanced Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: primaryBlue,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (_hasActiveFilters) _buildActiveFilterBadge(),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 300),
                      turns: isFilterExpanded ? 0.5 : 0,
                      child: const Icon(Icons.expand_more, color: primaryBlue),
                    ),
                  ],
                ),
              ),
            ),
            SizeTransition(
              sizeFactor: _filterAnimation,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Column(
                  children: [
                    _buildActiveFiltersRow(),
                    const SizedBox(height: 16),
                    // Fixed: Stack dropdowns vertically to prevent overflow
                    Column(
                      children: [
                        _buildStateDropdown(states),
                        const SizedBox(height: 12),
                        _buildSchemeDropdown(schemes),
                      ],
                    ),
                    if (_hasActiveFilters) ...[
                      const SizedBox(height: 16),
                      _buildClearFiltersButton(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterBadge() {
    final activeCount =
        (selectedScheme != null ? 1 : 0) +
        (selectedState != null ? 1 : 0) +
        (searchController.text.isNotEmpty ? 1 : 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentPink,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$activeCount',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActiveFiltersRow() {
    if (!_hasActiveFilters) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (selectedState != null)
          _buildFilterChip('State: $selectedState', () {
            setState(() {
              selectedState = null;
              _filterHospitals(searchController.text.toLowerCase());
            });
          }),
        if (selectedScheme != null)
          _buildFilterChip('Scheme: $selectedScheme', () {
            setState(() {
              selectedScheme = null;
              _filterHospitals(searchController.text.toLowerCase());
            });
          }),
        if (searchController.text.isNotEmpty)
          _buildFilterChip('Search: "${searchController.text}"', () {
            searchController.clear();
          }),
      ],
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: primaryBlue, fontSize: 12)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 16, color: primaryBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildStateDropdown(List<String> states) {
    return SizedBox(
      width: double.infinity,
      child: DropdownButtonFormField<String>(
        initialValue: selectedState,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'State',
          prefixIcon: const Icon(Icons.location_on, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text(
              'All States',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          ...states.map(
            (state) => DropdownMenuItem(
              value: state,
              child: Text(state, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() {
            selectedState = value;
            _filterHospitals(searchController.text.toLowerCase());
          });
        },
      ),
    );
  }

  Widget _buildSchemeDropdown(List<String> schemes) {
    return SizedBox(
      width: double.infinity,
      child: DropdownButtonFormField<String>(
        initialValue: selectedScheme,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Scheme',
          prefixIcon: const Icon(Icons.business, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text(
              'All Schemes',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          ...schemes.map(
            (scheme) => DropdownMenuItem(
              value: scheme,
              child: Text(scheme, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() {
            selectedScheme = value;
            _filterHospitals(searchController.text.toLowerCase());
          });
        },
      ),
    );
  }

  Widget _buildClearFiltersButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _clearFilters,
        icon: const Icon(Icons.clear_all),
        label: const Text('Clear All Filters'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[50],
          foregroundColor: Colors.red[700],
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildHindiToggle() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.language, color: primaryBlue, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            showHindi ? 'अंग्रेजी में देखें' : 'हिंदी में देखें',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => showHindi = !showHindi),
            child: Container(
              width: 42,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: showHindi ? primaryBlue : Colors.grey.shade300,
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeInOut,
                    left: showHindi ? 22 : 2,
                    top: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Card(
            child: Container(
              height: 80,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHospitalList() {
    if (filteredHospitals.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: _calculateTotalItems(),
      itemBuilder: (context, index) {
        if (_hasActiveFilters) {
          return _buildModernHospitalCard(filteredHospitals[index]);
        } else {
          return _buildGroupedListItem(index);
        }
      },
    );
  }

  Widget _buildEmptyState() {
  return Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No hospitals found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _clearFilters,
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    ),
  );
}
  Widget _buildGroupedListItem(int index) {
    final grouped = _groupHospitalsByState();
    final stateNames = grouped.keys.toList()..sort();

    int currentIndex = 0;

    for (final stateName in stateNames) {
      if (index == currentIndex) {
        return _buildStateHeader(stateName, grouped[stateName]!.length);
      }
      currentIndex++;

      final stateHospitals = grouped[stateName]!;
      for (final hospital in stateHospitals) {
        if (index == currentIndex) {
          return _buildModernHospitalCard(hospital);
        }
        currentIndex++;
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildStateHeader(String stateName, int hospitalCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            successOrange.withValues(alpha: 0.1),
            successOrange.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: successOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: successOrange.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_city, color: successOrange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stateName.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: successOrange,
                  ),
                ),
                Text(
                  '$hospitalCount hospitals',
                  style: TextStyle(
                    color: successOrange.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHospitalCard(Hospital hospital) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/hospitalDetails',
              arguments: hospital,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Keep the scheme indicator on the left
                    _buildSchemeIndicator(hospital.SCHEME),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            showHindi
                                ? _cleanText(hospital.Hosp_name_H)
                                : _cleanText(hospital.Hosp_name),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: darkText,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        showHindi
                            ? _cleanText(hospital.hosp_add_H)
                            : _cleanText(hospital.hosp_add),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSchemeIndicator(String scheme) {
    String indicatorText = scheme.trim();

    if (indicatorText.startsWith('"') && indicatorText.endsWith('"')) {
      indicatorText = indicatorText.substring(1, indicatorText.length - 1);
    }

    LinearGradient gradient;
    if (indicatorText == 'D') {
      gradient = LinearGradient(
        colors: [Colors.blue, const Color.fromARGB(255, 91, 101, 245)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      gradient = LinearGradient(
        colors: [Colors.orange, Colors.orange.shade700],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          indicatorText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// 🚀 Advanced Animated Sticky Search Delegate
class _AdvancedAnimatedStickySearchDelegate
    extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final Color primaryBlue;

  _AdvancedAnimatedStickySearchDelegate({
    required this.searchController,
    required this.primaryBlue,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final double progress = (shrinkOffset / (maxExtent - minExtent)).clamp(
      0.0,
      1.0,
    );

    // Animated values
    final double animatedTopPadding = 28 - (10 * progress); // 28 → 16
    final double animatedBottomPadding = 1.0; // 18 → 12
    final double animatedHorizontalPadding = 16 - (2 * progress); // 16 → 14
    final double animatedBorderRadius = 14 - (4 * progress); // 14 → 10
    final double animatedContentPadding = 14 - (4 * progress); // 14 → 10
    final double animatedShadowOpacity = 0.05 + (0.15 * progress);
    final double animatedShadowBlur = 8 + (8 * progress);
    final double animatedIconSize = 24 - (3 * progress);
    final double animatedFontSize = 16 - (1.5 * progress);
    final double animatedBorderWidth = 1 + (1 * progress);

    // This is the key: always match the header height to the sliver's current extent
    final double currentHeight = maxExtent - (maxExtent - minExtent) * progress;

    return SizedBox(
      height: currentHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: animatedShadowOpacity),
              blurRadius: animatedShadowBlur,
              offset: Offset(0, 2 + (3 * progress)),
            ),
          ],
        ),
        child: Container(
          padding: EdgeInsets.only(
            left: animatedHorizontalPadding,
            right: animatedHorizontalPadding,
            top: animatedTopPadding,
            bottom: animatedBottomPadding,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(animatedBorderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03 + (0.02 * progress)),
                  blurRadius: 6 + (2 * progress),
                  offset: Offset(0, 1 + progress),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              style: TextStyle(
                fontSize: animatedFontSize,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search hospitals...',
                hintStyle: TextStyle(
                  fontSize: animatedFontSize,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.search,
                    color: primaryBlue,
                    size: animatedIconSize,
                  ),
                ),
                suffixIcon:
                    searchController.text.isNotEmpty
                        ? AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: primaryBlue,
                              size: animatedIconSize - 2,
                            ),
                            onPressed: () => searchController.clear(),
                          ),
                        )
                        : null,
                filled: true,
                fillColor: Color.lerp(
                  Colors.grey[50],
                  Colors.grey[100],
                  progress * 0.5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(animatedBorderRadius),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(animatedBorderRadius),
                  borderSide: BorderSide(
                    color:
                        Color.lerp(
                          Colors.grey.shade200,
                          Colors.grey.shade300,
                          progress,
                        )!,
                    width: animatedBorderWidth,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(animatedBorderRadius),
                  borderSide: BorderSide(
                    color: primaryBlue,
                    width: 2 + (0.5 * progress),
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16 - (2 * progress),
                  vertical: animatedContentPadding,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 94.0;

  @override
  double get minExtent => 72.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate != this;
  }
}
