import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (kIsWeb) {
      path = inMemoryDatabasePath;
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Use proper app-specific directory on mobile
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, 'aplibhaji_customers.db');
    } else {
      // Desktop fallback
      path = 'aplibhaji_shared.db';
    }

    return openDatabase(
      path,
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        try { await db.execute("ALTER TABLE customers ADD COLUMN customer_code TEXT"); } catch (_) {}
        try { await db.execute("ALTER TABLE customers ADD COLUMN is_guest INTEGER DEFAULT 0"); } catch (_) {}
        try { await db.execute("ALTER TABLE customers ADD COLUMN area_name TEXT"); } catch (_) {}
        try { await db.execute("ALTER TABLE customers ADD COLUMN road_name TEXT"); } catch (_) {}
        try { await db.execute("ALTER TABLE customers ADD COLUMN sub_road_name TEXT"); } catch (_) {}
        try { await db.execute("ALTER TABLE products ADD COLUMN order_now_stock REAL DEFAULT 0.0"); } catch (_) {}
        try { await db.execute("ALTER TABLE products ADD COLUMN order_now_price REAL DEFAULT 0.0"); } catch (_) {}
        try { await db.execute("ALTER TABLE products ADD COLUMN order_now_mrp REAL DEFAULT 0.0"); } catch (_) {}
        try { await db.execute("ALTER TABLE products ADD COLUMN order_now_cost_price REAL DEFAULT 0.0"); } catch (_) {}
        try { await db.execute("ALTER TABLE products ADD COLUMN order_now_is_available INTEGER DEFAULT 1"); } catch (_) {}
        try { await db.execute("ALTER TABLE order_items ADD COLUMN total_price REAL DEFAULT 0.0"); } catch (_) {}
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS customer_login_logs (
              id TEXT PRIMARY KEY,
              customer_id TEXT,
              customer_code TEXT,
              customer_name TEXT,
              customer_phone TEXT,
              login_method TEXT,
              logged_in_at TEXT,
              device_info TEXT,
              app_version TEXT,
              expires_at TEXT,
              created_at TEXT
            )
          ''');
        } catch (_) {}
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Customer Login Logs Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_login_logs (
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        customer_code TEXT,
        customer_name TEXT,
        customer_phone TEXT,
        login_method TEXT,
        logged_in_at TEXT,
        device_info TEXT,
        app_version TEXT,
        expires_at TEXT,
        created_at TEXT
      )
    ''');

    // Categories Table
    await db.execute('''
      CREATE TABLE categories (

        id TEXT PRIMARY KEY,
        name TEXT UNIQUE,
        is_enabled INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    // Products Table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT,
        category_id TEXT,
        image_path TEXT,
        description TEXT,
        price REAL,
        unit TEXT,
        is_available INTEGER DEFAULT 1,
        is_enabled INTEGER DEFAULT 1,
        created_at TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // Customers Table
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT,
        phone TEXT UNIQUE,
        email TEXT,
        address TEXT,
        is_logged_in INTEGER DEFAULT 0,
        customer_code TEXT,
        is_guest INTEGER DEFAULT 0,
        area_id TEXT,
        road_id TEXT,
        sub_road_id TEXT,
        area_name TEXT,
        road_name TEXT,
        sub_road_name TEXT,
        delivery_schedule TEXT,
        cutoff_time TEXT DEFAULT '23:59',
        created_at TEXT
      )
    ''');

    // Orders Table (with sync_status for offline queue)
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        order_number TEXT UNIQUE,
        customer_id TEXT,
        customer_phone TEXT,
        delivery_address TEXT,
        order_date TEXT,
        status TEXT DEFAULT 'pending',
        total_amount REAL,
        delivery_date TEXT,
        area_id TEXT,
        area_name TEXT,
        road_id TEXT,
        road_name TEXT,
        sub_road_id TEXT,
        sub_road_name TEXT,
        customer_name TEXT,
        offline_order_no TEXT,
        order_type TEXT DEFAULT 'Normal',
        order_taking_date TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    // Order Items Table
    await db.execute('''
      CREATE TABLE order_items (
        id TEXT PRIMARY KEY,
        order_id TEXT,
        product_id TEXT,
        product_name TEXT,
        quantity REAL,
        price REAL,
        unit TEXT,
        total_price REAL,
        created_at TEXT,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
      )
    ''');

    // Settings Table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Cache Metadata Table
    await db.execute('''
      CREATE TABLE cache_metadata (
        key TEXT PRIMARY KEY,
        last_synced_at TEXT
      )
    ''');

    // Seed default settings
    await db.insert('settings', {'key': 'store_name', 'value': 'ApliBhaji Store'});
    await db.insert('settings', {'key': 'store_phone', 'value': '+91 9021107009'});
    await db.insert('settings', {'key': 'store_address', 'value': 'Main Bazar, Pune, Maharashtra'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sync_status column for offline order queue
      await db.execute("ALTER TABLE orders ADD COLUMN sync_status TEXT DEFAULT 'synced'");
    }
    if (oldVersion < 3) {
      // Add new route fields to customers
      try { await db.execute("ALTER TABLE customers ADD COLUMN area_id TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE customers ADD COLUMN road_id TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE customers ADD COLUMN sub_road_id TEXT"); } catch (_) {}

      // Add new route and snapshot fields to orders
      try { await db.execute("ALTER TABLE orders ADD COLUMN delivery_date TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN area_id TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN area_name TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN road_id TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN road_name TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN sub_road_id TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN sub_road_name TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN customer_name TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN offline_order_no TEXT"); } catch (_) {}
    }
    if (oldVersion < 4) {
      try { await db.execute("ALTER TABLE customers ADD COLUMN delivery_schedule TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN order_type TEXT DEFAULT 'Normal'"); } catch (_) {}
      try { await db.execute("ALTER TABLE orders ADD COLUMN order_taking_date TEXT"); } catch (_) {}
    }
    if (oldVersion < 5) {
      try { await db.execute("ALTER TABLE customers ADD COLUMN cutoff_time TEXT DEFAULT '23:59'"); } catch (_) {}
    }
    if (oldVersion < 6) {
      try { await db.execute("ALTER TABLE customers ADD COLUMN customer_code TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE customers ADD COLUMN is_guest INTEGER DEFAULT 0"); } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute("ALTER TABLE customers RENAME TO customers_old;");
        await db.execute('''
          CREATE TABLE customers (
            id TEXT PRIMARY KEY,
            name TEXT,
            phone TEXT UNIQUE,
            email TEXT,
            address TEXT,
            is_logged_in INTEGER DEFAULT 0,
            customer_code TEXT,
            is_guest INTEGER DEFAULT 0,
            area_id TEXT,
            road_id TEXT,
            sub_road_id TEXT,
            delivery_schedule TEXT,
            cutoff_time TEXT DEFAULT '23:59',
            created_at TEXT
          )
        ''');
        await db.execute('''
          INSERT INTO customers (
            id, name, phone, email, address, is_logged_in, customer_code, 
            is_guest, area_id, road_id, sub_road_id, delivery_schedule, cutoff_time, created_at
          )
          SELECT 
            id, name, phone, email, address, is_logged_in, customer_code, 
            is_guest, area_id, road_id, sub_road_id, delivery_schedule, cutoff_time, created_at
          FROM customers_old;
        ''');
        await db.execute("DROP TABLE customers_old;");
      } catch (_) {}
    }
    if (oldVersion < 8) {
      try {
        await db.execute('''
          CREATE TABLE cache_metadata (
            key TEXT PRIMARY KEY,
            last_synced_at TEXT
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 9) {
      try { await db.execute("ALTER TABLE customers ADD COLUMN area_name TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE customers ADD COLUMN road_name TEXT"); } catch (_) {}
      try { await db.execute("ALTER TABLE customers ADD COLUMN sub_road_name TEXT"); } catch (_) {}
    }
  }

  Future<void> clearOfflineOrders() async {
    try {
      final db = await database;
      await db.delete('order_items');
      await db.delete('orders');
    } catch (_) {}
  }

  Future<void> clearUserData() async {
    try {
      final db = await database;
      await db.delete('customers');
      await db.delete('orders');
      await db.delete('order_items');
      await db.delete('cache_metadata');
    } catch (_) {}
  }

  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('order_items');
    await db.delete('orders');
    await db.delete('customers');
    await db.delete('products');
    await db.delete('categories');
  }

  Future<bool> isCacheStale(String key, Duration ttl) async {
    try {
      final db = await database;
      final res = await db.query(
        'cache_metadata',
        where: 'key = ?',
        whereArgs: [key],
      );
      if (res.isEmpty) return true; // No record -> stale
      final lastSyncedStr = res.first['last_synced_at'] as String?;
      if (lastSyncedStr == null) return true;
      final lastSynced = DateTime.tryParse(lastSyncedStr);
      if (lastSynced == null) return true;
      return DateTime.now().difference(lastSynced) > ttl;
    } catch (_) {
      return true; // Error -> assume stale and revalidate
    }
  }

  Future<void> updateLastSynced(String key) async {
    try {
      final db = await database;
      await db.insert(
        'cache_metadata',
        {
          'key': key,
          'last_synced_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }
}
