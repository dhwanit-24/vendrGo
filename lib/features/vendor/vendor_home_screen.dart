import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import 'vendor_edit_stall_screen.dart';

class VendorHomeScreen extends StatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _busy = false;
  bool _loadingProfile = true;
  Map<String, dynamic>? _profile;

  Stream<List<Map<String, dynamic>>> get _stallStream {
    final user = _client.auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _client
        .from('stalls')
        .stream(primaryKey: ['id'])
        .eq('vendor_id', user.id);
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _client.auth.currentUser;

      if (user == null) {
        return;
      }

      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = response;
        _loadingProfile = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingProfile = false;
      });
    }
  }

  Future<Position?> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      _showMessage(
        'Location services are disabled. Please enable location services.',
        isError: true,
      );
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _showMessage(
        'Location permission was denied.',
        isError: true,
      );
      return null;
    }

    if (permission == LocationPermission.deniedForever) {
      _showMessage(
        'Location permission is permanently denied. Please enable it from settings.',
        isError: true,
      );
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      _showMessage(
        'Unable to get your current location.',
        isError: true,
      );
      return null;
    }
  }

  Future<bool> _updateLocation() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return false;
    }

    final position = await _getCurrentLocation();

    if (position == null) {
      return false;
    }

    await _client
        .from('stalls')
        .update({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'location_updated_at': DateTime.now().toUtc().toIso8601String(),
    })
        .eq('vendor_id', user.id);

    return true;
  }

  Future<void> _toggleStall(
      Map<String, dynamic> stall,
      ) async {
    if (_busy) {
      return;
    }

    final user = _client.auth.currentUser;

    if (user == null) {
      return;
    }

    final approvalStatus = stall['approval_status']?.toString() ?? 'pending';

    if (approvalStatus != 'approved') {
      _showMessage(
        approvalStatus == 'pending'
            ? 'Your stall is waiting for admin approval.'
            : approvalStatus == 'rejected'
            ? 'Your stall was rejected by the admin.'
            : 'Your stall is currently unavailable.',
        isError: true,
      );
      return;
    }

    final isCurrentlyOpen = stall['is_open'] == true;

    setState(() {
      _busy = true;
    });

    try {
      if (!isCurrentlyOpen) {
        final latitude = stall['latitude'];
        final longitude = stall['longitude'];

        if (latitude == null || longitude == null) {
          _showMessage(
            'Please update your location before opening the stall.',
            isError: true,
          );
          return;
        }

        await _client
            .from('stalls')
            .update({
          'is_open': true,
          'location_updated_at':
          DateTime.now().toUtc().toIso8601String(),
        })
            .eq('vendor_id', user.id);

        _showMessage('Your stall is now OPEN.');
      } else {
        await _client
            .from('stalls')
            .update({
          'is_open': false,
        })
            .eq('vendor_id', user.id);

        _showMessage('Your stall is now CLOSED.');
      }
    } catch (e) {
      _showMessage(
        'Could not update stall status.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _handleUpdateLocation() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final success = await _updateLocation();

      if (success) {
        _showMessage('Stall location updated successfully.');
      }
    } catch (_) {
      _showMessage(
        'Could not update stall location.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      _showMessage(
        'Could not log out.',
        isError: true,
      );
    }
  }

  void _showAnalyticsComingSoon() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Analytics'),
          content: const Text(
            'Vendor analytics will be added in a future version.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          isError ? VendrgoColors.error : VendrgoColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VendrgoColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Vendor Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VendorProfileScreen(),
                ),
              );
            },
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stallStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _profile == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: 'Unable to load your stall.',
              onRetry: _loadProfile,
            );
          }

          final stalls = snapshot.data ?? [];

          if (stalls.isEmpty) {
            return const Center(
              child: Text(
                'No stall found.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final stall = stalls.first;

          return RefreshIndicator(
            onRefresh: _loadProfile,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildWelcomeCard(),
                const SizedBox(height: 18),
                _buildStallCard(stall),
                const SizedBox(height: 18),
                _buildActions(stall),
                const SizedBox(height: 18),
                _buildStatusInfo(stall),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final name = _profile?['full_name']?.toString().trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VendrgoColors.peach,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: VendrgoColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: const BoxDecoration(
              color: VendrgoColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _loadingProfile
                  ? 'Welcome back'
                  : 'Welcome, ${name?.isNotEmpty == true ? name : 'Vendor'}',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStallCard(
      Map<String, dynamic> stall,
      ) {
    final name = stall['name']?.toString() ?? 'Your Stall';
    final description =
        stall['description']?.toString() ?? 'No description available';
    final approvalStatus =
        stall['approval_status']?.toString() ?? 'pending';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VendrgoColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: VendrgoColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: VendrgoColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _StatusChip(
            label: _approvalLabel(approvalStatus),
            color: _approvalColor(approvalStatus),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
      Map<String, dynamic> stall,
      ) {
    final isOpen = stall['is_open'] == true;
    final approved = stall['approval_status'] == 'approved';

    return Column(
      children: [
        GestureDetector(
          onTap: approved && !_busy
              ? () => _toggleStall(stall)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: !approved
                  ? VendrgoColors.textSecondary
                  : isOpen
                  ? VendrgoColors.success
                  : VendrgoColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (!approved
                      ? VendrgoColors.textSecondary
                      : isOpen
                      ? VendrgoColors.success
                      : VendrgoColors.primary)
                      .withValues(alpha: 0.20),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: _busy
                  ? const CircularProgressIndicator(
                color: Colors.white,
              )
                  : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOpen ? Icons.power_settings_new : Icons.store,
                    color: Colors.white,
                    size: 46,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isOpen ? 'CLOSE STALL' : 'OPEN STALL',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _ActionCard(
          icon: Icons.my_location,
          title: 'Update Location',
          subtitle: 'Fetch your current GPS location',
          onTap: _busy ? null : _handleUpdateLocation,
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.edit_outlined,
          title: 'Edit Stall',
          subtitle: 'Change stall information and menu',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VendorEditStallScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.bar_chart_outlined,
          title: 'Analytics',
          subtitle: 'View stall performance',
          onTap: _showAnalyticsComingSoon,
        ),
      ],
    );
  }

  Widget _buildStatusInfo(
      Map<String, dynamic> stall,
      ) {
    final isOpen = stall['is_open'] == true;
    final approvalStatus =
        stall['approval_status']?.toString() ?? 'pending';
    final rejectionReason =
    stall['rejection_reason']?.toString().trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VendrgoColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: VendrgoColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Status',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                isOpen ? Icons.circle : Icons.circle_outlined,
                size: 14,
                color: isOpen
                    ? VendrgoColors.success
                    : VendrgoColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                isOpen ? 'Currently OPEN' : 'Currently CLOSED',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 18,
                color: VendrgoColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Approval: ${_approvalLabel(approvalStatus)}',
                style: const TextStyle(
                  color: VendrgoColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (approvalStatus == 'rejected' &&
              rejectionReason != null &&
              rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: VendrgoColors.peach,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Admin note: $rejectionReason',
                style: const TextStyle(
                  color: VendrgoColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _approvalLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'suspended':
        return 'Suspended';
      default:
        return 'Pending Approval';
    }
  }

  Color _approvalColor(String status) {
    switch (status) {
      case 'approved':
        return VendrgoColors.success;
      case 'rejected':
        return VendrgoColors.error;
      case 'suspended':
        return VendrgoColors.warning;
      default:
        return VendrgoColors.textSecondary;
    }
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      color: VendrgoColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: VendrgoColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: VendrgoColors.lavender,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? VendrgoColors.accent
                      : VendrgoColors.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: VendrgoColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: VendrgoColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: VendrgoColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class VendorProfileScreen extends StatelessWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    return Scaffold(
      backgroundColor: VendrgoColors.background,
      appBar: AppBar(
        title: const Text('Vendor Profile'),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: user == null
            ? Future.value(null)
            : client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final profile = snapshot.data;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: VendrgoColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: VendrgoColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 38,
                      backgroundColor: VendrgoColors.peach,
                      child: Icon(
                        Icons.person,
                        size: 38,
                        color: VendrgoColors.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      profile?['full_name']?.toString() ?? 'Vendor',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile?['email']?.toString() ??
                          user?.email ??
                          '',
                      style: const TextStyle(
                        color: VendrgoColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ProfileRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: profile?['phone']?.toString() ?? '',
                    ),
                    const SizedBox(height: 12),
                    _ProfileRow(
                      icon: Icons.badge_outlined,
                      label: 'Role',
                      value: 'Vendor',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VendrgoColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: VendrgoColors.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: VendrgoColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}