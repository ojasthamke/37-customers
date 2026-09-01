import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'order_provider.dart';
import 'order_details_screen.dart';
import '../auth/auth_provider.dart';
import '../catalog/catalog_provider.dart';
import '../cart/cart_provider.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/skeleton_loader.dart';


class MyOrdersScreen extends ConsumerStatefulWidget {
  final bool showAppBar;

  const MyOrdersScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  String _selectedFilter = 'All';

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color brandPrimary = Color(0xFF1B3624);

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(orderListProvider);

    Widget content = ordersAsync.when(
      loading: () => SkeletonLoader.ordersList(count: 5),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Error loading orders: $err',
            style: GoogleFonts.inter(color: Colors.red.shade700),
          ),
        ),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 64,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No orders placed yet',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your weekly vegetable pre-orders and instant orders will appear here.',
                    style: GoogleFonts.inter(fontSize: 13.5, color: textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final filteredOrders = orders.where((order) {
          final status = (order['status'] ?? 'Pending').toString().toLowerCase();
          final orderType = (order['order_type'] ?? '').toString().toLowerCase();

          if (_selectedFilter == 'Pre-Orders') {
            return orderType == 'pre-order' || status == 'pending';
          } else if (_selectedFilter == 'Active') {
            return status != 'delivered' && status != 'cancelled';
          } else if (_selectedFilter == 'Delivered') {
            return status == 'delivered';
          }
          return true;
        }).toList();

        return RefreshIndicator(
          color: brandPrimary,
          onRefresh: () => ref.read(orderListProvider.notifier).fetchOrders(
                ref.read(authProvider).customer!['phone'],
              ),
          child: Column(
            children: [
              // Clean Filter Chips Row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: ['All', 'Pre-Orders', 'Active', 'Delivered'].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(
                            filter,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: brandPrimary,
                          backgroundColor: Colors.white,
                          elevation: isSelected ? 2 : 0,
                          pressElevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? brandPrimary : const Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                          ),
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedFilter = filter);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Orders List with Subtle White Cards
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildSubtleWhiteOrderCard(context, order);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.showAppBar) {
      return AmbientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            title: Text(
              'My Orders',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ),
          body: content,
        ),
      );
    } else {
      return AmbientBackground(child: content);
    }
  }

  String _formatDeliveryDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final parsed = DateTime.parse(raw);
      return DateFormat('EEEE, d MMM yyyy').format(parsed);
    } catch (_) {
      return raw;
    }
  }

  String _formatCurrency(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }

  Widget _buildSubtleWhiteOrderCard(BuildContext context, Map<String, dynamic> order) {
    final orderDate = (DateTime.tryParse(order['order_date'] ?? '') ?? DateTime.now()).toLocal();
    final formattedDate = DateFormat('dd MMM yyyy • hh:mm a').format(orderDate);
    final orderNo = order['order_number'] ?? order['offline_order_no'] ?? 'OK-#';
    final isOffline = order['sync_status'] == 'pending' || order['sync_status'] == 'failed';
    double totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    int itemsCount = 0;
    final rawItems = order['order_items'];
    List<dynamic> itemsList = [];
    if (rawItems is List) {
      itemsList = rawItems;
      itemsCount = rawItems.length;
    } else if (rawItems is String && rawItems.trim().isNotEmpty) {
      try {
        final decoded = json.decode(rawItems);
        if (decoded is List) {
          itemsList = decoded;
          itemsCount = decoded.length;
        }
      } catch (_) {}
    }

    final bool isQuickOrder = order['order_type'] == 'Quick Order';
    if (isQuickOrder && itemsList.isNotEmpty) {
      final allProducts = ref.watch(allProductsProvider).valueOrNull ?? [];
      double quickSubtotal = 0.0;
      for (final it in itemsList) {
        if (it is Map) {
          final pid = it['product_id']?.toString() ?? '';
          final pName = it['product_name']?.toString().toLowerCase().trim() ?? '';
          final prod = allProducts.firstWhere(
            (p) => (p['id']?.toString() == pid) || (p['name']?.toString().toLowerCase().trim() == pName),
            orElse: () => <String, dynamic>{},
          );
          double price = (it['price'] as num?)?.toDouble() ?? 0.0;
          if (prod.isNotEmpty) {
            final double onPrice = (prod['order_now_price'] as num?)?.toDouble() ?? 0.0;
            if (onPrice > 0) price = onPrice;
          }
          final double qty = (it['quantity'] as num?)?.toDouble() ?? 1.0;
          quickSubtotal += price * qty;
        }
      }
      if (quickSubtotal > 0) {
        final settings = ref.watch(appSettingsProvider).valueOrNull;
        double quickDeliveryFee = 10.0;
        if (settings != null && settings['order_now_delivery_charge'] != null) {
          quickDeliveryFee = (double.tryParse(settings['order_now_delivery_charge'].toString()) ?? 10.0);
        }
        final double expectedRaw = quickSubtotal + quickDeliveryFee;
        final double expectedRounded = (expectedRaw / 5).ceil() * 5.0;
        if (totalAmount <= 0 || (totalAmount - quickSubtotal).abs() > (quickDeliveryFee + 15.0)) {
          totalAmount = expectedRounded;
        }
      }
    }

    final deliveryDateStr = order['delivery_date']?.toString();


    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            final String orderId = order['id']?.toString() ?? order['order_number']?.toString() ?? '';
            if (orderId.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderDetailsScreen(orderId: orderId),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row: Order Number & Subtle Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$orderNo${isOffline ? " (Offline)" : ""}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textPrimary,
                      ),
                    ),
                    _buildSubtleStatusBadge(order),
                  ],
                ),
                const SizedBox(height: 10),

                // Date & Items Breakdown
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 5),
                    Text(
                      formattedDate,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (itemsCount > 0) ...[
                      const Spacer(),
                      if (order['order_type'] == 'Quick Order') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFB74D), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFE65100)),
                              const SizedBox(width: 2),
                              Text(
                                'Quick Order',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFE65100),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$itemsCount ${itemsCount == 1 ? "item" : "items"}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                if (deliveryDateStr != null && deliveryDateStr.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 14, color: Color(0xFF059669)),
                      const SizedBox(width: 5),
                      Text(
                        'Delivery: ${_formatDeliveryDate(deliveryDateStr)}',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF059669),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Bottom Row: Total Price & Clean Subtle Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${_formatCurrency(totalAmount)}',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'View Details',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF334155)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtleStatusBadge(Map<String, dynamic> order) {
    final status = order['status'] ?? 'Pending';
    final orderType = order['order_type'] ?? '';

    String displayStatus = status;
    Color bg;
    Color text;
    Color border;

    if (status.toLowerCase() == 'pending') {
      if (orderType.toLowerCase() == 'pre-order') {
        displayStatus = 'Pre-Ordered';
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFF92400E);
        border = const Color(0xFFFDE68A);
      } else if (orderType.toLowerCase() == 'quick-order' || orderType.toLowerCase() == 'quick order') {
        displayStatus = 'Quick Order';
        bg = const Color(0xFFFFF3E0);
        text = const Color(0xFFE65100);
        border = const Color(0xFFFFB74D);
      } else {
        displayStatus = 'Pending';
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFF92400E);
        border = const Color(0xFFFDE68A);
      }
    } else {
      switch (status) {
        case 'Confirmed':
          displayStatus = 'Confirmed';
          bg = const Color(0xFFD1FAE5);
          text = const Color(0xFF065F46);
          border = const Color(0xFFA7F3D0);
          break;
        case 'Preparing':
          displayStatus = 'Preparing';
          bg = const Color(0xFFF3E8FF);
          text = const Color(0xFF6B21A8);
          border = const Color(0xFFE9D5FF);
          break;
        case 'Out for Delivery':
          displayStatus = 'On The Way';
          bg = const Color(0xFFCCFBF1);
          text = const Color(0xFF115E59);
          border = const Color(0xFF99F6E4);
          break;
        case 'Delivered':
          displayStatus = 'Delivered';
          bg = const Color(0xFFF1F5F9);
          text = const Color(0xFF334155);
          border = const Color(0xFFE2E8F0);
          break;
        case 'Cancelled':
          displayStatus = 'Cancelled';
          bg = const Color(0xFFFEE2E2);
          text = const Color(0xFF991B1B);
          border = const Color(0xFFFCA5A5);
          break;
        default:
          displayStatus = status;
          bg = const Color(0xFFF1F5F9);
          text = const Color(0xFF475569);
          border = const Color(0xFFE2E8F0);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        displayStatus,
        style: GoogleFonts.inter(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
