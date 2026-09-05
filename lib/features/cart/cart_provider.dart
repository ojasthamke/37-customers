import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';

class CartItem {
  final String productId;
  final String productName;
  final double price;
  final double quantity;
  final String unit;
  final bool isOrderNow;
  final String? imagePath;

  CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.unit,
    this.isOrderNow = false,
    this.imagePath,
  });

  CartItem copyWith({
    String? productName,
    double? price,
    double? quantity,
    String? unit,
    bool? isOrderNow,
    String? imagePath,
  }) {
    return CartItem(
      productId: productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isOrderNow: isOrderNow ?? this.isOrderNow,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  double get totalPrice => price * quantity;
}

class CartState {
  final Map<String, CartItem> items;
  final double deliveryChargeValue;
  final double freeDeliveryLimit;
  final String idempotencyKey;

  CartState({
    this.items = const {},
    this.deliveryChargeValue = 30.0,
    this.freeDeliveryLimit = 300.0,
    String? idempotencyKey,
  }) : idempotencyKey = (idempotencyKey != null && idempotencyKey.isNotEmpty)
            ? idempotencyKey
            : const Uuid().v4();

  CartState copyWith({
    Map<String, CartItem>? items,
    double? deliveryChargeValue,
    double? freeDeliveryLimit,
    String? idempotencyKey,
    bool resetIdempotencyKey = false,
  }) {
    return CartState(
      items: items ?? this.items,
      deliveryChargeValue: deliveryChargeValue ?? this.deliveryChargeValue,
      freeDeliveryLimit: freeDeliveryLimit ?? this.freeDeliveryLimit,
      idempotencyKey: resetIdempotencyKey
          ? const Uuid().v4()
          : (idempotencyKey ?? this.idempotencyKey),
    );
  }

  int get itemCount => items.length;

  double get subtotal => items.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get baseDeliveryCharge {
    if (subtotal == 0) return 0.0;
    return subtotal >= freeDeliveryLimit ? 0.0 : deliveryChargeValue;
  }

  double get unroundedGrandTotal => subtotal + baseDeliveryCharge;

  /// Rounded to nearest multiple of 5 (ceil) for clean retail POS receipts
  double get roundedGrandTotal {
    if (unroundedGrandTotal == 0) return 0.0;
    // Normalize to 2 decimal places to remove floating-point precision noise (e.g. 150.00000000000003)
    final normalized = (unroundedGrandTotal * 100).round() / 100.0;
    return (normalized / 5.0).ceil() * 5.0;
  }

  /// Rounding difference added to delivery fee
  double get roundingDifference => roundedGrandTotal - unroundedGrandTotal;

  /// Final delivery charge including the auto round-off adjustment.
  /// When delivery is free (baseDeliveryCharge == 0), the rounding difference
  /// is NOT folded into delivery fee — it's shown as a separate round-off line.
  double get deliveryCharge {
    if (baseDeliveryCharge == 0) return 0.0;
    return baseDeliveryCharge + roundingDifference;
  }

  /// The portion of the rounding that is NOT accounted for by the delivery charge.
  /// Non-zero only when delivery is free but subtotal isn't a multiple of 5.
  double get separateRoundingAdjustment {
    if (baseDeliveryCharge == 0) return roundingDifference;
    return 0.0;
  }

  double get grandTotal => roundedGrandTotal;

  /// Item prices mapped to their exact totals
  Map<String, double> get adjustedItemPrices {
    final result = <String, double>{};
    for (final entry in items.entries) {
      result[entry.key] = entry.value.totalPrice;
    }
    return result;
  }
}

class CartNotifier extends StateNotifier<CartState> {
  final String _storageKey;

  CartNotifier({String storageKey = 'cart_items'})
      : _storageKey = storageKey,
        super(CartState(
          deliveryChargeValue: storageKey == 'quick_cart_items' ? 10.0 : 30.0,
          freeDeliveryLimit: storageKey == 'quick_cart_items' ? 100000.0 : 300.0,
        )) {
    _initCart();
  }

  Future<void> _initCart() async {
    await _loadCart();
    await loadDeliverySettings();
  }

  Future<void> loadDeliverySettings() async {
    try {
      final List<dynamic> res = await Supabase.instance.client.from('settings').select();
      final Map<String, String> fetched = {};
      for (var r in res) {
        final key = r['key']?.toString() ?? '';
        final val = r['value']?.toString() ?? '';
        if (key.isNotEmpty) {
          fetched[key] = val;
        }
      }
      
      // Update local SQLite cache
      final db = await DatabaseHelper.instance.database;
      for (var entry in fetched.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      final double defaultCharge = _storageKey == 'quick_cart_items' ? 10.0 : 30.0;
      final double charge = double.tryParse(
        _storageKey == 'quick_cart_items'
          ? (fetched['order_now_delivery_charge'] ?? fetched['quick_delivery_charge'] ?? '10.0')
          : (fetched['delivery_charge'] ?? '30.0')
      ) ?? defaultCharge;
      final double defaultLimit = _storageKey == 'quick_cart_items' ? 100000.0 : 300.0;
      final double limit = double.tryParse(
        _storageKey == 'quick_cart_items'
          ? (fetched['order_now_free_delivery_threshold'] ?? fetched['quick_free_delivery_threshold'] ?? '100000.0')
          : (fetched['free_delivery_threshold'] ?? '300.0')
      ) ?? defaultLimit;
      
      state = state.copyWith(
        deliveryChargeValue: charge,
        freeDeliveryLimit: limit,
      );
    } catch (_) {
      // Fallback: Read from local SQLite
      try {
        final db = await DatabaseHelper.instance.database;
        final chargeKey = _storageKey == 'quick_cart_items' ? 'order_now_delivery_charge' : 'delivery_charge';
        final chargeRes = await db.query('settings', where: 'key = ?', whereArgs: [chargeKey]);
        final limitKey = _storageKey == 'quick_cart_items' ? 'order_now_free_delivery_threshold' : 'free_delivery_threshold';
        final limitRes = await db.query('settings', where: 'key = ?', whereArgs: [limitKey]);
        
        final double defaultCharge = _storageKey == 'quick_cart_items' ? 10.0 : 30.0;
        final double charge = chargeRes.isNotEmpty ? (double.tryParse(chargeRes.first['value']?.toString() ?? '') ?? defaultCharge) : defaultCharge;
        final double defaultLimit = _storageKey == 'quick_cart_items' ? 100000.0 : 300.0;
        final double limit = limitRes.isNotEmpty ? (double.tryParse(limitRes.first['value']?.toString() ?? '') ?? defaultLimit) : defaultLimit;
        
        state = state.copyWith(
          deliveryChargeValue: charge,
          freeDeliveryLimit: limit,
        );
      } catch (_) {}
    }
  }

  Future<void> _loadCart() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> res = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [_storageKey],
      );
      if (res.isNotEmpty) {
        final String val = res.first['value'] as String;
        final dynamic decodedRaw = jsonDecode(val);
        List<dynamic> decoded;
        String? loadedIdempotencyKey;
        if (decodedRaw is Map<String, dynamic>) {
          decoded = decodedRaw['items'] as List<dynamic>? ?? [];
          loadedIdempotencyKey = decodedRaw['idempotencyKey']?.toString();
        } else if (decodedRaw is List<dynamic>) {
          decoded = decodedRaw;
        } else {
          decoded = [];
        }

        final Map<String, CartItem> items = {};
        for (var item in decoded) {
          final String prodId = item['productId']?.toString() ?? '';
          if (prodId.isEmpty) continue;
          final double price = (item['price'] is num)
              ? (item['price'] as num).toDouble()
              : (double.tryParse(item['price']?.toString() ?? '') ?? 0.0);
          final double quantity = (item['quantity'] is num)
              ? (item['quantity'] as num).toDouble()
              : (double.tryParse(item['quantity']?.toString() ?? '') ?? 0.0);
          items[prodId] = CartItem(
            productId: prodId,
            productName: item['productName']?.toString() ?? '',
            price: price,
            quantity: (quantity * 1000).round() / 1000.0,
            unit: item['unit']?.toString() ?? '',
            isOrderNow: item['isOrderNow'] == true || item['isOrderNow']?.toString() == '1' || item['isOrderNow']?.toString().toLowerCase() == 'true',
            imagePath: item['imagePath']?.toString() ?? item['image_path']?.toString(),
          );
        }
        state = state.copyWith(
          items: items,
          idempotencyKey: loadedIdempotencyKey,
        );
      }
    } catch (_) {
      // Ignore load error on startup
    }
  }

  int _saveVersion = 0;

  Future<void> _saveCart([CartState? targetState]) async {
    final int thisVersion = ++_saveVersion;
    try {
      final db = await DatabaseHelper.instance.database;
      if (thisVersion != _saveVersion) return;
      final CartState stateToSave = targetState ?? state;
      final List<Map<String, dynamic>> list = stateToSave.items.values.map((item) => {
        'productId': item.productId,
        'productName': item.productName,
        'price': item.price,
        'quantity': item.quantity,
        'unit': item.unit,
        'isOrderNow': item.isOrderNow,
        'imagePath': item.imagePath,
      }).toList();
      final Map<String, dynamic> payload = {
        'items': list,
        'idempotencyKey': stateToSave.idempotencyKey,
      };
      final String val = jsonEncode(payload);
      if (thisVersion != _saveVersion) return;
      await db.insert(
        'settings',
        {'key': _storageKey, 'value': val},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Ignore save error
    }
  }

  void addItem({
    required String productId,
    required String productName,
    required double price,
    required String unit,
    double quantity = 1.0,
    bool isOrderNow = false,
    String? imagePath,
  }) {
    final String cleanId = productId.trim();
    final double cleanQty = (quantity * 1000).round() / 1000.0;
    if (cleanId.isEmpty || cleanQty <= 0.0001) return;
    final double cleanPrice = price < 0 ? 0.0 : price;

    final Map<String, CartItem> updatedItems = Map.from(state.items);
    final existing = updatedItems[cleanId];

    if (existing != null) {
      final double totalQty = ((existing.quantity + cleanQty) * 1000).round() / 1000.0;
      updatedItems[cleanId] = existing.copyWith(
        quantity: totalQty,
        price: cleanPrice > 0 ? cleanPrice : existing.price,
        imagePath: imagePath ?? existing.imagePath,
      );
    } else {
      updatedItems[cleanId] = CartItem(
        productId: cleanId,
        productName: productName.trim().isEmpty ? 'Item' : productName.trim(),
        price: cleanPrice,
        quantity: cleanQty,
        unit: unit,
        isOrderNow: _storageKey == 'quick_cart_items' || isOrderNow,
        imagePath: imagePath,
      );
    }

    final newState = state.copyWith(items: updatedItems, resetIdempotencyKey: true);
    state = newState;
    _saveCart(newState);
  }

  void updateQuantity(String productId, double quantity) {
    final String cleanId = productId.trim();
    if (cleanId.isEmpty) return;
    final double cleanQty = (quantity * 1000).round() / 1000.0;
    if (cleanQty <= 0.0001) {
      removeItem(cleanId);
      return;
    }
    
    final existing = state.items[cleanId];
    if (existing == null) return;

    final Map<String, CartItem> updatedItems = Map.from(state.items);
    updatedItems[cleanId] = existing.copyWith(quantity: cleanQty);
    
    final newState = state.copyWith(items: updatedItems, resetIdempotencyKey: true);
    state = newState;
    _saveCart(newState);
  }

  void updateItemPrice(String productId, double price) {
    final String cleanId = productId.trim();
    if (cleanId.isEmpty) return;
    final existing = state.items[cleanId];
    if (existing == null) return;
    final double cleanPrice = price < 0 ? 0.0 : price;

    final Map<String, CartItem> updatedItems = Map.from(state.items);
    updatedItems[cleanId] = CartItem(
      productId: existing.productId,
      productName: existing.productName,
      price: cleanPrice,
      quantity: existing.quantity,
      unit: existing.unit,
      isOrderNow: existing.isOrderNow,
    );
    
    final newState = state.copyWith(items: updatedItems);
    state = newState;
    _saveCart(newState);
  }

  void removeItem(String productId) {
    final String cleanId = productId.trim();
    final Map<String, CartItem> updatedItems = Map.from(state.items);
    updatedItems.remove(cleanId);
    
    final newState = state.copyWith(items: updatedItems, resetIdempotencyKey: true);
    state = newState;
    _saveCart(newState);
  }

  void reorderItems(List<CartItem> itemsList) {
    final Map<String, CartItem> updatedItems = Map.from(state.items);
    for (final item in itemsList) {
      updatedItems[item.productId] = item;
    }
    final newState = state.copyWith(items: updatedItems, resetIdempotencyKey: true);
    state = newState;
    _saveCart(newState);
  }

  void clear() {
    final newState = state.copyWith(items: {}, resetIdempotencyKey: true);
    state = newState;
    _saveCart(newState);
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(storageKey: 'cart_items');
});

final quickCartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(storageKey: 'quick_cart_items');
});

bool isStoreClosed(Map<String, String>? settings) {
  if (settings == null) return false;
  final status = settings['store_status']?.trim().toLowerCase();
  if (status == 'closed') return true;
  final storeOpen = settings['store_open']?.trim().toLowerCase();
  if (storeOpen == 'false' || storeOpen == '0' || storeOpen == 'no') return true;
  return false;
}

enum OrderNowStatus {
  open,
  comingSoon,
  closed,
}

OrderNowStatus getOrderNowStatus(Map<String, String>? settings) {
  if (settings == null) return OrderNowStatus.open;
  if (isStoreClosed(settings)) return OrderNowStatus.closed;
  final status = settings['order_now_status']?.trim().toLowerCase();
  if (status == 'coming_soon' || status == 'comingsoon' || status == 'soon') {
    return OrderNowStatus.comingSoon;
  }
  if (status == 'closed' || status == 'false' || status == '0' || status == 'off' || status == 'disabled') {
    return OrderNowStatus.closed;
  }
  if (status == 'open' || status == 'true' || status == '1') {
    return OrderNowStatus.open;
  }
  return OrderNowStatus.closed;
}

bool isOrderNowClosed(Map<String, String>? settings) {
  return getOrderNowStatus(settings) != OrderNowStatus.open;
}

