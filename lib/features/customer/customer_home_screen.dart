import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../services/media_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/auth_services.dart';
import '../../shared/widgets/dialogs.dart';
import '../../shared/widgets/feedback_widgets.dart';
import '../../shared/widgets/network_image_with_fallback.dart';
import '../../shared/widgets/stall_card.dart';
import '../../shared/widgets/status_badge.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final client = Supabase.instance.client;
  final searchController = TextEditingController();

  Position? currentPosition;

  bool loadingLocation = true;
  bool openOnly = false;

  /// Search radius around the customer. Starts at 1 km, can be widened.
  static const radiusOptions = [1, 2, 5, 10];
  int radiusKm = 1;

  String selectedCategory = 'All';

  int selectedTab = 0;

  Map<String, String> categoryNames = {};

  Stream<List<Map<String, dynamic>>> get stallStream => client
      .from('stalls')
      .stream(primaryKey: ['id'])
      .eq('approval_status', 'approved');

  @override
  void initState() {
    super.initState();

    _loadLocation();
    _loadCategories();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final result = await client
          .from('categories')
          .select('id, name')
          .eq('is_active', true)
          .order('name');

      if (!mounted) return;

      setState(() {
        categoryNames = {
          for (final row in result) row['id'] as String: row['name'] as String,
        };
      });
    } catch (_) {
      // Category loading should not prevent the map from opening.
    }
  }

  Future<void> _loadLocation() async {
    setState(() {
      loadingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is permanently denied.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        currentPosition = position;
        loadingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loadingLocation = false;
      });
    }
  }

  double _distanceKm(Map<String, dynamic> stall) {
    if (currentPosition == null ||
        stall['latitude'] == null ||
        stall['longitude'] == null) {
      return double.infinity;
    }

    final meters = Geolocator.distanceBetween(
      currentPosition!.latitude,
      currentPosition!.longitude,
      (stall['latitude'] as num).toDouble(),
      (stall['longitude'] as num).toDouble(),
    );

    return meters / 1000;
  }

  List<Map<String, dynamic>> _filterStalls(List<Map<String, dynamic>> stalls) {
    final search = searchController.text.trim().toLowerCase();

    return stalls.where((stall) {
      if (_distanceKm(stall) > radiusKm) {
        return false;
      }

      if (openOnly && stall['is_open'] != true) {
        return false;
      }

      final stallCategory = categoryNames[stall['category_id']];

      if (selectedCategory != 'All' && stallCategory != selectedCategory) {
        return false;
      }

      final name = (stall['name'] as String? ?? '').toLowerCase();

      final description = (stall['description'] as String? ?? '').toLowerCase();

      final category = (stallCategory ?? '').toLowerCase();

      if (search.isNotEmpty &&
          !name.contains(search) &&
          !description.contains(search) &&
          !category.contains(search)) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> _showCategoryFilter() async {
    final categories = ['All', ...categoryNames.values.toSet()];

    if (!mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Text(
                'Filter by food category',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            ...categories.map((category) {
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(category),
                trailing: selectedCategory == category
                    ? const Icon(
                        Icons.check_rounded,
                        color: VendrgoColors.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(category),
              );
            }),
          ],
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      selectedCategory = result;
    });
  }

  Future<bool> _isFavorite(String stallId) async {
    final user = client.auth.currentUser;

    if (user == null) {
      return false;
    }

    final result = await client
        .from('favorites')
        .select('stall_id')
        .eq('user_id', user.id)
        .eq('stall_id', stallId)
        .maybeSingle();

    return result != null;
  }

  Future<void> _toggleFavorite(String stallId) async {
    final user = client.auth.currentUser;

    if (user == null) {
      return;
    }

    final existing = await client
        .from('favorites')
        .select('stall_id')
        .eq('user_id', user.id)
        .eq('stall_id', stallId)
        .maybeSingle();

    if (existing != null) {
      await client
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('stall_id', stallId);
    } else {
      await client.from('favorites').insert({
        'user_id': user.id,
        'stall_id': stallId,
      });
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openDirections(Map<String, dynamic> stall) async {
    final lat = stall['latitude'];
    final lng = stall['longitude'];

    if (lat == null || lng == null) {
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$lat,$lng',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps.'),
          backgroundColor: VendrgoColors.error,
        ),
      );
    }
  }

  void _openStall(Map<String, dynamic> stall) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StallDetailsScreen(
          stall: stall,
          categoryName: categoryNames[stall['category_id']],
          distanceKm: _distanceKm(stall),
          isFavorite: _isFavorite(stall['id'] as String),
          onToggleFavorite: () => _toggleFavorite(stall['id'] as String),
          onDirections: () => _openDirections(stall),
        ),
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  bool showMap = false;

  String? _imageUrl(Map<String, dynamic> stall) {
    return MediaService.urlFor(stall['stall_image_path']);
  }

  String? _cardDistance(Map<String, dynamic> stall) {
    final distance = _distanceKm(stall);

    if (distance == double.infinity) {
      return null;
    }

    if (distance < 1) {
      return '${(distance * 1000).round()} m';
    }

    return '${distance.toStringAsFixed(1)} km';
  }

  String? _hoursOf(Map<String, dynamic> stall) {
    final hours = stall['opening_hours'];

    if (hours is Map) {
      return hours['all'] as String?;
    }

    return null;
  }

  Future<void> _showRadiusPicker() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: Text('Search distance', style: VendrgoText.title),
              ),
              for (final km in radiusOptions)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(Icons.radar_rounded),
                  title: Text('Within $km km'),
                  trailing: radiusKm == km
                      ? const Icon(
                          Icons.check_rounded,
                          color: VendrgoColors.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(km),
                ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() {
      radiusKm = result;
    });
  }

  void _clearFilters() {
    setState(() {
      openOnly = false;
      radiusKm = 1;
      selectedCategory = 'All';
      searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selectedTab,
          children: [
            _buildHomePage(),
            _buildFavoritesPage(),
            _buildProfilePage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            selectedTab = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: VendrgoColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Near you', style: VendrgoText.heading),
                    Text(
                      currentPosition == null
                          ? (loadingLocation
                                ? 'Finding your location...'
                                : 'Location unavailable')
                          : 'Stalls within $radiusKm km',
                      style: VendrgoText.caption,
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Refresh my location',
                onPressed: loadingLocation ? null : _loadLocation,
                icon: const Icon(Icons.my_location_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search stalls, food...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  selected: openOnly,
                  avatar: Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: openOnly
                        ? VendrgoColors.primaryDark
                        : VendrgoColors.textSecondary,
                  ),
                  label: const Text('Open now'),
                  onSelected: (value) {
                    setState(() {
                      openOnly = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: selectedCategory != 'All',
                  avatar: Icon(
                    Icons.restaurant_menu_rounded,
                    size: 18,
                    color: selectedCategory != 'All'
                        ? VendrgoColors.primaryDark
                        : VendrgoColors.textSecondary,
                  ),
                  label: Text(
                    selectedCategory == 'All' ? 'Cuisine' : selectedCategory,
                  ),
                  onSelected: (_) => _showCategoryFilter(),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: radiusKm != 1,
                  avatar: Icon(
                    Icons.radar_rounded,
                    size: 18,
                    color: radiusKm != 1
                        ? VendrgoColors.primaryDark
                        : VendrgoColors.textSecondary,
                  ),
                  label: Text('Within $radiusKm km'),
                  onSelected: (_) => _showRadiusPicker(),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: showMap,
                  avatar: Icon(
                    showMap ? Icons.map_rounded : Icons.map_outlined,
                    size: 18,
                    color: showMap
                        ? VendrgoColors.primaryDark
                        : VendrgoColors.textSecondary,
                  ),
                  label: const Text('Map view'),
                  onSelected: (value) {
                    setState(() {
                      showMap = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomePage() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stallStream,
      builder: (context, snapshot) {
        Widget content;

        if (snapshot.hasError) {
          content = EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load nearby stalls',
            message: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: () => setState(() {}),
          );
        } else if (!snapshot.hasData ||
            (loadingLocation && currentPosition == null)) {
          content = _buildSkeletonList();
        } else if (currentPosition == null) {
          content = EmptyState(
            icon: Icons.location_off_rounded,
            title: 'Turn on location',
            message:
                'We need your location to show stalls within $radiusKm km.',
            actionLabel: 'Enable location',
            onAction: _loadLocation,
          );
        } else {
          final stalls = _filterStalls(snapshot.data!)
            ..sort((a, b) => _distanceKm(a).compareTo(_distanceKm(b)));

          content = showMap ? _buildMap(stalls) : _buildStallFeed(stalls);
        }

        return Column(
          children: [
            _buildHeader(),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, _) => const StallCardSkeleton(),
    );
  }

  Widget _buildStallFeed(List<Map<String, dynamic>> stalls) {
    final hasFilters =
        openOnly ||
        radiusKm != 1 ||
        selectedCategory != 'All' ||
        searchController.text.isNotEmpty;

    if (stalls.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadLocation,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight,
                child: EmptyState(
                  title: 'No stalls found',
                  message: hasFilters
                      ? 'Try removing a filter or searching for something else.'
                      : 'No approved stalls within $radiusKm km of you right now.',
                  actionLabel: hasFilters ? 'Clear filters' : null,
                  onAction: hasFilters ? _clearFilters : null,
                ),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLocation,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: stalls.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Text(
              '${stalls.length} ${stalls.length == 1 ? 'stall' : 'stalls'} nearby',
              style: VendrgoText.label,
            );
          }

          final stall = stalls[index - 1];

          return StallCard(
            name: stall['name'] as String? ?? 'Stall',
            imageUrl: _imageUrl(stall),
            categoryName: categoryNames[stall['category_id']],
            distanceLabel: _cardDistance(stall),
            hours: _hoursOf(stall),
            isOpen: stall['is_open'] == true,
            heroTag: 'stall-${stall['id']}',
            onTap: () => _openStall(stall),
          );
        },
      ),
    );
  }

  Widget _buildMap(List<Map<String, dynamic>> stalls) {
    final center = currentPosition == null
        ? const LatLng(22.990000, 72.486390)
        : LatLng(currentPosition!.latitude, currentPosition!.longitude);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: ClipRRect(
        borderRadius: VendrgoRadius.xlAll,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 14.5),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.vendrgo',
                  maxZoom: 19,
                ),
                MarkerLayer(
                  markers: [
                    if (currentPosition != null)
                      Marker(
                        point: center,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: VendrgoColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.person_pin_circle_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ...stalls
                        .where(
                          (stall) =>
                              stall['latitude'] != null &&
                              stall['longitude'] != null,
                        )
                        .map(
                          (stall) => Marker(
                            point: LatLng(
                              (stall['latitude'] as num).toDouble(),
                              (stall['longitude'] as num).toDouble(),
                            ),
                            width: 44,
                            height: 52,
                            child: GestureDetector(
                              onTap: () => _openStall(stall),
                              child: Icon(
                                Icons.location_on_rounded,
                                size: 46,
                                color: stall['is_open'] == true
                                    ? VendrgoColors.primary
                                    : VendrgoColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: VendrgoRadius.pillAll,
                  boxShadow: VendrgoShadows.card,
                ),
                child: Text(
                  '${stalls.length} ${stalls.length == 1 ? 'stall' : 'stalls'}',
                  style: VendrgoText.label,
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                color: Colors.white.withValues(alpha: 0.88),
                child: const Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(
                    fontSize: 9,
                    color: VendrgoColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesPage() {
    final user = client.auth.currentUser;

    if (user == null) {
      return const EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Please log in again',
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getFavoriteStalls(user.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load favorites',
            actionLabel: 'Retry',
            onAction: () => setState(() {}),
          );
        }

        if (!snapshot.hasData) {
          return _buildSkeletonList();
        }

        final stalls = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              const Text('Your favorites', style: VendrgoText.display),
              const SizedBox(height: 4),
              const Text(
                'Stalls you saved for later.',
                style: VendrgoText.bodySecondary,
              ),
              const SizedBox(height: 20),
              if (stalls.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'No favorites yet',
                    message: 'Tap the heart on a stall to save it here.',
                  ),
                )
              else
                ...stalls.map(
                  (stall) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: StallCard(
                      name: stall['name'] as String? ?? 'Stall',
                      imageUrl: _imageUrl(stall),
                      categoryName: categoryNames[stall['category_id']],
                      distanceLabel: _cardDistance(stall),
                      hours: _hoursOf(stall),
                      isOpen: stall['is_open'] == true,
                      isFavorite: true,
                      heroTag: 'fav-${stall['id']}',
                      onTap: () => _openStall(stall),
                      onToggleFavorite: () =>
                          _toggleFavorite(stall['id'] as String),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getFavoriteStalls(String userId) async {
    final favorites = await client
        .from('favorites')
        .select('stall_id')
        .eq('user_id', userId);

    final ids = favorites.map((row) => row['stall_id'] as String).toList();

    if (ids.isEmpty) {
      return [];
    }

    final stalls = await client
        .from('stalls')
        .select()
        .inFilter('id', ids)
        .eq('approval_status', 'approved');

    return List<Map<String, dynamic>>.from(stalls);
  }

  Widget _buildProfilePage() {
    final user = client.auth.currentUser;
    final metadata = user?.userMetadata ?? {};
    final name = metadata['full_name'] as String? ?? 'Customer';
    final phone = metadata['phone'] as String? ?? 'Not provided';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: VendrgoColors.peach,
              child: Text(
                name.isEmpty ? '?' : name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: VendrgoColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: VendrgoText.title),
                  const SizedBox(height: 2),
                  const Text('Customer', style: VendrgoText.caption),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: VendrgoColors.surface,
            borderRadius: VendrgoRadius.lgAll,
            boxShadow: VendrgoShadows.card,
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.email_outlined,
                  color: VendrgoColors.primary,
                ),
                title: const Text('Email', style: VendrgoText.caption),
                subtitle: Text(user?.email ?? '', style: VendrgoText.body),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(
                  Icons.phone_outlined,
                  color: VendrgoColors.primary,
                ),
                title: const Text('Phone', style: VendrgoText.caption),
                subtitle: Text(phone, style: VendrgoText.body),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showConfirmationDialog(
              context,
              title: 'Log out?',
              message: 'You will need to sign in again to see your favorites.',
              confirmLabel: 'Log out',
              destructive: true,
            );

            if (confirmed) {
              await AuthService.instance.signOut();
            }
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}

class StallDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> stall;
  final String? categoryName;
  final double distanceKm;
  final Future<bool> isFavorite;
  final Future<void> Function() onToggleFavorite;
  final Future<void> Function() onDirections;

  const StallDetailsScreen({
    super.key,
    required this.stall,
    this.categoryName,
    required this.distanceKm,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onDirections,
  });

  @override
  State<StallDetailsScreen> createState() => _StallDetailsScreenState();
}

class _StallDetailsScreenState extends State<StallDetailsScreen> {
  bool? favorite;
  bool togglingFavorite = false;

  @override
  void initState() {
    super.initState();

    widget.isFavorite
        .then((value) {
          if (mounted) {
            setState(() {
              favorite = value;
            });
          }
        })
        .catchError((_) {
          if (mounted) {
            setState(() {
              favorite = false;
            });
          }
        });
  }

  Future<void> _toggleFavorite() async {
    if (favorite == null || togglingFavorite) {
      return;
    }

    final previous = favorite!;

    HapticFeedback.selectionClick();

    setState(() {
      favorite = !previous;
      togglingFavorite = true;
    });

    try {
      await widget.onToggleFavorite();

      if (mounted) {
        showAppSnackBar(
          context,
          previous ? 'Removed from favorites' : 'Saved to favorites',
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        favorite = previous;
      });

      showAppSnackBar(context, 'Could not update favorites.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          togglingFavorite = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stall = widget.stall;

    final imagePath = stall['stall_image_path'] as String?;
    final menuPath = stall['menu_image_path'] as String?;

    final imageUrl = MediaService.urlFor(imagePath);

    final menuUrl = MediaService.urlFor(menuPath);

    final openingHours =
        (stall['opening_hours'] as Map<String, dynamic>?)?['all'] as String? ??
        'Not specified';

    final distanceText = widget.distanceKm == double.infinity
        ? 'Distance unavailable'
        : '${widget.distanceKm.toStringAsFixed(1)} km away';

    final isOpen = stall['is_open'] == true;
    final description = (stall['description'] as String? ?? '').trim();

    final meta = [
      if (widget.categoryName != null && widget.categoryName!.isNotEmpty)
        widget.categoryName!,
      distanceText,
    ].join(' • ');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            backgroundColor: VendrgoColors.surface,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: VendrgoColors.text,
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    tooltip: 'Favorite',
                    onPressed: favorite == null ? null : _toggleFavorite,
                    icon: Icon(
                      favorite == true
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: favorite == true
                          ? VendrgoColors.offer
                          : VendrgoColors.text,
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'stall-${stall['id']}',
                child: NetworkImageWithFallback(
                  url: imageUrl,
                  height: 260,
                  width: double.infinity,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        stall['name'] as String? ?? 'Stall',
                        style: VendrgoText.display,
                      ),
                    ),
                    const SizedBox(width: 12),
                    StatusBadge.openClosed(isOpen: isOpen),
                  ],
                ),
                const SizedBox(height: 6),
                Text(meta, style: VendrgoText.bodySecondary),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: VendrgoColors.surface,
                    borderRadius: VendrgoRadius.lgAll,
                    boxShadow: VendrgoShadows.card,
                  ),
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Address',
                        value: stall['address'] as String? ?? '',
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),
                      _DetailRow(
                        icon: Icons.schedule_outlined,
                        label: 'Opening hours',
                        value: openingHours,
                      ),
                    ],
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('About', style: VendrgoText.heading),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: VendrgoText.body.copyWith(height: 1.5),
                  ),
                ],
                if (menuUrl != null) ...[
                  const SizedBox(height: 24),
                  const Text('Menu', style: VendrgoText.heading),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: VendrgoRadius.lgAll,
                    child: Image.network(
                      menuUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        return Container(
                          height: 150,
                          color: VendrgoColors.surfaceMuted,
                          alignment: Alignment.center,
                          child: const Text('Menu image unavailable'),
                        );
                      },
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: VendrgoColors.surface,
            border: Border(top: BorderSide(color: VendrgoColors.divider)),
          ),
          child: ElevatedButton.icon(
            onPressed: widget.onDirections,
            icon: const Icon(Icons.directions_rounded),
            label: const Text('Get directions'),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: VendrgoColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: VendrgoText.caption),
              const SizedBox(height: 3),
              Text(
                value,
                style: VendrgoText.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
