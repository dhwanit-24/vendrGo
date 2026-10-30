import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import 'network_image_with_fallback.dart';
import 'status_badge.dart';

/// Zomato-style stall tile: large image, name, category and distance.
class StallCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String? categoryName;
  final String? distanceLabel;
  final String? hours;
  final bool isOpen;
  final bool? isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;
  final Object? heroTag;

  const StallCard({
    super.key,
    required this.name,
    required this.isOpen,
    this.imageUrl,
    this.categoryName,
    this.distanceLabel,
    this.hours,
    this.isFavorite,
    this.onTap,
    this.onToggleFavorite,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = NetworkImageWithFallback(
      url: imageUrl,
      height: 160,
      width: double.infinity,
    );
    if (heroTag != null) image = Hero(tag: heroTag!, child: image);

    final meta = [
      if (categoryName != null && categoryName!.isNotEmpty) categoryName!,
      if (distanceLabel != null && distanceLabel!.isNotEmpty) distanceLabel!,
    ].join(' · ');

    const topRadius = BorderRadius.vertical(
      top: Radius.circular(VendrgoRadius.lg),
    );

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(borderRadius: topRadius, child: image),
                  if (!isOpen)
                    const Positioned.fill(
                      child: ClipRRect(
                        borderRadius: topRadius,
                        child: ColoredBox(color: Color(0x66FFFFFF)),
                      ),
                    ),
                  if (isFavorite != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onToggleFavorite,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              isFavorite!
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 20,
                              color: isFavorite!
                                  ? VendrgoColors.offer
                                  : VendrgoColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: StatusBadge.openClosed(isOpen: isOpen),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VendrgoText.heading,
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VendrgoText.bodySecondary,
                      ),
                    ],
                    if (hours != null && hours!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: VendrgoColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hours!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VendrgoText.caption,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton version of [StallCard] for loading states.
class StallCardSkeleton extends StatelessWidget {
  const StallCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VendrgoColors.surface,
        borderRadius: VendrgoRadius.lgAll,
        boxShadow: VendrgoShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(height: 160, width: double.infinity),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  height: 16,
                  width: 160,
                  borderRadius: VendrgoRadius.smAll,
                ),
                const SizedBox(height: 8),
                ShimmerBox(
                  height: 12,
                  width: 100,
                  borderRadius: VendrgoRadius.smAll,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
