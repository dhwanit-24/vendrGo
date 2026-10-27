import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_services.dart';
import '../../shared/widgets/app_ui.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() =>
      _CustomerHomeScreenState();
}

class _CustomerHomeScreenState
    extends State<CustomerHomeScreen> {
  final client = Supabase.instance.client;
  final searchController = TextEditingController();

  Position? currentPosition;

  bool loadingLocation = true;
  bool openOnly = false;

  String selectedCategory = 'All';

  int selectedTab = 0;

  Map<String, String> categoryNames = {};

  Stream<List<Map<String, dynamic>>> get stallStream =>
      client
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
          for (final row in result)
            row['id'] as String:
            row['name'] as String,
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
      final serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Location services are disabled.',
        );
      }

      var permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        throw Exception(
          'Location permission denied.',
        );
      }

      if (permission ==
          LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied.',
        );
      }

      final position =
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
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

  double _distanceKm(
      Map<String, dynamic> stall,
      ) {
    if (currentPosition == null ||
        stall['latitude'] == null ||
        stall['longitude'] == null) {
      return double.infinity;
    }

    final meters =
    Geolocator.distanceBetween(
      currentPosition!.latitude,
      currentPosition!.longitude,
      (stall['latitude'] as num).toDouble(),
      (stall['longitude'] as num).toDouble(),
    );

    return meters / 1000;
  }

  String _distanceLabel(
      Map<String, dynamic> stall,
      ) {
    final distance = _distanceKm(stall);

    if (distance == double.infinity) {
      return 'Distance unavailable';
    }

    return '${distance.toStringAsFixed(1)} km';
  }

  List<Map<String, dynamic>> _filterStalls(
      List<Map<String, dynamic>> stalls,
      ) {
    final search =
    searchController.text.trim().toLowerCase();

    return stalls.where((stall) {
      if (_distanceKm(stall) > 1.0) {
        return false;
      }

      if (openOnly &&
          stall['is_open'] != true) {
        return false;
      }

      final stallCategory =
      categoryNames[stall['category_id']];

      if (selectedCategory != 'All' &&
          stallCategory != selectedCategory) {
        return false;
      }

      final name =
      (stall['name'] as String? ?? '')
          .toLowerCase();

      final description =
      (stall['description'] as String? ?? '')
          .toLowerCase();

      final category =
      (stallCategory ?? '')
          .toLowerCase();

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
    final categories = [
      'All',
      ...categoryNames.values.toSet(),
    ];

    if (!mounted) return;

    final result =
    await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24,
          ),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                8,
                0,
                8,
                10,
              ),
              child: Text(
                'Filter by food category',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ...categories.map(
                  (category) {
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  title: Text(category),
                  trailing:
                  selectedCategory == category
                      ? const Icon(
                    Icons.check_rounded,
                    color:
                    VendrgoColors.primary,
                  )
                      : null,
                  onTap: () =>
                      Navigator.of(context)
                          .pop(category),
                );
              },
            ),
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

  Future<bool> _isFavorite(
      String stallId,
      ) async {
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

  Future<void> _toggleFavorite(
      String stallId,
      ) async {
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

  Future<void> _openDirections(
      Map<String, dynamic> stall,
      ) async {
    final lat = stall['latitude'];
    final lng = stall['longitude'];

    if (lat == null || lng == null) {
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
          '&destination=$lat,$lng',
    );

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open Google Maps.',
          ),
          backgroundColor:
          VendrgoColors.error,
        ),
      );
    }
  }

  void _openStall(
      Map<String, dynamic> stall,
      ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StallDetailsScreen(
          stall: stall,
          categoryName:
          categoryNames[stall['category_id']],
          distanceKm:
          _distanceKm(stall),
          isFavorite:
          _isFavorite(
            stall['id'] as String,
          ),
          onToggleFavorite:
              () => _toggleFavorite(
            stall['id'] as String,
          ),
          onDirections:
              () => _openDirections(stall),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selectedTab,
          children: [
            _buildMapPage(),
            _buildFavoritesPage(),
            _buildProfilePage(),
          ],
        ),
      ),
      bottomNavigationBar:
      _buildBottomNavigation(),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        14,
        0,
        14,
        14,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color: VendrgoColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              selected: selectedTab == 0,
              icon: Icons.map_outlined,
              selectedIcon: Icons.map_rounded,
              label: 'Map',
              onTap: () {
                setState(() {
                  selectedTab = 0;
                });
              },
            ),
          ),
          Expanded(
            child: _NavItem(
              selected: selectedTab == 1,
              icon:
              Icons.favorite_border_rounded,
              selectedIcon:
              Icons.favorite_rounded,
              label: 'Favorites',
              onTap: () {
                setState(() {
                  selectedTab = 1;
                });
              },
            ),
          ),
          Expanded(
            child: _NavItem(
              selected: selectedTab == 2,
              icon:
              Icons.person_outline_rounded,
              selectedIcon:
              Icons.person_rounded,
              label: 'Profile',
              onTap: () {
                setState(() {
                  selectedTab = 2;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPage() {
    return StreamBuilder<
        List<Map<String, dynamic>>>(
      stream: stallStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not load nearby stalls.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final stalls =
        _filterStalls(snapshot.data!);

        final center =
        currentPosition == null
            ? const LatLng(
          22.990000,
          72.486390,
        )
            : LatLng(
          currentPosition!.latitude,
          currentPosition!.longitude,
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                14,
                16,
                10,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const VendrgoLogo(
                        size: 44,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Find nearby food.',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed:
                        _loadLocation,
                        icon: const Icon(
                          Icons.my_location_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  TextField(
                    controller:
                    searchController,
                    onChanged:
                        (_) => setState(() {}),
                    decoration:
                    InputDecoration(
                      hintText:
                      'Search stalls, food...',
                      prefixIcon:
                      const Icon(
                        Icons.search_rounded,
                      ),
                      suffixIcon:
                      searchController
                          .text
                          .isEmpty
                          ? null
                          : IconButton(
                        onPressed: () {
                          searchController
                              .clear();

                          setState(
                                () {},
                          );
                        },
                        icon:
                        const Icon(
                          Icons
                              .close_rounded,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SingleChildScrollView(
                    scrollDirection:
                    Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          selected: openOnly,
                          label: const Text(
                            'Open only',
                          ),
                          onSelected: (value) {
                            setState(() {
                              openOnly =
                                  value;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          label: Text(
                            selectedCategory,
                          ),
                          avatar:
                          const Icon(
                            Icons
                                .restaurant_menu_rounded,
                            size: 18,
                          ),
                          onPressed:
                          _showCategoryFilter,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              flex: 6,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    24,
                  ),
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 14.5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                            'com.example.vendrgo',
                            maxZoom: 19,
                          ),
                          MarkerLayer(
                            markers: [
                              if (currentPosition !=
                                  null)
                                Marker(
                                  point: center,
                                  width: 44,
                                  height: 44,
                                  child:
                                  Container(
                                    decoration:
                                    BoxDecoration(
                                      color:
                                      VendrgoColors
                                          .accent,
                                      shape:
                                      BoxShape
                                          .circle,
                                      border:
                                      Border.all(
                                        color:
                                        Colors.white,
                                        width:
                                        3,
                                      ),
                                    ),
                                    child:
                                    const Icon(
                                      Icons
                                          .person_pin_circle_rounded,
                                      color:
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ...stalls
                                  .where(
                                    (stall) =>
                                stall[
                                'latitude'] !=
                                    null &&
                                    stall[
                                    'longitude'] !=
                                        null,
                              )
                                  .map(
                                    (stall) =>
                                    Marker(
                                      point: LatLng(
                                        (stall['latitude']
                                        as num)
                                            .toDouble(),
                                        (stall['longitude']
                                        as num)
                                            .toDouble(),
                                      ),
                                      width: 44,
                                      height: 52,
                                      child:
                                      GestureDetector(
                                        onTap:
                                            () =>
                                            _openStall(
                                              stall,
                                            ),
                                        child:
                                        Icon(
                                          Icons
                                              .location_on_rounded,
                                          size: 46,
                                          color:
                                          stall['is_open'] ==
                                              true
                                              ? VendrgoColors
                                              .success
                                              : VendrgoColors
                                              .textSecondary,
                                        ),
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          color: Colors.white
                              .withValues(
                            alpha: 0.88,
                          ),
                          child: const Text(
                            '© OpenStreetMap contributors',
                            style: TextStyle(
                              fontSize: 9,
                              color:
                              VendrgoColors
                                  .textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              flex: 4,
              child: _NearbyStallList(
                stalls: stalls,
                distanceFor: _distanceLabel,
                onTap: _openStall,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFavoritesPage() {
    final user = client.auth.currentUser;

    if (user == null) {
      return const Center(
        child: Text(
          'Please log in again.',
        ),
      );
    }

    return FutureBuilder<
        List<Map<String, dynamic>>>(
      future:
      _getFavoriteStalls(user.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final stalls =
        snapshot.data!;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            28,
          ),
          children: [
            const Text(
              'Your favorites',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Stalls you saved for later.',
              style: TextStyle(
                color: VendrgoColors
                    .textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            if (stalls.isEmpty)
              const SectionCard(
                color:
                VendrgoColors.lavender,
                child: Text(
                  'You have not saved any stalls yet.',
                ),
              )
            else
              ...stalls.map(
                    (stall) =>
                    Padding(
                      padding:
                      const EdgeInsets.only(
                        bottom: 10,
                      ),
                      child: ListTile(
                        tileColor:
                        Colors.white,
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            16,
                          ),
                          side:
                          const BorderSide(
                            color:
                            VendrgoColors
                                .border,
                          ),
                        ),
                        title: Text(
                          stall['name']
                          as String? ??
                              'Stall',
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          stall['is_open'] ==
                              true
                              ? 'OPEN'
                              : 'CLOSED',
                        ),
                        trailing:
                        const Icon(
                          Icons
                              .arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        onTap: () =>
                            _openStall(
                              stall,
                            ),
                      ),
                    ),
              ),
          ],
        );
      },
    );
  }

  Future<
      List<Map<String, dynamic>>>
  _getFavoriteStalls(
      String userId,
      ) async {
    final favorites = await client
        .from('favorites')
        .select('stall_id')
        .eq('user_id', userId);

    final ids = favorites
        .map(
          (row) =>
      row['stall_id']
      as String,
    )
        .toList();

    if (ids.isEmpty) {
      return [];
    }

    final stalls = await client
        .from('stalls')
        .select()
        .inFilter('id', ids)
        .eq(
      'approval_status',
      'approved',
    );

    return List<
        Map<String, dynamic>>.from(
      stalls,
    );
  }

  Widget _buildProfilePage() {
    final user = client.auth.currentUser;
    final metadata =
        user?.userMetadata ?? {};

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        28,
      ),
      children: [
        const VendrgoLogo(size: 72),

        const SizedBox(height: 20),

        const Text(
          'Your profile',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          metadata['full_name'] as String? ??
              'Customer',
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          user?.email ?? '',
          style: const TextStyle(
            color:
            VendrgoColors.textSecondary,
          ),
        ),

        const SizedBox(height: 24),

        SectionCard(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Phone',
                style: TextStyle(
                  color:
                  VendrgoColors
                      .textSecondary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                metadata['phone']
                as String? ??
                    'Not provided',
                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await AuthService.instance
                  .signOut();
            },
            icon: const Icon(
              Icons.logout_rounded,
            ),
            label: const Text(
              'Logout',
            ),
          ),
        ),
      ],
    );
  }
}

class StallDetailsScreen
    extends StatelessWidget {
  final Map<String, dynamic> stall;
  final String? categoryName;
  final double distanceKm;
  final Future<bool> isFavorite;
  final Future<void> Function()
  onToggleFavorite;
  final Future<void> Function()
  onDirections;

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
  Widget build(
      BuildContext context,
      ) {
    final imagePath =
    stall['stall_image_path']
    as String?;

    final menuPath =
    stall['menu_image_path']
    as String?;

    final storage =
    Supabase.instance.client
        .storage
        .from('vendrgo-media');

    final imageUrl =
    imagePath == null ||
        imagePath.isEmpty
        ? null
        : storage.getPublicUrl(
      imagePath,
    );

    final menuUrl =
    menuPath == null ||
        menuPath.isEmpty
        ? null
        : storage.getPublicUrl(
      menuPath,
    );

    final openingHours =
        (stall['opening_hours']
        as Map<String, dynamic>?)
        ?['all'] as String? ??
            'Not specified';

    final distanceText =
    distanceKm == double.infinity
        ? 'Distance unavailable'
        : '${distanceKm.toStringAsFixed(1)} km away';

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          'Stall details',
        ),
        actions: [
          FutureBuilder<bool>(
            future: isFavorite,
            builder: (
                context,
                snapshot,
                ) {
              final favorite =
                  snapshot.data == true;

              return IconButton(
                onPressed:
                onToggleFavorite,
                icon: Icon(
                  favorite
                      ? Icons
                      .favorite_rounded
                      : Icons
                      .favorite_border_rounded,
                  color: favorite
                      ? VendrgoColors
                      .error
                      : null,
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding:
        const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          32,
        ),
        children: [
          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              22,
            ),
            child: SizedBox(
              height: 220,
              child: imageUrl == null
                  ? Container(
                color:
                VendrgoColors
                    .peach,
                child:
                const Center(
                  child: Icon(
                    Icons
                        .storefront_rounded,
                    size: 70,
                  ),
                ),
              )
                  : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (
                    _,
                    _,
                    _,
                    ) {
                  return Container(
                    color:
                    VendrgoColors
                        .peach,
                    child:
                    const Center(
                      child: Icon(
                        Icons
                            .image_not_supported_outlined,
                        size: 55,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              Expanded(
                child: Text(
                  stall['name']
                  as String? ??
                      'Stall',
                  style:
                  const TextStyle(
                    fontSize: 30,
                    fontWeight:
                    FontWeight
                        .w900,
                  ),
                ),
              ),
              Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration:
                BoxDecoration(
                  color:
                  stall['is_open'] ==
                      true
                      ? VendrgoColors
                      .mint
                      : VendrgoColors
                      .peach,
                  borderRadius:
                  BorderRadius
                      .circular(
                    12,
                  ),
                ),
                child: Text(
                  stall['is_open'] ==
                      true
                      ? 'OPEN'
                      : 'CLOSED',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.w800,
                    color:
                    stall['is_open'] ==
                        true
                        ? VendrgoColors
                        .success
                        : VendrgoColors
                        .primaryDark,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            [
              if (categoryName !=
                  null &&
                  categoryName!
                      .isNotEmpty)
                categoryName!,
              distanceText,
            ].join(' • '),
            style:
            const TextStyle(
              color:
              VendrgoColors
                  .textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          SectionCard(
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons
                      .location_on_outlined,
                  label: 'Address',
                  value:
                  stall['address']
                  as String? ??
                      '',
                ),
                const SizedBox(
                  height: 14,
                ),
                _DetailRow(
                  icon: Icons
                      .schedule_outlined,
                  label:
                  'Opening hours',
                  value:
                  openingHours,
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          if ((stall['description']
          as String? ??
              '')
              .trim()
              .isNotEmpty)
            SectionCard(
              color:
              VendrgoColors
                  .lavender,
              child: Text(
                stall['description']
                as String,
                style:
                const TextStyle(
                  height: 1.5,
                ),
              ),
            ),

          if (menuUrl != null) ...[
            const SizedBox(height: 18),
            const Text(
              'Menu',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius:
              BorderRadius.circular(
                18,
              ),
              child: Image.network(
                menuUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (
                    _,
                    _,
                    _,
                    ) {
                  return Container(
                    height: 150,
                    color:
                    VendrgoColors
                        .peach,
                    alignment:
                    Alignment
                        .center,
                    child: const Text(
                      'Menu image unavailable',
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
              onDirections,
              icon: const Icon(
                Icons
                    .directions_rounded,
              ),
              label: const Text(
                'Get directions',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyStallList
    extends StatelessWidget {
  final List<Map<String, dynamic>>
  stalls;
  final String Function(
      Map<String, dynamic>,
      ) distanceFor;
  final void Function(
      Map<String, dynamic>,
      ) onTap;

  const _NearbyStallList({
    required this.stalls,
    required this.distanceFor,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    if (stalls.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No matching stalls within 1 km.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
              VendrgoColors
                  .textSecondary,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding:
      const EdgeInsets.fromLTRB(
        14,
        10,
        14,
        20,
      ),
      itemCount: stalls.length,
      separatorBuilder:
          (_, _) =>
      const SizedBox(
        height: 8,
      ),
      itemBuilder: (
          context,
          index,
          ) {
        final stall =
        stalls[index];

        return ListTile(
          tileColor: Colors.white,
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              16,
            ),
            side: const BorderSide(
              color:
              VendrgoColors
                  .border,
            ),
          ),
          leading: Icon(
            stall['is_open'] == true
                ? Icons
                .storefront_rounded
                : Icons
                .storefront_outlined,
            color:
            stall['is_open'] ==
                true
                ? VendrgoColors
                .success
                : VendrgoColors
                .textSecondary,
          ),
          title: Text(
            stall['name']
            as String? ??
                'Stall',
            style:
            const TextStyle(
              fontWeight:
              FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '${stall['is_open'] == true ? 'Open' : 'Closed'} • '
                '${distanceFor(stall)}',
          ),
          trailing: const Icon(
            Icons
                .chevron_right_rounded,
          ),
          onTap: () => onTap(stall),
        );
      },
    );
  }
}

class _NavItem
    extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Container(
            padding:
            const EdgeInsets
                .symmetric(
              horizontal: 16,
              vertical: 7,
            ),
            decoration:
            BoxDecoration(
              color: selected
                  ? VendrgoColors
                  .peach
                  : Colors
                  .transparent,
              borderRadius:
              BorderRadius.circular(
                14,
              ),
            ),
            child: Icon(
              selected
                  ? selectedIcon
                  : icon,
              color: selected
                  ? VendrgoColors
                  .primary
                  : VendrgoColors
                  .textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected
                  ? FontWeight.w800
                  : FontWeight.w500,
              color: selected
                  ? VendrgoColors
                  .text
                  : VendrgoColors
                  .textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment
          .start,
      children: [
        Icon(
          icon,
          size: 21,
          color:
          VendrgoColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              Text(
                label,
                style:
                const TextStyle(
                  fontSize: 12,
                  color:
                  VendrgoColors
                      .textSecondary,
                ),
              ),
              const SizedBox(
                height: 3,
              ),
              Text(
                value,
                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}