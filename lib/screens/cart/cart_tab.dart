import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/widgets.dart';
import '../../providers/cart_provider.dart';
import '../checkout/checkout_screen.dart';

class CartTab extends StatelessWidget {
  const CartTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Cart')),
      body: cart.isEmpty
          ? const EmptyView(
              icon: Icons.shopping_cart_outlined,
              message: 'Your cart is empty',
              hint: 'Add fresh vegetables & groceries from the Home tab.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = cart.items[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.product.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                '${formatPrice(item.product.price)} / ${item.product.unit}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatPrice(item.lineTotal),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => cart.setQuantity(
                                  item.product.id, item.quantity - 1),
                              icon: const Icon(
                                  Icons.remove_circle_outline),
                            ),
                            Text('${item.quantity}',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            IconButton(
                              onPressed: () => cart.setQuantity(
                                  item.product.id, item.quantity + 1),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => cart.remove(item.product.id),
                          icon: Icon(Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error),
                          tooltip: 'Remove',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const CheckoutScreen()),
                  ),
                  child: Text(
                      'Checkout · ${formatPrice(cart.totalAmount)}'),
                ),
              ),
            ),
    );
  }
}
