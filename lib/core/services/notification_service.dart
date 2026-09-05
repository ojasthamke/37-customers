import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'dart:typed_data';
import '../../features/order/order_details_screen.dart';
import '../../features/dashboard/home_screen.dart';
import '../database/database_helper.dart';

const String kCustomerNotificationChannelId = 'aplibhaji_customer_channel';
const String kCustomerNotificationChannelName = 'Orderkart Alerts';
const String kCustomerNotificationChannelDesc = 'Real-time order updates, deliveries, and instant notifications';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    
    // Extract title, body, and payload from notification or data block
    final notification = message.notification;
    final data = message.data;
    
    final title = notification?.title ?? data['title'] ?? 'Orderkart Alert';
    final body = notification?.body ?? data['body'] ?? '';
    final payload = data['payload'] ?? '';
    final eventId = data['eventId'] ?? data['event_id'];
    final targetUserId = data['userId'] ?? data['user_id'];

    // If message is data-only (no OS-rendered notification block), display local notification
    if (notification == null && (title.isNotEmpty || body.isNotEmpty)) {
      await NotificationService.instance.initLocalNotificationsOnly();
      await NotificationService.instance.showNotification(
        id: message.messageId.hashCode,
        title: title,
        body: body,
        payload: payload,
        eventId: eventId,
        targetUserId: targetUserId,
      );
    }
  } catch (e) {
    debugPrint('Error in FCM background handler: $e');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  RealtimeChannel? _realtimeChannel;
  Timer? _periodicSyncTimer;
  AppLifecycleListener? _lifecycleListener;
  final Set<String> _seenNotificationIds = <String>{};
  final Set<String> _processedEventIds = <String>{};
  final Map<String, DateTime> _recentNotificationFingerprints = <String, DateTime>{};
  bool _isSyncRunning = false;
  String? _currentCustomerId;
  String? _currentAreaId;
  String? _pendingPayload;
  bool _isInitialized = false;

  NotificationService._();

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {}

    // Load persistent deduplication IDs
    await _loadProcessedEventIds();

    // 1. Initialize Local Notifications & Explicitly Create High-Importance Android Channel
    await initLocalNotificationsOnly();

    // 2. Request system notification permission (Android 13+ / POST_NOTIFICATIONS)
    await requestPermission();

    // 3. Start persistent notification background/realtime synchronizer
    await startRealtimeNotificationSync();

    try {
      // 4. Initialize Firebase Messaging
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request FCM permissions
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      // Set presentation options for foreground display:
      // Setting alert and sound to false prevents the OS from spawning an unmanaged duplicate banner
      // while our debounced local notification handler renders the alert cleanly and uniquely.
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      // Subscribe to general customer broadcast topic
      try {
        await FirebaseMessaging.instance.subscribeToTopic('all_customers');
      } catch (topicErr) {
        debugPrint('FCM topic subscription notice: $topicErr');
      }

      // Automatically register FCM token if user is already authenticated
      try {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
          await registerFCMToken(currentUser.id);
        }
      } catch (e) {
        debugPrint('FCM token user register notice: $e');
      }

      // Listen for foreground FCM notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final data = message.data;
        
        final title = notification?.title ?? data['title'] ?? 'Notification';
        final body = notification?.body ?? data['body'] ?? '';
        final payload = data['payload'] ?? '';
        final eventId = data['eventId'] ?? data['event_id'];
        final targetUserId = data['userId'] ?? data['user_id'] ?? data['target_user_id'];

        final orderNoMatch = RegExp(r'#?ORD-?\d+', caseSensitive: false).firstMatch('$title $body $payload');
        final String? orderNumber = orderNoMatch?.group(0)?.toUpperCase();

        final int deterministicId = (orderNumber != null
                ? orderNumber.hashCode
                : '${title.trim().toLowerCase()}|${body.trim().toLowerCase()}'.hashCode) &
            0x7FFFFFFF;

        showNotification(
          id: deterministicId,
          title: title,
          body: body,
          payload: payload,
          eventId: eventId,
          targetUserId: targetUserId,
          orderKey: orderNumber,
        );
      });

      // Handle FCM notification clicks when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final payload = message.data['payload'];
        _handleNotificationPayload(payload);
      });

      // Handle FCM notification click when app is launched from terminated state
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          final payload = message.data['payload'];
          _handleNotificationPayload(payload);
        }
      });

      // Listen for token refresh and update Supabase DB
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          final client = Supabase.instance.client;
          final user = client.auth.currentUser;
          if (user != null) {
            await registerFCMToken(user.id, explicitToken: newToken);
            debugPrint('FCM Token refreshed and registered: $newToken');
          }
        } catch (err) {
          debugPrint('Error saving refreshed FCM token: $err');
        }
      });

    } catch (e) {
      debugPrint('Firebase messaging initialization notice: $e');
    }
  }

  /// Starts real-time database listener, persistent storage, and background polling
  Future<void> startRealtimeNotificationSync({String? customerId, String? areaId}) async {
    _currentCustomerId = customerId;
    if (areaId != null && areaId.isNotEmpty) {
      _currentAreaId = areaId;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('aplibhaji_customer_area_id', areaId);
        final cleanAreaTopic = 'area_${areaId.replaceAll('-', '_')}';
        await FirebaseMessaging.instance.subscribeToTopic(cleanAreaTopic);
        debugPrint('Subscribed to area topic: $cleanAreaTopic');
      } catch (_) {}
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        _currentAreaId ??= prefs.getString('aplibhaji_customer_area_id');
      } catch (_) {}
    }

    await _loadSeenIdsFromStorage();

    // 1. Immediate sync on startup or customer switch
    await checkAndDeliverNewNotifications(customerId: customerId);

    // 2. Setup Realtime subscription for instant alerts from Admin
    _setupRealtimeChannel();

    // 3. Periodic Polling (every 15 seconds) to ensure delivery even if connection drops
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkAndDeliverNewNotifications(customerId: _currentCustomerId);
    });

    // 4. Lifecycle Listener (resync instantly when user switches back to app)
    _lifecycleListener?.dispose();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        checkAndDeliverNewNotifications(customerId: _currentCustomerId);
      },
      onShow: () {
        checkAndDeliverNewNotifications(customerId: _currentCustomerId);
      },
    );
  }

  Future<void> _loadSeenIdsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? stored = prefs.getStringList('aplibhaji_seen_notification_ids');
      if (stored != null) {
        _seenNotificationIds.addAll(stored);
      }
    } catch (_) {}
  }

  Future<void> _persistSeenId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_seenNotificationIds.length > 500) {
        final list = _seenNotificationIds.toList();
        _seenNotificationIds.clear();
        _seenNotificationIds.addAll(list.skip(list.length - 200));
      }
      await prefs.setStringList('aplibhaji_seen_notification_ids', _seenNotificationIds.toList());
    } catch (_) {}
  }

  void _setupRealtimeChannel() {
    try {
      final client = Supabase.instance.client;
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = client.channel('public:notifications').onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        callback: (payload) {
          final newRecord = payload.newRecord;
          // Synchronize database records for in-app inbox without popping duplicate OS tray banner
          // (FCM is the single authoritative driver for OS system-tray notifications)
          _processNotificationRecord(newRecord, customerId: _currentCustomerId, showPopup: false);
        },
      );
      _realtimeChannel?.subscribe();
    } catch (e) {
      debugPrint('Realtime channel subscription error: $e');
    }
  }

  Future<void> checkAndDeliverNewNotifications({String? customerId}) async {
    if (_isSyncRunning) return;
    _isSyncRunning = true;
    try {
      final client = Supabase.instance.client;
      final List<dynamic> records = await client
          .from('notifications')
          .select('*')
          .order('created_at', ascending: false)
          .limit(25);

      for (final record in records) {
        if (record is Map<String, dynamic>) {
          // On startup initial fetch, mark as seen to avoid duplicate startup popups
          await _processNotificationRecord(record, customerId: customerId, showPopup: false);
        }
      }
    } catch (e) {
      debugPrint('Notification sync error: $e');
    } finally {
      _isSyncRunning = false;
    }
  }

  Future<void> _processNotificationRecord(Map<String, dynamic> record, {String? customerId, bool showPopup = true}) async {
    final id = record['id']?.toString();
    if (id == null || id.isEmpty) return;

    if (_seenNotificationIds.contains(id)) return;

    final targetCustId = record['customer_id']?.toString();
    final targetAreaId = record['area_id']?.toString();
    final targetType = record['target_type']?.toString() ?? 'broadcast';
    final title = record['title']?.toString() ?? 'ApliBhaji Notification';
    final body = record['body']?.toString() ?? '';
    final createdAtStr = record['created_at']?.toString();

    // Check if within acceptable active window (sent in last 7 days)
    if (createdAtStr != null) {
      final createdAt = DateTime.tryParse(createdAtStr);
      if (createdAt != null) {
        final age = DateTime.now().toUtc().difference(createdAt.toUtc());
        if (age.inDays > 7) {
          _seenNotificationIds.add(id);
          await _persistSeenId(id);
          return;
        }
      }
    }

    // Accurate targeting validation:
    // 1. If targeted to a specific customer, match current customer ID
    // 2. If targeted to an area, match current customer area ID
    // 3. If broadcast, match all
    bool isTargeted = false;
    if (targetCustId != null && targetCustId.isNotEmpty) {
      isTargeted = (customerId != null && targetCustId == customerId);
    } else if (targetAreaId != null && targetAreaId.isNotEmpty) {
      isTargeted = (_currentAreaId != null && targetAreaId == _currentAreaId);
    } else {
      isTargeted = (targetType == 'broadcast' || targetType.isEmpty);
    }

    if (isTargeted) {
      _seenNotificationIds.add(id);
      await _persistSeenId(id);

      if (showPopup) {
        final orderNoMatch = RegExp(r'#?ORD-?\d+', caseSensitive: false).firstMatch('$title $body');
        final String? orderNumber = orderNoMatch?.group(0)?.toUpperCase();
        final String payload = orderNumber != null ? 'order_$orderNumber' : (record['payload']?.toString() ?? 'notif_$id');

        final int deterministicId = (orderNumber != null
                ? orderNumber.hashCode
                : '${title.trim().toLowerCase()}|${body.trim().toLowerCase()}'.hashCode) &
            0x7FFFFFFF;

        await showNotification(
          id: deterministicId,
          title: title,
          body: body,
          payload: payload,
          eventId: 'notif_$id',
          targetUserId: targetCustId,
          orderKey: orderNumber,
        );
      }
    }
  }

  Future<void> initLocalNotificationsOnly() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onSelectNotification,
    );

    // Explicitly create NotificationChannel on Android OS (API 26+) with MAX importance
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        kCustomerNotificationChannelId,
        kCustomerNotificationChannelName,
        description: kCustomerNotificationChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  Future<void> requestPermission() async {
    try {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (_) {}
  }

  // Register FCM Token for the authenticated customer
  Future<void> registerFCMToken(String userId, {String? explicitToken}) async {
    try {
      final fcmToken = explicitToken ?? await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        final client = Supabase.instance.client;

        // 1. Multi-device support: Register in device_tokens table
        try {
          await client.rpc('register_device_token', params: {
            'p_token': fcmToken,
            'p_role': 'customer',
            'p_device_type': 'android',
            'p_device_name': 'Customer Device',
          });
        } catch (_) {}

        // 2. Legacy backwards compatibility sync
        await client.from('customers').update({'fcm_token': fcmToken}).or('id.eq.$userId,auth_user_id.eq.$userId');
        debugPrint('FCM Token registered and updated in DB: $fcmToken');
      }
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  // Stop all sync timers, realtime channels, and clear cached customer context on logout
  void stopSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    try {
      if (_realtimeChannel != null) {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
        _realtimeChannel = null;
      }
    } catch (_) {}
    if (_currentAreaId != null && _currentAreaId!.isNotEmpty) {
      final cleanTopic = _currentAreaId!.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      FirebaseMessaging.instance.unsubscribeFromTopic('area_$cleanTopic').catchError((_) {});
    }
    _currentCustomerId = null;
    _currentAreaId = null;
  }

  // Clear FCM Token for the customer on logout
  Future<void> clearFCMToken(String userId) async {
    stopSync();
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      final client = Supabase.instance.client;
      if (fcmToken != null) {
        try {
          await client.rpc('delete_device_token', params: {'p_token': fcmToken});
        } catch (_) {}
      }
      await client.from('customers').update({'fcm_token': null}).or('id.eq.$userId,auth_user_id.eq.$userId');
      debugPrint('FCM Token cleared in DB for user: $userId');
    } catch (e) {
      debugPrint('Failed to clear FCM token: $e');
    }
  }

  Future<void> _loadProcessedEventIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('aplibhaji_processed_event_ids');
      if (list != null) {
        _processedEventIds.addAll(list);
      }
    } catch (_) {}
  }

  Future<void> _persistProcessedEventId(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _processedEventIds.add(eventId);
      if (_processedEventIds.length > 300) {
        final list = _processedEventIds.toList();
        _processedEventIds.clear();
        _processedEventIds.addAll(list.skip(list.length - 150));
      }
      await prefs.setStringList('aplibhaji_processed_event_ids', _processedEventIds.toList());
    } catch (_) {}
  }

  void _onSelectNotification(NotificationResponse response) {
    final payload = response.payload;
    _handleNotificationPayload(payload);
  }

  void _navigateToHome() {
    try {
      final nav = navigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Failed to navigate to Home: $e');
    }
  }

  void _handleNotificationPayload(String? payload) {
    if (navigatorKey.currentState == null) {
      _pendingPayload = payload;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        for (int i = 0; i < 20; i++) {
          if (navigatorKey.currentState != null) {
            final p = _pendingPayload;
            _pendingPayload = null;
            _processPayloadNavigation(p);
            break;
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }
      });
      return;
    }

    _processPayloadNavigation(payload);
  }

  Future<void> _processPayloadNavigation(String? payload) async {
    final cleanPayload = payload?.trim() ?? '';

    // 1. If payload is empty or not order-related -> Open Customer Home Screen
    if (cleanPayload.isEmpty ||
        cleanPayload == 'home' ||
        cleanPayload.startsWith('promo_') ||
        cleanPayload.startsWith('broadcast_') ||
        cleanPayload.startsWith('notif_')) {
      _navigateToHome();
      return;
    }

    // 2. Extract potential Order ID or Order Number
    String? orderIdOrNo;
    if (cleanPayload.startsWith('order_')) {
      orderIdOrNo = cleanPayload.substring(6).trim();
    } else if (RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(cleanPayload)) {
      orderIdOrNo = cleanPayload;
    } else if (RegExp(r'^#?ORD-?\d+$', caseSensitive: false).hasMatch(cleanPayload)) {
      orderIdOrNo = cleanPayload;
    }

    // If payload was not an order reference (e.g. malformed or general text) -> Open Home Screen
    if (orderIdOrNo == null || orderIdOrNo.isEmpty) {
      _navigateToHome();
      return;
    }

    // 3. Security & Ownership Verification:
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      final currentUserId = currentUser?.id ?? _currentCustomerId;

      // Unauthenticated user -> cannot view order details -> safely route to Home
      if (currentUserId == null) {
        _navigateToHome();
        return;
      }

      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(orderIdOrNo);
      
      Map<String, dynamic>? orderRow;
      try {
        final query = client.from('orders').select('id, customer_id, customer_phone, order_number');
        final res = isUuid 
            ? await query.eq('id', orderIdOrNo).maybeSingle()
            : await query.eq('order_number', orderIdOrNo).maybeSingle();
        orderRow = res;
      } catch (e) {
        debugPrint('Remote order query for notification tap failed, fallback to local: $e');
      }

      // If remote failed or returned null, check local SQLite
      if (orderRow == null) {
        try {
          final db = await DatabaseHelper.instance.database;
          final localRes = isUuid
              ? await db.query('orders', where: 'id = ?', whereArgs: [orderIdOrNo], limit: 1)
              : await db.query('orders', where: 'order_number = ?', whereArgs: [orderIdOrNo], limit: 1);
          if (localRes.isNotEmpty) {
            orderRow = localRes.first;
          }
        } catch (_) {}
      }

      // If order does not exist anywhere -> Open Home Screen safely
      if (orderRow == null) {
        debugPrint('Order not found for notification tap: $orderIdOrNo');
        _navigateToHome();
        return;
      }

      final orderCustId = orderRow['customer_id']?.toString();
      final targetOrderId = orderRow['id']?.toString();

      // SECURITY BOUNDARY: Verify that the current user owns this order
      if (orderCustId != null && orderCustId != currentUserId) {
        debugPrint('SECURITY ALERT: User $currentUserId attempted to open Order $targetOrderId owned by $orderCustId');
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access Denied: You do not have permission to view this order.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _navigateToHome();
        return;
      }

      // Valid & Owned Order -> Navigate directly to OrderDetailsScreen!
      if (targetOrderId != null && targetOrderId.isNotEmpty) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => OrderDetailsScreen(orderId: targetOrderId),
          ),
        );
      } else {
        _navigateToHome();
      }
    } catch (e) {
      debugPrint('Error navigating to order details from notification: $e');
      _navigateToHome();
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? eventId,
    String? targetUserId,
    String? orderKey,
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    final String cleanTitle = title.trim();
    final String cleanBody = body.trim();

    // 1. Account Switch Protection:
    try {
      final client = Supabase.instance.client;
      final currentUserId = client.auth.currentUser?.id ?? _currentCustomerId;
      if (targetUserId != null && targetUserId.isNotEmpty && currentUserId != null) {
        if (targetUserId != currentUserId) {
          debugPrint('NotificationService: Suppressed notification intended for user $targetUserId (current: $currentUserId)');
          return;
        }
      }
    } catch (_) {}

    // 2. Stable Event ID Extraction:
    final String stableEventId = (eventId != null && eventId.isNotEmpty)
        ? eventId
        : (orderKey != null && orderKey.isNotEmpty)
            ? 'order_${orderKey.toUpperCase()}_${cleanTitle.toLowerCase()}'
            : '${cleanTitle.toLowerCase()}|${cleanBody.toLowerCase()}';

    // 3. Persistent Event Deduplication:
    if (_processedEventIds.contains(stableEventId)) {
      debugPrint('NotificationService: Suppressed duplicate eventId "$stableEventId".');
      return;
    }
    await _persistProcessedEventId(stableEventId);

    // 4. Memory Fingerprint Debounce (prevents rapid re-trigger of identical text within 4s)
    final now = DateTime.now();
    final lastSeen = _recentNotificationFingerprints[stableEventId];
    if (lastSeen != null && now.difference(lastSeen).inSeconds < 4) {
      debugPrint('NotificationService: Suppressed rapid bounce for key "$stableEventId".');
      return;
    }
    _recentNotificationFingerprints[stableEventId] = now;

    // Prune stale fingerprints
    if (_recentNotificationFingerprints.length > 100) {
      _recentNotificationFingerprints.removeWhere((k, time) => now.difference(time).inMinutes > 5);
    }

    // 5. Deterministic Notification ID:
    final int deterministicId = (stableEventId.hashCode & 0x7FFFFFFF);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      kCustomerNotificationChannelId,
      kCustomerNotificationChannelName,
      channelDescription: kCustomerNotificationChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      tag: stableEventId,
      playSound: playSound,
      enableVibration: enableVibration,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.status,
      vibrationPattern: enableVibration
          ? Int64List.fromList([0, 250, 250, 250])
          : null,
    );
    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      deterministicId,
      cleanTitle,
      cleanBody,
      platformDetails,
      payload: payload,
    );
  }
}
