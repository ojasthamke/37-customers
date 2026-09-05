import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'catalog_provider.dart';
import '../../core/widgets/quantity_selector.dart';
import '../../core/utils/string_utils.dart';


class ProductDetailsScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailsProvider(widget.productId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
      ),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading details: $err')),
        data: (p) {
          if (p == null) {
            return const Center(child: Text('Product not found'));
          }

          final rawStockNum = (p['stock'] is num)
              ? (p['stock'] as num).toDouble()
              : double.tryParse(p['stock']?.toString() ?? '');
          final isAvailable = (p['is_available'] == null ||
                  p['is_available'] == true ||
                  p['is_available'] == 1 ||
                  p['is_available']?.toString() == '1' ||
                  p['is_available']?.toString().toLowerCase() == 'true') &&
              (p['is_enabled'] != false &&
                  p['is_enabled'] != 0 &&
                  p['is_enabled']?.toString() != '0' &&
                  p['is_enabled']?.toString().toLowerCase() != 'false') &&
              (rawStockNum != null && rawStockNum > 0);
          final bool isExplicitlyUnavailable = !(p['is_available'] == null ||
                  p['is_available'] == true ||
                  p['is_available'] == 1 ||
                  p['is_available']?.toString() == '1' ||
                  p['is_available']?.toString().toLowerCase() == 'true') ||
              (p['is_enabled'] == false ||
                  p['is_enabled'] == 0 ||
                  p['is_enabled']?.toString() == '0' ||
                  p['is_enabled']?.toString().toLowerCase() == 'false');

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image Container
                Container(
                  width: double.infinity,
                  height: 250,
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  child: Hero(
                    tag: 'product-image-${p['id']}',
                    child: Image.network(
                      getProductImage(p['name'] ?? '', p['image_path'] as String?),
                      fit: BoxFit.cover,
                      cacheWidth: 720,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.shopping_basket_rounded,
                            size: 96,
                            color: theme.colorScheme.primary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status / Availability Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isAvailable ? Colors.green : Colors.red).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isAvailable
                              ? 'IN STOCK'
                              : (isExplicitlyUnavailable ? 'UNAVAILABLE' : 'OUT OF STOCK'),
                          style: TextStyle(
                            color: isAvailable ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      // Rx Badge
                      if (p['prescription_required'] == true) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.description_rounded, color: Colors.orange, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'PRESCRIPTION REQUIRED (Rx)',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Name
                      Text(
                        p['name'] ?? '',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Price
                      if ((p['unit'] as String? ?? 'kg').toLowerCase().contains('kg')) ...[
                        Text(
                          '₹${_formatCurrency(((p['price'] as num?)?.toDouble() ?? 0.0) / 4)}/250g',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${_formatCurrency((p['price'] as num?)?.toDouble() ?? 0.0)} per kg',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else ...[
                        Text(
                          '₹${_formatCurrency((p['price'] as num?)?.toDouble() ?? 0.0)}/${p['unit']}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Description
                      Text(
                        'Description',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p['description'] != null && p['description'].isNotEmpty
                            ? p['description']
                            : 'No description available for this fresh product.',
                        style: TextStyle(color: Colors.grey[700], height: 1.4, fontSize: 15),
                      ),
                      
                      // Extra Info fields
                      if (p['dosage_info'] != null && p['dosage_info'].toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Dosage / Directions',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p['dosage_info'].toString(),
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                      ],

                      if ((p['expiry_date'] != null && p['expiry_date'].toString().isNotEmpty) ||
                          (p['best_before'] != null && p['best_before'].toString().isNotEmpty)) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (p['expiry_date'] != null && p['expiry_date'].toString().isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Text('Expiry Date: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(p['expiry_date'].toString(), style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ],
                              if (p['best_before'] != null && p['best_before'].toString().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Text('Best Before: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(p['best_before'].toString(), style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 36),


                      // Add to Cart Options
                      if (isAvailable) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Add to Cart:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            QuantitySelector(product: p),
                          ],
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'CURRENTLY OUT OF STOCK',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: const Color(0xFFDC2626),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]

                    ],
                  ),
                ),
              ],
            ),
          );
        },
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

