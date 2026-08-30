import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:typed_data';
import '../../features/order/order_details_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    final data = message.data;
    if (data.isNotEmpty) {
      final title = data['title'] ?? message.notification?.title ?? 'Alert';
      final body = data['body'] ?? message.notification?.body ?? '';
      final payload = data['payload'] ?? '';
      
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

  NotificationService._();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {}

    // Initialize Local Notifications
    await initLocalNotificationsOnly();

    try {
      // Initialize Firebase Messaging
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request notification permissions for FCM
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listen for foreground FCM notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final data = message.data;
        
        final title = notification?.title ?? data['title'] ?? 'Notification';
        final body = notification?.body ?? data['body'] ?? '';
        final payload = data['payload'] ?? '';

        showNotification(
          id: message.hashCode,
          title: title,
          body: body,
          payload: payload,
        );
      });

      // Handle FCM notification clicks when app is in background but alive
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

      // Listen for token refresh and update database if user is authenticated
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final client = Supabase.instance.client;
        final currentUser = client.auth.currentUser;
        if (currentUser != null) {
          try {
            await client.from('customers').update({'fcm_token': newToken}).eq('id', currentUser.id);
            debugPrint('FCM Token refreshed and updated in DB: $newToken');
          } catch (err) {
            debugPrint('Error saving refreshed FCM token to DB: $err');
          }
        }
      });

    } catch (e) {
      debugPrint('Firebase messaging initialization failed: $e');
    }

    // Ask for system notification permission for local notifications (Android 13+)
    await requestPermission();
  }

  Future<void> initLocalNotificationsOnly() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onSelectNotification,
    );
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
        await client.from('customers').update({'fcm_token': fcmToken}).eq('id', userId);
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
      await client.from('customers').update({'fcm_token': null}).eq('id', userId);
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
      'aplibhaji_customer_channel',
      'Orderkart Alerts',
      channelDescription: 'Notifications for Orderkart Customers',
      importance: Importance.max,
      priority: Priority.high,
      playSound: playSound,
      enableVibration: enableVibration,
      vibrationPattern: enableVibration
          ? Int64List.fromList([0, 80])
          : null,
    );
    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(id, title, body, platformDetails,
        payload: payload);
  }
}
