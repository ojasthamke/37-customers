import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'catalog_provider.dart';
import '../cart/cart_provider.dart';
import '../dashboard/home_screen.dart' show activeTabProvider, cartOriginTabProvider;
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/quantity_selector.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/animated_slashed_text.dart';

class OrderNowScreen extends ConsumerStatefulWidget {
  const OrderNowScreen({super.key});

  @override
  ConsumerState<OrderNowScreen> createState() => _OrderNowScreenState();
}

class _OrderNowScreenState extends ConsumerState<OrderNowScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _getProductTags(String productName) {
    final n = productName.toLowerCase();
    if (n.contains('mirchi') ||
        n.contains('chilli') ||
        n.contains('ginger') ||
        n.contains('aadrak') ||
        n.contains('adrak') ||
        n.contains('garlic') ||
        n.contains('lahsun')) {
      return ['Organic', 'Spicy'];
    }
    if (n.contains('apple') ||
        n.contains('banana') ||
        n.contains('mango') ||
        n.contains('orange') ||
        n.contains('fruit')) {
      return ['Organic', 'Sweet'];
    }
    return ['Organic', 'Fresh'];
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
    if (n.contains('coriander') ||
        n.contains('dhania') ||
        n.contains('kothimbir')) {
      return 'https://images.unsplash.com/photo-1588879460618-9249e7d947d1?auto=format&fit=crop&w=600&q=80';
    }
    if (n.contains('ginger') ||
        n.contains('adrak') ||
        n.contains('aadrak')) {
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

  String _formatSelectorQuantity(double qty, String unit) {
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
    } else {
      if (qty == qty.toInt()) {
        return '${qty.toInt()} $unit';
      }
      return '${qty.toStringAsFixed(1)} $unit';
    }
  }

