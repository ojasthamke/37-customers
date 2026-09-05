import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/secure_local_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/auth_rate_limiter.dart';
import 'core/services/crash_observability_service.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase core initialization notice: $e');
  }
  CrashObservabilityService.instance.init();
  GoogleFonts.config.allowRuntimeFetching = true;

  // Optimize Image Cache for Low-RAM / 2GB RAM Devices (Vivo Y3s, etc.)
  // Caps decoded bitmap memory to 25MB max and 40 items max (preventing LMK OutOfMemory kills)
  PaintingBinding.instance.imageCache.maximumSize = 40;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 25 * 1024 * 1024;

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

  // 1. Initialize Supabase FIRST so all downstream services have access
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

  // 2. Initialize secondary services non-blocking (so UI renders instantly)
  try {
    AuthRateLimiter.instance.init();
  } catch (_) {}

  try {
    NotificationService.instance.init();
  } catch (_) {}

  try {
    SyncService.instance.init();
  } catch (_) {}

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
      title: 'OrderKart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        // Optimize for Big Font / Accessibility users:
        // Clamps text scaling between 0.85x and 1.35x so text is large and legible
        // while preserving structural layouts and avoiding RenderFlex clipping.
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.35,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
