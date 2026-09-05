import 'package:flutter/services.dart';

class SoundService {
  static const MethodChannel _channel = MethodChannel('com.orderkart.app/sound');

  static Future<void> playSuccessSound() async {
    try {
      await _channel.invokeMethod('playSuccessSound');
    } catch (_) {
      // Gracefully silent if platform doesn't support or error occurs
    }
  }
}
