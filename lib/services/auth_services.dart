import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  SupabaseClient get client => Supabase.instance.client;

  User? get currentUser => client.auth.currentUser;

  Session? get currentSession => client.auth.currentSession;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUpCustomer({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) {
    return client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: SupabaseConfig.authRedirectUri,
      data: {
        'role': 'customer',
        'full_name': name.trim(),
        'phone': phone.trim(),
      },
    );
  }

  Future<AuthResponse> signUpVendor({
    required String ownerName,
    required String email,
    required String password,
    required String phone,
    required String stallName,
    required String stallDescription,
    required String categoryName,
    required String address,
    required String openingHours,
  }) {
    return client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: SupabaseConfig.authRedirectUri,
      data: {
        'role': 'vendor',
        'full_name': ownerName.trim(),
        'phone': phone.trim(),

        // These fields temporarily live in auth metadata until the
        // vendor verifies the email and completes stall setup.
        'stall_name': stallName.trim(),
        'stall_description': stallDescription.trim(),
        'category_name': categoryName.trim(),
        'stall_address': address.trim(),
        'opening_hours': openingHours.trim(),
      },
    );
  }

  Future<void> resendVerificationEmail(String email) async {
    await client.auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> sendPasswordReset(String email) async {
    await client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: SupabaseConfig.authRedirectUri,
    );
  }

  Future<void> updatePassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = currentUser;

    if (user == null) {
      return null;
    }

    return await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> getCurrentStall() async {
    final user = currentUser;

    if (user == null) {
      return null;
    }

    return await client
        .from('stalls')
        .select()
        .eq('vendor_id', user.id)
        .maybeSingle();
  }
}