  double _getStepSize(String unit) {
    final unitLower = unit.toLowerCase();
    if (unitLower == 'kg') return 0.25;
    if (unitLower == 'g' || unitLower == 'gram' || unitLower == 'grams') {
      return 250.0;
    }
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final orderNowStatus = getOrderNowStatus(settingsAsync.valueOrNull);

    if (orderNowStatus != OrderNowStatus.open) {
      final isComingSoon = orderNowStatus == OrderNowStatus.comingSoon;
      return Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE8F5E9),
                    Color(0xFFF5F2EB),
                    Color(0xFFFFF3E0),
                  ],
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                'Order Now ⚡',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF1B3624),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: GlassContainer(
                  borderRadius: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isComingSoon ? const Color(0xFFE0F2FE) : const Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isComingSoon ? const Color(0xFF7DD3FC) : const Color(0xFFFCA5A5),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          isComingSoon ? Icons.rocket_launch_rounded : Icons.lock_clock_rounded,
                          size: 48,
                          color: isComingSoon ? const Color(0xFF0284C7) : const Color(0xFFB91C1C),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        isComingSoon ? 'Coming Soon 🚀' : 'Quick Order Closed',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B3624),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isComingSoon
                            ? 'Quick Delivery (Order Now) is launching soon in your area! Get ready for lightning-fast delivery directly to your doorstep.'
                            : 'Quick Order (Order Now) is temporarily closed by the store. Please try again later or check standard scheduled delivery.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF475569),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
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

    final productsAsync = ref.watch(orderNowProductListProvider);
    final cartState = ref.watch(quickCartProvider);
    final cartItemCount = cartState.itemCount;
    final cartSubtotal = cartState.subtotal;

    return Stack(
      children: [
        // Ambient background gradient matching Home
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8F5E9), // Soft green
                  Color(0xFFF5F2EB), // Warm sand cream
                  Color(0xFFFFF3E0), // Peach tint
                ],
              ),
            ),
          ),
        ),
        // Soft Refraction Blobs with hardware-accelerated smooth radial gradients
        Positioned(
          top: 40,
          left: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFA5D6A7).withValues(alpha: 0.32),
                  const Color(0xFFA5D6A7).withValues(alpha: 0.12),
                  const Color(0xFFA5D6A7).withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: 350,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFCC80).withValues(alpha: 0.28),
                  const Color(0xFFFFCC80).withValues(alpha: 0.10),
                  const Color(0xFFFFCC80).withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // Main Scrollable Content
        RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(orderNowProductListProvider);
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // All Products Section Title
                Text(
                  'All Products',
                  style: GoogleFonts.playfairDisplay(
                    color: const Color(0xFF1B3624),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Products List
                productsAsync.when(
                  loading: () {
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: SkeletonLoader.listTile(),
                      ),
                    );
                  },
                  error: (err, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text('Error loading products: $err'),
                    ),
                  ),
                  data: (products) {
                    if (products.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bolt_rounded, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No quick order products currently available.',
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final p = products[index];
                        final double stock = (p['stock'] as num?)?.toDouble() ?? 0.0;
                        final isAvailable = (p['is_available'] == true ||
                                p['is_available'] == 1 ||
                                p['is_enabled'] == true) &&
                            stock > 0;
                        final name = p['name'] ?? '';
                        final price = (p['price'] as num?)?.toDouble() ?? 0.0;
                        final unit = p['unit'] ?? 'kg';

                        final tags = _getProductTags(name);
                        final dbImageUrl = (p['image_path'] as String?) ?? (p['image_url'] as String?);
                        final imageUrl = (dbImageUrl != null && dbImageUrl.trim().isNotEmpty)
                            ? dbImageUrl
                            : _getProductImage(name);

                        final existingCartItem = cartState.items[p['id']];
                        final isInCart = existingCartItem != null;

                        return GlassContainer(
                          margin: const EdgeInsets.only(bottom: 20),
                          borderRadius: 24,
                          padding: const EdgeInsets.all(18.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Left side: Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Tags
                                    Text(
                                      tags.join('  |  '),
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF2E6F40),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // Title
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        name,
                                        style: GoogleFonts.playfairDisplay(
                                          color: const Color(0xFF1B3624),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 21,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // Price & MRP Layout
                                    if (unit.toLowerCase().contains('kg')) ...[
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            '₹${(price / 4).toStringAsFixed(0)}/250g',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF1B3624),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 21,
                                            ),
                                          ),
                                          if (p['market_price'] != null &&
                                              (p['market_price'] as num).toDouble() > price) ...[
                                            const SizedBox(width: 8),
                                            AnimatedSlashedText(
                                              text: '₹${((p['market_price'] as num).toDouble() / 4).toStringAsFixed(0)}',
                                              style: GoogleFonts.inter(
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '₹${price.toStringAsFixed(0)} per kg',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF2E6F40),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (p['market_price'] != null &&
                                              (p['market_price'] as num).toDouble() > price) ...[
                                            const SizedBox(width: 8),
                                            AnimatedSlashedText(
                                              text: '₹${(p['market_price'] as num).toDouble().toStringAsFixed(0)}',
                                              style: GoogleFonts.inter(
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ] else ...[
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            '₹${price.toStringAsFixed(0)}/$unit',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF1B3624),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 21,
                                            ),
                                          ),
                                          if (p['market_price'] != null &&
                                              (p['market_price'] as num).toDouble() > price) ...[
                                            const SizedBox(width: 8),
                                            AnimatedSlashedText(
                                              text: '₹${(p['market_price'] as num).toDouble().toStringAsFixed(0)}',
                                              style: GoogleFonts.inter(
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Right side: Image & Action Button
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Product Image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      height: 100,
                                      width: 120,
                                      child: Image.network(
                                        imageUrl,
                                        height: 100,
                                        width: 120,
                                        cacheWidth: 360,
                                        cacheHeight: 300,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Image.network(
                                            _getProductImage(name),
                                            height: 100,
                                            width: 120,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                height: 100,
                                                width: 120,
                                                color: const Color(0xFFE8F5E9),
                                                child: const Icon(Icons.eco_rounded, color: Color(0xFF2E6F40), size: 36),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Button
                                  if (!isAvailable)
                                    SizedBox(
                                      height: 34,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[200],
                                          foregroundColor: Colors.grey[500],
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(17),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                        ),
                                        onPressed: null,
                                        child: Text(
                                          'OUT OF STOCK',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    )
                                  else if (!isInCart)
                                    SizedBox(
                                      height: 36,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1B3624),
                                          foregroundColor: Colors.white,
                                          elevation: 2,
                                          shadowColor: const Color(0xFF1B3624).withValues(alpha: 0.3),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                        ),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          showQuantitySelectionBottomSheet(
                                            context: context,
                                            ref: ref,
                                            product: Map<String, dynamic>.from(p)..['is_order_now'] = true,
                                          );
                                        },
                                        child: Text(
                                          'Add to Cart',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1B3624),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 14),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                            onPressed: () {
                                              HapticFeedback.lightImpact();
                                              final step = _getStepSize(unit);
                                              ref.read(quickCartProvider.notifier).updateQuantity(
                                                    p['id'],
                                                    existingCartItem.quantity - step,
                                                  );
                                            },
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              showQuantitySelectionBottomSheet(
                                                context: context,
                                                ref: ref,
                                                product: Map<String, dynamic>.from(p)..['is_order_now'] = true,
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                              child: Text(
                                                _formatSelectorQuantity(existingCartItem.quantity, unit),
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                            onPressed: () {
                                              HapticFeedback.lightImpact();
                                              showQuantitySelectionBottomSheet(
                                             context: context,
                                             ref: ref,
                                             product: Map<String, dynamic>.from(p)..['is_order_now'] = true,
                                           );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 90), // Space for floating cart bar
              ],
            ),
          ),
        ),

        // Floating Cart Bar (Matching Home)
        if (cartItemCount > 0)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildFloatingCartBar(cartItemCount, cartSubtotal),
          ),
      ],
    );
  }

  Widget _buildFloatingCartBar(int itemCount, double subtotal) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(cartOriginTabProvider.notifier).state = 2; // NOW is the origin
        final settingsAsync = ref.read(appSettingsProvider);
        final isClosed = isOrderNowClosed(settingsAsync.valueOrNull);
        if (isClosed) {
          ref.read(isViewingQuickOrderCartProvider.notifier).state = false;
        } else {
          ref.read(isViewingQuickOrderCartProvider.notifier).state = true;
        }
        ref.read(activeTabProvider.notifier).state = 1; // Switch to Cart tab
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF1B3624), // Deep Emerald Green
              Color(0xFF0D2517),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.6), // Gold Accent Border
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B3624).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: Color(0xFFE5C158),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$itemCount',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          itemCount == 1 ? " item" : " items",
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₹${subtotal.toStringAsFixed(subtotal.truncateToDouble() == subtotal ? 0 : 2)}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFE5C158),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    'VIEW CART',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1B3624),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF1B3624),
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
