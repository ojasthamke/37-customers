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

    // If message is data-only (no OS-rendered notification block), display local notification
    if (notification == null && (title.isNotEmpty || body.isNotEmpty)) {
      await NotificationService.instance.initLocalNotificationsOnly();
      await NotificationService.instance.showNotification(
        id: message.messageId.hashCode,
        title: title,
        body: body,
        payload: payload,
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
  bool _isSyncRunning = false;
  String? _currentCustomerId;
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

      // Set presentation options for foreground display
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
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

        showNotification(
          id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body,
          payload: payload,
        );
      });

      // Handle FCM notification clicks when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final payload = message.data['payload'];
        if (payload != null && payload.isNotEmpty) {
          _handleNotificationPayload(payload);
        }
      });

      // Handle FCM notification click when app is launched from terminated state
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          final payload = message.data['payload'];
          if (payload != null && payload.isNotEmpty) {
            _handleNotificationPayload(payload);
          }
        }
      });

      // Listen for token refresh and update Supabase DB
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          final client = Supabase.instance.client;
          final user = client.auth.currentUser;
          if (user != null) {
            await client.from('customers').update({'fcm_token': newToken}).or('id.eq.${user.id},auth_user_id.eq.${user.id}');
            debugPrint('FCM Token refreshed and updated in DB: $newToken');
          }
        } catch (err) {
          debugPrint('Error saving refreshed FCM token to DB: $err');
        }
      });

    } catch (e) {
      debugPrint('Firebase messaging initialization notice: $e');
    }
  }

  /// Starts real-time database listener, persistent storage, and background polling
  Future<void> startRealtimeNotificationSync({String? customerId}) async {
    _currentCustomerId = customerId;
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
          _processNotificationRecord(newRecord, customerId: _currentCustomerId, showPopup: true);
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

    // Match if broadcast (null / empty) or targeted to this customer
    final bool isTargeted = targetCustId == null ||
        targetCustId.isEmpty ||
        (customerId != null && targetCustId == customerId);

    if (isTargeted) {
      _seenNotificationIds.add(id);
      await _persistSeenId(id);

      if (showPopup) {
        final orderNoMatch = RegExp(r'#ORD-\d+').firstMatch('$title $body');
        final String? orderNumber = orderNoMatch?.group(0);
        final String payload = orderNumber != null ? 'order_$orderNumber' : 'promo_$id';

        await showNotification(
          id: id.hashCode,
          title: title,
          body: body,
          payload: payload,
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
  Future<void> registerFCMToken(String userId) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        final client = Supabase.instance.client;
        await client.from('customers').update({'fcm_token': fcmToken}).or('id.eq.$userId,auth_user_id.eq.$userId');
        debugPrint('FCM Token registered and updated in DB: $fcmToken');
      }
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  // Clear FCM Token for the customer on logout
  Future<void> clearFCMToken(String userId) async {
    try {
      final client = Supabase.instance.client;
      await client.from('customers').update({'fcm_token': null}).or('id.eq.$userId,auth_user_id.eq.$userId');
      debugPrint('FCM Token cleared in DB for user: $userId');
    } catch (e) {
      debugPrint('Failed to clear FCM token: $e');
    }
  }

  void _onSelectNotification(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _handleNotificationPayload(payload);
  }

  void _handleNotificationPayload(String payload) async {
    // Check if payload is directly a UUID (orderId)
    if (RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(payload)) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => OrderDetailsScreen(orderId: payload),
        ),
      );
      return;
    }

    // Otherwise check for order number payload (starts with order_)
    if (payload.startsWith('order_')) {
      final orderNo = payload.substring(6);
      try {
        final client = Supabase.instance.client;
        final res = await client
            .from('orders')
            .select('id')
            .eq('order_number', orderNo)
            .maybeSingle();
        if (res != null) {
          final orderId = res['id'] as String?;
          if (orderId != null) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => OrderDetailsScreen(orderId: orderId),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch order ID for payload: $e');
      }
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      kCustomerNotificationChannelId,
      kCustomerNotificationChannelName,
      channelDescription: kCustomerNotificationChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
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

    await flutterLocalNotificationsPlugin.show(id, title, body, platformDetails,
        payload: payload);
  }
}
