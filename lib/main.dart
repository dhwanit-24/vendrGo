import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_tokens.dart';
import 'features/admin/admin_home_screen.dart';
import 'features/auth/auth_screens.dart';
import 'features/customer/customer_home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/vendor/vendor_home_screen.dart';
import 'features/vendor/vendor_setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _installErrorSafetyNet();

  runApp(const VendrgoApp());
}

/// Last line of defence: a stray error must never show the red error screen.
/// Errors are still written to the console for debugging.
void _installErrorSafetyNet() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('VENDRGO UI ERROR: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('VENDRGO UNHANDLED ERROR: $error');
    debugPrint('$stack');
    return true;
  };

  ErrorWidget.builder = (details) => const FriendlyErrorWidget();
}

/// Shown in place of any widget that fails to build.
class FriendlyErrorWidget extends StatelessWidget {
  const FriendlyErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: VendrgoColors.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: VendrgoColors.peach,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sentiment_dissatisfied_rounded,
                    size: 36,
                    color: VendrgoColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: VendrgoText.heading,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Please go back and try again.',
                  textAlign: TextAlign.center,
                  style: VendrgoText.bodySecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ROOT APP
// ============================================================

class VendrgoApp extends StatefulWidget {
  const VendrgoApp({super.key});

  @override
  State<VendrgoApp> createState() => _VendrgoAppState();
}

class _VendrgoAppState extends State<VendrgoApp> {
  Object? startupError;
  bool initialized = false;
  bool showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final splashDelay = Future<void>.delayed(const Duration(milliseconds: 900));

    debugPrint('VENDRGO: Flutter started.');

    try {
      debugPrint('VENDRGO: Initializing Supabase...');

      await Future.wait([
        Supabase.initialize(
          url: SupabaseConfig.url,
          publishableKey: SupabaseConfig.publishableKey,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        ).timeout(const Duration(seconds: 10)),
        splashDelay,
      ]);

      debugPrint('VENDRGO: Supabase initialized successfully.');

      if (Supabase.instance.client.auth.currentSession == null) {
        showOnboarding = !await OnboardingScreen.hasBeenSeen();
      }
    } catch (error, stackTrace) {
      debugPrint('VENDRGO STARTUP ERROR: $error');
      debugPrint('$stackTrace');

      startupError = error;
    }

    await splashDelay;

    if (mounted) {
      setState(() {
        initialized = true;
      });
    }
  }

