import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/cart/cart_provider.dart';
import '../utils/product_helper.dart';

class QuantityOption {
  final String label;
  final double value;

  QuantityOption(this.label, this.value);
}

class QuantitySelectionSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;

  const QuantitySelectionSheet({super.key, required this.product});

  @override
  ConsumerState<QuantitySelectionSheet> createState() => _QuantitySelectionSheetState();
}

class _QuantitySelectionSheetState extends ConsumerState<QuantitySelectionSheet> {
  late final String unit;
  late final double price;
  late final String productId;
  List<QuantityOption> options = [];

  double? selectedValue;
  bool isCustom = false;
  final customController = TextEditingController();
  bool initialized = false;

  void _setupOptions() {
    unit = (widget.product['unit'] ?? 'kg').toString().toLowerCase();
    final bool isQuick = widget.product['is_order_now'] == true;
    final dynamic rawPrice = isQuick ? (widget.product['order_now_price'] ?? widget.product['price']) : widget.product['price'];
    price = (rawPrice is num)
        ? rawPrice.toDouble()
        : (double.tryParse(rawPrice?.toString() ?? '') ?? 0.0);
    productId = widget.product['id']?.toString() ?? '';

    final rawStock = isQuick ? widget.product['order_now_stock'] : widget.product['stock'];
    final double? rawStockNum = (rawStock is num)
        ? rawStock.toDouble()
        : double.tryParse(rawStock?.toString() ?? '');
    final double stock = rawStockNum ?? 0.0;

    if (unit == 'kg' || unit == 'g' || unit == 'gram' || unit == 'grams') {
      if (unit == 'kg') {
        options = [
          QuantityOption('250 g', 0.25),
          QuantityOption('500 g', 0.5),
          QuantityOption('1 kg', 1.0),
          QuantityOption('2 kg', 2.0),
          QuantityOption('5 kg', 5.0),
        ];
      } else {
        options = [
          QuantityOption('250 g', 250.0),
          QuantityOption('500 g', 500.0),
          QuantityOption('1000 g (1 kg)', 1000.0),
          QuantityOption('2000 g (2 kg)', 2000.0),
          QuantityOption('5000 g (5 kg)', 5000.0),
        ];
      }
    } else if (unit == 'dozen' || unit == 'doz') {
      options = [
        QuantityOption('0.5 Dozen (6 Pcs)', 0.5),
        QuantityOption('1 Dozen (12 Pcs)', 1.0),
        QuantityOption('1.5 Dozen (18 Pcs)', 1.5),
        QuantityOption('2 Dozen (24 Pcs)', 2.0),
        QuantityOption('3 Dozen (36 Pcs)', 3.0),
      ];
    } else {
      options = [
        QuantityOption('1 Unit', 1.0),
        QuantityOption('2 Units', 2.0),
        QuantityOption('3 Units', 3.0),
        QuantityOption('5 Units', 5.0),
        QuantityOption('10 Units', 10.0),
      ];
    }

    // Filter preset options based on available stock (if tracked)
    if (rawStockNum != null) {
      options = options.where((opt) => opt.value <= stock).toList();
    }
  }

  @override
  void initState() {
    super.initState();
    _setupOptions();
  }

  @override
  void didUpdateWidget(QuantitySelectionSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product != widget.product) {
      _setupOptions();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    customController.dispose();
    super.dispose();
  }

  double? get stock {
    final bool isQuick = widget.product['is_order_now'] == true;
    final raw = isQuick ? widget.product['order_now_stock'] : widget.product['stock'];
    final double? numVal = (raw is num) ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
    return numVal;
  }

  double getCalculatedQty() {
    if (isCustom) {
      final clean = customController.text.trim().toLowerCase().replaceAll(',', '.');
      if (clean.endsWith('kg')) {
        return double.tryParse(clean.replaceAll('kg', '').trim()) ?? 0.0;
      }
      if (clean.endsWith('g') || clean.endsWith('gm') || clean.endsWith('gram') || clean.endsWith('grams')) {
        final g = double.tryParse(clean.replaceAll(RegExp(r'[a-z]'), '').trim()) ?? 0.0;
        return ((g / 1000.0) * 1000).round() / 1000.0;
      }
      final input = double.tryParse(clean) ?? 0.0;
      if (unit == 'kg' && input >= 50.0) {
        return ((input / 1000.0) * 1000).round() / 1000.0; // convert grams to kg
      }
      return ((input) * 1000).round() / 1000.0;
    }
    return selectedValue ?? 0.0;
  }

