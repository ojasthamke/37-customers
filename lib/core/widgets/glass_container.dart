import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double borderOpacity;
  final Color color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool isStockOut;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.blur = 35,
    this.borderOpacity = 0.25,
    this.color = Colors.white,
    this.padding,
    this.margin,
    this.onTap,
    this.isStockOut = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = BorderRadius.circular(borderRadius);

    final baseColor = isStockOut
        ? (isDark ? const Color(0xFF2C1515) : const Color(0xFFFFF5F5))
        : (isDark ? const Color(0xFF1E293B) : color);

    final borderColor = isStockOut
        ? const Color(0xFFEF4444)
        : (isDark ? Colors.white24 : const Color(0xFFE2E8F0));

    final borderWidth = isStockOut ? 1.8 : 1.2;

    final shadows = isStockOut
        ? [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.35 : 0.22),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFFFEF2F2).withValues(alpha: isDark ? 0.15 : 0.8),
              blurRadius: 8,
              offset: Offset.zero,
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ];

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        color: baseColor.withValues(alpha: isDark ? 0.90 : 0.95),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: shadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}

