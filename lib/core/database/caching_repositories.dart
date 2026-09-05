import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm, Database;
import 'package:uuid/uuid.dart';
import 'repositories.dart';
import 'database_helper.dart';

double? _asDouble(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val.trim());
  return null;
}

/// Cache-through repository pattern for offline-first architecture.
/// Tries Supabase first → caches results in SQLite → falls back to SQLite on failure.

class CachingCatalogRepository implements CatalogRepository {
  final SupabaseCatalogRepository _remote;
  final SQLiteCatalogRepository _local;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  CachingCatalogRepository({
    SupabaseCatalogRepository? remote,
    SQLiteCatalogRepository? local,
  })  : _remote = remote ?? SupabaseCatalogRepository(),
        _local = local ?? SQLiteCatalogRepository();  @override
  Future<List<Map<String, dynamic>>> getCategories({
    Function(List<Map<String, dynamic>>)? onRefresh,
  }) async {
    // 1. Fetch cached data immediately
    final cachedData = await _local.getCategories();
    
    // 2. Check if cache is stale (TTL for categories is 2 hours)
    final bool isStale = await _dbHelper.isCacheStale('categories', const Duration(hours: 2));
    
    if (cachedData.isEmpty) {
      // Cache miss: must fetch blocking-ly
      debugPrint('[Cache] Categories cache miss. Fetching from remote...');
      try {
        final remoteData = await _remote.getCategories();
        await _cacheCategories(remoteData);
        await _dbHelper.updateLastSynced('categories');
        return remoteData;
      } catch (e) {
        debugPrint('[Cache] Categories remote fetch failed: $e');
        return cachedData; // returns empty list
      }
    }
    
    if (!isStale) {
      // Cache hit and fresh! Return cached data immediately
      debugPrint('[Cache] Categories cache hit (fresh).');
      return cachedData;
    }
    
    // Cache hit but stale! Return cached data immediately and revalidate in background
    debugPrint('[Cache] Categories cache hit (stale). Revalidating in background...');
    _revalidateCategories(onRefresh);
    
    return cachedData;
  }

