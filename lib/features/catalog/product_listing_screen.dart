import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'catalog_provider.dart';
import 'product_details_screen.dart';
import '../../core/widgets/quantity_selector.dart';
import '../../core/utils/string_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/ambient_background.dart';

class ProductListingScreen extends ConsumerStatefulWidget {
  final String? initialCategoryId;
  final String? initialCategoryName;

  const ProductListingScreen({super.key, this.initialCategoryId, this.initialCategoryName});

  @override
  ConsumerState<ProductListingScreen> createState() => _ProductListingScreenState();
}

class _ProductListingScreenState extends ConsumerState<ProductListingScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(catalogFilterProvider.notifier).setCategory(widget.initialCategoryId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    try {
      ref.read(catalogFilterProvider.notifier).clear();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final currentFilters = ref.watch(catalogFilterProvider);
    final theme = Theme.of(context);

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1B3624),
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.initialCategoryName ?? 'Browse Products',
            style: GoogleFonts.outfit(
              color: const Color(0xFF1B3624),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: Column(
          children: [
          // Filter & Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Search bar
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search veggies, fruits...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(catalogFilterProvider.notifier).setSearch('');
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) {
                      final cleaned = val.trim();
                      if (cleaned.isNotEmpty) {
                        ref.read(catalogFilterProvider.notifier).setCategory(null);
                      }
                      ref.read(catalogFilterProvider.notifier).setSearch(cleaned);
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 12),
                
                // Categories Dropdown Filter
                Expanded(
                  flex: 2,
                  child: categoriesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => const Text('Error'),
                    data: (categories) {
                      return DropdownButtonFormField<String?>(
                        isExpanded: true,
                        value: categories.any((c) => c['id']?.toString() == currentFilters.categoryId) ? currentFilters.categoryId : null,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All', overflow: TextOverflow.ellipsis),
                          ),
                          ...categories.map((c) {
                            return DropdownMenuItem<String?>(
                              value: c['id']?.toString(),
                              child: Text(c['name']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          ref.read(catalogFilterProvider.notifier).setCategory(val);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Product List
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: productsAsync.when(
                loading: () => const Center(
                  key: ValueKey('loading'),
                  child: CircularProgressIndicator(),
                ),
                error: (err, stack) => Center(
                  key: const ValueKey('error'),
                  child: Text('Error loading products: $err'),
                ),
                data: (products) {
                  if (products.isEmpty) {
                    return Center(
                      key: const ValueKey('empty'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No products found matching criteria.',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  final availableProducts = <Map<String, dynamic>>[];
                  final unavailableProducts = <Map<String, dynamic>>[];

                  for (final p in products) {
                    final rawStockNum = (p['stock'] is num)
                        ? (p['stock'] as num).toDouble()
                        : double.tryParse(p['stock']?.toString() ?? '');
                    final double stock = rawStockNum ?? 0.0;
                    final isAvailable = (p['is_available'] == null ||
                            p['is_available'] == true ||
                            p['is_available'] == 1 ||
                            p['is_available']?.toString() == '1' ||
                            p['is_available']?.toString().toLowerCase() == 'true') &&
                        (p['is_enabled'] != false &&
                            p['is_enabled'] != 0 &&
                            p['is_enabled']?.toString() != '0' &&
                            p['is_enabled']?.toString().toLowerCase() != 'false') &&
                        stock > 0;
                    if (isAvailable) {
                      availableProducts.add(p);
                    } else {
                      unavailableProducts.add(p);
                    }
                  }

                  return CustomScrollView(
                    key: const ValueKey('grid_view'),
                    slivers: [
                      if (availableProducts.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.all(16.0),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.75,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildProductCard(context, availableProducts[index], theme),
                              childCount: availableProducts.length,
                            ),
                          ),
                        ),
                      if (unavailableProducts.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.orange.withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.remove_shopping_cart_rounded,
                                          size: 14, color: Colors.orange),
                                      const SizedBox(width: 6),
                                      Text(
                                        'CURRENTLY UNAVAILABLE (${unavailableProducts.length})',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.orange.shade800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.75,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildProductCard(context, unavailableProducts[index], theme),
                              childCount: unavailableProducts.length,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildProductCard(BuildContext context, Map<String, dynamic> p, ThemeData theme) {
  final rawStockNum = (p['stock'] is num)
      ? (p['stock'] as num).toDouble()
      : double.tryParse(p['stock']?.toString() ?? '');
  final double stock = rawStockNum ?? 0.0;
  final isAvailable = (p['is_available'] == null ||
          p['is_available'] == true ||
          p['is_available'] == 1 ||
          p['is_available']?.toString() == '1' ||
          p['is_available']?.toString().toLowerCase() == 'true') &&
      (p['is_enabled'] != false &&
          p['is_enabled'] != 0 &&
          p['is_enabled']?.toString() != '0' &&
          p['is_enabled']?.toString().toLowerCase() != 'false') &&
      stock > 0;
  final bool isExplicitlyUnavailable = !(p['is_available'] == null ||
          p['is_available'] == true ||
          p['is_available'] == 1 ||
          p['is_available']?.toString() == '1' ||
          p['is_available']?.toString().toLowerCase() == 'true') ||
      (p['is_enabled'] == false ||
          p['is_enabled'] == 0 ||
          p['is_enabled']?.toString() == '0' ||
          p['is_enabled']?.toString().toLowerCase() == 'false');
  final double mrp = (p['market_price'] as num?)?.toDouble() ?? 0.0;
  final double price = (p['price'] as num?)?.toDouble() ?? 0.0;
  final bool hasSavings = mrp > price && price > 0;
  final double savingsPercent = hasSavings ? ((mrp - price) / mrp * 100) : 0.0;

  return GlassContainer(
    isStockOut: !isAvailable,
    borderRadius: 18,
    padding: const EdgeInsets.all(12.0),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailsScreen(productId: p['id']?.toString() ?? ''),
        ),
      );
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Placeholder Image Box
        Expanded(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  child: Hero(
                    tag: 'product-image-${p['id']}',
                    child: Image.network(
                      getProductImage(p['name'] ?? '', p['image_path'] as String?),
                      fit: BoxFit.cover,
                      cacheWidth: 360,
                      cacheHeight: 300,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.shopping_basket_rounded,
                          size: 48,
                          color: isAvailable ? theme.colorScheme.primary : Colors.grey,
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (hasSavings && isAvailable)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GlassContainer(
                    borderRadius: 8,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      'Save ${savingsPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Color(0xFF1B3624),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (!isAvailable)
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        isExplicitlyUnavailable ? 'UNAVAILABLE' : 'OUT OF STOCK',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        
        // Name & Rx badge
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  p['name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            if (p['prescription_required'] == true)
              const Padding(
                padding: EdgeInsets.only(left: 4.0),
                child: Tooltip(
                  message: 'Prescription Required',
                  child: Text(
                    'Rx',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 4),
        
        // Weight/unit
        Text(
          '1 ${p['unit'] ?? 'kg'}',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        
        const SizedBox(height: 12),
        
        // Price & MRP
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '₹${_formatCurrency(price)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: isAvailable ? const Color(0xFF1B3624) : Colors.grey,
              ),
            ),
            if (mrp > price && price > 0) ...[
              const SizedBox(width: 6),
              Text(
                '₹${_formatCurrency(mrp)}',
                style: TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Action Button: Add to Cart or Out of Stock Badge
        if (!isAvailable)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 13),
                const SizedBox(width: 4),
                Text(
                  isExplicitlyUnavailable ? 'UNAVAILABLE' : 'OUT OF STOCK',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 9.5,
                    color: const Color(0xFFDC2626),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerRight,
              child: QuantitySelector(product: p),
            ),
          ),
      ],
    ),
  );
}
}

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

