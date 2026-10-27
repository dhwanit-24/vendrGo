import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/admin_home_screen.dart';
import 'features/auth/auth_screens.dart';
import 'features/customer/customer_home_screen.dart';
import 'features/vendor/vendor_home_screen.dart';
import 'features/vendor/vendor_setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VendrgoApp());
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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final splashDelay = Future<void>.delayed(const Duration(seconds: 2));

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vendrgo',
      debugShowCheckedModeBanner: false,
      theme: VendrgoTheme.light(),
      home: !initialized
          ? const SplashScreen()
          : startupError == null
          ? const AuthRouter()
          : StartupErrorScreen(error: startupError.toString()),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFF8EA),
      body: Center(
        child: Image(
          image: AssetImage('assets/vendrgo_logo.png'),
          width: 310,
          semanticLabel: 'VendrGo',
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

    authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(
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
    debugPrint(
      'VENDRGO AUTH EVENT: ${state.event}',
    );

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

  Future<void> _resolveRole() async {
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

    debugPrint(
      'VENDRGO: Loading profile for ${user.id}',
    );

    final currentProfile = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (currentProfile == null) {
      debugPrint(
        'VENDRGO: No profile found for current user.',
      );

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

    debugPrint(
      'VENDRGO: Role resolved = ${currentProfile['role']}',
    );
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
            Navigator.of(context).pop();
            await _refreshRole();
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
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
      return AuthLandingScreen(
        onLogin: _openLogin,
        onSignup: _openSignup,
      );
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

  const StartupErrorScreen({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Vendrgo could not start',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Startup failed before the application loaded.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      error,
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
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
              color: const Color(0xFFFFF1EF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.block_rounded,
                  size: 50,
                  color: Colors.red,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Account unavailable',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
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
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
