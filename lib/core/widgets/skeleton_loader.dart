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

  /// A pre-constructed skeleton order card representation
  static Widget orderCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SkeletonLoader.text(height: 16, width: 110),
              SkeletonLoader(
                width: 75,
                height: 24,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonLoader.text(height: 13, width: 160),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonLoader.text(height: 14, width: 70),
              SkeletonLoader.text(height: 18, width: 90),
            ],
          ),

        ],
      ),
    );
  }

  /// Skeleton list representation for My Orders screen
  static Widget ordersList({int count = 4}) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (_, __) => orderCard(),
    );
  }

  /// Skeleton screen for Order Details screen
  static Widget orderDetails() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SkeletonLoader.text(height: 18, width: 140),
                    SkeletonLoader(
                      width: 80,
                      height: 26,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const SkeletonLoader.text(height: 13, width: 180),
                const SizedBox(height: 8),
                const SkeletonLoader.text(height: 13, width: 120),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader.text(height: 16, width: 100),
                const SizedBox(height: 16),
                for (int i = 0; i < 3; i++) ...[
                  Row(
                    children: [
                      SkeletonLoader(
                        width: 48,
                        height: 48,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader.text(height: 14, width: 120),
                            SizedBox(height: 6),
                            SkeletonLoader.text(height: 12, width: 60),
                          ],
                        ),
                      ),
                      const SkeletonLoader.text(height: 14, width: 60),
                    ],
                  ),
                  if (i < 2) const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonLoader.text(height: 14, width: 70),
                    SkeletonLoader.text(height: 14, width: 60),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonLoader.text(height: 14, width: 100),
                    SkeletonLoader.text(height: 14, width: 40),
                  ],
                ),
                Divider(height: 24, color: Color(0xFFF1F5F9)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonLoader.text(height: 18, width: 90),
                    SkeletonLoader.text(height: 20, width: 80),
                  ],
                ),
              ],
            ),
          ),
        ],
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
