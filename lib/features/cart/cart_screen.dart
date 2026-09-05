import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cart_provider.dart';
import '../catalog/catalog_provider.dart';
import '../checkout/checkout_screen.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/utils/string_utils.dart';
import '../../core/utils/product_helper.dart';

String _formatCurrency(double amount) {
  if ((amount - amount.roundToDouble()).abs() < 0.01) {
    return amount.round().toString();
  }
  final s = amount.toStringAsFixed(2);
  if (s.endsWith('.00')) {
    return amount.round().toString();
  }
  return s;
}

class CartScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  final VoidCallback? onBrowseClicked;

  const CartScreen({super.key, this.showAppBar = true, this.onBrowseClicked});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  void _deleteItem(String productId) {
    HapticFeedback.lightImpact();
    ref.read(activeCartNotifierProvider).removeItem(productId);
  }

  void _readjustAllExcess(WidgetRef ref, CartState cart, List<Map<String, dynamic>> allProducts) {
    int count = 0;
    for (final item in cart.items.values) {
      final matching = allProducts.firstWhere(
        (p) => p['id']?.toString().trim().toLowerCase() == item.productId.trim().toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (matching.isNotEmpty) {
        final rawSt = item.isOrderNow ? matching['order_now_stock'] : matching['stock'];
        final double? st = (rawSt is num) ? rawSt.toDouble() : double.tryParse(rawSt?.toString() ?? '');
        if (st != null && st > 0 && item.quantity > st) {
          ref.read(activeCartNotifierProvider).updateQuantity(item.productId, st);
          count++;
        }
      }
    }
    if (count > 0) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Readjusted $count item(s) to maximum available stock. Please review before proceeding.'),
          backgroundColor: const Color(0xFFD97706),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showRoundingExplanation(BuildContext context, double roundingDiff, double baseCharge) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF1B3624)),
              const SizedBox(width: 8),
              Text(
                'Auto Round-off Details',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Orderkart applies automatic rounding to the nearest multiple of 5 for a clean payment receipt.',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Base Delivery Fee:'),
                  Text('₹${baseCharge.toStringAsFixed(0)}'),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('POS Round-off Adj:'),
                  Text('+ ₹${roundingDiff.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Delivery Line:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('₹${(baseCharge + roundingDiff).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(activeCartProvider);
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final bool isClosed = isStoreClosed(settings);

    final allProducts = ref.watch(allProductsProvider).valueOrNull ?? [];
    bool hasStockOutItems = false;
    bool hasExcessQuantityItems = false;

    // SAFEGUARD: If catalog is still loading or empty, do NOT falsely flag items as out-of-stock!
    if (allProducts.isNotEmpty) {
      for (final it in cart.items.values) {
        final matching = allProducts.firstWhere(
          (p) => p['id']?.toString().trim().toLowerCase() == it.productId.trim().toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        if (matching.isEmpty) {
          // If product metadata is still streaming or not yet matched, keep existing cart item available
          continue;
        }

        final bool isOrderNow = it.isOrderNow;
        final double st = ProductHelper.getStock(matching, isOrderNow: isOrderNow);
        final bool avail = ProductHelper.isAvailable(matching, isOrderNow: isOrderNow);

        if (!avail) {
          hasStockOutItems = true;
        } else if (st > 0 && it.quantity > st) {
          hasExcessQuantityItems = true;
        }
      }
    }

    // OrderKart clean modern theme
    const bgScaffold = Color(0xFFF8FAFC);
    const textColorPrimary = Color(0xFF0F172A);
    const textColorSecondary = Color(0xFF64748B);
    const borderPillColor = Color(0xFFE2E8F0);

    Widget content;

    if (cart.items.isEmpty) {
      content = Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 80,
                      color: textColorSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your cart is empty',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColorPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add fresh vegetables and fruits to get started!',
                      style: GoogleFonts.inter(color: textColorSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: textColorPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: widget.onBrowseClicked,
                      icon: const Icon(Icons.shopping_basket_rounded),
                      label: Text(
                        'BROWSE PRODUCTS',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      content = Column(
        children: [
          if (hasStockOutItems)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Some items in your cart just went out of stock. Please remove them to proceed.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF991B1B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (hasExcessQuantityItems)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Color(0xFFD97706), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Items exceed available store stock',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF92400E),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Some items have more quantity than available in store.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF78350F),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _readjustAllExcess(ref, cart, allProducts),
                    child: const Text('Readjust All', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          if (cart.items.values.any((i) => i.isOrderNow)) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFEA580C), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚡ Quick Order — Express delivery in 1-2 hours today!',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF9A3412),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // List of items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: cart.items.length,
              itemBuilder: (context, index) {
                final item = cart.items.values.toList()[index];
                return _CartItemTile(
                  key: ValueKey(item.productId),
                  item: item,
                  onDelete: () => _deleteItem(item.productId),
                  onCustomSize: () => _showCustomSizeDialog(context, ref, item),
                );
              },
            ),
          ),
          
          // Bill summary & Checkout
          Container(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
            color: bgScaffold,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Items Total (',
                          style: GoogleFonts.inter(
                            color: textColorPrimary.withValues(alpha: 0.8),
                            fontSize: 15,
                          ),
                        ),
                        AnimatedCounter(
                          value: cart.itemCount,
                          style: GoogleFonts.inter(
                            color: textColorPrimary.withValues(alpha: 0.8),
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          ')',
                          style: GoogleFonts.inter(
                            color: textColorPrimary.withValues(alpha: 0.8),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    AnimatedCounter(
                      value: cart.subtotal,
                      prefix: '₹',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: textColorPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Delivery Fee',
                          style: GoogleFonts.inter(
                            color: textColorPrimary.withValues(alpha: 0.8),
                            fontSize: 15,
                          ),
                        ),
                        // Show info icon only when rounding is folded INTO delivery fee
                        if (cart.baseDeliveryCharge > 0 && cart.roundingDifference > 0.001) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              _showRoundingExplanation(
                                context,
                                cart.roundingDifference,
                                cart.baseDeliveryCharge,
                              );
                            },
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: textColorPrimary.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      cart.deliveryCharge == 0.0 ? 'Free' : '₹${_formatCurrency(cart.deliveryCharge)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: cart.deliveryCharge == 0.0 ? const Color(0xFF2E7D32) : textColorPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                // Show separate Round-off row when delivery is free but rounding applies
                if (cart.separateRoundingAdjustment > 0.001) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Round-off',
                            style: GoogleFonts.inter(
                              color: textColorPrimary.withValues(alpha: 0.8),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              _showRoundingExplanation(
                                context,
                                cart.separateRoundingAdjustment,
                                0.0,
                              );
                            },
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: textColorPrimary.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '₹${_formatCurrency(cart.separateRoundingAdjustment)}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: textColorPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(color: borderPillColor, height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Grand Total',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: textColorPrimary,
                      ),
                    ),
                    AnimatedCounter(
                      value: cart.grandTotal,
                      prefix: '₹',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: textColorPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Checkout Button
                Builder(
                  builder: (context) {
                    final bool isCheckoutBlocked = isClosed;
                    return SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCheckoutBlocked
                              ? const Color(0xFF94A3B8)
                              : (hasStockOutItems
                                  ? const Color(0xFF94A3B8)
                                  : (hasExcessQuantityItems ? const Color(0xFFD97706) : textColorPrimary)),
                          foregroundColor: Colors.white,
                          elevation: (hasStockOutItems || hasExcessQuantityItems) ? 4 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: isCheckoutBlocked
                            ? null
                            : (hasStockOutItems
                                ? () {
                                    HapticFeedback.heavyImpact();
                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded, color: Colors.white),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text('Please remove out-of-stock items before proceeding to checkout.'),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: Colors.red,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                : (hasExcessQuantityItems
                                    ? () {
                                        _readjustAllExcess(ref, cart, allProducts);
                                      }
                                    : () {
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            pageBuilder: (context, animation, secondaryAnimation) => const CheckoutScreen(),
                                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                              final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                                  .chain(CurveTween(curve: Curves.easeInOutCubic));
                                              return SlideTransition(
                                                position: animation.drive(tween),
                                                child: child,
                                              );
                                            },
                                            transitionDuration: const Duration(milliseconds: 350),
                                          ),
                                        );
                                      })),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isClosed
                                  ? 'Store is Closed'
                                  : (hasStockOutItems
                                      ? 'Remove Out-of-Stock Items'
                                      : (hasExcessQuantityItems ? 'Readjust Quantities to Continue' : 'Proceed to Checkout')),
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isCheckoutBlocked
                                  ? Icons.lock_outline_rounded
                                  : (hasStockOutItems
                                      ? Icons.warning_amber_rounded
                                      : (hasExcessQuantityItems ? Icons.tune_rounded : Icons.arrow_forward_rounded)),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),


              ],
            ),
          ),
        ],
      );
    }

    if (widget.showAppBar) {
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
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            title: Text(
              'Orderkart',
              style: GoogleFonts.outfit(
                color: textColorPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            centerTitle: true,
          ),
          body: content,
        ),
      );
    } else {
      return AmbientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(child: content),
        ),
      );
    }
  }

  void _showCustomSizeDialog(BuildContext context, WidgetRef ref, CartItem item) {
    final allProducts = ref.read(allProductsProvider).valueOrNull ?? [];
    final matchingProduct = allProducts.firstWhere(
      (p) => p['id']?.toString().trim().toLowerCase() == item.productId.trim().toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return CustomSizeDialog(
          item: item,
          product: matchingProduct.isNotEmpty ? matchingProduct : null,
          ref: ref,
        );
      },
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  final VoidCallback onDelete;
  final VoidCallback onCustomSize;

  const _CartItemTile({
    super.key,
    required this.item,
    required this.onDelete,
    required this.onCustomSize,
  });

  String _formatQuantity(double qty, String unit) {
    final u = unit.toLowerCase();
    if (u.contains('kg')) {
      if (qty < 1.0) {
        return '${(qty * 1000).round()} g';
      } else {
        final hasTwoDecimals = (qty * 100).round() % 10 != 0;
        final hasOneDecimal = (qty * 10).round() % 10 != 0;
        return '${qty.toStringAsFixed(hasTwoDecimals ? 2 : (hasOneDecimal ? 1 : 0))} kg';
      }
    } else if (u.contains('doz')) {
      return '$qty Dozen';
    } else {
      return '${qty.toStringAsFixed(qty == qty.toInt() ? 0 : 1)} $unit';
    }
  }

  double _getStepSize(String unit) {
    final unitLower = unit.toLowerCase();
    if (unitLower == 'kg') return 0.25;
    if (unitLower == 'g' || unitLower == 'gram' || unitLower == 'grams') return 250.0;
    return 1.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const textColorPrimary = Color(0xFF0F172A);
    const textColorSecondary = Color(0xFF64748B);
    const bgPill = Color(0xFFF1F5F9);
    const borderPillColor = Color(0xFFE2E8F0);

    final allProducts = ref.watch(allProductsProvider).valueOrNull ?? [];
    final matchingProduct = allProducts.firstWhere(
      (p) => p['id']?.toString().trim().toLowerCase() == item.productId.trim().toLowerCase(),
      orElse: () => <String, dynamic>{},
    );

    final bool isOrderNow = item.isOrderNow;
    final double availableStock = ProductHelper.getStock(matchingProduct, isOrderNow: isOrderNow);
    final bool isAvail = ProductHelper.isAvailable(matchingProduct, isOrderNow: isOrderNow);

    // Declare out of stock if unavailable, disabled, or stock <= 0
    final bool isStockOut = matchingProduct.isEmpty ? false : !isAvail;

    final bool isExcess = !isStockOut && availableStock > 0 && item.quantity > availableStock;

    final String? liveImagePath = matchingProduct['image_path'] as String? ?? matchingProduct['image_url'] as String?;
    final String? imageSource = (liveImagePath != null && liveImagePath.trim().isNotEmpty)
        ? liveImagePath
        : item.imagePath;
    final String imageUrl = getProductImage(item.productName, imageSource);

    return Dismissible(
      key: Key('cart_${item.productId}_${item.isOrderNow ? "q" : "n"}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red[700],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_sweep_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isStockOut ? const Color(0xFFFFF5F5) : (isExcess ? const Color(0xFFFFFDF8) : const Color(0xFFFFFFFF)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isStockOut ? const Color(0xFFEF4444) : (isExcess ? const Color(0xFFF59E0B) : borderPillColor),
            width: (isStockOut || isExcess) ? 1.8 : 1.0,
          ),
          boxShadow: isStockOut
              ? [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.22),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: const Color(0xFFFEF2F2).withValues(alpha: 0.9),
                    blurRadius: 8,
                    offset: Offset.zero,
                  ),
                ]
              : (isExcess
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isStockOut)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '⚠️ OUT OF STOCK',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else if (isExcess)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Only ${_formatQuantity(availableStock, item.unit)} available in stock.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(activeCartNotifierProvider).updateQuantity(item.productId, availableStock);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Adjusted ${item.productName} to available stock (${_formatQuantity(availableStock, item.unit)}).'),
                              backgroundColor: const Color(0xFF059669),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Readjust',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Product Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.network(
                          imageUrl,
                          width: 72,
                          height: 72,
                          cacheWidth: 216,
                          cacheHeight: 216,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.eco_rounded, color: Color(0xFF10B981), size: 28),
                          ),
                        ),
                        if (isStockOut)
                          Container(
                            width: 72,
                            height: 72,
                            color: Colors.black.withValues(alpha: 0.35),
                            child: const Center(
                              child: Icon(Icons.block_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Details & Controls
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name & Delete button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.productName,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.5,
                                  color: isStockOut ? const Color(0xFF991B1B) : textColorPrimary,
                                  decoration: isStockOut ? TextDecoration.lineThrough : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: onDelete,
                              child: const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: textColorSecondary,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Price per unit & Custom size button
                        Row(
                          children: [
                            Text(
                              '₹${_formatCurrency(item.price)}/${item.unit}',
                              style: GoogleFonts.inter(
                                color: isStockOut ? const Color(0xFFB91C1C) : textColorSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (!isStockOut) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: onCustomSize,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: borderPillColor),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.edit_note_rounded, size: 13, color: textColorPrimary),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Custom',
                                        style: GoogleFonts.inter(
                                          color: textColorPrimary,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Quantity selector & Total line price OR Remove Action
                        if (isStockOut)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                ),
                                onPressed: onDelete,
                                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                label: Text(
                                  'REMOVE ITEM',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                              Text(
                                'Unavailable',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFDC2626),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Capsule Selector
                              Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: bgPill,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderPillColor, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_rounded, color: textColorSecondary, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        final step = _getStepSize(item.unit);
                                        final nextQty = ((item.quantity - step) * 1000).round() / 1000.0;
                                        if (nextQty <= 0) {
                                          onDelete();
                                        } else {
                                          ref.read(activeCartNotifierProvider).updateQuantity(item.productId, nextQty);
                                        }
                                      },
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: Text(
                                        _formatQuantity(item.quantity, item.unit),
                                        style: GoogleFonts.inter(
                                          color: textColorPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                       icon: Icon(
                                         Icons.add_rounded,
                                         color: (availableStock > 0 && item.quantity >= availableStock)
                                             ? textColorSecondary.withValues(alpha: 0.3)
                                             : textColorSecondary,
                                         size: 14,
                                       ),
                                       padding: EdgeInsets.zero,
                                       constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                       onPressed: () {
                                         HapticFeedback.lightImpact();
                                         final step = _getStepSize(item.unit);
                                         final nextQty = ((item.quantity + step) * 1000).round() / 1000.0;
                                         if (availableStock > 0 && nextQty > availableStock) {
                                           HapticFeedback.heavyImpact();
                                           ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                           if (item.quantity < availableStock) {
                                             ref.read(activeCartNotifierProvider).updateQuantity(item.productId, availableStock);
                                             ScaffoldMessenger.of(context).showSnackBar(
                                               SnackBar(
                                                 content: Text('Cannot add more. Set to maximum available stock: ${_formatQuantity(availableStock, item.unit)}'),
                                                 backgroundColor: const Color(0xFFD97706),
                                                 duration: const Duration(seconds: 3),
                                               ),
                                             );
                                           } else {
                                             ScaffoldMessenger.of(context).showSnackBar(
                                               SnackBar(
                                                 content: Text('Maximum available stock reached (${_formatQuantity(availableStock, item.unit)}). Cannot add more.'),
                                                 backgroundColor: const Color(0xFFDC2626),
                                                 duration: const Duration(seconds: 3),
                                               ),
                                             );
                                           }
                                           return;
                                         }
                                         ref.read(activeCartNotifierProvider).updateQuantity(item.productId, nextQty);
                                       },
                                     ),
                                  ],
                                ),
                              ),

                              // Line price
                              Text(
                                '₹${_formatCurrency(item.totalPrice)}',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: textColorPrimary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class CustomSizeDialog extends StatefulWidget {
  final CartItem item;
  final Map<String, dynamic>? product;
  final WidgetRef ref;

  const CustomSizeDialog({
    super.key,
    required this.item,
    this.product,
    required this.ref,
  });

  @override
  State<CustomSizeDialog> createState() => _CustomSizeDialogState();
}

class _CustomSizeDialogState extends State<CustomSizeDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late String _selectedUnit;
  late List<String> _unitOptions;

  @override
  void initState() {
    super.initState();
    final unitLower = widget.item.unit.toLowerCase();
    if (unitLower == 'kg') {
      _unitOptions = ['kg', 'g'];
      final grams = (widget.item.quantity * 1000).round();
      if (widget.item.quantity < 1.0 && (grams % 50 == 0 || grams % 10 == 0 || grams % 100 == 0)) {
        _selectedUnit = 'g';
        _controller.text = grams.toString();
      } else {
        _selectedUnit = 'kg';
        _controller.text = widget.item.quantity.toString();
      }
    } else if (unitLower == 'dozen' || unitLower == 'doz') {
      _unitOptions = ['dozen', 'pcs'];
      if (widget.item.quantity < 1.0) {
        _selectedUnit = 'pcs';
        _controller.text = (widget.item.quantity * 12).round().toString();
      } else {
        _selectedUnit = 'dozen';
        _controller.text = widget.item.quantity.toString();
      }
    } else {
      _unitOptions = [widget.item.unit];
      _selectedUnit = widget.item.unit;
      if (widget.item.quantity == widget.item.quantity.toInt()) {
        _controller.text = widget.item.quantity.toInt().toString();
      } else {
        _controller.text = widget.item.quantity.toString();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _availableStock {
    final p = widget.product;
    if (p == null) return null;
    final isQuick = widget.item.isOrderNow;
    final raw = isQuick ? p['order_now_stock'] : p['stock'];
    final num? n = (raw is num) ? raw : num.tryParse(raw?.toString() ?? '');
    return n?.toDouble();
  }

  double get _enteredQty {
    final val = double.tryParse(_controller.text.trim().replaceAll(',', '.')) ?? 0.0;
    if (_selectedUnit == 'g') {
      return ((val / 1000.0) * 1000).round() / 1000.0;
    } else if (_selectedUnit == 'pcs' &&
        (widget.item.unit.toLowerCase() == 'dozen' ||
            widget.item.unit.toLowerCase() == 'doz')) {
      return ((val / 12.0) * 1000).round() / 1000.0;
    }
    return ((val) * 1000).round() / 1000.0;
  }

  String _formatQuantity(double qty, String unit) {
    final u = unit.toLowerCase();
    if (u.contains('kg')) {
      if (qty < 1.0) {
        return '${(qty * 1000).round()} g';
      } else {
        final hasTwoDecimals = (qty * 100).round() % 10 != 0;
        final hasOneDecimal = (qty * 10).round() % 10 != 0;
        return '${qty.toStringAsFixed(hasTwoDecimals ? 2 : (hasOneDecimal ? 1 : 0))} kg';
      }
    } else if (u.contains('doz')) {
      return '$qty Dozen';
    } else {
      return '${qty.toStringAsFixed(qty == qty.toInt() ? 0 : 1)} $unit';
    }
  }

  @override
  Widget build(BuildContext context) {
    const textColorPrimary = Color(0xFF3D1B0B);
    const textColorSecondary = Color(0xFF8F8077);
    const borderPillColor = Color(0xFFE2D6CA);

    final double sellingPrice = widget.item.price;
    final double mrp = (widget.product?['market_price'] as num?)?.toDouble() ?? sellingPrice;

    final double enteredQty = _enteredQty;
    final double totalSellingPrice = sellingPrice * enteredQty;
    final double totalMrp = mrp * enteredQty;
    final double totalSavings = totalMrp > totalSellingPrice ? totalMrp - totalSellingPrice : 0.0;

    return AlertDialog(
      backgroundColor: const Color(0xFFFAF6F2),
      title: Text(
        'Custom Size: ${widget.item.productName}',
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColorPrimary),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_availableStock != null && _availableStock! > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF166534)),
                          const SizedBox(width: 6),
                          Text(
                            'Available Stock: ${_formatQuantity(_availableStock!, widget.item.unit)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF166534),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (_selectedUnit == 'g' && widget.item.unit.toLowerCase().contains('kg')) {
                              _controller.text = (_availableStock! * 1000).round().toString();
                            } else {
                              _controller.text = (_availableStock! % 1 == 0)
                                  ? _availableStock!.toInt().toString()
                                  : _availableStock!.toStringAsFixed(2);
                            }
                          });
                        },
                        child: Text(
                          'Set to Max',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF166534),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(color: textColorPrimary),
                      decoration: InputDecoration(
                        labelText: 'Enter Quantity',
                        labelStyle: GoogleFonts.inter(color: textColorSecondary),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: textColorPrimary, width: 2),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Required';
                        }
                        final d = double.tryParse(val.trim().replaceAll(',', '.'));
                        if (d == null || d <= 0) {
                          return 'Must be > 0';
                        }
                        if (_availableStock != null && _availableStock! > 0 && _enteredQty > _availableStock!) {
                          return 'Exceeds stock (Max: ${_formatQuantity(_availableStock!, widget.item.unit)})';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_unitOptions.length > 1)
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        dropdownColor: const Color(0xFFFAF6F2),
                        style: GoogleFonts.inter(color: textColorPrimary, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                        items: _unitOptions
                            .map((opt) => DropdownMenuItem(
                                  value: opt,
                                  child: Text(opt),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedUnit = val;
                            });
                          }
                        },
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        _selectedUnit,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold, fontSize: 18, color: textColorPrimary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                color: const Color(0xFFFDFBF8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: borderPillColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildCalcRow('Selling Price', '₹${sellingPrice.toStringAsFixed(2)} / ${widget.item.unit}', isHeader: false),
                      if (mrp > sellingPrice) ...[
                        const SizedBox(height: 8),
                        _buildCalcRow('MRP', '₹${mrp.toStringAsFixed(2)} / ${widget.item.unit}', isHeader: false),
                      ],
                      const Divider(height: 24),
                      _buildCalcRow(
                        'Total Qty (Base)',
                        '${enteredQty.toStringAsFixed(3)} ${widget.item.unit}',
                        isHeader: false,
                      ),
                      const SizedBox(height: 8),
                      _buildCalcRow(
                        'Total Selling Price',
                        '₹${totalSellingPrice.toStringAsFixed(2)}',
                        isHeader: true,
                        color: textColorPrimary,
                      ),
                      if (totalSavings > 0) ...[
                        const SizedBox(height: 8),
                        _buildCalcRow(
                          'You Save',
                          '₹${totalSavings.toStringAsFixed(2)}',
                          isHeader: true,
                          color: const Color(0xFF2E7D32),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: totalMrp > 0 ? (totalSellingPrice / totalMrp).clamp(0.0, 1.0) : 1.0,
                            backgroundColor: Colors.green.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'You save ${(totalSavings / totalMrp * 100).toStringAsFixed(0)}% on this custom size!',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.inter(color: textColorSecondary, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: textColorPrimary,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              double finalQty = _enteredQty;
              if (_availableStock != null && _availableStock! > 0 && finalQty > _availableStock!) {
                finalQty = _availableStock!;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Adjusted ${widget.item.productName} to maximum available stock (${_formatQuantity(_availableStock!, widget.item.unit)}).'),
                    backgroundColor: const Color(0xFFD97706),
                  ),
                );
              }
              widget.ref.read(activeCartNotifierProvider).updateQuantity(widget.item.productId, finalQty);
              Navigator.pop(context);
            }
          },
          child: Text('Apply', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildCalcRow(String label, String value, {required bool isHeader, Color? color}) {
    final style = isHeader
        ? GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: color)
        : GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8F8077));
    final valStyle = isHeader
        ? GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: color)
        : GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: const Color(0xFF3D1B0B));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: valStyle),
      ],
    );
  }
}

class AnimatedCounter extends StatefulWidget {
  final num value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int? decimalPlaces;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.decimalPlaces,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _oldValue = 0.0;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: _oldValue, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value.toDouble();
      _animation = Tween<double>(begin: _oldValue, end: widget.value.toDouble()).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double val = _animation.value;
        String formatted;
        if (widget.decimalPlaces != null) {
          formatted = val.toStringAsFixed(widget.decimalPlaces!);
        } else if ((val - val.roundToDouble()).abs() < 0.01) {
          formatted = val.round().toString();
        } else {
          final s = val.toStringAsFixed(2);
          formatted = s.endsWith('.00') ? val.round().toString() : s;
        }
        return Text(
          '${widget.prefix}$formatted${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}
