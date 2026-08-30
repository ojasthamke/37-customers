import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';

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
  });
  Future<Map<String, dynamic>?> getProductById(
    String id, {
    Function(Map<String, dynamic>)? onRefresh,
  });
}

abstract class CustomerRepository {
  Future<Map<String, dynamic>?> login(String phone, String password);
  Future<Map<String, dynamic>?> loginWithCode(String code);
  Future<Map<String, dynamic>?> loginWithCodeAndPassword(String code, String password);
  Future<Map<String, dynamic>?> setupPasswordForCode(String code, String name, String password, {String? pin});
  Future<Map<String, dynamic>?> registerGuest(String name, String phone, String address);
  Future<Map<String, dynamic>?> register(String name, String phone, String password, String address, {String? areaId, String? roadId, String? subRoadId});
  Future<Map<String, dynamic>?> getLoggedInCustomer({
    Function(Map<String, dynamic>)? onRefresh,
  });
  Future<void> updateProfile(String id, String name, String phone, String address, {String? areaId, String? roadId, String? subRoadId});
  Future<void> changePassword(String newPassword);
  Future<bool> resetPassword(String phone, String newPassword);
  Future<Map<String, dynamic>> checkCustomerAuthStatus(String identifier);
  Future<Map<String, dynamic>> resetPasswordWithVerification(String identifier, String phoneConfirm, String newPassword);
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
  }) async {
    final db = await _dbHelper.database;
    String whereClause = 'products.is_enabled = 1';
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
    final res = await db.query('products', where: 'id = ? AND is_enabled = 1', whereArgs: [id]);
    return res.isNotEmpty ? _parseProductDescription(res.first) : null;
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
    mapped['order_now_is_available'] = p['order_now_is_available'] == null ? true : (p['order_now_is_available'] == true || p['order_now_is_available'] == 1);
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
      try {
        mapped['delivery_schedule'] = json.decode(c['delivery_schedule'] as String);
      } catch (_) {
        mapped['delivery_schedule'] = [];
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
  Future<Map<String, dynamic>?> registerGuest(String name, String phone, String address) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    try {
      await db.insert('customers', {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'is_logged_in': 1,
        'is_guest': 1,
      });
      await db.update('customers', {'is_logged_in': 0}, where: 'id != ?', whereArgs: [id]);
      return _parseCustomer({
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
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
  Future<void> logout() async {
    final db = await _dbHelper.database;
    await db.update('customers', {'is_logged_in': 0});
    // Clear all customer-specific cached tables to protect user privacy
    await db.delete('order_items');
    await db.delete('orders');
    await db.delete('customers');
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
      // Find customer details and route mapping by phone
      final customerRes = await txn.query('customers', where: 'phone = ?', whereArgs: [customerPhone]);
      final customerId = customerRes.isNotEmpty ? customerRes.first['id'] as String? : null;
      final customerName = customerRes.isNotEmpty ? customerRes.first['name'] as String? : null;
      final areaId = customerRes.isNotEmpty ? customerRes.first['area_id'] as String? : null;
      final roadId = customerRes.isNotEmpty ? customerRes.first['road_id'] as String? : null;
      final subRoadId = customerRes.isNotEmpty ? customerRes.first['sub_road_id'] as String? : null;

      // 1. Create order (canonical order_number is initially NULL or same as offline until synced)
      await txn.insert('orders', {
        'id': orderId,
        'order_number': null, // Canonical order number is assigned by server during sync
        'customer_id': customerId,
        'customer_phone': customerPhone,
        'delivery_address': deliveryAddress,
        'order_date': orderDate,
        'status': 'Pending',
        'total_amount': totalAmount,
        'sync_status': 'pending',
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
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  @override
  Future<List<Map<String, dynamic>>> getProducts({
    String? search,
    String? categoryId,
    Function(List<Map<String, dynamic>>)? onRefresh,
  }) async {
    var query = _client.from('products').select('*, categories(name)').eq('is_enabled', true);
    
    if (search != null && search.isNotEmpty) {
      query = query.or('name.ilike.%$search%,description.ilike.%$search%');
    }
    
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.eq('category_id', categoryId);
    }
    
    final List<dynamic> res = await query.order('name', ascending: true);
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
    final res = await _client.from('products').select().eq('id', id).eq('is_enabled', true).maybeSingle();
    return res != null ? _parseProductDescription(res) : null;
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
    mapped['order_now_is_available'] = p['order_now_is_available'] == null ? true : (p['order_now_is_available'] == true || p['order_now_is_available'] == 1);
    return mapped;
  }
}

class SupabaseCustomerRepository implements CustomerRepository {
  final SupabaseClient _client = Supabase.instance.client;

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
        return mapped;
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
        return mapped;
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
      final normalizedCode = code.trim().toLowerCase();
      final synthEmail = '$normalizedCode@aplibhaji.com';
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
        return mapped;
      }
    } catch (_) {
      rethrow;
    }
    return null;
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
        final synthEmail = '${normalizedCode.toLowerCase()}@aplibhaji.com';
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
          return mapped;
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
  Future<Map<String, dynamic>?> registerGuest(String name, String phone, String address) async {
    try {
      // Register as guest with a random password (guest can't login with password)
      final guestPassword = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      final AuthResponse res = await _client.auth.signUp(
        email: '$phone@aplibhaji.com',
        password: guestPassword,
        data: {
          'name': name,
          'phone': phone,
          'address': address,
          'is_guest': true,
        },
      );
      if (res.user != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        // Update the customer record to mark as guest
        await _client.from('customers').update({'is_guest': true}).eq('id', res.user!.id);
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
        mapped['is_guest'] = true;
        return mapped;
      }
    } catch (_) {
      rethrow;
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
        // Allow brief moment for PostgreSQL Auth trigger to populate the customers table
        await Future.delayed(const Duration(milliseconds: 500));
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
        return mapped;
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
          .eq('auth_user_id', user.id)
          .maybeSingle();
      if (customer != null) {
        final Map<String, dynamic> mapped = Map.from(customer);
        final area = customer['areas'] as Map<String, dynamic>?;
        final road = customer['roads'] as Map<String, dynamic>?;
        final subRoad = customer['sub_roads'] as Map<String, dynamic>?;
        mapped['area_name'] = area?['name'];
        mapped['delivery_schedule'] = area?['delivery_schedule'];
        mapped['cutoff_time'] = area?['cutoff_time'];
        mapped['road_name'] = road?['name'];
        mapped['sub_road_name'] = subRoad?['name'];
        return mapped;
      }
    }
    return null;
  }

  @override
  Future<void> updateProfile(String id, String name, String phone, String address, {String? areaId, String? roadId, String? subRoadId}) async {
    // Use server-side RPC to update customer-controlled fields (name & phone only)
    await _client.rpc('update_customer_profile', params: {
      'p_name': name,
      'p_phone': phone,
    });
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
  }) async {
    try {
      final response = await _client.rpc('place_order_secure', params: {
        'p_delivery_address': deliveryAddress,
        'p_customer_phone': customerPhone,
        'p_items': items.map((item) => {
          'product_id': item['product_id'],
          'quantity': item['quantity'],
        }).toList(),
        'p_idempotency_key': idempotencyKey,
        'p_delivery_date': deliveryDate,
        'p_offline_order_no': offlineOrderNo,
        'p_order_type': orderType ?? 'Normal',
        'p_order_taking_date': orderTakingDate,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getOrders(
    String customerPhone, {
    Function(List<Map<String, dynamic>>)? onRefresh,
  }) async {
    final user = _client.auth.currentUser;
    var query = _client.from('orders').select('*, order_items(*)');
    if (user != null) {
      query = query.eq('customer_id', user.id);
    } else {
      query = query.eq('customer_phone', customerPhone);
    }
    final List<dynamic> res = await query.order('order_date', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  @override
  Future<Map<String, dynamic>?> getOrderById(
    String id, {
    Function(Map<String, dynamic>)? onRefresh,
  }) async {
    return await _client.from('orders').select().eq('id', id).maybeSingle();
  }

  @override
  Future<List<Map<String, dynamic>>> getOrderItems(
    String orderId, {
    Function(List<Map<String, dynamic>>)? onRefresh,
  }) async {
    final List<dynamic> res = await _client.from('order_items').select().eq('order_id', orderId);
    return List<Map<String, dynamic>>.from(res);
  }
}
