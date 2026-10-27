import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_services.dart';
import '../../shared/widgets/app_ui.dart';

class AuthLandingScreen extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  const AuthLandingScreen({
    super.key,
    required this.onLogin,
    required this.onSignup,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 36),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VendrgoColors.peach,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'LOCAL FOOD • LOCAL VENDORS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: VendrgoColors.primaryDark,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const VendrgoLogo(size: 76),

              const SizedBox(height: 28),

              const Text(
                'Find what’s open\nnear you.',
                style: TextStyle(
                  fontSize: 40,
                  height: 1.02,
                  fontWeight: FontWeight.w800,
                  color: VendrgoColors.text,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Vendrgo connects local food stalls with nearby '
                'customers in real time.',
                style: TextStyle(
                  fontSize: 17,
                  height: 1.45,
                  color: VendrgoColors.textSecondary,
                ),
              ),

              const SizedBox(height: 34),

              SectionCard(
                color: VendrgoColors.mint,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: VendrgoColors.success,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Discover nearby stalls that are currently open.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onLogin,
                  child: const Text('Login'),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSignup,
                  child: const Text('Create an account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onForgotPassword;
  final Future<void> Function() onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.onBack,
    required this.onForgotPassword,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      await AuthService.instance.signIn(
        email: emailController.text,
        password: passwordController.text,
      );

      await widget.onLoginSuccess();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = friendlyAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              const Text(
                'Welcome back.',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 8),

              const Text(
                'Sign in to continue to Vendrgo.',
                style: TextStyle(
                  fontSize: 16,
                  color: VendrgoColors.textSecondary,
                ),
              ),

              const SizedBox(height: 28),

              if (errorMessage != null) ...[
                _ErrorBox(message: errorMessage!),
                const SizedBox(height: 16),
              ],

              AppTextField(
                controller: emailController,
                label: 'Email',
                hint: 'you@example.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required.';
                  }

                  if (!value.contains('@')) {
                    return 'Enter a valid email.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              AppTextField(
                controller: passwordController,
                label: 'Password',
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onForgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : submit,
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignupRoleScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onCustomer;
  final VoidCallback onVendor;

  const SignupRoleScreen({
    super.key,
    required this.onBack,
    required this.onCustomer,
    required this.onVendor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: VendrgoColors.peach,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'CREATE ACCOUNT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: VendrgoColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const VendrgoLogo(size: 76),
              const SizedBox(height: 28),
              const Text(
                'How will you\nuse Vendrgo?',
                style: TextStyle(
                  fontSize: 40,
                  height: 1.02,
                  fontWeight: FontWeight.w800,
                  color: VendrgoColors.text,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Choose the role that best fits you. '
                    'Your account role cannot be changed later.',
                style: TextStyle(
                  fontSize: 17,
                  height: 1.45,
                  color: VendrgoColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              _RoleCard(
                icon: Icons.person_rounded,
                color: VendrgoColors.mint,
                title: 'I’m a customer',
                description:
                'Discover nearby food stalls and see what is open.',
                onTap: onCustomer,
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.storefront_rounded,
                color: VendrgoColors.peach,
                title: 'I’m a vendor',
                description:
                'Register your stall and let nearby customers know when you are open.',
                onTap: onVendor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerSignupScreen extends StatefulWidget {
  final VoidCallback onBack;

  const CustomerSignupScreen({super.key, required this.onBack});

  @override
  State<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends State<CustomerSignupScreen> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;
  String? errorMessage;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await AuthService.instance.signUpCustomer(
        name: nameController.text,
        email: emailController.text,
        password: passwordController.text,
        phone: phoneController.text,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            email: emailController.text.trim(),
            role: 'customer',
            hasExistingSession: response.session != null,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = friendlyAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SignupFormScaffold(
      title: 'Customer signup',
      subtitle: 'Create your Vendrgo customer account.',
      onBack: widget.onBack,
      formKey: formKey,
      errorMessage: errorMessage,
      loading: loading,
      onSubmit: submit,
      children: [
        AppTextField(
          controller: nameController,
          label: 'Full name',
          hint: 'Your name',
          icon: Icons.person_outline_rounded,
          validator: _required('Name'),
        ),

        const SizedBox(height: 14),

        AppTextField(
          controller: emailController,
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Email is required.';
            }

            if (!value.contains('@')) {
              return 'Enter a valid email.';
            }

            return null;
          },
        ),

        const SizedBox(height: 14),

        AppTextField(
          controller: phoneController,
          label: 'Phone number',
          hint: '10 digit mobile number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: (value) {
            final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';

            if (digits.isEmpty) {
              return 'Phone number is required.';
            }

            if (digits.length < 10) {
              return 'Enter a valid phone number.';
            }

            return null;
          },
        ),

        const SizedBox(height: 14),

        AppTextField(
          controller: passwordController,
          label: 'Password',
          hint: 'At least 6 characters',
          icon: Icons.lock_outline_rounded,
          obscureText: obscurePassword,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                obscurePassword = !obscurePassword;
              });
            },
            icon: Icon(
              obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
          validator: (value) {
            if (value == null || value.length < 6) {
              return 'Password must be at least 6 characters.';
            }

            return null;
          },
        ),

        const SizedBox(height: 14),

        AppTextField(
          controller: confirmPasswordController,
          label: 'Confirm password',
          hint: 'Enter password again',
          icon: Icons.lock_reset_outlined,
          obscureText: obscureConfirm,
          textInputAction: TextInputAction.done,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                obscureConfirm = !obscureConfirm;
              });
            },
            icon: Icon(
              obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
          validator: (value) {
            if (value != passwordController.text) {
              return 'Passwords do not match.';
            }

            return null;
          },
        ),
      ],
    );
  }
}

class VendorSignupScreen extends StatefulWidget {
  final VoidCallback onBack;

  const VendorSignupScreen({super.key, required this.onBack});

  @override
  State<VendorSignupScreen> createState() => _VendorSignupScreenState();
}

class _VendorSignupScreenState extends State<VendorSignupScreen> {
  final formKey = GlobalKey<FormState>();

  final ownerController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final phoneController = TextEditingController();

  final stallNameController = TextEditingController();
  final descriptionController = TextEditingController();
  final categoryController = TextEditingController();
  final addressController = TextEditingController();
  final openingHoursController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;
  String? errorMessage;

  @override
  void dispose() {
    ownerController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    phoneController.dispose();
    stallNameController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
    addressController.dispose();
    openingHoursController.dispose();
    super.dispose();
  }

Future<void> _selectOpeningHours() async {
  final openingTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
    helpText: 'Select opening time',
  );

  if (openingTime == null || !mounted) {
    return;
  }

  final closingTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: (openingTime.hour + 8) % 24,
      minute: openingTime.minute,
    ),
    helpText: 'Select closing time',
  );

  if (closingTime == null || !mounted) {
    return;
  }

  setState(() {
    openingHoursController.text =
        '${openingTime.format(context)} – ${closingTime.format(context)}';
  });
}

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await AuthService.instance.signUpVendor(
        ownerName: ownerController.text,
        email: emailController.text,
        password: passwordController.text,
        phone: phoneController.text,
        stallName: stallNameController.text,
        stallDescription: descriptionController.text,
        categoryName: categoryController.text,
        address: addressController.text,
        openingHours: openingHoursController.text,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            email: emailController.text.trim(),
            role: 'vendor',
            hasExistingSession: response.session != null,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = friendlyAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SignupFormScaffold(
      title: 'Vendor signup',
      subtitle:
          'Create your account first. You will finish stall setup after email verification.',
      onBack: widget.onBack,
      formKey: formKey,
      errorMessage: errorMessage,
      loading: loading,
      onSubmit: submit,
      children: [
        const _FormSectionTitle(title: 'Owner information'),

        AppTextField(
          controller: ownerController,
          label: 'Owner name',
          hint: 'Your full name',
          icon: Icons.person_outline_rounded,
          validator: _required('Owner name'),
        ),

        const SizedBox(height: 14),

        AppTextField(
          controller: emailController,
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Email is required.';
            }

            if (!value.contains('@')) {
              return 'Enter a valid email.';
            }

            return null;
          },
        ),

        const SizedBox(height: 14),

        AppTextField(
          controller: phoneController,
          label: 'Phone number',
          hint: '10 digit mobile number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: (value) {
            final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';

            if (digits.length < 10) {
              return 'Enter a valid phone number.';
            }

            return null;
          },
        ),

        const SizedBox(height: 14),

        AppTextField(
          controller: passwordController,
          label: 'Password',
          hint: 'At least 6 characters',
          icon: Icons.lock_outline_rounded,
          obscureText: obscurePassword,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                obscurePassword = !obscurePassword;
              });
            },
            icon: Icon(
              obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
          validator: (value) {
            if (value == null || value.length < 6) {
              return 'Password must be at least 6 characters.';
            }

            return null;
          },
        ),

        const SizedBox(height: 14),

        AppTextField(
          controller: confirmController,
          label: 'Confirm password',
          hint: 'Enter password again',
          icon: Icons.lock_reset_outlined,
          obscureText: obscureConfirm,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                obscureConfirm = !obscureConfirm;
              });
            },
            icon: Icon(
              obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
          validator: (value) {
            if (value != passwordController.text) {
              return 'Passwords do not match.';
            }

            return null;
          },
        ),

        const SizedBox(height: 28),

        const _FormSectionTitle(title: 'Stall information'),

        AppTextField(
          controller: stallNameController,
          label: 'Stall name',
          hint: 'e.g. Sharma Chaat Corner',
          icon: Icons.storefront_outlined,
          validator: _required('Stall name'),
        ),

        const SizedBox(height: 14),

        AppTextField(
          controller: descriptionController,
          label: 'Stall description',
          hint: 'Tell customers what you serve',
          icon: Icons.description_outlined,
          validator: _required('Description'),
        ),

        const SizedBox(height: 14),

        AppTextField(
          controller: categoryController,
          label: 'Main food category',
          hint: 'e.g. Street Food',
          icon: Icons.restaurant_menu_outlined,
          validator: _required('Food category'),
        ),

        const SizedBox(height: 6),

        const Text(
          'You can create a new category later if the available list does not fit your food type.',
          style: TextStyle(fontSize: 12, color: VendrgoColors.textSecondary),
        ),

        const SizedBox(height: 14),

        AppTextField(
          controller: addressController,
          label: 'Address',
          hint: 'Stall location/address',
          icon: Icons.location_on_outlined,
          validator: _required('Address'),
        ),

        const SizedBox(height: 14),

        TextFormField(
  controller: openingHoursController,
  readOnly: true,
  onTap: _selectOpeningHours,
  validator: _required('Opening hours'),
  decoration: const InputDecoration(
    labelText: 'Opening hours',
    hintText: 'Select opening and closing time',
    prefixIcon: Icon(Icons.schedule_outlined),
    suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
  ),
),
      ],
    );
  }
}

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String role;
  final bool hasExistingSession;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.role,
    required this.hasExistingSession,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  StreamSubscription<AuthState>? authSubscription;

  bool sending = false;
  bool verified = false;
  String? message;
  DateTime? lastSent;

  @override
  void initState() {
    super.initState();

    if (widget.hasExistingSession) {
      verified = true;
    }

    authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.initialSession) {
        if (mounted && Supabase.instance.client.auth.currentSession != null) {
          setState(() {
            verified = true;
          });

          _returnToRoot();
        }
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    super.dispose();
  }

  void _returnToRoot() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<void> resend() async {
    if (lastSent != null &&
        DateTime.now().difference(lastSent!).inSeconds < 30) {
      setState(() {
        message = 'Please wait a few seconds before sending again.';
      });
      return;
    }

    setState(() {
      sending = true;
      message = null;
    });

    try {
      await AuthService.instance.resendVerificationEmail(widget.email);

      if (!mounted) return;

      setState(() {
        lastSent = DateTime.now();
        message = 'Verification email sent again.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        message = friendlyAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('Verify email'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VendrgoLogo(size: 68),

              const SizedBox(height: 26),

              const Text(
                'Check your inbox.',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 10),

              Text(
                'We sent a verification link to:',
                style: TextStyle(color: VendrgoColors.textSecondary),
              ),

              const SizedBox(height: 6),

              Text(
                widget.email,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 24),

              SectionCard(
                color: VendrgoColors.peach,
                child: const Text(
                  'Open the email and tap the verification link. '
                  'Vendrgo will continue once your account is verified.',
                  style: TextStyle(height: 1.45),
                ),
              ),

              const SizedBox(height: 18),

              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    message!,
                    style: TextStyle(
                      color: message!.contains('sent')
                          ? VendrgoColors.success
                          : VendrgoColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: sending ? null : resend,
                  child: sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Resend verification email'),
                ),
              ),

              const SizedBox(height: 12),

              if (verified)
                const Center(
                  child: Text(
                    'Email verified. Opening Vendrgo…',
                    style: TextStyle(
                      color: VendrgoColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  final VoidCallback onBack;

  const ForgotPasswordScreen({super.key, required this.onBack});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();

  bool sending = false;
  String? message;
  bool success = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> sendReset() async {
    final email = emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        success = false;
        message = 'Enter a valid email address.';
      });
      return;
    }

    setState(() {
      sending = true;
      message = null;
    });

    try {
      await AuthService.instance.sendPasswordReset(email);

      if (!mounted) return;

      setState(() {
        success = true;
        message =
            'If an account exists for this email, a password reset link has been sent.';
      });
    } catch (_) {
      if (!mounted) return;

      // Do not reveal whether an account exists.
      setState(() {
        success = true;
        message =
            'If an account exists for this email, a password reset link has been sent.';
      });
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const Text('Reset password'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          children: [
            const Text(
              'Forgot your password?',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 10),

            const Text(
              'Enter your email and we will send you a password reset link.',
              style: TextStyle(
                fontSize: 15,
                color: VendrgoColors.textSecondary,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 28),

            if (message != null) ...[
              SectionCard(
                color: success ? VendrgoColors.mint : VendrgoColors.peach,
                child: Text(message!, style: const TextStyle(height: 1.4)),
              ),
              const SizedBox(height: 18),
            ],

            AppTextField(
              controller: emailController,
              label: 'Email',
              hint: 'you@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: sending ? null : sendReset,
                child: sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send reset link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const ResetPasswordScreen({super.key, required this.onFinished});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final formKey = GlobalKey<FormState>();

  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool saving = false;
  bool obscure = true;
  bool obscureConfirm = true;
  String? errorMessage;

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
      errorMessage = null;
    });

    try {
      await AuthService.instance.updatePassword(passwordController.text);

      await AuthService.instance.signOut();

      if (!mounted) return;

      widget.onFinished();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = friendlyAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onFinished),
        title: const Text('Create new password'),
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            children: [
              const Text(
                'Create a new password.',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 10),

              const Text(
                'Choose a password you will remember.',
                style: TextStyle(color: VendrgoColors.textSecondary),
              ),

              const SizedBox(height: 26),

              if (errorMessage != null) ...[
                _ErrorBox(message: errorMessage!),
                const SizedBox(height: 16),
              ],

              AppTextField(
                controller: passwordController,
                label: 'New password',
                hint: 'At least 6 characters',
                icon: Icons.lock_outline_rounded,
                obscureText: obscure,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      obscure = !obscure;
                    });
                  },
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              AppTextField(
                controller: confirmController,
                label: 'Confirm new password',
                hint: 'Enter it again',
                icon: Icons.lock_reset_outlined,
                obscureText: obscureConfirm,
                textInputAction: TextInputAction.done,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      obscureConfirm = !obscureConfirm;
                    });
                  },
                  icon: Icon(
                    obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) {
                  if (value != passwordController.text) {
                    return 'Passwords do not match.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Update password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignupFormScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final GlobalKey<FormState> formKey;
  final String? errorMessage;
  final bool loading;
  final Future<void> Function() onSubmit;
  final List<Widget> children;

  const _SignupFormScaffold({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.formKey,
    required this.errorMessage,
    required this.loading,
    required this.onSubmit,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: Text(title),
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                subtitle,
                style: const TextStyle(
                  color: VendrgoColors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              if (errorMessage != null) ...[
                _ErrorBox(message: errorMessage!),
                const SizedBox(height: 16),
              ],

              ...children,

              const SizedBox(height: 26),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : onSubmit,
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, color: VendrgoColors.text),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      height: 1.35,
                      color: VendrgoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ),
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  final String title;

  const _FormSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD5CF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: VendrgoColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: VendrgoColors.error, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

String? Function(String?) _required(String label) {
  return (value) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }

    return null;
  };
}