  void _retry() {
    setState(() {
      initialized = false;
      startupError = null;
    });

    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vendrgo',
      debugShowCheckedModeBanner: false,
      theme: VendrgoTheme.light(),
      home: !initialized
          ? const SplashScreen()
          : startupError != null
          ? StartupErrorScreen(error: startupError.toString(), onRetry: _retry)
          : showOnboarding
          ? OnboardingScreen(
              onDone: () => setState(() => showOnboarding = false),
            )
          : const AuthRouter(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.92,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VendrgoColors.splash,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(
                  image: AssetImage('assets/vendrgo_logo.png'),
                  width: 280,
                  semanticLabel: 'VendrGo',
                ),
                SizedBox(height: 8),
                Text(
                  'Find what’s open near you',
                  style: VendrgoText.bodySecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// AUTH / SESSION ROUTER
// ============================================================

class AuthRouter extends StatefulWidget {
  const AuthRouter({super.key});

  @override
  State<AuthRouter> createState() => _AuthRouterState();
}

class _AuthRouterState extends State<AuthRouter> {
  late final StreamSubscription<AuthState> authSubscription;

  bool loading = true;
  bool passwordRecovery = false;

  Map<String, dynamic>? profile;
  Map<String, dynamic>? stall;

  @override
  void initState() {
    super.initState();

    authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        _handleAuthState(state);
      },
      onError: (_, _) {
        if (!mounted) return;

        setState(() {
          loading = false;
        });
      },
    );

    _loadCurrentSession();
  }

  @override
  void dispose() {
    authSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentSession() async {
    debugPrint('VENDRGO: Checking existing session...');

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      debugPrint('VENDRGO: No existing session.');

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      return;
    }

    debugPrint('VENDRGO: Existing session found.');

    try {
      await _resolveRole();
    } catch (error) {
      debugPrint('VENDRGO ROLE ERROR: $error');

      if (!mounted) return;

      setState(() {
        profile = null;
        stall = null;
      });
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _handleAuthState(AuthState state) async {
    debugPrint('VENDRGO AUTH EVENT: ${state.event}');

    if (state.event == AuthChangeEvent.passwordRecovery) {
      if (!mounted) return;

      setState(() {
        passwordRecovery = true;
        loading = false;
      });

      return;
    }

    if (state.event == AuthChangeEvent.signedOut) {
      if (!mounted) return;

      setState(() {
        profile = null;
        stall = null;
        passwordRecovery = false;
        loading = false;
      });

      return;
    }

    if (state.session != null &&
        (state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.initialSession ||
            state.event == AuthChangeEvent.tokenRefreshed ||
            state.event == AuthChangeEvent.userUpdated)) {
      try {
        await _resolveRole();
      } catch (error) {
        debugPrint('VENDRGO ROLE ERROR: $error');
      }
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void>? _resolvingRole;

  // Sign-in triggers both the auth listener and the login screen callback.
  // Share one in-flight lookup so the profile is fetched only once.
  Future<void> _resolveRole() {
    return _resolvingRole ??= _loadRole().whenComplete(() {
      _resolvingRole = null;
    });
  }

  Future<void> _loadRole() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        profile = null;
        stall = null;
      });

      return;
    }

    debugPrint('VENDRGO: Loading profile for ${user.id}');

    final currentProfile = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (currentProfile == null) {
      debugPrint('VENDRGO: No profile found for current user.');

      if (!mounted) return;

      setState(() {
        profile = null;
        stall = null;
      });

      return;
    }

    Map<String, dynamic>? currentStall;

    if (currentProfile['role'] == 'vendor') {
      currentStall = await client
          .from('stalls')
          .select()
          .eq('vendor_id', user.id)
          .maybeSingle();
    }

    if (!mounted) return;

    setState(() {
      profile = currentProfile;
      stall = currentStall;
      passwordRecovery = false;
    });

    debugPrint('VENDRGO: Role resolved = ${currentProfile['role']}');
  }

  Future<void> _refreshRole() async {
    await _resolveRole();

    if (mounted) {
      setState(() {});
    }
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onBack: () => Navigator.of(context).pop(),
          onForgotPassword: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ForgotPasswordScreen(
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
          onLoginSuccess: () async {
            // Resolve the role first, then close the login screen, so the
            // landing page never shows between login and the home screen.
            await _refreshRole();

            if (!mounted) return;

            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _openSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignupRoleScreen(
          onBack: () => Navigator.of(context).pop(),
          onCustomer: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerSignupScreen(
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
          onVendor: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VendorSignupScreen(
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoot() {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (passwordRecovery) {
      return ResetPasswordScreen(
        onFinished: () {
          if (!mounted) return;

          setState(() {
            passwordRecovery = false;
            profile = null;
            stall = null;
          });
        },
      );
    }

    if (profile == null) {
      return AuthLandingScreen(onLogin: _openLogin, onSignup: _openSignup);
    }

    if (profile!['is_active'] != true) {
      return const _DisabledAccountScreen();
    }

    final role = profile!['role'] as String? ?? 'customer';

    switch (role) {
      case 'customer':
        return const CustomerHomeScreen();

      case 'vendor':
        if (stall == null) {
          return const VendorSetupScreen();
        }

        return VendorHomeScreen();

      case 'admin':
        return const AdminHomeScreen();

      default:
        return const _UnknownRoleScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildRoot();
  }
}

// ============================================================
// STARTUP ERROR SCREEN
// ============================================================

class StartupErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const StartupErrorScreen({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: VendrgoColors.errorSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      size: 44,
                      color: VendrgoColors.error,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Vendrgo could not start',
                    style: VendrgoText.title,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check your internet connection and try again.',
                    style: VendrgoText.bodySecondary,
                    textAlign: TextAlign.center,
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ExpansionTile(
                    title: const Text('Details', style: VendrgoText.caption),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: VendrgoColors.surfaceMuted,
                          borderRadius: VendrgoRadius.mdAll,
                        ),
                        child: SelectableText(
                          error,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DISABLED ACCOUNT
// ============================================================

class _DisabledAccountScreen extends StatelessWidget {
  const _DisabledAccountScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: VendrgoColors.errorSoft,
              borderRadius: VendrgoRadius.xlAll,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.block_rounded,
                  size: 50,
                  color: VendrgoColors.error,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Account unavailable',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This account has been disabled.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// UNKNOWN ROLE
// ============================================================

class _UnknownRoleScreen extends StatelessWidget {
  const _UnknownRoleScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Unknown account role.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
