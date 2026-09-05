import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../cart/cart_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/home_screen.dart';
import '../order/order_details_screen.dart';
import '../auth/auth_provider.dart';
import '../../core/services/sound_service.dart';

// ── SPARKLE PARTICLE MODEL ──────────────────────────────────────────────────
class SparkleParticle {
  final double angle;
  final double speed;
  final double size;
  final double rotationSpeed;
  final Color color;
  final int type; // 0 = 4-point starburst, 1 = diamond, 2 = dot

  const SparkleParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.rotationSpeed,
    required this.color,
    required this.type,
  });
}

// ── TICKET NOTCH CLIPPER (Semicircular cutouts on left/right edges) ──────────
class TicketReceiptClipper extends CustomClipper<Path> {
  final double notchRadius;
  final double notchYFraction;
  final double cornerRadius;

  const TicketReceiptClipper({
    this.notchRadius = 12.0,
    this.notchYFraction = 0.28,
    this.cornerRadius = 24.0,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final notchY = size.height * notchYFraction;

    path.moveTo(cornerRadius, 0);
    path.lineTo(size.width - cornerRadius, 0);
    path.arcToPoint(
      Offset(size.width, cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(size.width, notchY - notchRadius);
    path.arcToPoint(
      Offset(size.width, notchY + notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(size.width, size.height - cornerRadius);
    path.arcToPoint(
      Offset(size.width - cornerRadius, size.height),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(cornerRadius, size.height);
    path.arcToPoint(
      Offset(0, size.height - cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(0, notchY + notchRadius);
    path.arcToPoint(
      Offset(0, notchY - notchRadius),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(0, cornerRadius);
    path.arcToPoint(
      Offset(cornerRadius, 0),
      radius: Radius.circular(cornerRadius),
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant TicketReceiptClipper oldClipper) =>
      oldClipper.notchYFraction != notchYFraction ||
      oldClipper.notchRadius != notchRadius ||
      oldClipper.cornerRadius != cornerRadius;
}

// ── DOTTED PERFORATION LINE ──────────────────────────────────────────────────
class DottedPerforationLine extends StatelessWidget {
  final Color color;
  final double height;

  const DottedPerforationLine({
    super.key,
    this.color = const Color(0xFFCBD5E1),
    this.height = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.constrainWidth();
        const double dashWidth = 6.0;
        const double dashSpace = 4.0;
        final int count = (width / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(math.max(1, count), (_) {
            return SizedBox(
              width: dashWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── FAST ANIMATED VECTOR CHECKMARK PAINTER (ZERO ALLOCATIONS) ────────────────
class AnimatedCheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  const AnimatedCheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final p1 = Offset(size.width * 0.26, size.height * 0.50);
    final p2 = Offset(size.width * 0.44, size.height * 0.70);
    final p3 = Offset(size.width * 0.76, size.height * 0.32);

    const double t1 = 0.35;
    if (progress <= t1) {
      final double f = progress / t1;
      final current = Offset(
        p1.dx + (p2.dx - p1.dx) * f,
        p1.dy + (p2.dy - p1.dy) * f,
      );
      canvas.drawLine(p1, current, paint);
    } else {
      canvas.drawLine(p1, p2, paint);
      final double f = (progress - t1) / (1.0 - t1);
      final current = Offset(
        p2.dx + (p3.dx - p2.dx) * f,
        p2.dy + (p3.dy - p2.dy) * f,
      );
      canvas.drawLine(p2, current, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AnimatedCheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// ── CELEBRATION SPARKLES PAINTER ─────────────────────────────────────────────
class SparklesPainter extends CustomPainter {
  final double progress;
  final List<SparkleParticle> particles;
  final Offset center;

  SparklesPainter({
    required this.progress,
    required this.particles,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final double distance = 85.0 * progress * p.speed;
      final double x = center.dx + math.cos(p.angle) * distance;
      final double y = center.dy + math.sin(p.angle) * distance;
      final double currentSize = p.size * (1.0 - progress);
      if (currentSize <= 0.0) continue;

      paint.color = p.color.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.angle + progress * p.rotationSpeed);

      if (p.type == 0) {
        final starPath = Path();
        starPath.moveTo(0, -currentSize);
        starPath.lineTo(currentSize * 0.28, -currentSize * 0.28);
        starPath.lineTo(currentSize, 0);
        starPath.lineTo(currentSize * 0.28, currentSize * 0.28);
        starPath.lineTo(0, currentSize);
        starPath.lineTo(-currentSize * 0.28, currentSize * 0.28);
        starPath.lineTo(-currentSize, 0);
        starPath.lineTo(-currentSize * 0.28, -currentSize * 0.28);
        starPath.close();
        canvas.drawPath(starPath, paint);
      } else if (p.type == 1) {
        final dPath = Path();
        dPath.moveTo(0, -currentSize * 0.8);
        dPath.lineTo(currentSize * 0.6, 0);
        dPath.lineTo(0, currentSize * 0.8);
        dPath.lineTo(-currentSize * 0.6, 0);
        dPath.close();
        canvas.drawPath(dPath, paint);
      } else {
        canvas.drawCircle(Offset.zero, currentSize * 0.5, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant SparklesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ── SLIT CLIPPER ─────────────────────────────────────────────────────────────
class _TopSlitClipper extends CustomClipper<Rect> {
  final double topThreshold;
  const _TopSlitClipper({required this.topThreshold});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(-1000, topThreshold, size.width + 1000, size.height + 1000);
  }

  @override
  bool shouldReclip(covariant _TopSlitClipper oldClipper) =>
      oldClipper.topThreshold != topThreshold;
}

// ── METALLIC DISPENSER BAR + REVEAL ──────────────────────────────────────────
class MetallicPrinterDispenserWidget extends StatelessWidget {
  final Widget child;
  final double revealProgress;
  final double settleProgress;

  const MetallicPrinterDispenserWidget({
    super.key,
    required this.child,
    required this.revealProgress,
    required this.settleProgress,
  });

  @override
  Widget build(BuildContext context) {
    final double dispenserWidth = math.min(MediaQuery.of(context).size.width * 0.88, 380.0);
    const double dispenserHeight = 28.0;

    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        // Clipped receipt emerging from slit
        ClipRect(
          clipper: const _TopSlitClipper(topThreshold: dispenserHeight * 0.5),
          child: Padding(
            padding: const EdgeInsets.only(top: dispenserHeight * 0.5),
            child: Transform.translate(
              offset: Offset(0.0, -480.0 * (1.0 - revealProgress)),
              child: Transform.scale(
                scale: 0.98 + (0.02 * settleProgress),
                alignment: Alignment.topCenter,
                child: RepaintBoundary(child: child),
              ),
            ),
          ),
        ),
        // Golden dispenser bar
        Positioned(
          top: 0,
          child: RepaintBoundary(
            child: Container(
              width: dispenserWidth,
              height: dispenserHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF9E6),
                    Color(0xFFE8CA76),
                    Color(0xFFD4AF37),
                    Color(0xFFB38318),
                    Color(0xFF7A550B),
                  ],
                  stops: [0.0, 0.22, 0.55, 0.85, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7A550B).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Container(
                width: dispenserWidth - 32,
                height: 5.0,
                decoration: BoxDecoration(
                  color: const Color(0xFF231709),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── ORDER CONFIRMATION SCREEN ────────────────────────────────────────────────
class OrderConfirmationScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final List<CartItem> cartItems;
  final double subtotal;
  final double deliveryCharge;
  final double grandTotal;

  const OrderConfirmationScreen({
    super.key,
    required this.order,
    required this.cartItems,
    required this.subtotal,
    required this.deliveryCharge,
    required this.grandTotal,
  });

  @override
  ConsumerState<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends ConsumerState<OrderConfirmationScreen>
    with SingleTickerProviderStateMixin {
  bool _hasTriggeredConfirmationFeedback = false;

  void _triggerConfirmationFeedback() {
    if (_hasTriggeredConfirmationFeedback) return;
    _hasTriggeredConfirmationFeedback = true;

    // 1. Short, soft, premium tactile pulse (crisp and satisfying)
    try {
      HapticFeedback.lightImpact();
    } catch (_) {
      // Gracefully do nothing if haptic hardware is unavailable
    }

    // 2. Play synchronized success chime (universfield-success-notification)
    try {
      SoundService.playSuccessSound();
    } catch (_) {}
  }

  late final AnimationController _controller;
  late final Animation<double> _revealProgress;
  late final Animation<double> _settleProgress;
  late final Animation<double> _badgeScale;
  late final Animation<double> _checkmarkDraw;
  late final Animation<double> _sparkles;
  late final Animation<double> _contentFade;
  late final Animation<double> _actionButtonsFade;
  late final List<SparkleParticle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _revealProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.65, curve: Curves.easeOutCubic),
    );
    _settleProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOutBack),
    );
    _badgeScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.75, curve: Curves.easeOutBack),
    );
    _checkmarkDraw = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.60, 0.90, curve: Curves.easeOutCubic),
    );
    _sparkles = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.60, 1.00, curve: Curves.easeOutQuart),
    );
    _contentFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.20, 0.65, curve: Curves.easeOut),
    );
    _actionButtonsFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.65, 1.00, curve: Curves.easeOutCubic),
    );

    final random = math.Random(42);
    _particles = List.generate(24, (index) {
      final angle = (index / 24) * 2 * math.pi + (random.nextDouble() * 0.2);
      final speed = 0.6 + random.nextDouble() * 0.8;
      final size = 6.0 + random.nextDouble() * 8.0;
      final rotSpeed = (random.nextBool() ? 1.0 : -1.0) * (3.0 + random.nextDouble() * 4.0);
      final color = index % 3 == 0
          ? const Color(0xFFF59E0B)
          : index % 3 == 1
              ? const Color(0xFF10B981)
              : const Color(0xFF38BDF8);
      return SparkleParticle(
        angle: angle, speed: speed, size: size,
        rotationSpeed: rotSpeed, color: color, type: index % 3,
      );
    });

    _controller.addListener(() {
      final value = _controller.value;
      if (!mounted) return;

      // Synchronized single subtle haptic pulse + success chime when checkmark appears (at 0.65)
      if (value >= 0.65 && !_hasTriggeredConfirmationFeedback) {
        _triggerConfirmationFeedback();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNow() {
    try {
      final now = DateTime.now();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${now.day} ${months[now.month - 1]} ${now.year} \u2022 ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return 'Today';
    }
  }

  String _formatDeliveryDate(String raw) {
    try {
      final parsed = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return "${parsed.day} ${months[parsed.month - 1]} ${parsed.year}";
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOffline = widget.order['sync_status'] == 'pending' ||
        widget.order['is_offline'] == true ||
        (widget.order['order_number'] == null && widget.order['offline_order_no'] != null);
    final orderNo = widget.order['order_number'] ?? widget.order['offline_order_no'] ?? widget.order['id'] ?? 'OK-0001';
    final String rawCustName = (widget.order['customer_name'] ??
            widget.order['customers']?['name'] ??
            widget.order['customer']?['name'] ??
            '')
        .toString();

    String customerName = rawCustName;
    if (customerName.isEmpty || customerName == 'Valued Customer' || customerName == 'Customer') {
      final currentCust = ref.watch(authProvider).customer;
      customerName = currentCust?['name'] ?? currentCust?['phone'] ?? 'Valued Customer';
    }
    final deliveryDateStr = widget.order['delivery_date'] ?? '';
    final formattedDateTime = _formatNow();
    final formattedDeliveryDate = _formatDeliveryDate(deliveryDateStr);

    final ticketBody = _buildTicket(orderNo, customerName, formattedDateTime, formattedDeliveryDate, isOffline);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(activeTabProvider.notifier).state = 0;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5FA),
        body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            const Positioned.fill(
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF8FAFC), Color(0xFFEEF2F9), Color(0xFFE2E8F0)],
                    ),
                  ),
                ),
              ),
            ),

            // Top header
            Positioned(
              top: 16, left: 20, right: 20,
              child: Column(
                children: [
                  const Text('Payment Confirmation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(isOffline ? 'Order Queued Offline' : 'Order Received',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isOffline ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),

            // Main ticket area with smooth Metallic Dispenser emergence animation
            Positioned.fill(
              top: 75, bottom: 84,
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return MetallicPrinterDispenserWidget(
                        revealProgress: _revealProgress.value,
                        settleProgress: _settleProgress.value,
                        child: ticketBody,
                      );
                    },
                  ),
                ),
              ),
            ),

            // Bottom action buttons with smooth fade-in (Always interactive & clickable)
            Positioned(
              bottom: 20, left: 20, right: 20,
              child: AnimatedBuilder(
                animation: _actionButtonsFade,
                builder: (context, child) {
                  return Opacity(
                    opacity: _actionButtonsFade.value.clamp(0.0, 1.0),
                    child: _buildActionButtons(orderNo, customerName),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildTicket(String orderNo, String customerName, String formattedDateTime, String formattedDeliveryDate, bool isOffline) {
    return PhysicalShape(
      clipper: const TicketReceiptClipper(notchRadius: 12.0, notchYFraction: 0.28, cornerRadius: 24.0),
      color: Colors.white,
      elevation: 8.0,
      shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.14),
      child: Container(
        width: math.min(MediaQuery.of(context).size.width * 0.86, 350.0),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand Logo header on receipt
            Center(
              child: Image.asset(
                'assets/orderkart_logo.png',
                height: 58,
                width: 186,
                cacheHeight: 120,
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 12),

            // Success badge + sparkles (Isolated AnimatedBuilder)
            Center(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _badgeScale,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 140, height: 140,
                          child: CustomPaint(
                            painter: SparklesPainter(progress: _sparkles.value, particles: _particles, center: const Offset(70, 70)),
                          ),
                        ),
                        Transform.scale(
                          scale: _badgeScale.value,
                          child: Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 6)),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: CustomPaint(
                              size: const Size(26, 26),
                              painter: AnimatedCheckmarkPainter(progress: _checkmarkDraw.value, color: const Color(0xFFD97706)),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Thank you text
            FadeTransition(
              opacity: _contentFade,
              child: Column(
                children: [
                  Text(isOffline ? 'Order Queued Offline!' : 'Thank you!', textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(
                    isOffline
                        ? 'Your order is saved locally and will\nsync automatically once connected'
                        : 'Your order has been placed\nsuccessfully',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF64748B), height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Perforation line
            const DottedPerforationLine(color: Color(0xFFCBD5E1)),
            const SizedBox(height: 18),

            // Metadata grid
            FadeTransition(
              opacity: _contentFade,
              child: Column(
                children: [
                  // TICKET ID | AMOUNT
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _metaColumn('TICKET ID', orderNo, CrossAxisAlignment.start)),
                      _metaColumn('AMOUNT', '\u20B9${((widget.order['total_amount'] as num?)?.toDouble() ?? widget.grandTotal).toStringAsFixed(2)}', CrossAxisAlignment.end, isBold: true),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // DATE & TIME | STATUS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _metaColumn('DATE & TIME', formattedDateTime, CrossAxisAlignment.start)),
                      _statusColumn(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Customer pill
                  _customerPill(customerName, formattedDeliveryDate),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaColumn(String label, String value, CrossAxisAlignment align, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.8)),
        const SizedBox(height: 3),
        Text(value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _statusColumn() {
    final bool isOffline = widget.order['sync_status'] == 'pending' ||
        widget.order['is_offline'] == true ||
        (widget.order['order_number'] == null && widget.order['offline_order_no'] != null);
    final status = widget.order['status']?.toString().toLowerCase();
    final orderType = widget.order['order_type']?.toString().toLowerCase();
    String statusText;
    Color statusColor;

    if (isOffline) {
      statusText = 'Queued Offline';
      statusColor = const Color(0xFFD97706);
    } else if (status == 'pending') {
      if (orderType == 'pre-order') {
        statusText = 'Pre-Ordered';
        statusColor = Colors.orange[800]!;
      } else {
        statusText = 'Pending';
        statusColor = Colors.amber[800]!;
      }
    } else {
      statusText = widget.order['status'] ?? 'Confirmed';
      statusColor = const Color(0xFF10B981);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.8)),
        const SizedBox(height: 3),
        Text(statusText, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: statusColor)),
      ],
    );
  }

  Widget _customerPill(String customerName, String formattedDeliveryDate) {
    String displayName = customerName;
    if (customerName.isEmpty || customerName == 'Valued Customer' || customerName == 'Customer') {
      displayName = Supabase.instance.client.auth.currentUser?.userMetadata?['name']?.toString() ?? 'Valued Member';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFEF2F2)),
            alignment: Alignment.center,
            child: const Icon(Icons.person_rounded, size: 18, color: Color(0xFFEF4444)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Valued Customer',
                  style: GoogleFonts.inter(fontSize: 11.0, fontWeight: FontWeight.w700, color: const Color(0xFF64748B), letterSpacing: 0.2)),
                const SizedBox(height: 2),
                Text(displayName,
                  style: GoogleFonts.outfit(fontSize: 14.0, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                if (formattedDeliveryDate.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Delivery: $formattedDeliveryDate',
                    style: GoogleFonts.inter(fontSize: 11.0, fontWeight: FontWeight.w600, color: const Color(0xFF059669))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String orderNo, String customerName) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              minimumSize: const Size(0, 52),
            ),
            onPressed: () => _showSupportModal(context, orderNo, customerName),
            icon: const Icon(Icons.headset_mic_rounded, size: 18, color: Color(0xFF0F172A)),
            label: const Text('Help', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Consumer(
            builder: (context, ref, child) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.35),
                  minimumSize: const Size(0, 52),
                ),
                onPressed: () {
                  ref.read(activeTabProvider.notifier).state = 2;
                  final String orderId = (widget.order['id'] ?? '').toString();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailsScreen(orderId: orderId),
                    ),
                  );
                },
                child: const Text('View Order Details →', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSupportModal(BuildContext context, String orderNo, String customerName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Customer Support',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('How can we help you today? Connect with our store directly.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final msg = 'Hello Orderkart Support! I am $customerName, and I need assistance with my order (#$orderNo).';
                    final encodedMsg = Uri.encodeComponent(msg);
                    final whatsappUri = Uri.parse('whatsapp://send?phone=919021107009&text=$encodedMsg');
                    final webUri = Uri.parse('https://wa.me/919021107009?text=$encodedMsg');
                    try {
                      bool launched = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
                      if (!launched) await launchUrl(webUri, mode: LaunchMode.externalApplication);
                    } catch (_) {
                      try { await launchUrl(webUri, mode: LaunchMode.externalApplication); } catch (_) {}
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                  label: const Text('Chat on WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final url = Uri.parse('tel:+919021107009');
                    if (await canLaunchUrl(url)) await launchUrl(url);
                  },
                  icon: const Icon(Icons.phone_outlined, color: Colors.white),
                  label: const Text('Call Us Directly', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
