import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

enum BadgeTone { success, error, warning, neutral }

/// Small pill used for open/closed and approval states.
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
  });

  factory StatusBadge.openClosed({Key? key, required bool isOpen}) {
    return StatusBadge(
      key: key,
      label: isOpen ? 'Open' : 'Closed',
      tone: isOpen ? BadgeTone.success : BadgeTone.neutral,
    );
  }

  factory StatusBadge.approval({Key? key, required String status}) {
    switch (status) {
      case 'approved':
        return StatusBadge(
          key: key,
          label: 'Approved',
          tone: BadgeTone.success,
          icon: Icons.check_circle_rounded,
        );
      case 'rejected':
        return StatusBadge(
          key: key,
          label: 'Rejected',
          tone: BadgeTone.error,
          icon: Icons.cancel_rounded,
        );
      case 'suspended':
        return StatusBadge(
          key: key,
          label: 'Suspended',
          tone: BadgeTone.error,
          icon: Icons.block_rounded,
        );
      default:
        return StatusBadge(
          key: key,
          label: 'Pending',
          tone: BadgeTone.warning,
          icon: Icons.schedule_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      BadgeTone.success => (VendrgoColors.successSoft, VendrgoColors.success),
      BadgeTone.error => (VendrgoColors.errorSoft, VendrgoColors.error),
      BadgeTone.warning => (VendrgoColors.warningSoft, VendrgoColors.warning),
      BadgeTone.neutral => (
        VendrgoColors.surfaceMuted,
        VendrgoColors.textSecondary,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: VendrgoRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
