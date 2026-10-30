import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

/// First-run intro shown once to signed-out users.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  static const _seenKey = 'onboarding_seen_v1';

  /// Returns true if the intro was already shown. Storage failures count as
  /// "seen" so a broken preference store can never block the app.
  static Future<bool> hasBeenSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_seenKey) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    } catch (_) {
      // Ignore: the intro may simply show again next launch.
    }
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final controller = PageController();
  int page = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.storefront_rounded,
      title: 'Discover food stalls near you',
      message:
          'See street food and local stalls within 1 km, '
          'right on your phone.',
    ),
    _OnboardingPage(
      icon: Icons.schedule_rounded,
      title: 'Know what is open right now',
      message:
          'Vendors update their status live, so you never walk '
          'to a closed stall.',
    ),
    _OnboardingPage(
      icon: Icons.location_on_rounded,
      title: 'Allow location for best results',
      message:
          'We only use your location to find stalls around you '
          'and give you directions.',
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    widget.onDone();
  }

  void _next() {
    if (page == _pages.length - 1) {
      _finish();
      return;
    }

    controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = page == _pages.length - 1;

    return Scaffold(
      backgroundColor: VendrgoColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: TextButton(
                  onPressed: isLast ? null : _finish,
                  child: Text(isLast ? '' : 'Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: controller,
                onPageChanged: (index) => setState(() => page = index),
                children: _pages,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: i == page ? 24 : 8,
                    decoration: BoxDecoration(
                      color: i == page
                          ? VendrgoColors.primary
                          : VendrgoColors.border,
                      borderRadius: VendrgoRadius.pillAll,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ElevatedButton(
                onPressed: _next,
                child: Text(isLast ? 'Get started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: const BoxDecoration(
              color: VendrgoColors.peach,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 72, color: VendrgoColors.primary),
          ),
          const SizedBox(height: 40),
          Text(title, textAlign: TextAlign.center, style: VendrgoText.display),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: VendrgoText.bodySecondary.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
