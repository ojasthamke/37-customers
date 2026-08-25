// ---------------------------------------------------------------------------
// PLACEHOLDER firebase_options.dart — NOT yet generated.
//
// This project has not been connected to a Firebase project yet. Run:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=aplibhaji
// which regenerates this file with real values (see docs/firebase_setup.md).
//
// Until then, Firebase.initializeApp() will throw and the app shows the
// full-screen "Firebase not configured" message (see lib/main.dart).
// This is deliberate: no fake data, no hidden errors.
// ---------------------------------------------------------------------------
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web. '
        'Run `flutterfire configure` (see docs/firebase_setup.md).',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform. '
          'Run `flutterfire configure` (see docs/firebase_setup.md).',
        );
    }
  }

  // Placeholder values — initializeApp() with these throws at runtime,
  // which main.dart catches to show the "Firebase not configured" screen.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'aplibhaji',
    storageBucket: 'aplibhaji.appspot.com',
  );
}
