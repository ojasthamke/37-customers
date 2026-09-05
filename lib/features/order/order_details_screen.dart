import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'order_provider.dart';
import '../dashboard/home_screen.dart';
import '../cart/cart_provider.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/product_helper.dart';

class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  static const Color bgScaffold = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color brandPrimary = Color(0xFF10B981);
  static const Color brandDark = Color(0xFF047857);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(orderDetailsProvider(orderId));
    final theme = Theme.of(context);

    return AmbientBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Order Details',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          detailsAsync.when(
            data: (details) {
              final order = details.order;
              final orderNo = order['order_number'] ?? order['offline_order_no'] ?? '';
              final customerName = order['customer_name'] ?? 'Customer';

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.headset_mic_rounded, color: textPrimary, size: 22),
                    tooltip: 'Customer Support',
                    onPressed: () => _showSupportModal(context, orderNo, customerName),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: textPrimary, size: 22),
                    tooltip: 'Share Receipt',
                    onPressed: () {
                      _shareTextReceipt(context, details.order, details.items);
                    },
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: detailsAsync.when(
        data: (details) {

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.replay_rounded, size: 18, color: textPrimary),
                      label: const Text('Reorder', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator()),
                        );
                        try {
                          final productIds = details.items
                              .map((i) => i['product_id']?.toString())
                              .whereType<String>()
                              .where((id) => id.isNotEmpty)
                              .toList();
                          List<Map<String, dynamic>> currentProducts = [];
                          try {
                            final client = Supabase.instance.client;
                            final response = await client.from('products').select().inFilter('id', productIds).timeout(const Duration(seconds: 10));
                            currentProducts = List<Map<String, dynamic>>.from(response);
                          } catch (_) {
                            // Fallback to local SQLite cache
                            final db = await DatabaseHelper.instance.database;
                            final placeholders = List.filled(productIds.length, '?').join(',');
                            final localRes = await db.query(
                              'products',
                              where: 'id IN ($placeholders)',
                              whereArgs: productIds,
                            );
                            currentProducts = List<Map<String, dynamic>>.from(localRes);
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                          if (context.mounted) {
                            if (currentProducts.isNotEmpty) {
                              _showReorderDialog(context, ref, details.items, currentProducts, orderType: details.order['order_type']?.toString());
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Products are currently unavailable.'), backgroundColor: Colors.orange),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to load current prices: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                      label: const Text(
                        'Done',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () {
                        ref.read(activeTabProvider.notifier).state = 0;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => _buildErrorOrOfflineState(context, ref, err),
        data: (details) {
          final order = details.order;
          final items = details.items;

          final availableItems = items.where((item) => !_isItemUnavailable(item)).toList();
          double subtotal = 0.0;
          for (final item in availableItems) {
            subtotal += (item['total_price'] as num?)?.toDouble() ?? 0.0;
          }
          final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
          final deliveryCharge = items.isEmpty ? 0.0 : (totalAmount - subtotal);
          final displayDeliveryCharge = (deliveryCharge > 0.08 && items.isNotEmpty) ? deliveryCharge : 0.0;

          final orderDate = (DateTime.tryParse(order['order_date'] ?? '') ?? DateTime.now()).toLocal();
          final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(orderDate);
          final status = order['status'] ?? 'Pending';

          return Stack(
            children: [
              // Ambient soft glow background decorations
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                top: 250,
                left: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
                  ),
                ),
              ),

              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. ORDER STATUS & ID HEADER CARD ──────────────────────
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${order['order_number'] ?? order['offline_order_no'] ?? ''}${order['sync_status'] == 'permanently_failed' ? ' (Sync Failed)' : (order['sync_status'] == 'pending' || order['sync_status'] == 'failed' ? ' (Offline)' : '')}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Placed: $formattedDate',
                                      style: GoogleFonts.inter(
                                        color: textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _buildStatusChip(order),
                        ],
                      ),
                    ),

                    if (order['sync_status'] == 'permanently_failed') ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.cloud_off_rounded, color: Color(0xFFDC2626), size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Order Sync Failed',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF991B1B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'This order could not be synced to the server after multiple attempts. You can retry syncing or dismiss this order.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF7F1D1D),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final orderId = order['id']?.toString() ?? '';
                                    if (orderId.isNotEmpty) {
                                      await ref.read(orderListProvider.notifier).retryOrderSync(orderId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Retrying order sync...')),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                                  label: const Text('Retry Sync', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  onPressed: () async {
                                    final orderId = order['id']?.toString() ?? '';
                                    if (orderId.isNotEmpty) {
                                      await ref.read(orderListProvider.notifier).dismissFailedOrder(orderId);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                  child: const Text('Dismiss', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── 2. ELEGANT TOP DELIVERY INFO (MINIMALISTIC WARNING FORMAT) ──
                    _buildTopDeliveryWarningCard(order),

                    // ── 3. ORDER PROGRESS STEPPER ─────────────────────────────
                    _buildProgressStepper(status, theme),

                    // ── 4. STORE MODIFICATION NOTICE ──────────────────────────
                    Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Note: Only OrderKart can modify or update items in this order. If you need any adjustments, tap Help below.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF1E40AF),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── 5. DISTINGUISHED ORDERED ITEMS SECTION ────────────────
                    _buildOrderedItemsCard(items, subtotal, displayDeliveryCharge, totalAmount),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
  }

  /// Top Delivery Notice banner in clean, subtle white format with green accents (without customer name/address)
  Widget _buildTopDeliveryWarningCard(Map<String, dynamic> order) {
    final bool isPreOrder = order['order_type'] == 'Pre-Order';
    final bool isQuickOrder = order['order_type'] == 'Quick Order';
    final deliveryDateStr = order['delivery_date']?.toString();
    final takingDateStr = order['order_taking_date']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  size: 18,
                  color: Color(0xFF047857),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Scheduled Delivery Info',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isQuickOrder 
                      ? const Color(0xFFFFF3E0)
                      : (isPreOrder ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isQuickOrder
                        ? const Color(0xFFFFB74D)
                        : (isPreOrder ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0)),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isQuickOrder) ...[
                      const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFE65100)),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      isQuickOrder 
                          ? 'Quick Order (1-2 Hours)' 
                          : (isPreOrder ? 'Pre-Order' : 'Standard Delivery'),
                      style: TextStyle(
                        color: isQuickOrder
                            ? const Color(0xFFE65100)
                            : (isPreOrder ? const Color(0xFF92400E) : const Color(0xFF047857)),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isQuickOrder) ...[
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFFE65100)),
                const SizedBox(width: 8),
                Text(
                  'Expected Delivery: ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Today (within 1-2 Hours)',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (deliveryDateStr != null && deliveryDateStr.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Text(
                  'Delivery Date: ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatDeliveryDate(deliveryDateStr),
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (takingDateStr != null && takingDateStr.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  'Order-Taking Date: ',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatDeliveryDate(takingDateStr),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (deliveryDateStr == null || deliveryDateStr.isEmpty)
            Text(
              'Will arrive within 2 hours of confirmation.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  /// Distinguished, elegant Ordered Items list card with clear formatting
  Widget _buildOrderedItemsCard(
      List<dynamic> items, double subtotal, double displayDeliveryCharge, double totalAmount) {
    final availableItems = items.where((item) => !_isItemUnavailable(item)).toList();
    final unavailableItems = items.where((item) => _isItemUnavailable(item)).toList();

    double totalDeducted = 0.0;
    for (final item in unavailableItems) {
      final double qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
      final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final double itemTotal = (item['total_price'] as num?)?.toDouble() ?? 0.0;
      totalDeducted += itemTotal > 0.001 ? itemTotal : (qty * price);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ordered Items',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${availableItems.length} ${availableItems.length == 1 ? "item" : "items"}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...availableItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
            final String unit = item['unit'] ?? '';
            final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
            final double lineTotal =
                (item['total_price'] as num?)?.toDouble() ?? (qty * price);
            final String rawName = item['product_name'] ?? 'Item';

            return Container(
              margin: EdgeInsets.only(bottom: idx == availableItems.length - 1 ? 0 : 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${idx + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rawName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatQuantity(qty, unit),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '@ ₹${price.toStringAsFixed(2)} / $unit',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '₹${lineTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),

          if (unavailableItems.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFFED7AA)),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.remove_shopping_cart_rounded, color: Color(0xFFEA580C), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Out of Stock / Unavailable Items',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFC2410C),
                  ),
                ),
              ],
            ),
            if (totalDeducted > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFC2410C)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '₹${totalDeducted.toStringAsFixed(2)} deducted from bill due to item unavailability.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF9A3412),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            ...unavailableItems.map((item) {
              final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
              final String unit = item['unit'] ?? '';
              final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
              final String rawName = item['product_name'] ?? 'Item';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rawName,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF9A3412),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatQuantity(qty, unit)} @ ₹${price.toStringAsFixed(2)} / $unit',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFFC2410C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹0.00',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFC2410C),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Out of Stock',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          // Financial Summary Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items Subtotal',
                style: GoogleFonts.inter(fontSize: 13.5, color: textSecondary),
              ),
              Text(
                '₹${subtotal.toStringAsFixed(2)}',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery Fee',
                style: GoogleFonts.inter(fontSize: 13.5, color: textSecondary),
              ),
              Text(
                displayDeliveryCharge == 0.0 ? 'Free' : '₹${displayDeliveryCharge.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: displayDeliveryCharge == 0.0 ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paid Total',
                  style: GoogleFonts.outfit(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF065F46),
                  ),
                ),
                Text(
                  '₹${totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                    Text(
                      'Customer Support',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'How can we help you today? Connect with our store directly.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final String msg =
                        'Hello Orderkart Support! I am $customerName, and I need assistance with my order (#$orderNo).';
                    final String encodedMsg = Uri.encodeComponent(msg);
                    final whatsappUri = Uri.parse('whatsapp://send?phone=919021107009&text=$encodedMsg');
                    final webUri = Uri.parse('https://wa.me/919021107009?text=$encodedMsg');
                    try {
                      bool launched = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
                      if (!launched) {
                        await launchUrl(webUri, mode: LaunchMode.externalApplication);
                      }
                    } catch (_) {
                      try {
                        await launchUrl(webUri, mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                  label: const Text('Chat on WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final url = Uri.parse('tel:+919021107009');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  icon: const Icon(Icons.phone_outlined, color: Colors.white),
                  label: const Text('Call Us Directly', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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

  String _formatQuantity(double qty, String unit) {
    final u = unit.toLowerCase();
    if (u.contains('kg')) {
      if (qty < 1.0) {
        return '${(qty * 1000).toStringAsFixed(0)} g';
      } else {
        return '${qty.toStringAsFixed(qty == qty.toInt() ? 0 : 1)} kg';
      }
    } else if (u.contains('doz')) {
      return '$qty Dozen';
    } else {
      return '${qty.toStringAsFixed(qty == qty.toInt() ? 0 : 1)} $unit';
    }
  }

  String _formatDeliveryDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, d MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildStatusChip(Map<String, dynamic> order) {
    final syncStatus = order['sync_status']?.toString();
    if (syncStatus == 'permanently_failed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5), width: 0.8),
        ),
        child: const Text(
          'Sync Failed',
          style: TextStyle(
            color: Color(0xFFDC2626),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    final status = order['status'] ?? 'Pending';
    final orderType = order['order_type'] ?? '';
    
    String displayStatus = status;
    Color color;
    
    if (status.toLowerCase() == 'pending') {
      if (orderType.toLowerCase() == 'pre-order') {
        displayStatus = 'Pre-Ordered';
        color = Colors.orange[800]!;
      } else {
        color = Colors.amber[800]!;
      }
    } else {
      switch (status.toString().toLowerCase()) {
        case 'confirmed':
          displayStatus = 'Confirmed';
          color = Colors.blue;
          break;
        case 'preparing':
          displayStatus = 'Preparing';
          color = Colors.purple;
          break;
        case 'out for delivery':
          displayStatus = 'Out for Delivery';
          color = Colors.teal;
          break;
        case 'delivered':
          displayStatus = 'Delivered';
          color = const Color(0xFF10B981);
          break;
        case 'cancelled':
          displayStatus = 'Cancelled';
          color = Colors.red;
          break;
        case 'denied':
          displayStatus = 'Denied';
          color = Colors.red;
          break;
        default:
          displayStatus = status;
          color = Colors.grey;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _shareTextReceipt(BuildContext context, Map<String, dynamic> order, List<dynamic> items) {
    final orderNumber = order['order_number'] ?? order['offline_order_no'] ?? 'N/A';
    final orderDate = (DateTime.tryParse(order['order_date'] ?? '') ?? DateTime.now()).toLocal();
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(orderDate);
    final totalAmount = (order['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00';

    final buffer = StringBuffer();
    buffer.writeln('================================');
    buffer.writeln('        ORDERKART RECEIPT       ');
    buffer.writeln('================================');
    buffer.writeln('Order Number: $orderNumber');
    buffer.writeln('Date: $formattedDate');
    buffer.writeln('Status: ${order['status'] ?? 'Pending'}');
    buffer.writeln('--------------------------------');
    buffer.writeln('Item          Price   Qty   Total');
    buffer.writeln('--------------------------------');

    for (final item in items) {
      final name = (item['product_name'] ?? 'N/A').toString().padRight(12);
      final price = '₹${(item['price'] as num?)?.toStringAsFixed(0) ?? '0'}'.padRight(7);
      final qty = '${item['quantity']} ${item['unit']}'.padRight(6);
      final total = '₹${(item['total_price'] as num?)?.toStringAsFixed(0) ?? '0'}';
      buffer.writeln('$name $price $qty $total');
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('Paid Total:             ₹$totalAmount');
    buffer.writeln('================================');
    buffer.writeln('Thank you for choosing Orderkart!');
    buffer.writeln('================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt copied to clipboard! Share it anywhere.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildProgressStepper(String status, ThemeData theme) {
    final normStatus = status.toLowerCase();
    if (normStatus == 'cancelled' || normStatus == 'denied') {
      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA), width: 1.0),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 12),
            Text(
              normStatus == 'denied' ? 'This order was declined.' : 'This order was cancelled.',
              style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    const steps = [
      {'name': 'Placed', 'icon': Icons.receipt_long_rounded, 'sub': 'Order received'},
      {'name': 'Confirmed', 'icon': Icons.check_circle_rounded, 'sub': 'Accepted for packing'},
      {'name': 'Packing', 'icon': Icons.inventory_2_rounded, 'sub': 'Produce being packed'},
      {'name': 'On Way', 'icon': Icons.local_shipping_rounded, 'sub': 'Out for delivery'},
      {'name': 'Delivered', 'icon': Icons.done_all_rounded, 'sub': 'Order delivered'},
    ];

    int currentStepIndex = 0;
    switch (status.toLowerCase()) {
      case 'confirmed':
        currentStepIndex = 1;
        break;
      case 'preparing':
        currentStepIndex = 2;
        break;
      case 'out for delivery':
        currentStepIndex = 3;
        break;
      case 'delivered':
        currentStepIndex = 4;
        break;
      default:
        currentStepIndex = 0;
    }

    final currentStep = steps[currentStepIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Progress',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  'Step ${currentStepIndex + 1} of 5',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Horizontal Stepper Bar
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isEven) {
                final stepIdx = index ~/ 2;
                final isPassed = stepIdx <= currentStepIndex;
                final isCurrent = stepIdx == currentStepIndex;
                final step = steps[stepIdx];

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPassed
                            ? (isCurrent ? const Color(0xFF10B981) : const Color(0xFF047857))
                            : const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: isPassed ? Colors.transparent : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Icon(
                        step['icon'] as IconData,
                        size: 16,
                        color: isPassed ? Colors.white : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 50,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          step['name']?.toString() ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: isPassed ? FontWeight.w700 : FontWeight.w500,
                            color: isPassed ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                final lineIdx = index ~/ 2;
                final isLinePassed = lineIdx < currentStepIndex;

                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isLinePassed ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }
            }),
          ),
          const SizedBox(height: 14),

          // Current Status Highlight Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${currentStep['name']}: ${currentStep['sub']}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
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

  void _showReorderDialog(BuildContext context, WidgetRef ref, List<dynamic> items,
      List<Map<String, dynamic>> currentProducts, {String? orderType}) {
    final bool isQuick = orderType == 'Quick Order';
    final Map<String, Map<String, dynamic>> selectedItems = {};
    for (var item in items) {
      final pid = item['product_id']?.toString() ?? '';
      if (pid.isEmpty) continue;
      final currentProd = currentProducts.firstWhere(
        (p) => (p['id']?.toString() ?? '') == pid,
        orElse: () => {},
      );
      if (currentProd.isEmpty || !ProductHelper.isEnabled(currentProd)) {
        continue;
      }
      final bool isAvail = ProductHelper.isAvailable(currentProd, isOrderNow: isQuick);
      if (!isAvail) continue;

      final double stockNum = ProductHelper.getStock(currentProd, isOrderNow: isQuick);
      final price = ProductHelper.getPrice(currentProd, isOrderNow: isQuick);

      final double rawQty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
      final double availableStock = stockNum;
      if (availableStock <= 0) continue;
      final double safeQty = (rawQty > availableStock) ? availableStock : rawQty;
      if (safeQty <= 0) continue;

      selectedItems[pid] = {
        'product_id': pid,
        'product_name': currentProd['name'] ?? item['product_name'] ?? 'N/A',
        'price': price,
        'unit': currentProd['unit'] ?? item['unit'] ?? '',
        'quantity': safeQty,
        'stock': stockNum,
      };
    }

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('None of the items are currently available for purchase.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            List<double> getQuantitySteps(String unit) {
              final u = unit.toLowerCase();
              if (u.contains('kg')) {
                return [0.25, 0.5, 1.0, 2.0, 5.0];
              } else if (u.contains('doz')) {
                return [0.5, 1.0, 1.5, 2.0, 3.0];
              } else {
                return [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];
              }
            }

            String formatQtyText(double qty, String unit) {
              final u = unit.toLowerCase();
              if (u.contains('kg')) {
                if (qty < 1.0) {
                  return '${(qty * 1000).toStringAsFixed(0)} g';
                } else {
                  return '${qty.toStringAsFixed(qty == qty.toInt() ? 0 : 1)} kg';
                }
              } else if (u.contains('doz')) {
                return '$qty Dozen';
              } else {
                return '${qty.toStringAsFixed(qty == qty.toInt() ? 0 : 1)} $unit';
              }
            }

            return Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))
                ],
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isQuick ? 'Reorder Express Items' : 'Reorder Items',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review and edit item quantities before adding to cart:',
                      style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
                    ),
                    const Divider(height: 24),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: selectedItems.values.map((item) {
                            final pid = item['product_id']?.toString() ?? '';
                            final name = item['product_name']?.toString() ?? '';
                            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                            final unit = item['unit']?.toString() ?? 'kg';
                            final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₹${price.toStringAsFixed(2)} / $unit',
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF64748B)),
                                        onPressed: () {
                                          setState(() {
                                            final steps = getQuantitySteps(unit);
                                            final prevIndex = steps.lastIndexWhere((s) => s < qty);
                                            if (prevIndex != -1) {
                                              item['quantity'] = steps[prevIndex];
                                            } else {
                                              selectedItems.remove(pid);
                                            }
                                          });
                                        },
                                      ),
                                      Text(
                                        formatQtyText(qty, unit),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.add_circle_outline_rounded,
                                          color: (item['stock'] != null && qty >= (item['stock'] as num).toDouble())
                                              ? const Color(0xFFCBD5E1)
                                              : const Color(0xFF10B981),
                                        ),
                                        onPressed: (item['stock'] != null && qty >= (item['stock'] as num).toDouble())
                                            ? null
                                            : () {
                                                setState(() {
                                                  final steps = getQuantitySteps(unit);
                                                  final nextIndex = steps.indexWhere((s) => s > qty);
                                                  double nextQty = (nextIndex != -1) ? steps[nextIndex] : qty + 1.0;
                                                  if (item['stock'] != null && nextQty > (item['stock'] as num).toDouble()) {
                                                    nextQty = (item['stock'] as num).toDouble();
                                                  }
                                                  item['quantity'] = nextQty;
                                                });
                                              },
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: selectedItems.isEmpty
                          ? null
                          : () {
                              final cartNotifier = ref.read(isQuick ? quickCartProvider.notifier : cartProvider.notifier);
                              for (var item in selectedItems.values) {
                                cartNotifier.addItem(
                                  productId: item['product_id']?.toString() ?? '',
                                  productName: item['product_name']?.toString() ?? '',
                                  price: (item['price'] as num?)?.toDouble() ?? 0.0,
                                  unit: item['unit']?.toString() ?? 'kg',
                                  quantity: (item['quantity'] as num?)?.toDouble() ?? 1.0,
                                  isOrderNow: isQuick,
                                );
                              }

                              ref.read(cartOriginTabProvider.notifier).state = 3;
                              ref.read(isViewingQuickOrderCartProvider.notifier).state = isQuick;
                              ref.read(activeTabProvider.notifier).state = 1;

                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);

                              navigator.pop();
                              if (navigator.canPop()) {
                                navigator.pop();
                              } else {
                                navigator.pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                                  (route) => false,
                                );
                              }

                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Items added to cart successfully!'),
                                  backgroundColor: Color(0xFF0F172A),
                                ),
                              );
                            },
                      child: const Text(
                        'CONFIRM & GO TO CART',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static bool _isItemUnavailable(dynamic item) {
    if (item == null) return false;
    final isAvail = item['is_available'];
    if (isAvail == false || isAvail == 0 || isAvail == '0' || isAvail == 'false') {
      return true;
    }
    final double totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0.0;
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
    if (totalPrice <= 0.001 && (price > 0 || qty > 0)) {
      return true;
    }
    return false;
  }

  Widget _buildErrorOrOfflineState(BuildContext context, WidgetRef ref, Object err) {
    final errStr = err.toString();
    final bool isOffline = errStr.contains('SocketException') ||
        errStr.contains('ClientException') ||
        errStr.contains('Network') ||
        errStr.contains('Failed host lookup') ||
        errStr.contains('TimeoutException');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isOffline ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOffline ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
                size: 52,
                color: isOffline ? const Color(0xFF3B82F6) : const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isOffline ? "You're Offline" : 'Order Details Unavailable',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isOffline
                  ? 'Your order was placed and stored locally. It will automatically sync to our servers as soon as your internet connection is restored.'
                  : 'Unable to load order details at the moment: $errStr',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textPrimary,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    ref.invalidate(orderDetailsProvider(orderId));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


