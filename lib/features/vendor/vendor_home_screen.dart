import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../services/media_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/feedback_widgets.dart';
import '../../shared/widgets/network_image_with_fallback.dart';
import '../../shared/widgets/status_badge.dart';
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
      _showMessage('Location permission was denied.', isError: true);
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
      _showMessage('Unable to get your current location.', isError: true);
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

  Future<void> _toggleStall(Map<String, dynamic> stall) async {
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
              'location_updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('vendor_id', user.id);

        _showMessage('Your stall is now OPEN.');
      } else {
        await _client
            .from('stalls')
            .update({'is_open': false})
            .eq('vendor_id', user.id);

        _showMessage('Your stall is now CLOSED.');
      }
    } catch (e) {
      _showMessage('Could not update stall status.', isError: true);
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
      _showMessage('Could not update stall location.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmationDialog(
        title: 'Log out?',
        content: 'Do you want to continue?',
        confirmText: 'Confirm',
        cancelText: 'Cancel',
        confirmColor: VendrgoColors.error,
      ),
    );

    if (shouldLogout != true) {
      return;
    }

    try {
      await _client.auth.signOut();
    } catch (_) {
      _showMessage('Could not log out.', isError: true);
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

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? VendrgoColors.error
              : VendrgoColors.success,
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
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VendorProfileScreen()),
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
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: 'Unable to load your stall.',
              onRetry: _loadProfile,
            );
          }

          final stalls = snapshot.data ?? [];

          if (stalls.isEmpty) {
            return const EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No stall found',
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

    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: const BoxDecoration(
            color: VendrgoColors.peach,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: VendrgoColors.primaryDark,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome back', style: VendrgoText.caption),
              Text(
                _loadingProfile
                    ? '...'
                    : (name?.isNotEmpty == true ? name! : 'Vendor'),
                style: VendrgoText.title,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStallCard(Map<String, dynamic> stall) {
    final name = stall['name']?.toString() ?? 'Your Stall';
    final description =
        stall['description']?.toString() ?? 'No description available';
    final approvalStatus = stall['approval_status']?.toString() ?? 'pending';
    final imagePath = stall['stall_image_path']?.toString();
    final imageUrl = MediaService.urlFor(imagePath);

    return Container(
      decoration: BoxDecoration(
        color: VendrgoColors.surface,
        borderRadius: VendrgoRadius.lgAll,
        boxShadow: VendrgoShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetworkImageWithFallback(
            url: imageUrl,
            height: 150,
            width: double.infinity,
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: VendrgoText.title)),
                    const SizedBox(width: 8),
                    StatusBadge.approval(status: approvalStatus),
                  ],
                ),
                const SizedBox(height: 6),
                Text(description, style: VendrgoText.bodySecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(Map<String, dynamic> stall) {
    final isOpen = stall['is_open'] == true;
    final approvalStatus = stall['approval_status']?.toString() ?? 'pending';
    final approved = approvalStatus == 'approved';

    final Color tone = !approved
        ? VendrgoColors.textSecondary
        : isOpen
        ? VendrgoColors.success
        : VendrgoColors.primary;

    final String hint = !approved
        ? 'Available once an admin approves your stall'
        : isOpen
        ? 'Customers can see you as OPEN. Tap to close.'
        : 'Customers see you as CLOSED. Tap to open.';

    return Column(
      children: [
        Material(
          color: tone,
          borderRadius: VendrgoRadius.lgAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: approved && !_busy
                ? () {
                    HapticFeedback.mediumImpact();
                    _toggleStall(stall);
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(
                children: [
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Icon(
                            isOpen
                                ? Icons.power_settings_new_rounded
                                : Icons.storefront_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOpen ? 'CLOSE STALL' : 'OPEN STALL',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hint,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ActionCard(
          icon: Icons.my_location_rounded,
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
              MaterialPageRoute(builder: (_) => const VendorEditStallScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.bar_chart_rounded,
          title: 'Analytics',
          subtitle: 'View stall performance',
          onTap: _showAnalyticsComingSoon,
        ),
      ],
    );
  }

  Widget _buildStatusInfo(Map<String, dynamic> stall) {
    final approvalStatus = stall['approval_status']?.toString() ?? 'pending';
    final rejectionReason = stall['rejection_reason']?.toString().trim();

    final approved = approvalStatus == 'approved';
    final rejected = approvalStatus == 'rejected';
    final suspended = approvalStatus == 'suspended';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VendrgoColors.surface,
        borderRadius: VendrgoRadius.lgAll,
        boxShadow: VendrgoShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Approval progress', style: VendrgoText.heading),
          const SizedBox(height: 16),
          const _TimelineStep(label: 'Stall submitted', state: _StepState.done),
          _TimelineStep(
            label: 'Admin review',
            state: approvalStatus == 'pending'
                ? _StepState.current
                : _StepState.done,
          ),
          _TimelineStep(
            label: rejected
                ? 'Rejected'
                : suspended
                ? 'Suspended'
                : 'Approved and visible to customers',
            state: approved
                ? _StepState.done
                : (rejected || suspended)
                ? _StepState.failed
                : _StepState.upcoming,
            isLast: true,
          ),
          if (rejected &&
              rejectionReason != null &&
              rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: VendrgoColors.errorSoft,
                borderRadius: VendrgoRadius.mdAll,
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
}

enum _StepState { done, current, upcoming, failed }

class _TimelineStep extends StatelessWidget {
  final String label;
  final _StepState state;
  final bool isLast;

  const _TimelineStep({
    required this.label,
    required this.state,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (state) {
      _StepState.done => (Icons.check_circle_rounded, VendrgoColors.success),
      _StepState.current => (Icons.schedule_rounded, VendrgoColors.warning),
      _StepState.failed => (Icons.cancel_rounded, VendrgoColors.error),
      _StepState.upcoming => (
        Icons.radio_button_unchecked_rounded,
        VendrgoColors.textTertiary,
      ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, size: 22, color: color),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: VendrgoColors.divider),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Text(
                label,
                style: VendrgoText.body.copyWith(
                  fontWeight: state == _StepState.current
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: state == _StepState.upcoming
                      ? VendrgoColors.textTertiary
                      : VendrgoColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

    return Container(
      decoration: BoxDecoration(
        color: VendrgoColors.surface,
        borderRadius: VendrgoRadius.lgAll,
        boxShadow: VendrgoShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: VendrgoRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: VendrgoColors.peach,
                    borderRadius: VendrgoRadius.mdAll,
                  ),
                  child: Icon(
                    icon,
                    color: enabled
                        ? VendrgoColors.primaryDark
                        : VendrgoColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: VendrgoText.heading),
                      const SizedBox(height: 2),
                      Text(subtitle, style: VendrgoText.caption),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: VendrgoColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: message,
      actionLabel: 'Retry',
      onAction: onRetry,
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
      appBar: AppBar(title: const Text('Vendor Profile')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: user == null
            ? Future.value(null)
            : client.from('profiles').select().eq('id', user.id).maybeSingle(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: VendrgoColors.surface,
                  borderRadius: VendrgoRadius.lgAll,
                  boxShadow: VendrgoShadows.card,
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
                      profile?['email']?.toString() ?? user?.email ?? '',
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
        color: VendrgoColors.surfaceMuted,
        borderRadius: VendrgoRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(icon, color: VendrgoColors.primary),
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
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
