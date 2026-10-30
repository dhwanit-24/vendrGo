import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

/// Icon + message + optional action, for empty and error states.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.title,
    this.icon = Icons.search_off_rounded,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VendrgoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: VendrgoColors.peach,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: VendrgoColors.primaryDark),
            ),
            const SizedBox(height: VendrgoSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: VendrgoText.heading,
            ),
            if (message != null) ...[
              const SizedBox(height: VendrgoSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: VendrgoText.bodySecondary,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: VendrgoSpacing.lg),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 44),
                ),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Heading row with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: VendrgoText.heading)),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? VendrgoColors.error : VendrgoColors.text,
      ),
    );
}
