import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cart_provider.dart';
import '../checkout/checkout_screen.dart';
import '../catalog/catalog_provider.dart';
import '../../core/widgets/ambient_background.dart';

class CartScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  final VoidCallback? onBrowseClicked;

  const CartScreen({super.key, this.showAppBar = true, this.onBrowseClicked});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> with TickerProviderStateMixin {
  final Set<String> _animatingOutIds = {};

  void _deleteItemWithAnimation(String productId) {
    if (_animatingOutIds.contains(productId)) return;
    setState(() {
      _animatingOutIds.add(productId);
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(activeCartNotifierProvider).removeItem(productId);
        setState(() {
          _animatingOutIds.remove(productId);
        });
      }
    });
  }



  // Helper to format quantity for display on the right side
  String _formatCartItemQuantity(double qty, String unit) {
    final unitLower = unit.toLowerCase();
    if (unitLower == 'kg') {
      if (qty == 0.25) return '250 g';
      if (qty == 0.5) return '500 g';
      if (qty == 0.75) return '750 g';
      final s = qty.toString();
      if (s.endsWith('.0')) {
        return '${qty.toInt()} kg';
      }
      return '$qty kg';
    } else if (unitLower == 'g' || unitLower == 'gram' || unitLower == 'grams') {
      return '${qty.toInt()} g';
    } else if (unitLower == 'dozen' || unitLower == 'doz') {
      final pcs = (qty * 12).round();
      return '$pcs pcs';
    } else {
      if (qty == qty.toInt()) {
        return '${qty.toInt()} $unit';
      }
      return '${qty.toStringAsFixed(1)} $unit';
    }
  }

  void _showRoundingExplanation(BuildContext context, double roundingDiff, double baseCharge) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
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
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('POS Round-off Adj:'),
                  Text('₹${roundingDiff.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
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

  // Helper to get step size for calculations
  double _getStepSize(String unit) {
    final unitLower = unit.toLowerCase();
    if (unitLower == 'kg') return 0.25;
    if (unitLower == 'g' || unitLower == 'gram' || unitLower == 'grams') return 250.0;
    return 1.0;
  }

  String _getProductImage(String productName) {
    final n = productName.toLowerCase();
    if (n.contains('potato') || n.contains('aalu') || n.contains('batata')) {
      return 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('tomato') || n.contains('tamatar')) {
      return 'https://images.unsplash.com/photo-1595855759920-86582396756a?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('onion') || n.contains('pyaz') || n.contains('kanda')) {
      return 'https://images.unsplash.com/photo-1508747703725-719777637510?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('apple') || n.contains('seb')) {
      return 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('banana') || n.contains('kela')) {
      return 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('coriander') || n.contains('dhania') || n.contains('kothimbir')) {
      return 'https://images.unsplash.com/photo-1588879460618-9249e7d947d1?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('ginger') || n.contains('adrak') || n.contains('aadrak')) {
      return 'https://images.unsplash.com/photo-1599940824399-b87987ceb72a?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('beet') || n.contains('beetroot')) {
      return 'https://images.unsplash.com/photo-1593105544559-ecb03bf76f82?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('milk')) {
      return 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('paneer')) {
      return 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=600&q=80';
    }
    return 'https://images.unsplash.com/photo-1610397613050-59f7f1554d67?auto=format&fit=crop&w=600&q=80';
  }

  // Helper to get placeholder accent color
  Color _getAccentColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('apple') || n.contains('banana') || n.contains('orange') || n.contains('mango') || n.contains('fruit')) {
      return const Color(0xFFE65100); // Vibrant Citrus Orange
    } else if (n.contains('milk') || n.contains('paneer') || n.contains('dairy') || n.contains('cheese')) {
      return const Color(0xFF1565C0); // Royal Blue
    } else if (n.contains('coriander') || n.contains('ginger') || n.contains('herbs') || n.contains('adrak') || n.contains('dhania')) {
      return const Color(0xFF0EA5E9); // Sky Blue / Herb Accent
    } else {
      return const Color(0xFF388E3C); // Fresh Leaf Green (Vegetables)
    }
  }

  // Helper to get placeholder icon
  IconData _getPlaceholderIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('milk') || n.contains('paneer') || n.contains('dairy') || n.contains('cheese')) {
      return Icons.local_drink_rounded;
    } else if (n.contains('apple') || n.contains('banana') || n.contains('orange') || n.contains('mango')) {
      return Icons.eco_rounded;
    } else {
      return Icons.shopping_bag_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawIsQuick = ref.watch(isViewingQuickOrderCartProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final isQuickOrderClosed = isOrderNowClosed(settingsAsync.valueOrNull);
    final isQuick = isQuickOrderClosed ? false : rawIsQuick;

    final toggleSelector = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(isViewingQuickOrderCartProvider.notifier).state = false;
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: !isQuick ? const Color(0xFF1B3624) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Normal Delivery',
                    style: GoogleFonts.inter(
                      color: !isQuick ? Colors.white : const Color(0xFF475569),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: isQuickOrderClosed
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Quick Order is currently closed.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    : () {
                        HapticFeedback.lightImpact();
                        ref.read(isViewingQuickOrderCartProvider.notifier).state = true;
                      },
                child: Container(
                  decoration: BoxDecoration(
                    color: isQuick ? const Color(0xFF1B3624) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: isQuick ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                        size: 15,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Quick Order',
                        style: GoogleFonts.inter(
                          color: isQuick ? Colors.white : const Color(0xFF475569),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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

    final cart = ref.watch(activeCartProvider);
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final bool isClosed = isStoreClosed(settings);

    // Check if any items in the cart are out of stock or have insufficient stock
    bool hasOutOfStockItem = false;
    for (final item in cart.items.values) {
      final productState = ref.watch(productDetailsProvider(item.productId));
      productState.whenData((product) {
        if (product != null) {
          final isAvailable = product['is_available'] as bool? ?? true;
          if (!isAvailable) {
            hasOutOfStockItem = true;
          }
          final descriptionStr = product['description']?.toString() ?? '';
          if (descriptionStr.isNotEmpty && descriptionStr.startsWith('{')) {
            try {
              final descObj = jsonDecode(descriptionStr);
              if (descObj['stock'] != null) {
                final double stock = (descObj['stock'] as num).toDouble();
                if (item.quantity > stock) {
                  hasOutOfStockItem = true;
                }
              }
            } catch (_) {}
          }
        }
      });
    }

    // OrderKart clean modern theme
    const bgScaffold = Color(0xFFF8FAFC);
    const bgCard = Color(0xFFFFFFFF);
    const textColorPrimary = Color(0xFF0F172A);
    const textColorSecondary = Color(0xFF64748B);
    const bgPill = Color(0xFFF1F5F9);
    const borderPillColor = Color(0xFFE2E8F0);

    Widget content;

    if (cart.items.isEmpty) {
      content = Column(
        children: [
          toggleSelector,
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
          toggleSelector,
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
                final productAsync = ref.watch(productDetailsProvider(item.productId));
                final accentColor = _getAccentColor(item.productName);
                final isDeleting = _animatingOutIds.contains(item.productId);
                
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isDeleting ? 0.0 : 1.0,
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: isDeleting
                        ? const SizedBox(width: double.infinity, height: 0)
                        : Dismissible(
                            key: Key(item.productId),
                            direction: DismissDirection.endToStart,
                            onDismissed: (direction) {
                              ref.read(activeCartNotifierProvider).removeItem(item.productId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${item.productName} removed from cart'),
                                  action: SnackBarAction(
                                    label: 'UNDO',
                                    textColor: Colors.greenAccent,
                                    onPressed: () {
                                      ref.read(activeCartNotifierProvider).addItem(
                                        productId: item.productId,
                                        productName: item.productName,
                                        price: item.price,
                                        unit: item.unit,
                                        quantity: item.quantity,
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red[700],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.delete_sweep_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: bgCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderPillColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Image / Placeholder
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: productAsync.maybeWhen(
                                        data: (product) {
                                          final imgPath = product?['image_path']?.toString() ?? product?['image_url']?.toString();
                                          final finalImgUrl = (imgPath != null && imgPath.isNotEmpty)
                                              ? imgPath
                                              : _getProductImage(item.productName);
                                          return Image.network(
                                            finalImgUrl,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _buildPlaceholder(item.productName, accentColor),
                                          );
                                        },
                                        orElse: () => Image.network(
                                          _getProductImage(item.productName),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _buildPlaceholder(item.productName, accentColor),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Details and Controls
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Name and Delete button
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.productName,
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: textColorPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  _deleteItemWithAnimation(item.productId);
                                                },
                                                child: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: textColorSecondary,
                                                  size: 22,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          
                                          // Price/Unit and Custom Size Button
                                          Row(
                                            children: [
                                              Text(
                                                '₹${item.price.toStringAsFixed(0)}/${item.unit}',
                                                style: GoogleFonts.inter(
                                                  color: textColorSecondary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              InkWell(
                                                onTap: () {
                                                  _showCustomSizeDialog(context, ref, item, productAsync.value);
                                                },
                                                borderRadius: BorderRadius.circular(12),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: borderPillColor),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.edit_note_rounded, size: 14, color: textColorPrimary),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Custom Size',
                                                        style: GoogleFonts.inter(
                                                          color: textColorPrimary,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          
                                          // Stock Warning Badge
                                          productAsync.maybeWhen(
                                            data: (product) {
                                              if (product == null) return const SizedBox.shrink();
                                              final isAvailable = product['is_available'] as bool? ?? true;
                                              double stock = double.infinity;
                                              final descriptionStr = product['description']?.toString() ?? '';
                                              if (descriptionStr.isNotEmpty && descriptionStr.startsWith('{')) {
                                                try {
                                                  final descObj = jsonDecode(descriptionStr);
                                                  if (descObj['stock'] != null) {
                                                    stock = (descObj['stock'] as num).toDouble();
                                                  }
                                                } catch (_) {}
                                              }
                                              
                                              if (!isAvailable) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(top: 6.0),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 14),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Out of Stock',
                                                        style: GoogleFonts.inter(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                              
                                              if (item.quantity > stock) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(top: 6.0),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Insufficient Stock (Max: ${stock.toStringAsFixed(0)})',
                                                        style: GoogleFonts.inter(color: Colors.orange[800], fontSize: 12, fontWeight: FontWeight.bold),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                            orElse: () => const SizedBox.shrink(),
                                          ),
                                          const SizedBox(height: 12),
                                          
                                          // Quantity selector and total
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Capsule Selector
                                              Container(
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: bgPill,
                                                  borderRadius: BorderRadius.circular(24),
                                                  border: Border.all(color: borderPillColor, width: 1),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.remove_rounded, color: textColorSecondary, size: 16),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                      onPressed: () {
                                                        HapticFeedback.lightImpact();
                                                        final step = _getStepSize(item.unit);
                                                        final nextQty = item.quantity - step;
                                                        if (nextQty <= 0) {
                                                          _deleteItemWithAnimation(item.productId);
                                                        } else {
                                                          ref.read(activeCartNotifierProvider).updateQuantity(item.productId, nextQty);
                                                        }
                                                      },
                                                    ),
                                                    Text(
                                                      _formatCartItemQuantity(item.quantity, item.unit),
                                                      style: GoogleFonts.inter(
                                                        color: textColorPrimary,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.add_rounded, color: textColorSecondary, size: 16),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                      onPressed: () {
                                                        HapticFeedback.lightImpact();
                                                        final step = _getStepSize(item.unit);
                                                        ref.read(activeCartNotifierProvider).updateQuantity(item.productId, item.quantity + step);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              
                                              // Selected amount and price total
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    _formatCartItemQuantity(item.quantity, item.unit),
                                                    style: GoogleFonts.inter(
                                                      color: textColorSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 1),
                                                  Text(
                                                    '₹${(cart.adjustedItemPrices[item.productId] ?? item.totalPrice).toStringAsFixed(0)}',
                                                    style: GoogleFonts.outfit(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                      color: textColorPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
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
                      value: cart.roundedGrandTotal - cart.deliveryCharge,
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
                    ),
                    Text(
                      cart.deliveryCharge == 0.0 ? 'Free' : '₹${cart.deliveryCharge.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: cart.deliveryCharge == 0.0 ? const Color(0xFF2E7D32) : textColorPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
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
                      value: cart.roundedGrandTotal,
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
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (hasOutOfStockItem || isClosed) ? Colors.grey : textColorPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: (hasOutOfStockItem || isClosed) ? null : () {
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
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          hasOutOfStockItem 
                              ? 'Fix Out of Stock Items' 
                              : isClosed 
                                  ? 'Store is Closed' 
                                  : 'Proceed to Checkout',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          hasOutOfStockItem 
                              ? Icons.error_outline_rounded 
                              : isClosed 
                                  ? Icons.lock_outline_rounded 
                                  : Icons.arrow_forward_rounded,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
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

  Widget _buildPlaceholder(String name, Color accentColor) {
    return Container(
      width: 80,
      height: 80,
      color: accentColor.withValues(alpha: 0.12),
      child: Center(
        child: Icon(
          _getPlaceholderIcon(name),
          color: accentColor,
          size: 32,
        ),
      ),
    );
  }

  void _showCustomSizeDialog(BuildContext context, WidgetRef ref, CartItem item, Map<String, dynamic>? product) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return CustomSizeDialog(item: item, product: product, ref: ref);
      },
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
      if (widget.item.quantity < 1.0 && (widget.item.quantity * 1000) % 100 == 0) {
        _selectedUnit = 'g';
        _controller.text = (widget.item.quantity * 1000).toInt().toString();
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

  double get _enteredQty {
    final val = double.tryParse(_controller.text.trim()) ?? 0.0;
    if (_selectedUnit == 'g') {
      return val / 1000.0;
    } else if (_selectedUnit == 'pcs' &&
        (widget.item.unit.toLowerCase() == 'dozen' ||
            widget.item.unit.toLowerCase() == 'doz')) {
      return val / 12.0;
    }
    return val;
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
                        final d = double.tryParse(val.trim());
                        if (d == null || d <= 0) {
                          return 'Must be > 0';
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
                        initialValue: _selectedUnit,
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
              final double finalQty = _enteredQty;
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
  final int decimalPlaces;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.decimalPlaces = 0,
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
        return Text(
          '${widget.prefix}${_animation.value.toStringAsFixed(widget.decimalPlaces)}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}