  double getCalculatedPrice() {
    return getCalculatedQty() * price;
  }

  String? get _validationError {
    final bool isQuick = widget.product['is_order_now'] == true;
    final double stockNum = ProductHelper.getStock(widget.product, isOrderNow: isQuick);
    final bool isAvail = ProductHelper.isAvailable(widget.product, isOrderNow: isQuick);

    if (!isAvail || stockNum <= 0) {
      return 'Item is currently out of stock';
    }

    if (!isCustom) {
      if (selectedValue != null && selectedValue! > stockNum) {
        return 'Only ${formatQuantity(stockNum, unit)} available in stock';
      }
      return null;
    }
    final text = customController.text.trim();
    if (text.isEmpty) return 'Quantity is required';
    final qty = getCalculatedQty();
    if (qty <= 0) return 'Quantity must be greater than zero';
    
    if (qty > stockNum) {
      return 'Exceeds stock. Only ${formatQuantity(stockNum, unit)} available.';
    }
    return null;
  }

  String? get _helperText {
    if (!isCustom) return null;
    final text = customController.text.trim().toLowerCase().replaceAll(',', '.');
    if (text.isEmpty) return null;
    if (text.endsWith('kg')) {
      final numPart = double.tryParse(text.replaceAll('kg', '').trim());
      if (numPart != null && numPart > 0) return 'Calculated: $numPart kg';
    }
    if (text.endsWith('g') || text.endsWith('gm') || text.endsWith('gram') || text.endsWith('grams')) {
      final numPart = double.tryParse(text.replaceAll(RegExp(r'[a-z]'), '').trim());
      if (numPart != null && numPart > 0) {
        return 'Calculated: ${(numPart / 1000.0).toStringAsFixed(3)} kg (${numPart.toInt()} g)';
      }
    }
    final val = double.tryParse(text);
    if (val != null && val > 0) {
      if (unit == 'kg' && val >= 50.0) {
        return 'Calculated: ${(val / 1000.0).toStringAsFixed(3)} kg (${val.toInt()} g)';
      }
    }
    return null;
  }

  bool get _isValidQty {
    final qty = getCalculatedQty();
    return qty > 0 && _validationError == null;
  }

