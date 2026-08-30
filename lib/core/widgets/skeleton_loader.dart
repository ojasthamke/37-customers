import 'package:flutter/material.dart';

class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double? height;
  final ShapeBorder shape;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8.0)),
    ),
  });

  const SkeletonLoader.rectangle({
    super.key,
    this.width,
    this.height,
    double borderRadius = 8.0,
  }) : shape = const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        );

  const SkeletonLoader.circle({
    super.key,
    double radius = 24.0,
  })  : width = radius * 2,
        height = radius * 2,
        shape = const CircleBorder();

  const SkeletonLoader.text({
    super.key,
    this.width = double.infinity,
    this.height = 16.0,
  }) : shape = const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4.0)),
        );

  /// A pre-constructed skeleton list tile representation
  static Widget listTile({double avatarRadius = 24.0}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        children: [
          SkeletonLoader.circle(radius: avatarRadius),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader.text(height: 16, width: 140),
                SizedBox(height: 8),
                SkeletonLoader.text(height: 12, width: double.infinity),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A pre-constructed skeleton grid product card representation
  static Widget productCard() {
    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: SkeletonLoader.rectangle(borderRadius: 12),
            ),
            SizedBox(height: 12),
            SkeletonLoader.text(height: 16, width: 120),
            SizedBox(height: 8),
            SkeletonLoader.text(height: 12, width: 60),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonLoader.text(height: 18, width: 50),
                SkeletonLoader.circle(radius: 14),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Choose base and highlight colors depending on theme brightness
    final baseColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.4);
    final highlightColor = isDark ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.8);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            shape: widget.shape,
            gradient: LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
