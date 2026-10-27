import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class VendrgoLogo extends StatelessWidget {
  final double size;

  const VendrgoLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: VendrgoColors.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        Icons.storefront_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final Widget child;
  final Color color;

  const SectionCard({
    super.key,
    required this.child,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VendrgoColors.border),
      ),
      child: child,
    );
  }
}

String friendlyAuthError(Object error) {
  final message = error.toString().toLowerCase();

  if (message.contains('invalid login credentials')) {
    return 'Email or password is incorrect.';
  }

  if (message.contains('email not confirmed')) {
    return 'Please verify your email before signing in.';
  }

  if (message.contains('user already registered')) {
    return 'An account with this email already exists.';
  }

  if (message.contains('password should be at least')) {
    return 'Please use a stronger password.';
  }

  if (message.contains('rate limit')) {
    return 'Too many attempts. Please try again later.';
  }

  if (message.contains('network')) {
    return 'Network error. Check your internet connection.';
  }

  return 'Something went wrong. Please try again.';
}