  @override
  Widget build(BuildContext context) {
    final isQuick = widget.product['is_order_now'] == true;
    final cartState = ref.watch(isQuick ? quickCartProvider : cartProvider);
    final existingItem = cartState.items[productId];
    final currentQty = existingItem?.quantity ?? 0.0;

    if (!initialized) {
      initialized = true;
      if (currentQty > 0.0) {
        final roundedCurrentQty = (currentQty * 1000).round() / 1000.0;
        final matchingOpt = options.where((opt) => (opt.value - roundedCurrentQty).abs() < 0.001).firstOrNull;
        if (matchingOpt != null) {
          selectedValue = matchingOpt.value;
        } else {
          isCustom = true;
          customController.text = (currentQty == currentQty.toInt()) ? currentQty.toInt().toString() : roundedCurrentQty.toString();
        }
      } else {
        if (options.isNotEmpty) {
          selectedValue = options.first.value;
        } else {
          selectedValue = null;
          isCustom = true;
        }
      }
    }

    const Color textColorPrimary = Color(0xFF3D1B0B);
    const Color textColorSecondary = Color(0xFF8F8077);
    const Color bgCard = Color(0xFFF3ECE6);
    const Color borderPillColor = Color(0xFFE2D6CA);

    return SafeArea(
      top: false,
      bottom: true,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 20,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.product['name'] ?? '',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: textColorPrimary,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: textColorPrimary),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              'Unit Price: ₹${_formatCurrency(price)} per $unit',
              style: GoogleFonts.inter(color: textColorSecondary, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  (stock == null || stock! > 0) ? Icons.inventory_2_outlined : Icons.warning_amber_rounded,
                  size: 14,
                  color: (stock == null || stock! > 0) ? const Color(0xFF166534) : const Color(0xFF991B1B),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    stock != null
                        ? (stock! > 0 ? 'Available in Stock: ${formatQuantity(stock!, unit)}' : 'Out of Stock')
                        : 'In Stock',
                    style: GoogleFonts.inter(
                      color: (stock == null || stock! > 0) ? const Color(0xFF166534) : const Color(0xFF991B1B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Select Quantity',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColorPrimary,
              ),
            ),
            const SizedBox(height: 12),
            
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...options.map((opt) {
                  final isSelected = !isCustom && selectedValue == opt.value;
                  return ChoiceChip(
                    label: Text(
                      opt.label,
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : textColorPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: textColorPrimary,
                    backgroundColor: bgCard,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: borderPillColor),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          isCustom = false;
                          selectedValue = opt.value;
                        });
                      }
                    },
                  );
                }),
                ChoiceChip(
                  label: Text(
                    'Custom',
                    style: GoogleFonts.inter(
                      color: isCustom ? Colors.white : textColorPrimary,
                      fontWeight: isCustom ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isCustom,
                  selectedColor: textColorPrimary,
                  backgroundColor: bgCard,
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: borderPillColor),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        isCustom = true;
                        selectedValue = null;
                      });
                    }
                  },
                ),
              ],
            ),
            
            if (isCustom) ...[
              const SizedBox(height: 16),
              if (stock != null && stock! > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Custom quantity ($unit):',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textColorPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            final formatted = (stock! % 1 == 0) ? stock!.toInt().toString() : stock!.toStringAsFixed(2);
                            customController.text = (unit == 'kg' && stock! >= 50.0) ? '$formatted kg' : formatted;
                          });
                        },
                        child: Text(
                          'Set to Max (${formatQuantity(stock!, unit)})',
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
              TextField(
                controller: customController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(color: textColorPrimary),
                decoration: InputDecoration(
                  labelText: 'Enter custom quantity ($unit)',
                  labelStyle: GoogleFonts.inter(color: textColorSecondary),
                  errorText: _validationError,
                  helperText: _helperText,
                  helperStyle: GoogleFonts.inter(color: Colors.green[700]),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: borderPillColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: textColorPrimary, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),
            ],
            
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Price:',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: textColorPrimary),
                ),
                Text(
                  '₹${_formatCurrency(getCalculatedPrice())}',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColorPrimary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: textColorPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: _isValidQty ? () {
                  final qty = getCalculatedQty();
                  if (stock != null && qty > stock!) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(stock! <= 0
                            ? 'This item is currently out of stock.'
                            : 'Cannot add. Maximum available stock is ${formatQuantity(stock!, unit)}.'),
                        backgroundColor: const Color(0xFFDC2626),
                      ),
                    );
                    return;
                  }
                  
                  HapticFeedback.lightImpact();
                  
                  final notifier = ref.read(isQuick ? quickCartProvider.notifier : cartProvider.notifier);
                  if (existingItem != null) {
                    notifier.updateQuantity(productId, qty);
                  } else {
                    notifier.addItem(
                      productId: productId,
                      productName: widget.product['name'] ?? '',
                      price: price,
                      unit: widget.product['unit'] ?? '',
                      quantity: qty,
                      isOrderNow: isQuick,
                      imagePath: widget.product['image_path'] as String? ?? widget.product['image_url'] as String?,
                    );
                  }
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${widget.product['name']} cart quantity updated to ${formatQuantity(qty, unit)}!'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                } : null,
                child: Text(
                  'Confirm Selection',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

void showQuantitySelectionBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Map<String, dynamic> product,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFFDF8),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => QuantitySelectionSheet(product: product),
  );
}

