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
                        initialValue: currentFilters.categoryId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All'),
                          ),
                          ...categories.map((c) {
                            return DropdownMenuItem<String?>(
                              value: c['id'],
                              child: Text(c['name'] ?? ''),
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

                  return GridView.builder(
                    key: const ValueKey('grid_view'),
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    final double stock = (p['stock'] as num?)?.toDouble() ?? 0.0;
                    final isAvailable = (p['is_available'] == true || p['is_available'] == 1) && stock > 0;
                    final double mrp = (p['market_price'] as num?)?.toDouble() ?? 0.0;
                    final double price = (p['price'] as num?)?.toDouble() ?? 0.0;
                    final bool hasSavings = mrp > price && price > 0;
                    final double savingsPercent = hasSavings ? ((mrp - price) / mrp * 100) : 0.0;

                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetailsScreen(productId: p['id']),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
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
                                    if (hasSavings)
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
                                              color: Colors.red[800]!.withValues(alpha: 0.9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'OUT OF STOCK',
                                              style: TextStyle(
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
                              
                              // Price/Unit
                              if ((p['unit'] as String? ?? 'kg').toLowerCase().contains('kg')) ...[
                                Text(
                                  '₹${(((p['price'] as num?)?.toDouble() ?? 0.0) / 4).toStringAsFixed(0)}/250g',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${(p['price'] as num?)?.toStringAsFixed(0) ?? '0'} per kg',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  '₹${(p['price'] as num?)?.toStringAsFixed(0) ?? '0'}/${p['unit']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                              if (isAvailable && stock > 0 && stock <= 5)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Only ${stock.toInt()} left!',
                                    style: const TextStyle(
                                      color: Colors.deepOrange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              
                              // Availability Status / Add Button
                              if (!isAvailable)
                                SizedBox(
                                  width: double.infinity,
                                  height: 32,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[200],
                                      foregroundColor: Colors.grey[500],
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: null,
                                    child: const Text(
                                      'OUT OF STOCK',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
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
                        ),
                      ),
                    );
                  },
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
}
