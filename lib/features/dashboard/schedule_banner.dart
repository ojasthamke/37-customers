import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/schedule_helper.dart';
import '../auth/auth_provider.dart';
import '../cart/cart_provider.dart';

class ScheduleBanner extends ConsumerStatefulWidget {
  final VoidCallback? onStartPreOrderTap;

  const ScheduleBanner({super.key, this.onStartPreOrderTap});

  @override
  ConsumerState<ScheduleBanner> createState() => _ScheduleBannerState();
}

class _ScheduleBannerState extends ConsumerState<ScheduleBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final customer = ref.watch(authProvider).customer;
    if (customer == null) return const SizedBox.shrink();

    List<dynamic>? orderDays;
    final rawSchedule = customer['delivery_schedule'];
    if (rawSchedule is List) {
      orderDays = rawSchedule;
    } else if (rawSchedule is String && rawSchedule.trim().isNotEmpty) {
      try {
        final decoded = json.decode(rawSchedule);
        if (decoded is List) orderDays = decoded;
      } catch (_) {
        orderDays = rawSchedule.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }
    final cutoffTimeStr = customer['cutoff_time']?.toString();
    
    final settingsAsync = ref.watch(appSettingsProvider);
    final bool isClosed = isStoreClosed(settingsAsync.valueOrNull);

    if (isClosed) {
      return _buildStoreClosedBanner();
    }

    final details = AreaScheduleHelper.calculateDetails(
      orderDays, 
      cutoffTimeStr: cutoffTimeStr,
      isStoreClosed: isClosed,
    );

    switch (details.state) {
      case ScheduleState.openToday:
        return _buildOpenBanner(details);
      case ScheduleState.closedToday:
        return _buildClosedBanner(details);
      case ScheduleState.noSchedule:
        return _buildNoScheduleBanner();
    }
  }

  Widget _buildOpenBanner(ScheduleDetails details) {
    final timeStr = AreaScheduleHelper.formatDuration(details.remainingTime ?? Duration.zero);
    final deliveryStr = AreaScheduleHelper.formatDayAndDate(details.deliveryDate ?? DateTime.now());
    
    final cutoffFormatted = details.cutoffTime != null
        ? DateFormat('h:mm a').format(details.cutoffTime!).toUpperCase()
        : '11:59 PM';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B3624), // Rich Dark Forest Emerald
            Color(0xFF0F2618),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B3624).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF4CAF50), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ORDERING OPEN TILL $cutoffFormatted',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF81C784),
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, color: Color(0xFFD4AF37), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Order will be delivered tomorrow',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              deliveryStr,
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedBanner(ScheduleDetails details) {
    final nextDate = details.nextOrderDate ?? DateTime.now();
    final nextOrderDay = AreaScheduleHelper.weekdays[nextDate.weekday - 1];
    final deliveryStr = AreaScheduleHelper.formatDayAndDate(details.nextDeliveryDate ?? DateTime.now());

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B3624), // Rich Dark Forest Emerald
            Color(0xFF0D2517),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B3624).withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Stack(
        children: [
          // Gold ambient background glow
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 13, color: Color(0xFFE5C158)),
                          const SizedBox(width: 4),
                          Text(
                            'PRE-ORDER OPEN',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFE5C158),
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Next Delivery Slot',
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'YOU CAN ORDER ON $nextOrderDay'.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFE5C158),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, color: Colors.white70, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'Estimated Delivery: ',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      deliveryStr,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Prominent Gold Pre-Order Action Button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onStartPreOrderTap?.call();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'START PRE-ORDER',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1B3624),
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, color: Color(0xFF1B3624), size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoScheduleBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ORDERING SCHEDULE NOT AVAILABLE',
                  style: GoogleFonts.inter(
                    color: Colors.red[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No order schedule set for your Area yet. Please check back later.',
                  style: GoogleFonts.inter(
                    color: Colors.red[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreClosedBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E1C1C), // Deep Crimson Wine
            Color(0xFF1A0A0A),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E1C1C).withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Stack(
        children: [
          // Red ambient background glow
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEF4444), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 13, color: Color(0xFFFCA5A5)),
                          const SizedBox(width: 4),
                          Text(
                            'STORE CLOSED',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFCA5A5),
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'WE WILL BE BACK IN SOME TIME',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.white60, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'We are currently not accepting new orders. Please check back later!',
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