String formatQuantity(double qty, String unit) {
  final unitLower = unit.toLowerCase();
  final roundedQty = (qty * 1000).round() / 1000.0;
  if (unitLower == 'kg') {
    if ((roundedQty - 0.25).abs() < 0.001) return '250 g';
    if ((roundedQty - 0.50).abs() < 0.001) return '500 g';
    if ((roundedQty - 0.75).abs() < 0.001) return '750 g';
    if (roundedQty == roundedQty.toInt()) {
      return '${roundedQty.toInt()} kg';
    }
    return '${roundedQty.toStringAsFixed(roundedQty * 10 == (roundedQty * 10).toInt() ? 1 : 2)} kg';
  } else if (unitLower == 'g' || unitLower == 'gram' || unitLower == 'grams') {
    return '${roundedQty.toInt()} g';
  } else if (unitLower == 'dozen' || unitLower == 'doz') {
    if ((roundedQty - 0.5).abs() < 0.001) return '6 Pcs';
    if ((roundedQty - 1.0).abs() < 0.001) return '1 Dozen';
    if ((roundedQty - 1.5).abs() < 0.001) return '18 Pcs';
    if (roundedQty == roundedQty.toInt()) return '${roundedQty.toInt()} Dozen';
    return '$roundedQty Dozen';
  } else {
    if (roundedQty == roundedQty.toInt()) {
      return '${roundedQty.toInt()} $unit';
    }
    return '${roundedQty.toStringAsFixed(1)} $unit';
  }
}

class QuantitySelector extends ConsumerWidget {
  final Map<String, dynamic> product;

  const QuantitySelector({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productId = product['id']?.toString() ?? '';

    final bool isQuick = product['is_order_now'] == true;
    final double stockNum = ProductHelper.getStock(product, isOrderNow: isQuick);
    final bool isAvail = ProductHelper.isAvailable(product, isOrderNow: isQuick);

    const Color textColorPrimary = Color(0xFF3D1B0B);

    if (!isAvail || stockNum <= 0) {
      return Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 12),
            const SizedBox(width: 4),
            Text(
              'OUT OF STOCK',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 9,
                color: const Color(0xFFDC2626),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }
    
    // Select only this product's quantity to isolate rebuild boundaries
    final currentQty = ref.watch(
      (isQuick ? quickCartProvider : cartProvider).select(
        (state) => state.items[productId]?.quantity,
      ),
    );

    if (currentQty == null || currentQty <= 0) {
      return SizedBox(
        height: 32,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: textColorPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            showQuantitySelectionBottomSheet(
              context: context,
              ref: ref,
              product: product,
            );
          },
          child: Text('ADD', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      );
    }

    final String unit = (product['unit'] ?? 'kg').toString();
    final double step = getStepSize(unit);

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: textColorPrimary,
        borderRadius: BorderRadius.circular(16),
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
              final newQty = ((currentQty - step) * 1000).round() / 1000.0;
              if (isQuick) {
                ref.read(quickCartProvider.notifier).updateQuantity(productId, newQty);
              } else {
                ref.read(cartProvider.notifier).updateQuantity(productId, newQty);
              }
            },
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              showQuantitySelectionBottomSheet(
                context: context,
                ref: ref,
                product: product,
              );
            },
            child: Text(
              formatQuantity(currentQty, unit),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () {
              HapticFeedback.lightImpact();
              final isQuick = product['is_order_now'] == true;
              final rawStock = isQuick ? product['order_now_stock'] : product['stock'];
              final double? stockNum = (rawStock is num) ? rawStock.toDouble() : double.tryParse(rawStock?.toString() ?? '');
              if (stockNum != null && (stockNum <= 0 || currentQty >= stockNum || currentQty + step > stockNum)) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(stockNum <= 0
                        ? 'This item is currently out of stock.'
                        : 'Cannot add more. Maximum available stock is ${formatQuantity(stockNum, unit)}.'),
                    backgroundColor: const Color(0xFFDC2626),
                    duration: const Duration(seconds: 2),
                  ),
                );
                return;
              }
              showQuantitySelectionBottomSheet(
                context: context,
                ref: ref,
                product: product,
              );
            },
          ),
        ],
      ),
    );
  }
}

double getStepSize(String unit) {
  final unitLower = unit.toLowerCase();
  if (unitLower == 'kg') return 0.25;
  if (unitLower == 'g' || unitLower == 'gram' || unitLower == 'grams') return 250.0;
  return 1.0;
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

