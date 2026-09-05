import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'database_helper.dart';

double? _asDouble(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val.trim());
  return null;
}

// ==========================================
// ABSTRACT REPOSITORY INTERFACES
// ==========================================

abstract class CatalogRepository {
  Future<List<Map<String, dynamic>>> getCategories({
    Function(List<Map<String, dynamic>>)? onRefresh,
  });
  Future<List<Map<String, dynamic>>> getProducts({
    String? search,
    String? categoryId,
    Function(List<Map<String, dynamic>>)? onRefresh,
    bool forceRefresh = false,
  });
  Future<Map<String, dynamic>?> getProductById(
    String id, {
    Function(Map<String, dynamic>)? onRefresh,
  });
  Future<void> cacheProducts(List<Map<String, dynamic>> products);
}

abstract class CustomerRepository {
  Future<Map<String, dynamic>?> login(String phone, String password);
  Future<Map<String, dynamic>?> loginWithCode(String code);
  Future<Map<String, dynamic>?> loginWithCodeAndPassword(String code, String password);
  Future<Map<String, dynamic>?> loginWithVerifiedPhone(String phone, {String? firebaseUid});
  Future<Map<String, dynamic>?> loginWithGoogle();
  Future<Map<String, dynamic>?> completeGoogleOnboarding({
    required String customerId,
    required String name,
    required String phone,
    required String customerCode,
    required String password,
  });
  Future<Map<String, dynamic>?> setupPasswordForCode(String code, String name, String password, {String? pin});
  Future<Map<String, dynamic>?> registerGuest(String name, String phone, String address, {String? areaId, String? roadId, String? subRoadId});
  Future<Map<String, dynamic>?> register(String name, String phone, String password, String address, {String? areaId, String? roadId, String? subRoadId});
  Future<Map<String, dynamic>?> getLoggedInCustomer({
    Function(Map<String, dynamic>)? onRefresh,
  });
  Future<void> updateProfile(String id, String name, String phone, String address, {String? areaId, String? roadId, String? subRoadId});
  Future<void> changePassword(String newPassword);
  Future<bool> resetPassword(String phone, String newPassword);
  Future<Map<String, dynamic>> checkCustomerAuthStatus(String identifier);
  Future<Map<String, dynamic>> resetPasswordWithVerification(String identifier, String phoneConfirm, String newPassword);
  Future<void> deleteAccount();
  Future<void> logout();
}

abstract class OrderRepository {
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
  });
  Future<List<Map<String, dynamic>>> getOrders(
    String customerPhone, {
    Function(List<Map<String, dynamic>>)? onRefresh,
  });
  Future<Map<String, dynamic>?> getOrderById(
    String id, {
    Function(Map<String, dynamic>)? onRefresh,
  });
  Future<List<Map<String, dynamic>>> getOrderItems(
    String orderId, {
    Function(List<Map<String, dynamic>>)? onRefresh,
  });
  Future<void> retryOrderSync(String orderId);
  Future<void> dismissPermanentlyFailedOrder(String orderId);
}

// ==========================================
// SQLITE IMPLEMENTATIONS (OFFLINE FALLBACK)
// ==========================================

