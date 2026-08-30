import 'package:flutter/material.dart';

class AnimatedSlashedText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double strokeWidth;
  final Color slashColor;
  final Duration duration;

  const AnimatedSlashedText({
    super.key,
    required this.text,
    required this.style,
    this.strokeWidth = 1.3,
    this.slashColor = const Color(0xFF878787), // Flipkart Grey
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  State<AnimatedSlashedText> createState() => _AnimatedSlashedTextState();
}

class _AnimatedSlashedTextState extends State<AnimatedSlashedText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _SlashPainter(
        progress: _animation,
        strokeWidth: widget.strokeWidth,
        color: widget.slashColor,
      ),
      child: Text(
        widget.text,
        style: widget.style.copyWith(
          decoration: TextDecoration.none, // Custom paint handles line
        ),
      ),
    );
  }
}

class _SlashPainter extends CustomPainter {
  final Animation<double> progress;
  final double strokeWidth;
  final Color color;

  _SlashPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress.value == 0.0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw a horizontal slashing line (like Flipkart)
    final y = size.height * 0.52;
    const startX = -1.0;
    final totalWidth = size.width + 2.0;
    final currentEndX = startX + totalWidth * progress.value;

    canvas.drawLine(Offset(startX, y), Offset(currentEndX, y), paint);
  }

  @override
  bool shouldRepaint(covariant _SlashPainter oldDelegate) {
    return oldDelegate.progress.value != progress.value ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color;
  }
}
