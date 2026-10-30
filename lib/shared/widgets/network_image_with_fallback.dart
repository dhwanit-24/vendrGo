import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Network image with a skeleton while loading and an icon on failure.
class NetworkImageWithFallback extends StatelessWidget {
  final String? url;
  final double? height;
  final double? width;
  final BoxFit fit;
  final IconData fallbackIcon;
  final BorderRadius? borderRadius;

  const NetworkImageWithFallback({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.storefront_rounded,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final address = url;
    final Widget image = (address == null || address.isEmpty)
        ? _fallback()
        : Image.network(
            address,
            height: height,
            width: width,
            fit: fit,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return ShimmerBox(height: height, width: width);
            },
            errorBuilder: (_, _, _) => _fallback(),
          );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  Widget _fallback() {
    return Container(
      height: height,
      width: width,
      color: VendrgoColors.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, size: 40, color: VendrgoColors.textTertiary),
    );
  }
}

/// Pulsing grey placeholder used as a loading skeleton.
class ShimmerBox extends StatefulWidget {
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;

  const ShimmerBox({super.key, this.height, this.width, this.borderRadius});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            color: Color.lerp(
              VendrgoColors.surfaceMuted,
              VendrgoColors.divider,
              _controller.value,
            ),
          ),
        );
      },
    );
  }
}
