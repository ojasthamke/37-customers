import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';

class LoginTrackerService {
  LoginTrackerService._();
  static final LoginTrackerService instance = LoginTrackerService._();

  static const _uuid = Uuid();

  /// Track a customer login event in the database (Supabase & SQLite)
  /// and automatically delete logs older than 5 days.
  Future<void> recordLogin({
    required Map<String, dynamic> customer,
    required String loginMethod,
  }) async {
    try {
      final String id = _uuid.v4();
      final String? customerId = customer['id']?.toString();
      final String? customerCode = customer['customer_code']?.toString();
      final String? customerName = customer['name']?.toString();
      final String? customerPhone = customer['phone']?.toString();
      final now = DateTime.now().toUtc();
      final String loggedInAt = now.toIso8601String();
      final String expiresAt = now.add(const Duration(days: 5)).toIso8601String();

      final String deviceInfo = kIsWeb
          ? 'Web Browser'
          : (Platform.isAndroid
              ? 'Android'
              : (Platform.isIOS ? 'iOS' : Platform.operatingSystem));

      final logEntry = {
        'id': id,
        'customer_id': customerId,
        'customer_code': customerCode,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'login_method': loginMethod,
        'logged_in_at': loggedInAt,
        'device_info': deviceInfo,
        'app_version': '1.0.0',
        'expires_at': expiresAt,
        'created_at': loggedInAt,
      };

      // 1. Insert into Supabase (Remote DB) & auto-prune
      _recordRemoteLogin(logEntry);

      // 2. Insert into SQLite (Local DB) & auto-prune
      _recordLocalLogin(logEntry);
    } catch (e) {
      debugPrint('LoginTrackerService: recordLogin error: ');
    }
  }

  Future<void> _recordRemoteLogin(Map<String, dynamic> logEntry) async {
    try {
      final client = Supabase.instance.client;
      await client.from('customer_login_logs').insert(logEntry);
      debugPrint('LoginTrackerService: Successfully recorded login for  via ');

      // Client-side prune: Delete remote records older than 5 days
      final fiveDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 5)).toIso8601String();
      await client.from('customer_login_logs').delete().lt('logged_in_at', fiveDaysAgo);
    } catch (e) {
      debugPrint('LoginTrackerService: Remote login record/prune error: ');
    }
  }

  Future<void> _recordLocalLogin(Map<String, dynamic> logEntry) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'customer_login_logs',
        logEntry,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Prune SQLite logs older than 5 days
      final fiveDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 5)).toIso8601String();
      await db.delete(
        'customer_login_logs',
        where: 'logged_in_at < ?',
        whereArgs: [fiveDaysAgo],
      );
    } catch (e) {
      debugPrint('LoginTrackerService: Local SQLite login record/prune error: ');
    }
  }

  /// Retrieve login logs for a customer or recent audit logs
  Future<List<Map<String, dynamic>>> getLoginLogs({String? customerPhone, int limit = 50}) async {
    try {
      final client = Supabase.instance.client;
      if (customerPhone != null && customerPhone.isNotEmpty) {
        final list = await client
            .from('customer_login_logs')
            .select()
            .eq('customer_phone', customerPhone)
            .order('logged_in_at', ascending: false)
            .limit(limit);
        return List<Map<String, dynamic>>.from(list);
      }
      final list = await client
          .from('customer_login_logs')
          .select()
          .order('logged_in_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(list);
    } catch (_) {
      // Local SQLite fallback
      try {
        final db = await DatabaseHelper.instance.database;
        if (customerPhone != null && customerPhone.isNotEmpty) {
          return await db.query(
            'customer_login_logs',
            where: 'customer_phone = ?',
            whereArgs: [customerPhone],
            orderBy: 'logged_in_at DESC',
            limit: limit,
          );
        }
        return await db.query(
          'customer_login_logs',
          orderBy: 'logged_in_at DESC',
          limit: limit,
        );
      } catch (e) {
        return [];
      }
    }
  }
}
