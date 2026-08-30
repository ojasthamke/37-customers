import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable Ambient Background Widget providing the signature 'Your Harvest'
/// soft green, sand cream, and peach gradient with colorful glassmorphism blobs and backdrop blur.
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Ambient background gradient (Original 'Your Harvest' Soft Green & Warm Sand Cream)
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8F5E9), // Soft green
                  Color(0xFFF5F2EB), // Warm sand cream
                  Color(0xFFFFF3E0), // Peach tint
                ],
              ),
            ),
          ),
        ),

        // Colorful background blobs with hardware-accelerated smooth radial gradients
        Positioned(
          top: 40,
          left: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFA5D6A7).withValues(alpha: 0.18),
                  const Color(0xFFA5D6A7).withValues(alpha: 0.05),
                  const Color(0xFFA5D6A7).withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: 350,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFCC80).withValues(alpha: 0.16),
                  const Color(0xFFFFCC80).withValues(alpha: 0.04),
                  const Color(0xFFFFCC80).withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 50,
          left: -50,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFCE93D8).withValues(alpha: 0.12),
                  const Color(0xFFCE93D8).withValues(alpha: 0.03),
                  const Color(0xFFCE93D8).withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // BackdropFilter to blur the blobs so they are smooth and their round shapes are not visible
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: const SizedBox.shrink(),
          ),
        ),

        // Main Page Content Layer
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}
