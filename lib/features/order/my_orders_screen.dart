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
          return RefreshIndicator(
            color: brandPrimary,
            onRefresh: () async {
              final cust = ref.read(authProvider).customer;
              final phone = cust?['phone']?.toString() ?? '';
              await ref.read(orderListProvider.notifier).fetchOrders(phone);
            },
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
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
                  ),
                ),
              ),
            ),
          );
        }

        final filteredOrders = orders.where((order) {
          final status = (order['status'] ?? 'Pending').toString().toLowerCase();
          final orderType = (order['order_type'] ?? '').toString().toLowerCase();

          if (_selectedFilter == 'Pre-Orders') {
            return orderType == 'pre-order';
          } else if (_selectedFilter == 'Active') {
            return status != 'delivered' && status != 'cancelled' && status != 'denied';
          } else if (_selectedFilter == 'Delivered') {
            return status == 'delivered';
          }
          return true;
        }).toList();

        return RefreshIndicator(
          color: brandPrimary,
          onRefresh: () async {
            final cust = ref.read(authProvider).customer;
            final phone = cust?['phone']?.toString() ?? '';
            await ref.read(orderListProvider.notifier).fetchOrders(phone);
          },
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
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: brandPrimary,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? brandPrimary : const Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                          ),
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          visualDensity: VisualDensity.compact,
                          elevation: isSelected ? 2 : 0,
                          pressElevation: 1,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF334155),
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

              // Orders List with Subtle White Cards (Optimized for low-RAM devices)
              Expanded(
                child: filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.filter_list_off_rounded, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'No $_selectedFilter orders found',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        cacheExtent: 250,
                        addAutomaticKeepAlives: false,
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
    final syncStatus = order['sync_status']?.toString();
    final bool isPermanentlyFailed = syncStatus == 'permanently_failed';
    final isOffline = syncStatus == 'pending' || syncStatus == 'failed' || isPermanentlyFailed;
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
    if (totalAmount <= 0 && isQuickOrder && itemsList.isNotEmpty) {
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
        totalAmount = expectedRounded;
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
                // Top Header Row: Order Number & Subtle Status Badge (Adaptive to big fonts)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$orderNo${isPermanentlyFailed ? " (Sync Failed)" : (isOffline ? " (Offline)" : "")}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSubtleStatusBadge(order),
                  ],
                ),
                const SizedBox(height: 10),

                // Date & Items Breakdown (Wrap allows natural break under high font scale)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
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
                      ],
                    ),
                    if (itemsCount > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                      ),
                  ],
                ),

                if (deliveryDateStr != null && deliveryDateStr.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 14, color: Color(0xFF059669)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Delivery: ${_formatDeliveryDate(deliveryDateStr)}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFF059669),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Bottom Row: Total Price & Clean Subtle Button (Adaptive to big fonts)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '₹${_formatCurrency(totalAmount)}',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                if (isPermanentlyFailed) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sync failed after retries',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final orderId = order['id']?.toString() ?? '';
                            if (orderId.isNotEmpty) {
                              ref.read(orderListProvider.notifier).retryOrderSync(orderId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Retrying order sync...')),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Retry',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () {
                            final orderId = order['id']?.toString() ?? '';
                            if (orderId.isNotEmpty) {
                              ref.read(orderListProvider.notifier).dismissFailedOrder(orderId);
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Dismiss',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtleStatusBadge(Map<String, dynamic> order) {
    final syncStatus = order['sync_status']?.toString();
    if (syncStatus == 'permanently_failed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5), width: 0.8),
        ),
        child: Text(
          'Sync Failed',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF991B1B),
          ),
        ),
      );
    }

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
      switch (status.toString().toLowerCase()) {
        case 'confirmed':
          displayStatus = 'Confirmed';
          bg = const Color(0xFFD1FAE5);
          text = const Color(0xFF065F46);
          border = const Color(0xFFA7F3D0);
          break;
        case 'preparing':
          displayStatus = 'Preparing';
          bg = const Color(0xFFF3E8FF);
          text = const Color(0xFF6B21A8);
          border = const Color(0xFFE9D5FF);
          break;
        case 'out for delivery':
          displayStatus = 'On The Way';
          bg = const Color(0xFFCCFBF1);
          text = const Color(0xFF115E59);
          border = const Color(0xFF99F6E4);
          break;
        case 'delivered':
          displayStatus = 'Delivered';
          bg = const Color(0xFFF1F5F9);
          text = const Color(0xFF334155);
          border = const Color(0xFFE2E8F0);
          break;
        case 'cancelled':
          displayStatus = 'Cancelled';
          bg = const Color(0xFFFEE2E2);
          text = const Color(0xFF991B1B);
          border = const Color(0xFFFCA5A5);
          break;
        case 'denied':
          displayStatus = 'Denied';
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
