import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../auth/auth_provider.dart';
import '../cart/cart_provider.dart';
import '../order/order_provider.dart';
import '../../core/widgets/quantity_selector.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/schedule_helper.dart';
import 'order_confirmation_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final String _idempotencyKey = const Uuid().v4();
  bool _isPlacingOrder = false;

  ScheduleDetails? _scheduleDetails;

  @override
  void initState() {
    super.initState();
    // Resolve area schedule for the logged-in customer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customer = ref.read(authProvider).customer;
      if (customer != null) {
        final orderDays = customer['delivery_schedule'] as List<dynamic>?;
        final cutoffStr = customer['cutoff_time']?.toString();

        final settings = ref.read(appSettingsProvider).valueOrNull;
        final bool isClosed = isStoreClosed(settings);

        setState(() {
          _scheduleDetails = AreaScheduleHelper.calculateDetails(
            orderDays,
            cutoffTimeStr: cutoffStr,
            isStoreClosed: isClosed,
          );
        });
      }
    });
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _placeOrder() async {
    final customer = ref.read(authProvider).customer;
    if (customer == null) return;

    final cart = ref.read(activeCartProvider);
    final isOrderNow = cart.items.values.any((item) => item.isOrderNow);

    var details = _scheduleDetails;
    if (!isOrderNow && (details == null || details.state == ScheduleState.noSchedule)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No delivery schedule available for your area.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Stock, Availability & Price Validation before placing order
    try {
      final client = Supabase.instance.client;
      final List<dynamic> remoteProducts = await client
          .from('products')
          .select('id, price, is_available, description')
          .inFilter('id', cart.items.keys.toList());

      bool priceChanged = false;
      for (final p in remoteProducts) {
        final String id = p['id'] as String;
        final bool isAvailable = (p['is_available'] == true || p['is_available'] == 1);
        final localItem = cart.items[id];
        if (localItem == null) continue;

        if (!isAvailable) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${localItem.productName} is currently out of stock. Please remove it from cart.'),
              backgroundColor: Colors.red,
            ),
          );
          return; // Block order placement!
        }

        // Check stock levels from description JSON object
        final descStr = p['description']?.toString() ?? '';
        if (descStr.isNotEmpty && descStr.startsWith('{')) {
          try {
            final descObj = jsonDecode(descStr);
            if (descObj['stock'] != null) {
              final double stock = (descObj['stock'] as num).toDouble();
              if (localItem.quantity > stock) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Insufficient stock for ${localItem.productName} (Available: ${stock.toInt()} ${localItem.unit}). Please adjust quantity.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return; // Block order placement!
              }
            }
          } catch (_) {}
        }

        final double remotePrice = (p['price'] as num).toDouble();
        if (localItem.price != remotePrice) {
          ref.read(activeCartNotifierProvider).updateItemPrice(id, remotePrice);
          priceChanged = true;
        }
      }

      if (priceChanged) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Some product prices have changed. Your cart has been updated. Please review before proceeding.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        return; // Reject submission and let the user see the updated grand total!
      }
    } catch (e) {
      debugPrint('Online stock/price check error: $e');
    }

    setState(() {
      _isPlacingOrder = true;
    });

    final name = customer['name'] ?? '';
    final phone = customer['phone'] ?? '';
    String address = (customer['address'] ?? '').toString().trim();

    // Fallback: build address from area/road/sub_road fields if main address is empty
    if (address.isEmpty) {
      final parts = <String>[
        (customer['sub_road_name'] ?? '').toString().trim(),
        (customer['road_name'] ?? '').toString().trim(),
        (customer['area_name'] ?? '').toString().trim(),
      ].where((s) => s.isNotEmpty).toList();
      address = parts.join(', ');
    }

    // If still empty after fallback, block the order
    if (address.isEmpty) {
      setState(() { _isPlacingOrder = false; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery address is missing. Please update your address in Profile before placing an order.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    final settings = ref.read(appSettingsProvider).valueOrNull;
    final bool isClosed = isStoreClosed(settings);
    if (isClosed) {
      setState(() { _isPlacingOrder = false; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We are currently not accepting orders. We will be back in some time.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    String orderType;
    String orderTakingDateStr;
    String deliveryDateStr;

    if (isOrderNow) {
      orderType = 'Quick Order';
      orderTakingDateStr = _formatDate(DateTime.now());
      deliveryDateStr = _formatDate(DateTime.now());
    } else {
      details = AreaScheduleHelper.calculateDetails(
        customer['delivery_schedule'] as List<dynamic>?,
        cutoffTimeStr: customer['cutoff_time']?.toString(),
        isStoreClosed: isClosed,
      );

      if (details.state == ScheduleState.noSchedule) {
        setState(() { _isPlacingOrder = false; });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No delivery schedule available for your area. Order cannot be placed.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (details.state == ScheduleState.openToday) {
        orderType = 'Normal';
        orderTakingDateStr = _formatDate(details.orderTakingDate!);
        deliveryDateStr = _formatDate(details.deliveryDate!);
      } else {
        // closedToday → Pre-Order
        orderType = 'Pre-Order';
        orderTakingDateStr = _formatDate(details.nextOrderDate!);
        deliveryDateStr = _formatDate(details.nextDeliveryDate!);
      }
    }

    try {
      final order = await ref.read(orderListProvider.notifier).placeOrder(
            name: name,
            phone: phone,
            address: address,
            idempotencyKey: _idempotencyKey,
            deliveryDate: deliveryDateStr,
            orderType: orderType,
            orderTakingDate: orderTakingDateStr,
          );

      if (!mounted) return;
      setState(() {
        _isPlacingOrder = false;
      });

      if (order != null) {
        // Trigger pleasant system chime notification for vocal order confirmation
        NotificationService.instance.showNotification(
          id: (order['id'] as String).hashCode,
          title: 'Order Placed! 🎉',
          body: 'Your order ${order['order_number'] ?? 'OK-#'} has been successfully received.',
          payload: order['id'] as String,
        );

        ref.invalidate(orderListProvider);

        // Push OrderConfirmationScreen for high-fidelity confirmation animation
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 200),
            pageBuilder: (context, animation, secondaryAnimation) => OrderConfirmationScreen(
              order: order,
              cartItems: cart.items.values.toList(),
              subtotal: cart.subtotal,
              deliveryCharge: cart.deliveryCharge,
              grandTotal: cart.grandTotal,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to place order. Please check connectivity and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPlacingOrder = false;
      });

      String errorMsg = e.toString();
      if (errorMsg.contains('Insufficient stock')) {
        errorMsg = 'Some items no longer have enough stock. Please review your cart.';
      } else if (errorMsg.contains('Product is unavailable')) {
        errorMsg = 'Some items are no longer available. Please review your cart.';
      } else {
        errorMsg = 'Failed to place order: ${errorMsg.replaceAll('PostgrestException(', '').replaceAll(')', '')}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(activeCartProvider);
    final customer = ref.watch(authProvider).customer;
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final bool isClosed = isStoreClosed(settings);

    if (cart.items.isEmpty) {
      return AmbientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            title: Text(
              'Order Summary',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          body: Center(
            child: Text(
              'Your cart is empty.',
              style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF64748B)),
            ),
          ),
        ),
      );
    }

    final adjustedPrices = cart.adjustedItemPrices;
    const Color textColorPrimary = Color(0xFF0F172A);
    const Color textColorSecondary = Color(0xFF64748B);
    const Color accentGreen = Color(0xFF059669);

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textColorPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Order Summary',
            style: GoogleFonts.outfit(
              color: textColorPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          centerTitle: true,
        ),
        body: _isPlacingOrder
            ? Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Placing Your Order...',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColorPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Securing items & syncing receipt',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: textColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── 1. ELEGANT DELIVERY LOCATION CARD ─────────────────────
                          if (customer != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                                    ),
                                    child: const Icon(
                                      Icons.location_on_rounded,
                                      color: accentGreen,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              customer['name']?.toString() ?? 'Valued Customer',
                                              style: GoogleFonts.outfit(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: textColorPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                customer['phone']?.toString() ?? '',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColorSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          customer['address']?.toString() ?? 'Default Delivery Address',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            color: textColorSecondary,
                                            height: 1.25,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ── 3. ELEGANT DELIVERY SCHEDULE CARD ────────────────────
                          if (cart.items.values.any((item) => item.isOrderNow)) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFFDBA74),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEA580C).withValues(alpha: 0.05),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFFEDD5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.bolt_rounded,
                                      color: Color(0xFFC2410C),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '⚡ Quick Order (1-2 Hours Delivery)',
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF9A3412),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Estimated Delivery: Today, within 1 to 2 hours',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFFC2410C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ] else if (_scheduleDetails != null && _scheduleDetails!.state != ScheduleState.noSchedule) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _scheduleDetails!.state == ScheduleState.openToday
                                    ? const Color(0xFFF0FDF4).withValues(alpha: 0.9)
                                    : const Color(0xFFFFFBEB).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _scheduleDetails!.state == ScheduleState.openToday
                                      ? const Color(0xFFBBF7D0)
                                      : const Color(0xFFFDE68A),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _scheduleDetails!.state == ScheduleState.openToday
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFFEF3C7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _scheduleDetails!.state == ScheduleState.openToday
                                          ? Icons.local_shipping_rounded
                                          : Icons.event_available_rounded,
                                      color: _scheduleDetails!.state == ScheduleState.openToday
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFFB45309),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _scheduleDetails!.state == ScheduleState.openToday
                                              ? 'Next-Day Delivery'
                                              : 'Pre-Order (Scheduled)',
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: _scheduleDetails!.state == ScheduleState.openToday
                                              ? const Color(0xFF14532D)
                                              : const Color(0xFF78350F),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _scheduleDetails!.state == ScheduleState.openToday
                                              ? 'Delivery: ${AreaScheduleHelper.formatDayAndDate(_scheduleDetails!.deliveryDate!)}'
                                              : 'Order Day: ${AreaScheduleHelper.formatDayAndDate(_scheduleDetails!.nextOrderDate!)}\nDelivery: ${AreaScheduleHelper.formatDayAndDate(_scheduleDetails!.nextDeliveryDate!)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: _scheduleDetails!.state == ScheduleState.openToday
                                                ? const Color(0xFF15803D)
                                                : const Color(0xFFB45309),
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          const SizedBox(height: 16),

// ── 2. HERO GLASS ORDER SUMMARY CARD ──────────────────────
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Title Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.receipt_long_rounded,
                                            color: textColorPrimary,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Order Items',
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: textColorPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Text(
                                        '${cart.items.length} ${cart.items.length == 1 ? 'Item' : 'Items'}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: textColorSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Divider(height: 1, color: const Color(0xFFE2E8F0).withValues(alpha: 0.7)),
                                const SizedBox(height: 14),

                                // Product List Rows
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: cart.items.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = cart.items.values.toList()[index];
                                    final displayPrice = adjustedPrices[item.productId] ?? item.totalPrice;

                                    return Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: accentGreen,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: item.productName,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: textColorPrimary,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: '  (${formatQuantity(item.quantity, item.unit)})',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: textColorSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '₹${displayPrice.toStringAsFixed(0)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.bold,
                                            color: textColorPrimary,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),

                                const SizedBox(height: 18),
                                Divider(height: 1, color: const Color(0xFFE2E8F0).withValues(alpha: 0.7)),
                                const SizedBox(height: 16),

                                // Subtotal Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Subtotal',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: textColorSecondary,
                                      ),
                                    ),
                                    Text(
                                      '₹${(cart.roundedGrandTotal - cart.deliveryCharge).toStringAsFixed(0)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: textColorPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Delivery Charge Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Delivery Charge',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: textColorSecondary,
                                      ),
                                    ),
                                    cart.deliveryCharge == 0
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'FREE',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: accentGreen,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            '₹${cart.deliveryCharge.toStringAsFixed(0)}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: textColorPrimary,
                                            ),
                                          ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                Container(
                                  height: 1,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFE2E8F0),
                                        Color(0xFFCBD5E1),
                                        Color(0xFFE2E8F0),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Grand Total Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Grand Total',
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: textColorPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Inclusive of all taxes & charges',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: textColorSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '₹${cart.roundedGrandTotal.toStringAsFixed(0)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: textColorPrimary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
// ── 4. LUXURIOUS FLOATING "PLACE ORDER" BUTTON ───────────────────
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      MediaQuery.of(context).padding.bottom + 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isClosed ? Colors.grey : textColorPrimary,
                          foregroundColor: Colors.white,
                          elevation: isClosed ? 0 : 4,
                          shadowColor: isClosed ? Colors.transparent : textColorPrimary.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: isClosed || _scheduleDetails == null || _scheduleDetails!.state == ScheduleState.noSchedule
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                _placeOrder();
                              },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isClosed
                                  ? 'STORE CLOSED'
                                  : _scheduleDetails?.state == ScheduleState.closedToday
                                      ? 'CONFIRM PRE-ORDER'
                                      : 'PLACE ORDER',
                              style: GoogleFonts.outfit(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isClosed ? Icons.lock_outline_rounded : Icons.arrow_forward_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        ),
      );
  }
}
