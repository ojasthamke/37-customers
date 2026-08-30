import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/cart/cart_provider.dart';

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

  @override
  void initState() {
    super.initState();
    unit = (widget.product['unit'] ?? 'kg').toString().toLowerCase();
    price = (widget.product['price'] as num?)?.toDouble() ?? 0.0;
    productId = widget.product['id'] as String;

    final double stock = (widget.product['stock'] as num?)?.toDouble() ?? 0.0;

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

    // Filter preset options based on available stock
    options = options.where((opt) => opt.value <= stock).toList();
  }

  @override
  void dispose() {
    customController.dispose();
    super.dispose();
  }

  double getCalculatedQty() {
    if (isCustom) {
      final input = double.tryParse(customController.text) ?? 0.0;
      if (unit == 'kg' && input >= 10.0) {
        return input / 1000.0; // convert grams to kg
      }
      return input;
    }
    return selectedValue ?? 0.0;
  }

  double getCalculatedPrice() {
    return getCalculatedQty() * price;
  }

  String? get _validationError {
    final double stock = (widget.product['stock'] as num?)?.toDouble() ?? 0.0;
    if (!isCustom) {
      if (selectedValue != null && selectedValue! > stock) {
        return 'Only $stock $unit available in stock';
      }
      return null;
    }
    final text = customController.text.trim();
    if (text.isEmpty) return 'Quantity is required';
    final val = double.tryParse(text);
    if (val == null) return 'Please enter a valid number';
    if (val <= 0) return 'Quantity must be greater than zero';
    
    double checkQty = val;
    if (unit == 'kg' && val >= 10.0) {
      checkQty = val / 1000.0;
    }
    
    if (checkQty > stock) {
      return 'Only $stock $unit available in stock';
    }
    return null;
  }

  String? get _helperText {
    if (!isCustom) return null;
    final text = customController.text.trim();
    if (text.isEmpty) return null;
    final val = double.tryParse(text);
    if (val != null && val > 0) {
      if (unit == 'kg' && val >= 10.0) {
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
        final matchesPreset = options.any((opt) => opt.value == currentQty);
        if (matchesPreset) {
          selectedValue = currentQty;
        } else {
          isCustom = true;
          customController.text = currentQty.toString();
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            'Unit Price: ₹${price.toStringAsFixed(0)} per $unit',
            style: GoogleFonts.inter(color: textColorSecondary, fontSize: 14),
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
                '₹${getCalculatedPrice().toStringAsFixed(0)}',
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

class QuantitySelector extends ConsumerWidget {
  final Map<String, dynamic> product;

  const QuantitySelector({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productId = product['id'] as String;
    final isQuick = product['is_order_now'] == true;
    
    // Select only this product's quantity to isolate rebuild boundaries
    final currentQty = ref.watch(
      (isQuick ? quickCartProvider : cartProvider).select(
        (state) => state.items[productId]?.quantity,
      ),
    );
    
    const Color textColorPrimary = Color(0xFF3D1B0B);

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
              product: Map<String, dynamic>.from(product)..['is_order_now'] = isQuick,
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
              final newQty = currentQty - step;
              ref.read(isQuick ? quickCartProvider.notifier : cartProvider.notifier).updateQuantity(productId, newQty);
            },
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              showQuantitySelectionBottomSheet(
                context: context,
                ref: ref,
                product: Map<String, dynamic>.from(product)..['is_order_now'] = isQuick,
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
              showQuantitySelectionBottomSheet(
                context: context,
                ref: ref,
                product: Map<String, dynamic>.from(product)..['is_order_now'] = isQuick,
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