  Future<void> _revalidateCategories(Function(List<Map<String, dynamic>>)? onRefresh) async {
    try {
      final remoteData = await _remote.getCategories();
      await _cacheCategories(remoteData);
      await _dbHelper.updateLastSynced('categories');
      debugPrint('[Cache] Categories revalidation success.');
      if (onRefresh != null) {
        onRefresh(remoteData);
      }
    } catch (e) {
      debugPrint('[Cache] Categories revalidation failure: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProducts({
    String? search,
    String? categoryId,
    Function(List<Map<String, dynamic>>)? onRefresh,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      debugPrint('[Cache] Products force refresh. Fetching from remote...');
      try {
        final remoteData = await _remote.getProducts(search: search, categoryId: categoryId);
        await _cacheProducts(remoteData);
        await _dbHelper.updateLastSynced('products');
        return remoteData;
      } catch (e) {
        debugPrint('[Cache] Products force refresh failed: $e');
      }
    }

    // 1. Fetch cached data immediately
    final cachedData = await _local.getProducts(search: search, categoryId: categoryId);
    
    // 2. Check if cache is stale (TTL for products is 30 minutes)
    final bool isStale = await _dbHelper.isCacheStale('products', const Duration(minutes: 30));
    
    if (cachedData.isEmpty) {
      // Cache miss
      debugPrint('[Cache] Products cache miss. Fetching from remote...');
      try {
        final remoteData = await _remote.getProducts(search: search, categoryId: categoryId);
        if (search == null && categoryId == null) {
          await _cacheProducts(remoteData);
          await _dbHelper.updateLastSynced('products');
        }
        return remoteData;
      } catch (e) {
        debugPrint('[Cache] Products remote fetch failed: $e');
        return cachedData;
      }
    }
    
    if (!isStale) {
      debugPrint('[Cache] Products cache hit (fresh).');
      return cachedData;
    }
    
    debugPrint('[Cache] Products cache hit (stale). Revalidating in background...');
    _revalidateProducts(search, categoryId, onRefresh);
    
    return cachedData;
  }

  Future<void> _revalidateProducts(
    String? search,
    String? categoryId,
    Function(List<Map<String, dynamic>>)? onRefresh,
  ) async {
    try {
      final remoteData = await _remote.getProducts(search: search, categoryId: categoryId);
      if (search == null && categoryId == null) {
        await _cacheProducts(remoteData);
        await _dbHelper.updateLastSynced('products');
      }
      debugPrint('[Cache] Products revalidation success.');
      if (onRefresh != null) {
        onRefresh(remoteData);
      }
    } catch (e) {
      debugPrint('[Cache] Products revalidation failure: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getProductById(
    String id, {
    Function(Map<String, dynamic>)? onRefresh,
  }) async {
    final cachedData = await _local.getProductById(id);
    final bool isStale = await _dbHelper.isCacheStale('product_$id', const Duration(minutes: 10));
    
    if (cachedData == null) {
      debugPrint('[Cache] ProductDetail cache miss. Fetching...');
      try {
        final remoteData = await _remote.getProductById(id);
        if (remoteData != null) {
          final db = await _dbHelper.database;
          await db.insert('products', _sanitizeProductForSqlite(remoteData), conflictAlgorithm: ConflictAlgorithm.replace);
          await _dbHelper.updateLastSynced('product_$id');
        }
        return remoteData;
      } catch (e) {
        debugPrint('[Cache] ProductDetail remote fetch failed: $e');
        return null;
      }
    }
    
    if (!isStale) {
      debugPrint('[Cache] ProductDetail cache hit (fresh).');
      return cachedData;
    }
    
    debugPrint('[Cache] ProductDetail cache hit (stale). Revalidating in background...');
    _revalidateProductById(id, onRefresh);
    return cachedData;
  }

  Future<void> _revalidateProductById(String id, Function(Map<String, dynamic>)? onRefresh) async {
    try {
      final remoteData = await _remote.getProductById(id);
      if (remoteData != null) {
        final db = await _dbHelper.database;
        await db.insert('products', _sanitizeProductForSqlite(remoteData), conflictAlgorithm: ConflictAlgorithm.replace);
        await _dbHelper.updateLastSynced('product_$id');
        debugPrint('[Cache] ProductDetail revalidation success.');
        if (onRefresh != null) {
          onRefresh(remoteData);
        }
      }
    } catch (e) {
      debugPrint('[Cache] ProductDetail revalidation failure: $e');
    }
  }

  Map<String, dynamic> _sanitizeProductForSqlite(Map<String, dynamic> p) {
    return {
      'id': p['id'],
      'name': p['name'],
      'category_id': p['category_id'],
      'image_path': p['image_path'],
      'description': p['description'] is String ? p['description'] : p['description']?.toString(),
      'price': _asDouble(p['price']) ?? 0.0,
      'unit': p['unit'],
      'stock': _asDouble(p['stock']) ?? 0.0,
      'is_available': (p['is_available'] == null || p['is_available'] == true || p['is_available'] == 1) ? 1 : 0,
      'is_enabled': (p['is_enabled'] != false && p['is_enabled'] != 0) ? 1 : 0,
      'created_at': p['created_at']?.toString(),
      'order_now_stock': _asDouble(p['order_now_stock']) ?? 0.0,
      'order_now_price': _asDouble(p['order_now_price']) ?? (_asDouble(p['price']) ?? 0.0),
      'order_now_mrp': _asDouble(p['order_now_mrp']) ?? (_asDouble(p['mrp']) ?? 0.0),
      'order_now_cost_price': _asDouble(p['order_now_cost_price']) ?? 0.0,
      'order_now_is_available': (p['order_now_is_available'] == true ||
              p['order_now_is_available'] == 1 ||
              p['order_now_is_available']?.toString() == '1' ||
              p['order_now_is_available']?.toString().toLowerCase() == 'true')
          ? 1
          : 0,
    };
  }

  @override
  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    await _cacheProducts(products);
  }

  /// Cache categories into SQLite (upsert)
  Future<void> _cacheCategories(List<Map<String, dynamic>> categories) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();
      for (final cat in categories) {
        batch.insert(
          'categories',
          {
            'id': cat['id']?.toString(),
            'name': cat['name']?.toString() ?? '',
            'is_enabled': (cat['is_enabled'] == true || cat['is_enabled'] == 1) ? 1 : 0,
            'created_at': cat['created_at']?.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('CachingCatalog: SQLite category cache failed: $e');
    }
  }

  /// Cache products into SQLite (upsert)
  Future<void> _cacheProducts(List<Map<String, dynamic>> products) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();
      for (final p in products) {
        batch.insert(
          'products',
          _sanitizeProductForSqlite(p),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('CachingCatalog: SQLite product cache failed: $e');
    }
  }
}

class CachingOrderRepository implements OrderRepository {
  final SupabaseOrderRepository _remote;
  final SQLiteOrderRepository _local;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  CachingOrderRepository({
    SupabaseOrderRepository? remote,
    SQLiteOrderRepository? local,
  })  : _remote = remote ?? SupabaseOrderRepository(),
        _local = local ?? SQLiteOrderRepository();

  @override
  Future<Map<String, dynamic>> placeOrder({
    required String customerPhone,
    required String deliveryAddress,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String? idempotencyKey,
    String? deliveryDate,
    String? offlineOrderNo,
    String? areaName,
    String? roadName,
    String? subRoadName,
    String? orderType,
    String? orderTakingDate,
    String? customerId,
  }) async {
    final String actualOfflineNo = offlineOrderNo ?? () {
      final now = DateTime.now();
      final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
      final msStr = (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
      return 'OFF-$dateStr-$msStr';
    }();

    final connectivityResults = await Connectivity().checkConnectivity();
    final bool isOffline = connectivityResults.every((r) => r == ConnectivityResult.none);

    Future<Map<String, dynamic>> queueLocally() async {
      debugPrint('CachingOrder: Queuing order locally in SQLite for background sync.');
      final localResult = await _local.placeOrder(
        customerPhone: customerPhone,
        deliveryAddress: deliveryAddress,
        totalAmount: totalAmount,
        items: items,
        idempotencyKey: idempotencyKey,
        deliveryDate: deliveryDate,
        offlineOrderNo: actualOfflineNo,
        areaName: areaName,
        roadName: roadName,
        subRoadName: subRoadName,
        orderType: orderType,
        orderTakingDate: orderTakingDate,
        customerId: customerId,
      );
      final db = await _dbHelper.database;
      await db.update(
        'orders',
        {
          'sync_status': 'pending',
          'offline_order_no': actualOfflineNo,
        },
        where: 'id = ?',
        whereArgs: [localResult['id']],
      );
      return {
        ...localResult,
        'sync_status': 'pending',
        'is_offline': true,
        'offline_order_no': actualOfflineNo,
      };
    }

    if (!isOffline) {
      // ONLINE MODE: Submit directly to Supabase RPC
      try {
        final result = await _remote.placeOrder(
          customerPhone: customerPhone,
          deliveryAddress: deliveryAddress,
          totalAmount: totalAmount,
          items: items,
          idempotencyKey: idempotencyKey,
          deliveryDate: deliveryDate,
          offlineOrderNo: actualOfflineNo,
          areaName: areaName,
          roadName: roadName,
          subRoadName: subRoadName,
          orderType: orderType,
          orderTakingDate: orderTakingDate,
          customerId: customerId,
        );
        final mergedResult = Map<String, dynamic>.from(result);
        mergedResult['total_amount'] = (result['total_amount'] as num?)?.toDouble() ?? totalAmount;
        mergedResult['order_type'] = orderType ?? 'Normal';

        // Clean up any local offline duplicate before caching the synced order
        final db = await _dbHelper.database;
        await _deleteLocalOrderDuplicate(db, mergedResult);
        if (actualOfflineNo.isNotEmpty) {
          try {
            await db.delete('orders', where: "offline_order_no = ?", whereArgs: [actualOfflineNo]);
          } catch (_) {}
        }
        // Cache the synced order locally
        await _cacheOrder(mergedResult, items, 'synced');
        return mergedResult;
      } catch (e) {
        debugPrint('CachingOrder: Online order submission error: $e');
        final errorStr = e.toString().toLowerCase();
        final bool isNetworkError = errorStr.contains('socketexception') ||
            errorStr.contains('clientexception') ||
            errorStr.contains('timeoutexception') ||
            errorStr.contains('failed host lookup') ||
            errorStr.contains('connection refused') ||
            errorStr.contains('connection closed') ||
            errorStr.contains('network is unreachable') ||
            errorStr.contains('software caused connection abort') ||
            errorStr.contains('connection reset') ||
            errorStr.contains('handshakeexception') ||
            errorStr.contains('failed to connect') ||
            errorStr.contains('network error');

        if (isNetworkError) {
          debugPrint('CachingOrder: Network error detected. Gracefully queuing offline order.');
          return await queueLocally();
        }
        rethrow;
      }
    } else {
      // OFFLINE MODE: Network is disconnected. Queue locally in SQLite for future sync
      debugPrint('CachingOrder: Network is offline, queuing order locally for sync.');
      return await queueLocally();
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getOrders(
    String customerPhone, {
    Function(List<Map<String, dynamic>>)? onRefresh,
  }) async {
    // 1. Fetch cached local data immediately (including pending unsynced orders)
    final db = await _dbHelper.database;
    final cachedLocal = await _local.getOrders(customerPhone);
    final pendingOrders = await db.query(
      'orders',
      where: "sync_status IN ('pending', 'failed', 'permanently_failed')",
      orderBy: 'order_date DESC',
    );
    
    // Deduplicate
    final Map<String, Map<String, dynamic>> dedup = {};
    for (final o in cachedLocal) {
      final key = o['order_number']?.toString() ?? o['id']?.toString() ?? '';
      if (key.isNotEmpty) {
        dedup[key] = o;
      }
    }
    for (final o in pendingOrders) {
      final key = o['order_number']?.toString() ?? o['offline_order_no']?.toString() ?? o['id']?.toString() ?? '';
      if (key.isNotEmpty && !dedup.containsKey(key)) {
        dedup[key] = o;
      }
    }
    
    final allLocalOrders = dedup.values.toList();
    allLocalOrders.sort((a, b) {
      final aDate = DateTime.tryParse(a['order_date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b['order_date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    // 2. Check if cache is stale (TTL for orders cache is 1 minute)
    final bool isStale = await _dbHelper.isCacheStale('orders_$customerPhone', const Duration(minutes: 1));
    
    if (allLocalOrders.isEmpty) {
      // Cache miss: block on remote fetch
      debugPrint('[Cache] Orders cache miss. Fetching from remote...');
      try {
        final remoteOrders = await _remote.getOrders(customerPhone);
        for (final order in remoteOrders) {
          await _deleteLocalOrderDuplicate(db, order);
          await _cacheOrder(order, [], 'synced');
        }
        await _dbHelper.updateLastSynced('orders_$customerPhone');
        return remoteOrders;
      } catch (e) {
        debugPrint('[Cache] Orders remote fetch failed: $e');
        return allLocalOrders;
      }
    }

    if (!isStale) {
      debugPrint('[Cache] Orders cache hit (fresh).');
      return allLocalOrders;
    }

    debugPrint('[Cache] Orders cache hit (stale). Revalidating in background...');
    _revalidateOrders(customerPhone, onRefresh);
    return allLocalOrders;
  }

  Future<void> _deleteLocalOrderDuplicate(Database db, Map<String, dynamic> order) async {
    final orderNo = order['order_number']?.toString();
    final offlineNo = order['offline_order_no']?.toString();
    final orderId = order['id']?.toString();
    final idempotencyKey = order['idempotency_key']?.toString();

    if (offlineNo != null && offlineNo.isNotEmpty) {
      try {
        await db.delete('orders', where: "offline_order_no = ? AND (order_number IS NULL OR order_number = '' OR sync_status != 'synced')", whereArgs: [offlineNo]);
      } catch (_) {}
    }
    if (orderNo != null && orderNo.isNotEmpty) {
      try {
        await db.delete('orders', where: "order_number = ? AND sync_status != 'synced'", whereArgs: [orderNo]);
      } catch (_) {}
    }
    if (orderId != null && orderId.isNotEmpty) {
      try {
        await db.delete('orders', where: "id = ? AND sync_status != 'synced'", whereArgs: [orderId]);
      } catch (_) {}
    }
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      try {
        await db.delete('orders', where: "idempotency_key = ?", whereArgs: [idempotencyKey]);
      } catch (_) {}
    }
  }

  Future<void> _revalidateOrders(String customerPhone, Function(List<Map<String, dynamic>>)? onRefresh) async {
    try {
      final remoteOrders = await _remote.getOrders(customerPhone);
      final db = await _dbHelper.database;
      
      final remoteIds = remoteOrders.map((e) => e['id']?.toString()).where((e) => e != null && e.isNotEmpty).toList();
      if (remoteIds.isNotEmpty) {
        final placeholders = List.filled(remoteIds.length, '?').join(',');
        await db.delete(
          'orders',
          where: "customer_phone = ? AND sync_status = 'synced' AND id NOT IN ($placeholders)",
          whereArgs: [customerPhone, ...remoteIds],
        );
      } else {
        await db.delete(
          'orders',
          where: "customer_phone = ? AND sync_status = 'synced'",
          whereArgs: [customerPhone],
        );
      }

      for (final order in remoteOrders) {
        final localExisting = await _local.getOrderById(order['id']?.toString() ?? '');
        final Map<String, dynamic> merged = Map<String, dynamic>.from(order);
        if (localExisting != null) {
          merged['order_type'] = localExisting['order_type'] ?? merged['order_type'];
          final localTotal = (localExisting['total_amount'] as num?)?.toDouble() ?? 0.0;
          final remoteTotal = (merged['total_amount'] as num?)?.toDouble() ?? 0.0;
          if (localTotal > 0 && (remoteTotal <= 0 || (merged['order_type'] == 'Quick Order' && localTotal != remoteTotal))) {
            merged['total_amount'] = localTotal;
          }
        }
        await _deleteLocalOrderDuplicate(db, merged);
        await _cacheOrder(merged, [], 'synced');
      }
      await _dbHelper.updateLastSynced('orders_$customerPhone');
      debugPrint('[Cache] Orders revalidation success.');
      
      if (onRefresh != null) {
        final pendingOrders = await db.query(
          'orders',
          where: "sync_status IN ('pending', 'failed', 'permanently_failed')",
          orderBy: 'order_date DESC',
        );
        final Map<String, Map<String, dynamic>> dedup = {};
        for (final o in remoteOrders) {
          final key = o['order_number']?.toString() ?? o['id']?.toString() ?? '';
          if (key.isNotEmpty) {
            dedup[key] = o;
          }
        }
        for (final o in pendingOrders) {
          final key = o['order_number']?.toString() ?? o['offline_order_no']?.toString() ?? o['id']?.toString() ?? '';
          if (key.isNotEmpty && !dedup.containsKey(key)) {
            dedup[key] = o;
          }
        }
        final allOrders = dedup.values.toList();
        allOrders.sort((a, b) {
          final aDate = DateTime.tryParse(a['order_date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = DateTime.tryParse(b['order_date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        onRefresh(allOrders);
      }
    } catch (e) {
      debugPrint('[Cache] Orders revalidation failure: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getOrderById(
    String id, {
    Function(Map<String, dynamic>)? onRefresh,
  }) async {
    final cachedData = await _local.getOrderById(id);
    final bool isStale = await _dbHelper.isCacheStale('order_detail_$id', const Duration(minutes: 5));
    
    if (cachedData == null) {
      debugPrint('[Cache] Order detail cache miss. Fetching...');
      try {
        final order = await _remote.getOrderById(id);
        if (order != null) {
          await _cacheOrder(order, [], 'synced');
          await _dbHelper.updateLastSynced('order_detail_$id');
        }
        return order;
      } catch (e) {
        debugPrint('[Cache] Order detail fetch failed: $e');
        return null;
      }
    }
    
    if (!isStale) {
      debugPrint('[Cache] Order detail cache hit (fresh).');
      return cachedData;
    }
    
    debugPrint('[Cache] Order detail cache hit (stale). Revalidating in background...');
    _revalidateOrderById(id, onRefresh);
    return cachedData;
  }

  Future<void> _revalidateOrderById(String id, Function(Map<String, dynamic>)? onRefresh) async {
    try {
      final order = await _remote.getOrderById(id);
      if (order != null) {
        final localExisting = await _local.getOrderById(id);
        final Map<String, dynamic> merged = Map<String, dynamic>.from(order);
        if (localExisting != null) {
          merged['order_type'] = localExisting['order_type'] ?? merged['order_type'];
          final localTotal = (localExisting['total_amount'] as num?)?.toDouble() ?? 0.0;
          if (localTotal > 0 && merged['order_type'] == 'Quick Order') {
            merged['total_amount'] = localTotal;
          }
        }
        await _cacheOrder(merged, [], 'synced');
        await _dbHelper.updateLastSynced('order_detail_$id');
        debugPrint('[Cache] Order detail revalidation success.');
        if (onRefresh != null) {
          onRefresh(merged);
        }
      }
    } catch (e) {
      debugPrint('[Cache] Order detail revalidation failure: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getOrderItems(
    String orderId, {
    Function(List<Map<String, dynamic>>)? onRefresh,
  }) async {
    final cachedData = await _local.getOrderItems(orderId);
    final bool isStale = await _dbHelper.isCacheStale('order_items_$orderId', const Duration(minutes: 5));
    
    if (cachedData.isEmpty) {
      debugPrint('[Cache] Order items cache miss. Fetching...');
      try {
        final remoteItems = await _remote.getOrderItems(orderId);
        if (remoteItems.isNotEmpty) {
          await _cacheOrderItems(orderId, remoteItems);
          await _dbHelper.updateLastSynced('order_items_$orderId');
        }
        return remoteItems;
      } catch (e) {
        debugPrint('[Cache] Order items fetch failed: $e');
        return cachedData;
      }
    }
    
    if (!isStale) {
      debugPrint('[Cache] Order items cache hit (fresh).');
      return cachedData;
    }
    
    debugPrint('[Cache] Order items cache hit (stale). Revalidating...');
    _revalidateOrderItems(orderId, onRefresh);
    return cachedData;
  }

  Future<void> _revalidateOrderItems(String orderId, Function(List<Map<String, dynamic>>)? onRefresh) async {
    try {
      final localItems = await _local.getOrderItems(orderId);
      if (localItems.isNotEmpty) {
        if (onRefresh != null) {
          onRefresh(localItems);
        }
        return;
      }
      final remoteItems = await _remote.getOrderItems(orderId);
      if (remoteItems.isNotEmpty) {
        await _cacheOrderItems(orderId, remoteItems);
        await _dbHelper.updateLastSynced('order_items_$orderId');
        debugPrint('[Cache] Order items revalidation success.');
        if (onRefresh != null) {
          onRefresh(remoteItems);
        }
      }
    } catch (e) {
      debugPrint('[Cache] Order items revalidation failure: $e');
    }
  }

  Future<void> _cacheOrderItems(String orderId, List<Map<String, dynamic>> items) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();
      batch.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      for (final item in items) {
        final String itemId = (item['id'] != null && item['id'].toString().isNotEmpty)
            ? item['id'].toString()
            : const Uuid().v4();

        double price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        double totalPrice = (item['total_price'] as num?)?.toDouble() ?? (qty * price);

        batch.insert(
          'order_items',
          {
            'id': itemId,
            'order_id': orderId,
            'product_id': item['product_id']?.toString(),
            'product_name': item['product_name']?.toString() ?? 'Item',
            'price': price,
            'quantity': qty,
            'unit': item['unit']?.toString() ?? 'kg',
            'total_price': totalPrice,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      debugPrint('CachingOrder: Successfully cached ${items.length} items for order $orderId');
    } catch (e) {
      debugPrint('CachingOrder: SQLite order items cache failed: $e');
    }
  }

  /// Cache a synced order locally
  Future<void> _cacheOrder(Map<String, dynamic> order, List<Map<String, dynamic>> items, String syncStatus) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'orders',
        {
          'id': order['id']?.toString(),
          'order_number': order['order_number']?.toString(),
          'customer_id': order['customer_id']?.toString(),
          'customer_phone': order['customer_phone']?.toString(),
          'delivery_address': order['delivery_address']?.toString(),
          'order_date': order['order_date']?.toString(),
          'status': order['status']?.toString() ?? 'Pending',
          'total_amount': (order['total_amount'] as num?)?.toDouble() ?? 0.0,
          'sync_status': syncStatus,
          'delivery_date': order['delivery_date']?.toString(),
          'area_id': order['area_id']?.toString(),
          'area_name': order['area_name']?.toString(),
          'road_id': order['road_id']?.toString(),
          'road_name': order['road_name']?.toString(),
          'sub_road_id': order['sub_road_id']?.toString(),
          'sub_road_name': order['sub_road_name']?.toString(),
          'customer_name': order['customer_name']?.toString(),
          'offline_order_no': (order['offline_order_no'] ?? order['order_number'])?.toString(),
          'order_type': order['order_type']?.toString() ?? 'Normal',
          'order_taking_date': order['order_taking_date']?.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (items.isNotEmpty && order['id'] != null) {
        await _cacheOrderItems(order['id'].toString(), items);
      }
    } catch (e) {
      debugPrint('CachingOrder: SQLite order cache failed: $e');
    }
  }

  /// Get pending orders for sync
  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    final db = await _dbHelper.database;
    return await db.query(
      'orders',
      where: "sync_status = 'pending' OR sync_status = 'failed'",
      orderBy: 'order_date ASC',
    );
  }

  /// Get items for a pending local order
  Future<List<Map<String, dynamic>>> getLocalOrderItems(String orderId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  /// Mark a local order as synced after successful server submission
  Future<void> markOrderSynced(String localOrderId, String remoteOrderId, String remoteOrderNumber) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Update order items to point to the new remoteOrderId
      await txn.update(
        'order_items',
        {'order_id': remoteOrderId},
        where: 'order_id = ?',
        whereArgs: [localOrderId],
      );
      // 2. Update order ID and sync status
      await txn.update(
        'orders',
        {
          'sync_status': 'synced',
          'id': remoteOrderId,
          'order_number': remoteOrderNumber,
        },
        where: 'id = ?',
        whereArgs: [localOrderId],
      );
    });
  }

  /// Mark a local order as failed and increment the retry counter
  Future<void> markOrderFailed(String orderId, String error) async {
    final db = await _dbHelper.database;
    await db.rawUpdate(
      "UPDATE orders SET sync_status = 'failed', sync_retry_count = COALESCE(sync_retry_count, 0) + 1 WHERE id = ?",
      [orderId],
    );
  }

  /// Mark a local order as permanently failed (exceeded max retries)
  Future<void> markOrderPermanentlyFailed(String orderId) async {
    final db = await _dbHelper.database;
    await db.update(
      'orders',
      {'sync_status': 'permanently_failed'},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  @override
  Future<void> retryOrderSync(String orderId) async {
    await _local.retryOrderSync(orderId);
  }

  @override
  Future<void> dismissPermanentlyFailedOrder(String orderId) async {
    await _local.dismissPermanentlyFailedOrder(orderId);
  }
}

class CachingCustomerRepository implements CustomerRepository {
  final SupabaseCustomerRepository _remote;
  final SQLiteCustomerRepository _local;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  CachingCustomerRepository({
    SupabaseCustomerRepository? remote,
    SQLiteCustomerRepository? local,
  })  : _remote = remote ?? SupabaseCustomerRepository(),
        _local = local ?? SQLiteCustomerRepository();

  @override
  Future<Map<String, dynamic>?> login(String phone, String password) async {
    try {
      final customer = await _remote.login(phone, password);
      if (customer != null) {
        await _cacheCustomer(customer);
      }
      return customer;
    } catch (e) {
      debugPrint('CachingCustomer: Supabase login failed, trying local: $e');
      return await _local.login(phone, password);
    }
  }

  @override
  Future<Map<String, dynamic>?> loginWithCode(String code) async {
    try {
      final customer = await _remote.loginWithCode(code);
      if (customer != null) {
        await _cacheCustomer(customer);
      }
      return customer;
    } catch (e) {
      debugPrint('CachingCustomer: Supabase loginWithCode failed, trying local: $e');
      return await _local.loginWithCode(code);
    }
  }

  @override
  Future<Map<String, dynamic>?> loginWithCodeAndPassword(String code, String password) async {
    try {
      final customer = await _remote.loginWithCodeAndPassword(code, password);
      if (customer != null) {
        await _cacheCustomer(customer);
      }
      return customer;
    } catch (e) {
      debugPrint('CachingCustomer: Supabase loginWithCodeAndPassword failed, trying local: $e');
      return await _local.loginWithCodeAndPassword(code, password);
    }
  }

  @override
  Future<Map<String, dynamic>?> loginWithGoogle() async {
    try {
      final customer = await _remote.loginWithGoogle();
      if (customer != null) {
        await _cacheCustomer(customer);
      }
      return customer;
    } catch (e) {
      debugPrint('CachingCustomer: Supabase loginWithGoogle failed: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> completeGoogleOnboarding({
    required String customerId,
    required String name,
    required String phone,
    required String customerCode,
    required String password,
  }) async {
    try {
      final customer = await _remote.completeGoogleOnboarding(
        customerId: customerId,
        name: name,
        phone: phone,
        customerCode: customerCode,
        password: password,
      );
      if (customer != null) {
        await _cacheCustomer(customer);
        return customer;
      }
    } catch (e) {
      debugPrint('CachingCustomer: Supabase completeGoogleOnboarding failed: $e');
    }
    final localCust = await _local.completeGoogleOnboarding(
      customerId: customerId,
      name: name,
      phone: phone,
      customerCode: customerCode,
      password: password,
    );
    if (localCust != null) {
      await _cacheCustomer(localCust);
    }
    return localCust;
  }

  @override
  Future<Map<String, dynamic>?> setupPasswordForCode(String code, String name, String password, {String? pin}) async {
    try {
      final customer = await _remote.setupPasswordForCode(code, name, password, pin: pin);
      if (customer != null) {
        await _cacheCustomer(customer);
      }
      return customer;
    } catch (e) {
      debugPrint('CachingCustomer: Supabase setupPasswordForCode failed: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> registerGuest(String name, String phone, String address, {String? areaId, String? roadId, String? subRoadId}) async {
    try {
      final customer = await _remote.registerGuest(name, phone, address, areaId: areaId, roadId: roadId, subRoadId: subRoadId);
      if (customer != null) {
        await _cacheCustomer(customer);
        return customer;
      }
    } catch (e) {
      debugPrint('CachingCustomer: Supabase registerGuest failed, trying local: $e');
    }
    final localCustomer = await _local.registerGuest(name, phone, address, areaId: areaId, roadId: roadId, subRoadId: subRoadId);
    return localCustomer;
  }

  @override
  Future<Map<String, dynamic>?> register(String name, String phone, String password, String address, {String? areaId, String? roadId, String? subRoadId}) async {
    try {
      final customer = await _remote.register(name, phone, password, address, areaId: areaId, roadId: roadId, subRoadId: subRoadId);
      if (customer != null) {
        await _cacheCustomer(customer);
      }
      return customer;
    } catch (e) {
      debugPrint('CachingCustomer: Supabase register failed, trying local: $e');
      return await _local.register(name, phone, password, address, areaId: areaId, roadId: roadId, subRoadId: subRoadId);
    }
  }

  @override
  Future<Map<String, dynamic>?> getLoggedInCustomer({
    Function(Map<String, dynamic>)? onRefresh,
  }) async {
    // 1. Fetch cached local customer immediately
    final cachedData = await _local.getLoggedInCustomer();
    
    // 2. Check if cache is stale (TTL for customer profile is 5 minutes)
    bool isStale = await _dbHelper.isCacheStale('customer_profile', const Duration(minutes: 5));
    
    if (cachedData != null) {
      final bool hasMissingRouteFields = 
          (cachedData['area_id'] != null && cachedData['area_name'] == null) ||
          (cachedData['road_id'] != null && cachedData['road_name'] == null) ||
          (cachedData['sub_road_id'] != null && cachedData['sub_road_name'] == null);
      final rawSched = cachedData['delivery_schedule'];
      final bool hasMissingSchedule = rawSched == null || 
          (rawSched is List && rawSched.isEmpty) ||
          (rawSched is String && (rawSched.trim().isEmpty || rawSched.trim() == '[]'));
      final rawAddr = cachedData['address']?.toString().trim();
      final bool hasMissingAddress = rawAddr == null || rawAddr.isEmpty || rawAddr.toLowerCase() == 'n/a';
      if (hasMissingRouteFields || hasMissingSchedule || hasMissingAddress) {
        debugPrint('[Cache] Customer profile has missing route/schedule/address. Forcing revalidation.');
        isStale = true;
      }
    }
    
    if (cachedData == null) {
      // Cache miss: block on remote fetch
      debugPrint('[Cache] Customer profile cache miss. Fetching from remote...');
      try {
        final customer = await _remote.getLoggedInCustomer();
        if (customer != null) {
          await _cacheCustomer(customer);
          await _dbHelper.updateLastSynced('customer_profile');
        }
        return customer;
      } catch (e) {
        debugPrint('[Cache] Customer profile remote fetch failed: $e');
        return null;
      }
    }
    
    if (!isStale) {
      debugPrint('[Cache] Customer profile cache hit (fresh).');
      return cachedData;
    }
    
    debugPrint('[Cache] Customer profile cache hit (stale). Revalidating...');
    _revalidateCustomer(onRefresh);
    return cachedData;
  }

  Future<void> _revalidateCustomer(Function(Map<String, dynamic>)? onRefresh) async {
    try {
      final customer = await _remote.getLoggedInCustomer();
      if (customer != null) {
        await _cacheCustomer(customer);
        await _dbHelper.updateLastSynced('customer_profile');
        debugPrint('[Cache] Customer profile revalidation success.');
        if (onRefresh != null) {
          onRefresh(customer);
        }
      }
    } catch (e) {
      debugPrint('[Cache] Customer profile revalidation failure: $e');
    }
  }

  @override
  Future<void> updateProfile(String id, String name, String phone, String address, {String? areaId, String? roadId, String? subRoadId}) async {
    try {
      await _remote.updateProfile(id, name, phone, address, areaId: areaId, roadId: roadId, subRoadId: subRoadId);
      await _local.updateProfile(id, name, phone, address, areaId: areaId, roadId: roadId, subRoadId: subRoadId);
    } catch (e) {
      debugPrint('CachingCustomer: Supabase updateProfile failed: $e');
      throw Exception('Network connection required to update profile. Please check your internet connection and try again.');
    }
  }

  @override
  Future<void> changePassword(String newPassword) async {
    try {
      await _remote.changePassword(newPassword);
      await _local.changePassword(newPassword);
    } catch (e) {
      debugPrint('CachingCustomer: changePassword failed: $e');
      throw Exception('Network connection required to change password. Please check your internet connection and try again.');
    }
  }

  @override
  Future<bool> resetPassword(String phone, String newPassword) async {
    try {
      final success = await _remote.resetPassword(phone, newPassword);
      if (success) {
        await _local.resetPassword(phone, newPassword);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('CachingCustomer: resetPassword failed: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> checkCustomerAuthStatus(String identifier) async {
    try {
      final res = await _remote.checkCustomerAuthStatus(identifier);
      if (res['exists'] == true) return res;
      final localRes = await _local.checkCustomerAuthStatus(identifier);
      if (localRes['exists'] == true) return localRes;
      return res;
    } catch (e) {
      debugPrint('CachingCustomer: checkCustomerAuthStatus remote error: $e');
      final localRes = await _local.checkCustomerAuthStatus(identifier);
      if (localRes['exists'] == true) return localRes;
      return {
        'exists': false,
        'has_password': false,
        'message': 'Unable to connect to server. Please check your internet connection and try again.',
      };
    }
  }

  @override
  Future<Map<String, dynamic>> resetPasswordWithVerification(
    String identifier,
    String phoneConfirm,
    String newPassword,
  ) async {
    try {
      final res = await _remote.resetPasswordWithVerification(identifier, phoneConfirm, newPassword);
      if (res['success'] == true) {
        await _local.resetPasswordWithVerification(identifier, phoneConfirm, newPassword);
      }
      return res;
    } catch (e) {
      debugPrint('CachingCustomer: resetPasswordWithVerification failed: $e');
      return {
        'success': false,
        'error': 'Network connection required to reset password. Please check your internet connection and try again.',
      };
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _remote.deleteAccount();
    } catch (_) {}
    try {
      await _local.deleteAccount();
    } catch (_) {}
    try {
      await _dbHelper.clearUserData();
    } catch (_) {}
  }

  @override
  Future<void> logout() async {
    try {
      await _remote.logout();
    } finally {
      await _local.logout();
    }
  }

  Future<void> _cacheCustomer(Map<String, dynamic> customer) async {
    try {
      final db = await _dbHelper.database;

      // Auto-compose address if blank or N/A
      String resolvedAddr = (customer['address'] as String? ?? '').trim();
      if (resolvedAddr.isEmpty || resolvedAddr.toUpperCase() == 'N/A') {
        final parts = <String>[];
        final srName = (customer['sub_road_name'] as String? ?? '').trim();
        final rName = (customer['road_name'] as String? ?? '').trim();
        final aName = (customer['area_name'] as String? ?? '').trim();
        if (srName.isNotEmpty && srName.toUpperCase() != 'N/A') parts.add(srName);
        if (rName.isNotEmpty && rName.toUpperCase() != 'N/A') parts.add(rName);
        if (aName.isNotEmpty && aName.toUpperCase() != 'N/A' && !rName.contains(aName)) parts.add(aName);
        if (parts.isNotEmpty) {
          resolvedAddr = parts.join(', ');
        }
      }

      final Map<String, dynamic> row = {
        'id': customer['id'],
        'name': customer['name'],
        'phone': customer['phone'],
        'email': customer['email'],
        'address': resolvedAddr.isNotEmpty ? resolvedAddr : customer['address'],
        'is_logged_in': 1,
        'customer_code': customer['customer_code'],
        'is_guest': (customer['is_guest'] == true || customer['is_guest'] == 1) ? 1 : 0,
        'area_id': customer['area_id'],
        'road_id': customer['road_id'],
        'sub_road_id': customer['sub_road_id'],
        'area_name': customer['area_name'],
        'road_name': customer['road_name'],
        'sub_road_name': customer['sub_road_name'],
        'auth_provider': customer['auth_provider'] ?? 'phone_password',
        'google_id': customer['google_id']?.toString(),
        'is_new_customer': (customer['is_new_customer'] == true || customer['is_new_customer'] == 1) ? 1 : 0,
        'delivery_schedule': customer['delivery_schedule'] != null ? json.encode(customer['delivery_schedule']) : null,
        'cutoff_time': customer['cutoff_time'],
        'created_at': customer['created_at']?.toString(),
      };
      await db.insert(
        'customers',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.update(
        'customers',
        {'is_logged_in': 0},
        where: 'id != ?',
        whereArgs: [customer['id']],
      );
    } catch (e) {
      debugPrint('CachingCustomer: SQLite customer cache failed: $e');
    }
  }
}