final isViewingQuickOrderCartProvider = StateProvider<bool>((ref) => false);

final activeCartProvider = Provider<CartState>((ref) {
  final isQuick = ref.watch(isViewingQuickOrderCartProvider);
  return isQuick ? ref.watch(quickCartProvider) : ref.watch(cartProvider);
});

final activeCartNotifierProvider = Provider<CartNotifier>((ref) {
  final isQuick = ref.watch(isViewingQuickOrderCartProvider);
  return isQuick ? ref.watch(quickCartProvider.notifier) : ref.watch(cartProvider.notifier);
});


final appSettingsProvider = StreamProvider<Map<String, String>>((ref) async* {
  Map<String, String> cached = {};
  final dbHelper = DatabaseHelper.instance;

  // 1. Load cached settings immediately from SQLite
  try {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> res = await db.query('settings');
    for (var r in res) {
      cached[r['key'] as String] = (r['value'] ?? '').toString();
    }
    if (cached.isNotEmpty) {
      yield cached;
    }
  } catch (_) {}

  // 2. Check if cache is stale (TTL for store settings is 30 seconds)
  final bool isStale = await dbHelper.isCacheStale('store_settings', const Duration(seconds: 30));

  Future<Map<String, String>?> fetchRemoteSettings() async {
    try {
      final List<dynamic> res = await Supabase.instance.client.from('settings').select();
      final Map<String, String> fetched = {};
      for (var r in res) {
        fetched[r['key'] as String] = (r['value'] ?? '').toString();
      }
      if (fetched.isNotEmpty) {
        final db = await dbHelper.database;
        final batch = db.batch();
        for (var entry in fetched.entries) {
          batch.insert(
            'settings',
            {'key': entry.key, 'value': entry.value},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        await dbHelper.updateLastSynced('store_settings');
        return fetched;
      }
    } catch (_) {}
    return null;
  }

  if (cached.isEmpty || isStale) {
    debugPrint('[Cache] Store settings cache miss or stale. Fetching in background...');
    final remote = await fetchRemoteSettings();
    if (remote != null && remote.isNotEmpty) {
      cached = remote;
      yield remote;
    }
  } else {
    debugPrint('[Cache] Store settings cache hit (fresh).');
  }

  bool isDisposed = false;
  RealtimeChannel? realtimeChannel;
  try {
    realtimeChannel = Supabase.instance.client
        .channel('public:settings_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'settings',
          callback: (payload) {
            ref.invalidateSelf();
          },
        )
        .subscribe();
  } catch (e) {
    debugPrint('[Cache] Realtime settings subscribe error: $e');
  }

  ref.onDispose(() {
    isDisposed = true;
    try {
      realtimeChannel?.unsubscribe();
    } catch (_) {}
  });

  // 3. Fallback polling loop (every 15 seconds) for background updates
  while (!isDisposed) {
    await Future.delayed(const Duration(seconds: 15));
    if (isDisposed) break;
    final remote = await fetchRemoteSettings();
    if (isDisposed) break;
    if (remote != null && remote.isNotEmpty) {
      bool changed = false;
      if (remote.length != cached.length) {
        changed = true;
      } else {
        for (var entry in remote.entries) {
          if (cached[entry.key] != entry.value) {
            changed = true;
            break;
          }
        }
      }
      if (changed && !isDisposed) {
        debugPrint('[Cache] Store settings updated in background.');
        cached = remote;
        yield remote;
      }
    }
  }
});
