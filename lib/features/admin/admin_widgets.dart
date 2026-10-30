import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

/// Lays cards out two per row. Every row sizes itself to its tallest card, so
/// nothing overflows whatever the screen width or text scale.
class KpiGrid extends StatelessWidget {
  final List<Widget> children;

  const KpiGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < children.length ? 12 : 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(children: rows);
  }
}

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final String? footnote;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    this.footnote,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: VendrgoRadius.smAll,
                  ),
                  child: Icon(icon, size: 20, color: VendrgoColors.text),
                ),
                const SizedBox(height: 12),
                Text(value, style: VendrgoText.display),
                const SizedBox(height: 2),
                Text(label, style: VendrgoText.label),
                if (footnote != null) ...[
                  const SizedBox(height: 2),
                  Text(footnote!, style: VendrgoText.caption),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White card with a title, used to frame every chart and table.
class ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const ChartCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VendrgoColors.surface,
        borderRadius: VendrgoRadius.lgAll,
        boxShadow: VendrgoShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: VendrgoText.heading),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: VendrgoText.caption),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class ChartItem {
  final String label;
  final int value;
  final Color color;

  const ChartItem(this.label, this.value, this.color);
}

/// Horizontal bars with a label and a value on top of each bar.
class HBarChart extends StatelessWidget {
  final List<ChartItem> items;

  const HBarChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<int>(0, (m, item) => math.max(m, item.value));

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VendrgoText.label,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${items[i].value}', style: VendrgoText.label),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: VendrgoRadius.pillAll,
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: maxValue == 0 ? 0 : items[i].value / maxValue,
                    backgroundColor: VendrgoColors.surfaceMuted,
                    valueColor: AlwaysStoppedAnimation(items[i].color),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Vertical bars, one per label (e.g. the last 7 days).
class ColumnChart extends StatelessWidget {
  final List<int> values;
  final List<String> labels;
  final Color color;
  final double maxBarHeight;

  const ColumnChart({
    super.key,
    required this.values,
    required this.labels,
    this.color = VendrgoColors.primary,
    this.maxBarHeight = 96,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(0, (m, v) => math.max(m, v));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${values[i]}', style: VendrgoText.caption),
                const SizedBox(height: 4),
                Container(
                  height: maxValue == 0
                      ? 4
                      : math.max(4, maxBarHeight * values[i] / maxValue),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: values[i] == 0 ? VendrgoColors.surfaceMuted : color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: VendrgoText.caption,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Ring chart with the total in the middle and a legend beside it.
class DonutChart extends StatelessWidget {
  final List<ChartItem> segments;
  final String centerLabel;

  const DonutChart({
    super.key,
    required this.segments,
    required this.centerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (sum, item) => sum + item.value);

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(130),
                painter: _DonutPainter(segments),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$total', style: VendrgoText.title),
                  Text(centerLabel, style: VendrgoText.caption),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final segment in segments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: segment.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          segment.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VendrgoText.bodySecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${segment.value}', style: VendrgoText.label),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<ChartItem> segments;

  _DonutPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final total = segments.fold<int>(0, (sum, item) => sum + item.value);

    if (total == 0) {
      paint.color = VendrgoColors.surfaceMuted;
      canvas.drawArc(rect, 0, math.pi * 2, false, paint);
      return;
    }

    var start = -math.pi / 2;

    for (final segment in segments) {
      if (segment.value == 0) continue;

      final sweep = math.pi * 2 * segment.value / total;
      paint.color = segment.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

/// Row-style card used by every admin list.
class AdminListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? badge;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AdminListCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
    this.leading,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VendrgoText.heading,
                      ),
                      const SizedBox(height: 3),
                      Text(subtitle, style: VendrgoText.bodySecondary),
                      if (badge != null) ...[const SizedBox(height: 8), badge!],
                    ],
                  ),
                ),
                trailing ??
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

/// Label/value line used in the detail sheets.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: VendrgoColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: VendrgoText.caption),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: VendrgoText.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