class SQLiteCatalogRepository implements CatalogRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<Map<String, dynamic>>> getCategories({
    Function(List<Map<String, dynamic>>)? onRefresh,
  }) async {
    final db = await _dbHelper.database;
    return await db.query('categories', where: 'is_enabled = 1', orderBy: 'name ASC');
  }

  @override
  Future<List<Map<String, dynamic>>> getProducts({
    String? search,
    String? categoryId,
    Function(List<Map<String, dynamic>>)? onRefresh,
    bool forceRefresh = false,
  }) async {
    final db = await _dbHelper.database;
    String whereClause = '(products.is_enabled != 0 OR products.is_enabled IS NULL)';
    List<dynamic> whereArgs = [];

    if (search != null && search.isNotEmpty) {
      whereClause += ' AND (products.name LIKE ? OR products.description LIKE ?)';
      whereArgs.add('%$search%');
      whereArgs.add('%$search%');
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      whereClause += ' AND products.category_id = ?';
      whereArgs.add(categoryId);
    }

    final query = '''
      SELECT products.*, categories.name as category_name
      FROM products
      LEFT JOIN categories ON products.category_id = categories.id
      WHERE $whereClause
      ORDER BY products.name ASC
    ''';
    final List<Map<String, dynamic>> res = await db.rawQuery(query, whereArgs);
    return res.map((p) => _parseProductDescription(p)).toList();
  }

  @override
  Future<Map<String, dynamic>?> getProductById(
    String id, {
    Function(Map<String, dynamic>)? onRefresh,
  }) async {
    final db = await _dbHelper.database;
    final res = await db.query('products', where: 'id = ? AND (is_enabled != 0 OR is_enabled IS NULL)', whereArgs: [id]);
    return res.isNotEmpty ? _parseProductDescription(res.first) : null;
  }

  @override
  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final p in products) {
      batch.insert(
        'products',
        {
          'id': p['id'],
          'name': p['name'],
          'category_id': p['category_id'],
          'image_path': p['image_path'],
          'description': p['description'] is Map || p['description'] is List
              ? json.encode(p['description'])
              : p['description']?.toString() ?? '',
          'price': _asDouble(p['price']) ?? 0.0,
          'unit': p['unit']?.toString() ?? '',
          'stock': _asDouble(p['stock']) ?? 0.0,
          'is_available': (p['is_available'] == false || p['is_available'] == 0 || p['is_available']?.toString() == '0' || p['is_available']?.toString().toLowerCase() == 'false') ? 0 : 1,
          'is_enabled': (p['is_enabled'] == false || p['is_enabled'] == 0 || p['is_enabled']?.toString() == '0' || p['is_enabled']?.toString().toLowerCase() == 'false') ? 0 : 1,
          'order_now_stock': _asDouble(p['order_now_stock']) ?? 0.0,
          'order_now_price': _asDouble(p['order_now_price']) ?? 0.0,
          'order_now_mrp': _asDouble(p['order_now_mrp']) ?? 0.0,
          'order_now_cost_price': _asDouble(p['order_now_cost_price']) ?? 0.0,
          'order_now_is_available': (p['order_now_is_available'] == true ||
                  p['order_now_is_available'] == 1 ||
                  p['order_now_is_available']?.toString() == '1' ||
                  p['order_now_is_available']?.toString().toLowerCase() == 'true')
              ? 1
              : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Map<String, dynamic> _parseProductDescription(Map<String, dynamic> p) {
    final Map<String, dynamic> mapped = Map.from(p);
    final desc = p['description'] as String? ?? '';
    if (desc.trim().startsWith('{') && desc.trim().endsWith('}')) {
      try {
        final Map<String, dynamic> decoded = json.decode(desc);
        mapped['description'] = decoded['text'] as String? ?? '';
        mapped['cost_price'] = (decoded['cost_price'] as num?)?.toDouble() ?? 0.0;
        mapped['market_price'] = ((decoded['market_price'] ?? decoded['mrp']) as num?)?.toDouble() ?? 0.0;
        mapped['stock'] = (decoded['stock'] as num?)?.toDouble() ?? 0.0;
        mapped['min_stock'] = (decoded['min_stock'] as num?)?.toDouble() ?? 0.0;
        mapped['barcode'] = decoded['barcode'] as String? ?? '';
        mapped['weight_per_piece'] = (decoded['weight_per_piece'] as num?)?.toDouble() ?? 0.25;
        mapped['sequence_no'] = decoded['sequence_no'] as int? ?? decoded['serial_no'] as int? ?? 0;
        mapped['expiry_date'] = decoded['expiry_date'] as String? ?? '';
        mapped['batch_number'] = decoded['batch_number'] as String? ?? '';
        mapped['prescription_required'] = decoded['prescription_required'] as bool? ?? false;
        mapped['dosage_info'] = decoded['dosage_info'] as String? ?? '';
        mapped['best_before'] = decoded['best_before'] as String? ?? '';
        mapped['pack_date'] = decoded['pack_date'] as String? ?? '';
      } catch (_) {
        mapped['description'] = desc;
      }
    } else {
      mapped['description'] = desc;
    }

    // Override from standalone db columns if present
    if (p['mrp'] != null) {
      mapped['market_price'] = (p['mrp'] as num).toDouble();
    }
    if (p['stock'] != null) {
      mapped['stock'] = (p['stock'] as num).toDouble();
    }
    if (p['price'] != null) {
      mapped['price'] = (p['price'] as num).toDouble();
    }
    mapped['order_now_stock'] = (p['order_now_stock'] as num?)?.toDouble() ?? 0.0;
    mapped['order_now_price'] = (p['order_now_price'] as num?)?.toDouble() ?? (p['order_now_selling_price'] as num?)?.toDouble() ?? mapped['price'] ?? 0.0;
    mapped['order_now_mrp'] = (p['order_now_mrp'] as num?)?.toDouble() ?? mapped['market_price'] ?? 0.0;
    mapped['order_now_cost_price'] = (p['order_now_cost_price'] as num?)?.toDouble() ?? 0.0;
    mapped['order_now_is_available'] = (p['order_now_is_available'] == true ||
        p['order_now_is_available'] == 1 ||
        p['order_now_is_available']?.toString() == '1' ||
        p['order_now_is_available']?.toString().toLowerCase() == 'true');
    return mapped;
  }
}

class SQLiteCustomerRepository implements CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();

  Map<String, dynamic>? _parseCustomer(Map<String, dynamic>? c) {
    if (c == null) return null;
    final mapped = Map<String, dynamic>.from(c);
    if (c['delivery_schedule'] != null) {
      if (c['delivery_schedule'] is List) {
        mapped['delivery_schedule'] = c['delivery_schedule'];
      } else {
        try {
          mapped['delivery_schedule'] = json.decode(c['delivery_schedule'].toString());
        } catch (_) {
          mapped['delivery_schedule'] = [];
        }
      }
    }
    return mapped;
  }

  @override
  Future<Map<String, dynamic>?> login(String phone, String password) async {
    // Plaintext or hashed passwords are never stored in SQLite local cache.
    // Offline authentication is disabled for security; remote Supabase is the single source of truth.
    return null;
  }

  @override
  Future<Map<String, dynamic>?> loginWithCode(String code) async {
    final db = await _dbHelper.database;
    final normalized = code.trim().toUpperCase();
    final res = await db.query(
      'customers',
      where: 'customer_code = ?',
      whereArgs: [normalized],
    );

    if (res.isNotEmpty) {
      final customer = res.first;
      await db.update(
        'customers',
        {'is_logged_in': 1},
        where: 'id = ?',
        whereArgs: [customer['id']],
      );
      await db.update(
        'customers',
        {'is_logged_in': 0},
        where: 'id != ?',
        whereArgs: [customer['id']],
      );
      return _parseCustomer({...customer, 'is_logged_in': 1});
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> loginWithCodeAndPassword(String code, String password) async {
    // Plaintext or hashed passwords are never stored in SQLite local cache.
    // Offline authentication is disabled for security; remote Supabase is the single source of truth.
    return null;
  }

  @override
  Future<Map<String, dynamic>?> loginWithVerifiedPhone(String phone, {String? firebaseUid}) async {
    final db = await _dbHelper.database;
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '').trim();
    final last10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    final res = await db.query(
      'customers',
      where: 'phone = ? OR phone LIKE ?',
      whereArgs: [phone, '%$last10'],
    );
    if (res.isNotEmpty) {
      final customer = res.first;
      await db.update('customers', {'is_logged_in': 1}, where: 'id = ?', whereArgs: [customer['id']]);
      await db.update('customers', {'is_logged_in': 0}, where: 'id != ?', whereArgs: [customer['id']]);
      return _parseCustomer({...customer, 'is_logged_in': 1});
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> setupPasswordForCode(String code, String name, String password, {String? pin}) async {
    final db = await _dbHelper.database;
    final normalized = code.trim().toUpperCase();
    final res = await db.query('customers', where: 'customer_code = ?', whereArgs: [normalized]);

    if (res.isNotEmpty) {
      final customer = res.first;
      await db.update(
        'customers',
        {'name': name, 'is_logged_in': 1},
        where: 'id = ?',
        whereArgs: [customer['id']],
      );
      await db.update('customers', {'is_logged_in': 0}, where: 'id != ?', whereArgs: [customer['id']]);
      return _parseCustomer({...customer, 'name': name, 'is_logged_in': 1});
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> loginWithGoogle() async {
    // Offline authentication is disabled for Google OAuth; remote Supabase is the single source of truth.
    return null;
  }

  @override
  Future<Map<String, dynamic>?> registerGuest(String name, String phone, String address, {String? areaId, String? roadId, String? subRoadId}) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    try {
      await db.insert('customers', {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'area_id': areaId,
        'road_id': roadId,
        'sub_road_id': subRoadId,
        'is_logged_in': 1,
        'is_guest': 1,
      });
      await db.update('customers', {'is_logged_in': 0}, where: 'id != ?', whereArgs: [id]);
      return _parseCustomer({
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'area_id': areaId,
        'road_id': roadId,
        'sub_road_id': subRoadId,
        'is_logged_in': 1,
        'is_guest': true,
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> register(String name, String phone, String password, String address, {String? areaId, String? roadId, String? subRoadId}) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();

    try {
      await db.insert('customers', {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'is_logged_in': 1, // log in immediately after registration
        'area_id': areaId,
        'road_id': roadId,
        'sub_road_id': subRoadId,
      });

      // Logout others
      await db.update(
        'customers',
        {'is_logged_in': 0},
        where: 'id != ?',
        whereArgs: [id],
      );

      return _parseCustomer({
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'area_id': areaId,
        'road_id': roadId,
        'sub_road_id': subRoadId,
        'is_logged_in': 1,
      });
    } catch (_) {
      return null; // Handle phone collision
    }
  }

  @override
  Future<Map<String, dynamic>?> getLoggedInCustomer({
    Function(Map<String, dynamic>)? onRefresh,
  }) async {
    final db = await _dbHelper.database;
    final res = await db.query('customers', where: 'is_logged_in = 1');
    return res.isNotEmpty ? _parseCustomer(res.first) : null;
  }

  @override
  Future<void> updateProfile(String id, String name, String phone, String address, {String? areaId, String? roadId, String? subRoadId}) async {
    final db = await _dbHelper.database;
    await db.update(
      'customers',
      {
        'name': name,
        'phone': phone,
        'address': address,
        'area_id': areaId,
        'road_id': roadId,
        'sub_road_id': subRoadId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> changePassword(String newPassword) async {
    // Plaintext or hashed passwords are never stored in SQLite local cache.
  }

  @override
  Future<bool> resetPassword(String phone, String newPassword) async {
    // Plaintext or hashed passwords are never stored in SQLite local cache.
    return true;
  }

  @override
  Future<Map<String, dynamic>> checkCustomerAuthStatus(String identifier) async {
    final db = await _dbHelper.database;
    final cleanId = identifier.trim().toUpperCase();
    final res = await db.query(
      'customers',
      where: 'customer_code = ? OR phone = ?',
      whereArgs: [cleanId, cleanId],
    );
    if (res.isNotEmpty) {
      final cust = res.first;
      // If cached in SQLite and not a guest, they have completed password setup.
      final bool hasPass = (cust['is_guest'] == 0 || cust['is_guest'] == false || cust['is_guest'] == '0');
      final String phone = cust['phone']?.toString() ?? '';
      final String maskedPhone = phone.length >= 4
          ? '${phone.substring(0, 2)}******${phone.substring(phone.length - 2)}'
          : phone;
      return {
        'exists': true,
        'has_password': hasPass,
        'customer_id': cust['id'],
        'customer_code': cust['customer_code'] ?? cleanId,
        'name': cust['name'] ?? '',
        'phone': phone,
        'phone_masked': maskedPhone,
      };
    }
    return {'exists': false, 'has_password': false, 'message': 'Customer not found'};
  }

  @override
  Future<Map<String, dynamic>> resetPasswordWithVerification(
    String identifier,
    String phoneConfirm,
    String newPassword,
  ) async {
    final db = await _dbHelper.database;
    final cleanId = identifier.trim().toUpperCase();
    final cleanPhone = phoneConfirm.trim();
    final res = await db.query(
      'customers',
      where: 'customer_code = ? OR phone = ?',
      whereArgs: [cleanId, cleanId],
    );
    if (res.isEmpty) {
      return {'success': false, 'error': 'Customer account not found.'};
    }
    final cust = res.first;
    final String regPhone = cust['phone']?.toString() ?? '';
    if (cleanPhone.isNotEmpty && !regPhone.endsWith(cleanPhone) && regPhone != cleanPhone) {
      return {'success': false, 'error': 'Mobile number does not match registered account details.'};
    }
    // Plaintext or hashed passwords are never stored in SQLite local cache.
    return {'success': true, 'message': 'Password reset successfully!'};
  }

  @override
  Future<Map<String, dynamic>?> completeGoogleOnboarding({
    required String customerId,
    required String name,
    required String phone,
    required String customerCode,
    required String password,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'customers',
      {
        'name': name,
        'phone': phone,
        'customer_code': customerCode.trim().toUpperCase(),
        'is_new_customer': 1,
        'is_guest': 0,
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
    final res = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
    return res.isNotEmpty ? _parseCustomer(res.first) : null;
  }

  @override
  Future<void> deleteAccount() async {
    await logout();
  }

  @override
  Future<void> logout() async {
    final db = await _dbHelper.database;
    await db.update('customers', {'is_logged_in': 0});
    // Clear all customer-specific cached tables to protect user privacy
    await db.delete('order_items');
    await db.delete('orders');
    await db.delete('customers');
    await db.delete('customer_login_logs');
    await db.delete('settings', where: 'key IN (?, ?)', whereArgs: ['cart_items', 'quick_cart_items']);
  }
}

class SQLiteOrderRepository implements OrderRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();

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
    final db = await _dbHelper.database;
    final orderId = _uuid.v4();
    
    // Generate a unique offline order number: OLO-YYYYMMDD-XXX
    final now = DateTime.now();
    final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final msStr = (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
    final orderNo = offlineOrderNo ?? 'OLO-$dateStr-$msStr';
    final orderDate = now.toIso8601String();

    await db.transaction((txn) async {
      // Find customer details and route mapping by phone or passed customerId
      Map<String, dynamic>? matchedCustomer;
      if (customerId != null && customerId.isNotEmpty) {
        final custById = await txn.query('customers', where: 'id = ?', whereArgs: [customerId]);
        if (custById.isNotEmpty) matchedCustomer = custById.first;
      }
      if (matchedCustomer == null) {
        final customerRes = await txn.query('customers', where: 'phone = ?', whereArgs: [customerPhone]);
        if (customerRes.isNotEmpty) {
          matchedCustomer = customerRes.first;
        } else {
          // Fallback: match by last 10 digits
          final cleanTarget = customerPhone.replaceAll(RegExp(r'\D'), '');
          final targetDigits = cleanTarget.length >= 10 ? cleanTarget.substring(cleanTarget.length - 10) : cleanTarget;
          final allCusts = await txn.query('customers');
          for (final c in allCusts) {
            final cp = (c['phone']?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
            final cDigits = cp.length >= 10 ? cp.substring(cp.length - 10) : cp;
            if (targetDigits.isNotEmpty && cDigits == targetDigits) {
              matchedCustomer = c;
              break;
            }
          }
        }
      }

      final resolvedCustomerId = customerId ?? matchedCustomer?['id'] as String?;
      final customerName = matchedCustomer?['name'] as String?;
      final areaId = matchedCustomer?['area_id'] as String?;
      final roadId = matchedCustomer?['road_id'] as String?;
      final subRoadId = matchedCustomer?['sub_road_id'] as String?;

      // 1. Create order (canonical order_number is initially NULL or same as offline until synced)
      await txn.insert('orders', {
        'id': orderId,
        'order_number': null, // Canonical order number is assigned by server during sync
        'customer_id': resolvedCustomerId,
        'customer_phone': customerPhone,
        'delivery_address': deliveryAddress,
        'order_date': orderDate,
        'status': 'Pending',
        'total_amount': totalAmount,
        'sync_status': 'pending',
        'idempotency_key': idempotencyKey,
        'delivery_date': deliveryDate ?? orderDate.split('T').first,
        'area_id': areaId,
        'area_name': areaName,
        'road_id': roadId,
        'road_name': roadName,
        'sub_road_id': subRoadId,
        'sub_road_name': subRoadName,
        'customer_name': customerName,
        'offline_order_no': orderNo,
        'order_type': orderType ?? 'Normal',
        'order_taking_date': orderTakingDate,
      });

      // 2. Create order line items
      for (var item in items) {
        await txn.insert('order_items', {
          'id': _uuid.v4(),
          'order_id': orderId,
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'price': item['price'],
          'quantity': item['quantity'],
          'unit': item['unit'],
          'total_price': item['total_price'],
        });
      }
    });

    return {
      'id': orderId,
      'order_number': orderNo, // Return offline number to UI as current order_number placeholder
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'order_date': orderDate,
      'status': 'Pending',
      'total_amount': totalAmount,
      'delivery_date': deliveryDate ?? orderDate.split('T').first,
      'offline_order_no': orderNo,
      'order_type': orderType ?? 'Normal',
      'order_taking_date': orderTakingDate,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getOrders(
    String customerPhone, {
    Function(List<Map<String, dynamic>>)? onRefresh,
  }) async {
    final db = await _dbHelper.database;
    return await db.query(
      'orders',
      where: 'customer_phone = ?',
      whereArgs: [customerPhone],
      orderBy: 'order_date DESC',
    );
  }

  @override
  Future<Map<String, dynamic>?> getOrderById(
    String id, {
    Function(Map<String, dynamic>)? onRefresh,
  }) async {
    final db = await _dbHelper.database;
    final res = await db.query('orders', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  @override
  Future<List<Map<String, dynamic>>> getOrderItems(
    String orderId, {
    Function(List<Map<String, dynamic>>)? onRefresh,
  }) async {
    final db = await _dbHelper.database;
    return await db.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
  }

  @override
  Future<void> retryOrderSync(String orderId) async {
    final db = await _dbHelper.database;
    await db.update(
      'orders',
      {
        'sync_status': 'pending',
        'sync_retry_count': 0,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  @override
  Future<void> dismissPermanentlyFailedOrder(String orderId) async {
    final db = await _dbHelper.database;
    await db.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
    await db.delete('orders', where: 'id = ?', whereArgs: [orderId]);
  }
}

// ==========================================
// SUPABASE IMPLEMENTATIONS (REMOTE BACKEND)
// ==========================================

class SupabaseCatalogRepository implements CatalogRepository {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> getCategories({
    Function(List<Map<String, dynamic>>)? onRefresh,
  }) async {
    final List<dynamic> res = await _client
        .from('categories')
        .select()
        .eq('is_enabled', true)
        .order('name', ascending: true)
        .timeout(const Duration(seconds: 15));
    return List<Map<String, dynamic>>.from(res);
  }

  @override
  Future<List<Map<String, dynamic>>> getProducts({
    String? search,
    String? categoryId,
    Function(List<Map<String, dynamic>>)? onRefresh,
    bool forceRefresh = false,
  }) async {
    var query = _client.from('products').select('*, categories(name)').neq('is_enabled', false);
    
    if (search != null && search.isNotEmpty) {
      query = query.or('name.ilike.%$search%,description.ilike.%$search%');
    }
    
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.eq('category_id', categoryId);
    }
    
    final List<dynamic> res = await query.order('name', ascending: true).timeout(const Duration(seconds: 20));
    return res.map((p) {
      final Map<String, dynamic> mapped = Map.from(p);
      final cat = p['categories'] as Map<String, dynamic>?;
      mapped['category_name'] = cat != null ? cat['name'] : 'N/A';
      return _parseProductDescription(mapped);
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> getProductById(
    String id, {
    Function(Map<String, dynamic>)? onRefresh,
  }) async {
    final res = await _client.from('products').select().eq('id', id).eq('is_enabled', true).maybeSingle().timeout(const Duration(seconds: 15));
    return res != null ? _parseProductDescription(res) : null;
  }

  @override
  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    // No-op for remote repository
  }

  static Map<String, dynamic> parseProductDescription(Map<String, dynamic> p) => _parseProductDescription(p);

  static Map<String, dynamic> _parseProductDescription(Map<String, dynamic> p) {
    final Map<String, dynamic> mapped = Map.from(p);
    final desc = p['description'] as String? ?? '';
    if (desc.trim().startsWith('{') && desc.trim().endsWith('}')) {
      try {
        final Map<String, dynamic> decoded = json.decode(desc);
        mapped['description'] = decoded['text'] as String? ?? '';
        mapped['cost_price'] = _asDouble(decoded['cost_price']) ?? 0.0;
        mapped['market_price'] = _asDouble(decoded['market_price'] ?? decoded['mrp']) ?? 0.0;
        mapped['stock'] = _asDouble(decoded['stock']) ?? 0.0;
        mapped['min_stock'] = _asDouble(decoded['min_stock']) ?? 0.0;
        mapped['barcode'] = decoded['barcode'] as String? ?? '';
        mapped['weight_per_piece'] = _asDouble(decoded['weight_per_piece']) ?? 0.25;
        mapped['sequence_no'] = decoded['sequence_no'] as int? ?? decoded['serial_no'] as int? ?? 0;
        mapped['expiry_date'] = decoded['expiry_date'] as String? ?? '';
        mapped['batch_number'] = decoded['batch_number'] as String? ?? '';
        mapped['prescription_required'] = decoded['prescription_required'] as bool? ?? false;
        mapped['dosage_info'] = decoded['dosage_info'] as String? ?? '';
        mapped['best_before'] = decoded['best_before'] as String? ?? '';
        mapped['pack_date'] = decoded['pack_date'] as String? ?? '';
      } catch (_) {
        mapped['description'] = desc;
      }
    } else {
      mapped['description'] = desc;
    }

    // Override from standalone db columns if present
    if (p['mrp'] != null) {
      final v = _asDouble(p['mrp']);
      if (v != null) mapped['market_price'] = v;
    }
    if (p['stock'] != null) {
      final v = _asDouble(p['stock']);
      if (v != null) mapped['stock'] = v;
    }
    if (p['price'] != null) {
      final v = _asDouble(p['price']);
      if (v != null) mapped['price'] = v;
    }
    mapped['order_now_stock'] = _asDouble(p['order_now_stock']) ?? 0.0;
    mapped['order_now_price'] = _asDouble(p['order_now_price']) ?? _asDouble(p['order_now_selling_price']) ?? (_asDouble(mapped['price']) ?? 0.0);
    mapped['order_now_mrp'] = _asDouble(p['order_now_mrp']) ?? (_asDouble(mapped['market_price']) ?? 0.0);
    mapped['order_now_cost_price'] = _asDouble(p['order_now_cost_price']) ?? 0.0;
    mapped['order_now_is_available'] = (p['order_now_is_available'] == true ||
        p['order_now_is_available'] == 1 ||
        p['order_now_is_available']?.toString() == '1' ||
        p['order_now_is_available']?.toString().toLowerCase() == 'true');
    return mapped;
  }
}

class SupabaseCustomerRepository implements CustomerRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Map<String, dynamic> _enrichCustomerAddress(
    Map<String, dynamic> mapped, {
    String? defaultAddress,
    String? userMetaAddress,
  }) {
    String addr = (mapped['address'] as String? ?? '').trim();
    if (addr.isEmpty || addr.toUpperCase() == 'N/A') {
      if (defaultAddress != null && defaultAddress.trim().isNotEmpty && defaultAddress.trim().toUpperCase() != 'N/A') {
        addr = defaultAddress.trim();
      } else if (userMetaAddress != null && userMetaAddress.trim().isNotEmpty && userMetaAddress.trim().toUpperCase() != 'N/A') {
        addr = userMetaAddress.trim();
      } else {
        final parts = <String>[];
        final srName = (mapped['sub_road_name'] as String? ?? '').trim();
        final rName = (mapped['road_name'] as String? ?? '').trim();
        final aName = (mapped['area_name'] as String? ?? '').trim();
        if (srName.isNotEmpty && srName.toUpperCase() != 'N/A') parts.add(srName);
        if (rName.isNotEmpty && rName.toUpperCase() != 'N/A') parts.add(rName);
        if (aName.isNotEmpty && aName.toUpperCase() != 'N/A' && !rName.contains(aName)) parts.add(aName);
        if (parts.isNotEmpty) {
          addr = parts.join(', ');
        }
      }
      if (addr.isNotEmpty && addr.toUpperCase() != 'N/A') {
        mapped['address'] = addr;
        final custId = mapped['id']?.toString();
        if (custId != null && custId.isNotEmpty) {
          _client.from('customers').update({'address': addr}).eq('id', custId).then((_) {}).catchError((_) {});
        }
      }
    }
    return mapped;
  }

  @override
  Future<Map<String, dynamic>?> login(String phone, String password) async {
    try {
      final AuthResponse res = await _client.auth.signInWithPassword(
        email: '$phone@aplibhaji.com',
        password: password,
      );
      if (res.user != null) {
        final customer = await _client
            .from('customers')
            .select('*, areas(name, delivery_schedule, cutoff_time), roads(name), sub_roads(name)')
            .eq('id', res.user!.id)
            .single();
        final Map<String, dynamic> mapped = Map.from(customer);
        final area = customer['areas'] as Map<String, dynamic>?;
        final road = customer['roads'] as Map<String, dynamic>?;
        final subRoad = customer['sub_roads'] as Map<String, dynamic>?;
        mapped['area_name'] = area?['name'];
        mapped['delivery_schedule'] = area?['delivery_schedule'];
        mapped['cutoff_time'] = area?['cutoff_time'];
        mapped['road_name'] = road?['name'];
        mapped['sub_road_name'] = subRoad?['name'];
        return _enrichCustomerAddress(mapped, userMetaAddress: res.user?.userMetadata?['address']?.toString());
      }
    } catch (_) {
      rethrow;
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> loginWithCode(String code) async {
    try {
      final normalizedCode = code.trim().toUpperCase();

      // Step 1: Request a one-time login token from the server
      final tokenResponse = await _client.rpc('generate_code_login_token', params: {
        'p_code': normalizedCode,
      });
      final String token = tokenResponse['token'];

      // Step 2: Exchange the token for ephemeral credentials
      final credResponse = await _client.rpc('exchange_code_login_token', params: {
        'p_token': token,
      });
      final String email = credResponse['email'];
      final String password = credResponse['password'];

      // Step 3: Sign in with the ephemeral credentials (one-time use)
      final AuthResponse res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user != null) {
        final customer = await _client
            .from('customers')
            .select('*, areas(name, delivery_schedule, cutoff_time), roads(name), sub_roads(name)')
            .eq('id', res.user!.id)
            .single();
        final Map<String, dynamic> mapped = Map.from(customer);
        final area = customer['areas'] as Map<String, dynamic>?;
        final road = customer['roads'] as Map<String, dynamic>?;
        final subRoad = customer['sub_roads'] as Map<String, dynamic>?;
        mapped['area_name'] = area?['name'];
        mapped['delivery_schedule'] = area?['delivery_schedule'];
        mapped['cutoff_time'] = area?['cutoff_time'];
        mapped['road_name'] = road?['name'];
        mapped['sub_road_name'] = subRoad?['name'];
        return _enrichCustomerAddress(mapped, userMetaAddress: res.user?.userMetadata?['address']?.toString());
      }
    } catch (_) {
      rethrow;
    }
    return null;
  }

  String _formatAuthPassword(String raw) {
    final trimmed = raw.trim();
    return trimmed.length < 6 ? 'OK_${trimmed}_2026' : trimmed;
  }

  @override
  Future<Map<String, dynamic>?> loginWithCodeAndPassword(String code, String password) async {
    try {
      String resolvedCode = code.trim().toLowerCase();

      // If user typed a phone number, resolve their canonical customer_code first
      final isDigits = RegExp(r'^\+?[0-9]{7,15}$').hasMatch(resolvedCode.replaceAll(RegExp(r'[\s\-]'), ''));
      if (isDigits) {
        try {
          final status = await checkCustomerAuthStatus(code);
          final serverCode = status['customer_code']?.toString().trim().toLowerCase();
          if (serverCode != null && serverCode.isNotEmpty) {
            resolvedCode = serverCode;
          }
        } catch (_) {}
      }

      final synthEmail = '$resolvedCode@aplibhaji.com';
      final authPassword = _formatAuthPassword(password);

      // Sign in natively with Supabase Auth using synthetic email and user's password
      final AuthResponse res = await _client.auth.signInWithPassword(
        email: synthEmail,
        password: authPassword,
      );
      if (res.user != null) {
        final customer = await _client
            .from('customers')
            .select('*, areas(name, delivery_schedule, cutoff_time), roads(name), sub_roads(name)')
            .eq('auth_user_id', res.user!.id)
            .single();
        final Map<String, dynamic> mapped = Map.from(customer);
        final area = customer['areas'] as Map<String, dynamic>?;
        final road = customer['roads'] as Map<String, dynamic>?;
        final subRoad = customer['sub_roads'] as Map<String, dynamic>?;
        mapped['area_name'] = area?['name'];
        mapped['delivery_schedule'] = area?['delivery_schedule'];
        mapped['cutoff_time'] = area?['cutoff_time'];
        mapped['road_name'] = road?['name'];
        mapped['sub_road_name'] = subRoad?['name'];
        return _enrichCustomerAddress(mapped, userMetaAddress: res.user?.userMetadata?['address']?.toString());
      }
    } catch (_) {
      rethrow;
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> loginWithVerifiedPhone(String phone, {String? firebaseUid}) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '').trim();
      final last10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;

      // 1. First check if customer exists in Supabase by phone or last 10 digits
      final response = await _client
          .from('customers')
          .select('*, areas(name, delivery_schedule, cutoff_time), roads(name), sub_roads(name)')
          .or('phone.eq.$cleanPhone,phone.eq.+91$last10,phone.like.%$last10')
          .limit(1);

      if (response.isNotEmpty) {
        final customer = response.first;
        final Map<String, dynamic> mapped = Map.from(customer);
        final area = customer['areas'] as Map<String, dynamic>?;
        final road = customer['roads'] as Map<String, dynamic>?;
        final subRoad = customer['sub_roads'] as Map<String, dynamic>?;
        mapped['area_name'] = area?['name'];
        mapped['delivery_schedule'] = area?['delivery_schedule'];
        mapped['cutoff_time'] = area?['cutoff_time'];
        mapped['road_name'] = road?['name'];
        mapped['sub_road_name'] = subRoad?['name'];
        mapped['firebase_uid'] = firebaseUid;
        return _enrichCustomerAddress(mapped);
      } else {
        // Brand new customer with verified phone number -> create initial customer record
        final newCode = 'OK${last10.length >= 4 ? last10.substring(last10.length - 4) : last10}';
        final insertRes = await _client.from('customers').insert({
          'name': 'Customer $last10',
          'phone': cleanPhone.length == 10 ? '+91$cleanPhone' : cleanPhone,
          'customer_code': newCode,
          'is_active': 1,
        }).select('*, areas(name, delivery_schedule, cutoff_time), roads(name), sub_roads(name)').single();

        final Map<String, dynamic> mapped = Map.from(insertRes);
        mapped['is_brand_new'] = true;
        mapped['firebase_uid'] = firebaseUid;
        return _enrichCustomerAddress(mapped);
      }
    } catch (e) {
      debugPrint('Supabase loginWithVerifiedPhone error: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> loginWithGoogle() async {
    try {
      GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '177314279725-6vtc8rspo2c749e3h89tqrgfpts2ovft.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );

      // Trigger native Google Sign-In sheet
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await googleSignIn.signIn();
      } catch (e) {
        debugPrint('Google Sign-in with serverClientId failed ($e), attempting fallback without serverClientId...');
        final fallbackGoogleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
        );
        googleUser = await fallbackGoogleSignIn.signIn();
      }

      if (googleUser == null) {
        // User canceled sign-in
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      // 1. Attempt Supabase Google OAuth sign-in if enabled in Supabase Dashboard
      if (idToken != null && idToken.isNotEmpty) {
        try {
          await _client.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          );
        } catch (authErr) {
          debugPrint('Supabase OAuth notice (proceeding via verified Google ID): $authErr');
        }
      }

      // 2. Authoritative customer linking or creation via PostgreSQL RPC
      final rpcRes = await _client.rpc('register_or_link_google_customer', params: {
        'p_google_id': googleUser.id,
        'p_email': googleUser.email,
        'p_name': googleUser.displayName ?? '',
        'p_phone': null,
        'p_address': null,
        'p_area_id': null,
        'p_road_id': null,
        'p_sub_road_id': null,
        'p_customer_code': null,
      });

      if (rpcRes != null && rpcRes is Map) {
        final mapped = Map<String, dynamic>.from(rpcRes);
        return _enrichCustomerAddress(mapped);
      }

      // Fallback query for enriched customer record for the verified authenticated user
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId != null) {
        final existing = await _client
            .from('customers')
            .select('*, areas(name, delivery_schedule, cutoff_time), roads(name), sub_roads(name)')
            .eq('id', currentUserId)
            .maybeSingle();

        if (existing != null) {
          final Map<String, dynamic> mapped = Map.from(existing);
          final area = existing['areas'] as Map<String, dynamic>?;
          final road = existing['roads'] as Map<String, dynamic>?;
          final subRoad = existing['sub_roads'] as Map<String, dynamic>?;
          mapped['area_name'] = area?['name'];
          mapped['delivery_schedule'] = area?['delivery_schedule'];
          mapped['cutoff_time'] = area?['cutoff_time'];
          mapped['road_name'] = road?['name'];
          mapped['sub_road_name'] = subRoad?['name'];
          return _enrichCustomerAddress(mapped);
        }
      }
    } catch (e) {
      debugPrint('loginWithGoogle error: $e');
      rethrow;
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> completeGoogleOnboarding({
    required String customerId,
    required String name,
    required String phone,
    required String customerCode,
    required String password,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '').trim();
    final cleanCode = customerCode.trim().toUpperCase();
    try {
      final rpcRes = await _client.rpc('complete_google_onboarding_secure', params: {
        'p_customer_id': customerId,
        'p_name': name.trim(),
        'p_phone': cleanPhone,
        'p_customer_code': cleanCode,
        'p_password': password,
      });

      if (rpcRes != null && rpcRes is Map) {
        final mapped = Map<String, dynamic>.from(rpcRes);
        return _enrichCustomerAddress(mapped);
      }

      // Fallback: Fetch enriched customer record
      final customer = await _client
          .from('customers')
          .select('*, areas(name, delivery_schedule, cutoff_time), roads(name), sub_roads(name)')
          .eq('id', customerId)
          .single();
      final Map<String, dynamic> mapped = Map.from(customer);
      final area = customer['areas'] as Map<String, dynamic>?;
      final road = customer['roads'] as Map<String, dynamic>?;
      final subRoad = customer['sub_roads'] as Map<String, dynamic>?;
      mapped['area_name'] = area?['name'];
      mapped['delivery_schedule'] = area?['delivery_schedule'];
      mapped['cutoff_time'] = area?['cutoff_time'];
      mapped['road_name'] = road?['name'];
      mapped['sub_road_name'] = subRoad?['name'];
      return _enrichCustomerAddress(mapped);
    } catch (e) {
      debugPrint('completeGoogleOnboarding error: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> setupPasswordForCode(String code, String name, String password, {String? pin}) async {
    try {
      final normalizedCode = code.trim().toUpperCase();

      // Invoke server-side trusted RPC setup_customer_password
      final response = await _client.rpc('setup_customer_password', params: {
        'p_code': normalizedCode,
        'p_name': name,
        'p_password': password,
      });

      if (response != null && response is Map && response['success'] == true) {
        final serverCode = (response['customer_code'] as String? ?? normalizedCode).trim().toLowerCase();
        final synthEmail = '$serverCode@aplibhaji.com';
        final authPassword = _formatAuthPassword(password);

        // Sign in with the newly configured credentials
        final AuthResponse res = await _client.auth.signInWithPassword(
          email: synthEmail,
          password: authPassword,
        );
        if (res.user != null) {
          final customer = await _client
              .from('customers')
              .select('*, areas(name, delivery_schedule, cutoff_time), roads(name), sub_roads(name)')
              .eq('auth_user_id', res.user!.id)
              .single();
          final Map<String, dynamic> mapped = Map.from(customer);
          final area = customer['areas'] as Map<String, dynamic>?;
          final road = customer['roads'] as Map<String, dynamic>?;
          final subRoad = customer['sub_roads'] as Map<String, dynamic>?;
          mapped['area_name'] = area?['name'];
          mapped['delivery_schedule'] = area?['delivery_schedule'];
          mapped['cutoff_time'] = area?['cutoff_time'];
          mapped['road_name'] = road?['name'];
          mapped['sub_road_name'] = subRoad?['name'];
          return _enrichCustomerAddress(mapped, userMetaAddress: res.user?.userMetadata?['address']?.toString());
        }
      } else {
        throw Exception('Account setup failed');
      }
    } catch (e) {
      final cleanError = e.toString().replaceAll('Exception: ', '').trim();
      throw Exception(cleanError.isNotEmpty ? cleanError : 'Account setup failed');
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> registerGuest(String name, String phone, String address, {String? areaId, String? roadId, String? subRoadId}) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final email = '$cleanPhone@aplibhaji.com';
      final guestPassword = 'Guest_${cleanPhone}_2026';
      
      try {
        await _client.auth.signUp(
          email: email,
          password: guestPassword,
          data: {
            'name': name,
            'phone': phone,
            'address': address,
            if (areaId != null && areaId.isNotEmpty) 'area_id': areaId,
            if (roadId != null && roadId.isNotEmpty) 'road_id': roadId,
            if (subRoadId != null && subRoadId.isNotEmpty) 'sub_road_id': subRoadId,
            'is_guest': true,
          },
        );
      } catch (signUpErr) {
        debugPrint('Guest signUp notice: $signUpErr. Attempting signIn...');
        try {
          await _client.auth.signInWithPassword(
            email: email,
            password: guestPassword,
          );
        } catch (_) {}
      }

      // 1. Call register_guest_customer RPC to guarantee separate guest row in customers table
      try {
        final rpcRes = await _client.rpc('register_guest_customer', params: {
          'p_name': name,
          'p_phone': phone,
          'p_address': address,
          if (areaId != null && areaId.isNotEmpty) 'p_area_id': areaId,
          if (roadId != null && roadId.isNotEmpty) 'p_road_id': roadId,
          if (subRoadId != null && subRoadId.isNotEmpty) 'p_sub_road_id': subRoadId,
        });
        if (rpcRes != null && rpcRes is Map) {
          final mapped = Map<String, dynamic>.from(rpcRes);
          mapped['is_guest'] = true;
          return _enrichCustomerAddress(mapped, defaultAddress: address);
        }
      } catch (rpcErr) {
        debugPrint('register_guest_customer RPC notice: $rpcErr');
      }

      // 2. Query public.customers table for the guest record
      final existing = await _client
          .from('customers')
          .select('*, areas(name, delivery_schedule, cutoff_time), roads(name), sub_roads(name)')
          .or('phone.eq.$phone,phone.eq.$cleanPhone')
          .maybeSingle();

      if (existing != null) {
        final Map<String, dynamic> mapped = Map.from(existing);
        final area = existing['areas'] as Map<String, dynamic>?;
        final road = existing['roads'] as Map<String, dynamic>?;
        final subRoad = existing['sub_roads'] as Map<String, dynamic>?;
        mapped['area_name'] = area?['name'];
        mapped['delivery_schedule'] = area?['delivery_schedule'];
        mapped['cutoff_time'] = area?['cutoff_time'];
        mapped['road_name'] = road?['name'];
        mapped['sub_road_name'] = subRoad?['name'];
        mapped['is_guest'] = true;
        return _enrichCustomerAddress(mapped, defaultAddress: address);
      }
    } catch (e) {
      debugPrint('Supabase registerGuest error: $e');
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> register(String name, String phone, String password, String address, {String? areaId, String? roadId, String? subRoadId}) async {
    try {
      final AuthResponse res = await _client.auth.signUp(
        email: '$phone@aplibhaji.com',
        password: password,
        data: {
          'name': name,
          'phone': phone,
          'address': address,
          'area_id': areaId,
          'road_id': roadId,
          'sub_road_id': subRoadId,
        },
      );
      if (res.user != null) {
        final userId = res.user!.id;
        try {
          await _client.from('customers').upsert({
            'id': userId,
            'auth_user_id': userId,
            'name': name,
            'phone': phone,
            'address': address,
            if (areaId != null && areaId.isNotEmpty) 'area_id': areaId,
            if (roadId != null && roadId.isNotEmpty) 'road_id': roadId,
            if (subRoadId != null && subRoadId.isNotEmpty) 'sub_road_id': subRoadId,
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (upsertErr) {
          debugPrint('register customers upsert fallback notice: $upsertErr');
          try {
            await _client.from('customers').update({
              'auth_user_id': userId,
              'name': name,
              'address': address,
              if (areaId != null && areaId.isNotEmpty) 'area_id': areaId,
              if (roadId != null && roadId.isNotEmpty) 'road_id': roadId,
              if (subRoadId != null && subRoadId.isNotEmpty) 'sub_road_id': subRoadId,
              'updated_at': DateTime.now().toIso8601String(),
            }).or('id.eq.$userId,phone.eq.$phone');
          } catch (_) {}
        }

        await Future.delayed(const Duration(milliseconds: 300));
        final customer = await _client
            .from('customers')
            .select('*, areas(name, delivery_schedule, cutoff_time), roads(name), sub_roads(name)')
            .eq('id', userId)
            .single();
        final Map<String, dynamic> mapped = Map.from(customer);
        final area = customer['areas'] as Map<String, dynamic>?;
        final road = customer['roads'] as Map<String, dynamic>?;
        final subRoad = customer['sub_roads'] as Map<String, dynamic>?;
        mapped['area_name'] = area?['name'];
        mapped['delivery_schedule'] = area?['delivery_schedule'];
        mapped['cutoff_time'] = area?['cutoff_time'];
        mapped['road_name'] = road?['name'];
        mapped['sub_road_name'] = subRoad?['name'];
        return _enrichCustomerAddress(mapped, defaultAddress: address);
      }
    } catch (_) {
      rethrow;
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getLoggedInCustomer({
    Function(Map<String, dynamic>)? onRefresh,
  }) async {
    final user = _client.auth.currentUser;
    if (user != null) {
      final customer = await _client
          .from('customers')
          .select('*, areas(name, delivery_schedule, cutoff_time), roads(name), sub_roads(name)')
          .or('auth_user_id.eq.${user.id},id.eq.${user.id}')
          .maybeSingle();
      if (customer != null) {
        final Map<String, dynamic> mapped = Map.from(customer);
        final area = customer['areas'] as Map<String, dynamic>?;
        final road = customer['roads'] as Map<String, dynamic>?;
        final subRoad = customer['sub_roads'] as Map<String, dynamic>?;
        mapped['area_name'] = area?['name'] ?? mapped['area_name'];
        mapped['delivery_schedule'] = area?['delivery_schedule'] ?? mapped['delivery_schedule'];
        mapped['cutoff_time'] = area?['cutoff_time'] ?? mapped['cutoff_time'];
        mapped['road_name'] = road?['name'] ?? mapped['road_name'];
        mapped['sub_road_name'] = subRoad?['name'] ?? mapped['sub_road_name'];

        // Fallback to default area schedule if schedule is still empty
        if (mapped['delivery_schedule'] == null ||
            (mapped['delivery_schedule'] is List && (mapped['delivery_schedule'] as List).isEmpty)) {
          try {
            final defaultArea = await _client
                .from('areas')
                .select('name, delivery_schedule, cutoff_time')
                .order('created_at', ascending: true)
                .limit(1)
                .maybeSingle();
            if (defaultArea != null) {
              if (mapped['area_name'] == null) mapped['area_name'] = defaultArea['name'];
              mapped['delivery_schedule'] = defaultArea['delivery_schedule'];
              if (mapped['cutoff_time'] == null) mapped['cutoff_time'] = defaultArea['cutoff_time'];
            }
          } catch (_) {}
        }

        // Auto-compose address if blank or 'N/A'
        final rawAddr = (mapped['address'] as String? ?? '').trim();
        if (rawAddr.isEmpty || rawAddr.toLowerCase() == 'n/a') {
          final parts = <String>[];
          final rName = (mapped['road_name'] as String? ?? '').trim();
          final aName = (mapped['area_name'] as String? ?? '').trim();
          if (rName.isNotEmpty && rName.toLowerCase() != 'n/a') parts.add(rName);
          if (aName.isNotEmpty && aName.toLowerCase() != 'n/a' && !parts.contains(aName)) parts.add(aName);
          if (parts.isNotEmpty) {
            mapped['address'] = parts.join(', ');
          }
        }

        return mapped;
      }
    }
    return null;
  }

  @override
  Future<void> updateProfile(String id, String name, String phone, String address, {String? areaId, String? roadId, String? subRoadId}) async {
    // 1. Invoke server-side trusted RPC to update customer profile
    bool rpcSucceeded = false;
    try {
      await _client.rpc('update_customer_profile', params: {
        'p_name': name,
        'p_phone': phone,
        'p_address': address,
        'p_area_id': areaId,
        'p_road_id': roadId,
        'p_sub_road_id': subRoadId,
        'p_id': id,
      });
      rpcSucceeded = true;
      debugPrint('updateProfile: Successfully updated customer profile via RPC.');
    } catch (e) {
      debugPrint('updateProfile: RPC update_customer_profile failed: $e. Falling back to direct update.');
    }

    // 2. Directly persist updated fields to public.customers as fallback
    if (!rpcSucceeded) {
      try {
        final updateData = <String, dynamic>{
          'name': name,
          'phone': phone,
          'address': address,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        if (areaId != null && areaId.isNotEmpty) updateData['area_id'] = areaId;
        if (roadId != null && roadId.isNotEmpty) updateData['road_id'] = roadId;
        if (subRoadId != null && subRoadId.isNotEmpty) updateData['sub_road_id'] = subRoadId;
        await _client.from('customers').update(updateData).or('id.eq.$id,auth_user_id.eq.$id');
        debugPrint('updateProfile: Direct update to customers table succeeded.');
      } catch (e) {
        debugPrint('updateProfile customers table update error: $e');
      }
    }
  }

  @override
  Future<void> changePassword(String newPassword) async {
    final user = _client.auth.currentUser;
    if (user != null) {
      final authPassword = _formatAuthPassword(newPassword);
      await _client.auth.updateUser(UserAttributes(password: authPassword));
    }
  }

  @override
  Future<bool> resetPassword(String phone, String newPassword) async {
    try {
      // Use RPC if available to reset customer password
      await _client.rpc('reset_customer_password', params: {
        'p_phone': phone,
        'p_new_password': newPassword,
      });
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<Map<String, dynamic>> checkCustomerAuthStatus(String identifier) async {
    final cleanId = identifier.trim();
    if (cleanId.isEmpty) {
      return {'exists': false, 'has_password': false, 'message': 'Identifier cannot be empty'};
    }

    try {
      final response = await _client.rpc('check_customer_auth_status', params: {
        'p_identifier': cleanId,
      });
      if (response != null && response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {'exists': false, 'has_password': false, 'message': 'Invalid response from server'};
    } catch (e) {
      return {
        'exists': false,
        'has_password': false,
        'error': 'Verification failed: ${e.toString().replaceAll('Exception: ', '').trim()}'
      };
    }
  }

  @override
  Future<Map<String, dynamic>> resetPasswordWithVerification(
    String identifier,
    String phoneConfirm,
    String newPassword,
  ) async {
    final cleanId = identifier.trim();
    final cleanPhone = phoneConfirm.trim();
    final cleanPass = newPassword.trim();

    try {
      final res = await _client.rpc('reset_customer_password', params: {
        'p_identifier': cleanId,
        'p_phone_confirm': cleanPhone,
        'p_new_password': cleanPass,
      });
      if (res != null) {
        if (res is Map && res['success'] == true) {
          return {'success': true, 'message': res['message'] ?? 'Password reset successfully!'};
        } else if (res is bool && res == true) {
          return {'success': true, 'message': 'Password reset successfully!'};
        } else if (res is Map && res['error'] != null) {
          return {'success': false, 'error': res['error'].toString()};
        }
      }
      return {'success': false, 'error': 'Invalid response from server'};
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '').trim();
      return {'success': false, 'error': errStr};
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        try {
          await _client.rpc('delete_customer_account');
        } catch (_) {}
      }
    } catch (_) {
    } finally {
      await logout();
    }
  }

  @override
  Future<void> logout() async {
    await _client.auth.signOut();
  }
}

class SupabaseOrderRepository implements OrderRepository {
  final SupabaseClient _client = Supabase.instance.client;

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
    // Only send trusted inputs: product_id and quantity.
    // The backend RPC authoritatively resolves prices, stock, delivery charges, and final totals.
    final response = await _client.rpc('place_order_secure', params: {
      'p_delivery_address': deliveryAddress,
      'p_customer_phone': customerPhone,
      'p_items': items.map((item) => {
        'product_id': item['product_id']?.toString(),
        'quantity': (item['quantity'] as num?)?.toDouble() ?? 1.0,
      }).toList(),
      'p_idempotency_key': idempotencyKey,
      'p_delivery_date': deliveryDate,
      'p_offline_order_no': offlineOrderNo,
      'p_order_type': orderType ?? 'Normal',
      'p_order_taking_date': orderTakingDate,
    }).timeout(const Duration(seconds: 25));
    
    final mapped = Map<String, dynamic>.from(response);
    mapped['delivery_date'] ??= deliveryDate;
    mapped['order_type'] ??= (orderType ?? 'Normal');
    mapped['order_taking_date'] ??= orderTakingDate;
    return mapped;
  }

  @override
  Future<List<Map<String, dynamic>>> getOrders(
    String customerPhone, {
    Function(List<Map<String, dynamic>>)? onRefresh,
  }) async {
    final user = _client.auth.currentUser;
    var query = _client.from('orders').select('*, order_items(*)');
    if (customerPhone.trim().isNotEmpty) {
      query = query.eq('customer_phone', customerPhone.trim());
    } else if (user != null) {
      query = query.eq('customer_id', user.id);
    }
    final List<dynamic> res = await query.order('order_date', ascending: false).timeout(const Duration(seconds: 15));
    return List<Map<String, dynamic>>.from(res);
  }

  @override
  Future<Map<String, dynamic>?> getOrderById(
    String id, {
    Function(Map<String, dynamic>)? onRefresh,
  }) async {
    return await _client.from('orders').select().eq('id', id).maybeSingle().timeout(const Duration(seconds: 15));
  }

  @override
  Future<List<Map<String, dynamic>>> getOrderItems(
    String orderId, {
    Function(List<Map<String, dynamic>>)? onRefresh,
  }) async {
    final List<dynamic> res = await _client.from('order_items').select().eq('order_id', orderId).timeout(const Duration(seconds: 15));
    return List<Map<String, dynamic>>.from(res);
  }

  @override
  Future<void> retryOrderSync(String orderId) async {}

  @override
  Future<void> dismissPermanentlyFailedOrder(String orderId) async {}
}
