import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/secure_local_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/auth_rate_limiter.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system status bar icons to DARK for crisp visibility on light background screens
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Android: dark icons
      statusBarBrightness: Brightness.light, // iOS: dark icons
    ),
  );

  // Initialize Auth Rate Limiter
  try {
    await AuthRateLimiter.instance.init();
    debugPrint('AuthRateLimiter initialized with session: ${AuthRateLimiter.instance.sessionId}');
  } catch (e) {
    debugPrint('AuthRateLimiter initialization failed: $e');
  }

  // Initialize Notification Service (asks for permission on Android 13+)
  try {
    await NotificationService.instance.init();
    debugPrint('NotificationService initialized successfully.');
  } catch (e) {
    debugPrint('NotificationService initialization failed: $e');
  }
  
  // Try initializing Supabase
  try {
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://xsqaxvbrjvhgemlfgoxn.supabase.co',
    );
    const supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_7w2JdGBs0yI-P1pKfz7eOg_p2yV1qd_',
    );
    
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureLocalStorage(persistSessionKey: 'aplibhaji_customer_session'),
      ),
    );
    debugPrint('Supabase initialized successfully.');
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

  // Initialize Sync Service for offline order queue
  try {
    SyncService.instance.init();
    debugPrint('SyncService initialized successfully.');
  } catch (e) {
    debugPrint('SyncService initialization failed: $e');
  }

  runApp(
    const ProviderScope(
      child: ApliBhajiApp(),
    ),
  );
}

class ApliBhajiApp extends StatelessWidget {
  const ApliBhajiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'ApliBhaji',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
