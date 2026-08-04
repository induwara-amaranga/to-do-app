import 'package:flutter/services.dart';

class RingtonePicker {
  static const _channel = MethodChannel('com.example.to_do_app/ringtone');

  static Future<Map<String, String>?> pickAlarmTone({
    String? currentUri,
  }) async {
    final result = await _channel.invokeMapMethod<String, String>(
      'pickAlarmTone',
      {'currentUri': currentUri},
    );
    if (result == null) return null;
    return (result as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  static Future<Map<String, String>?> pickNotificationTone({
    String? currentUri,
  }) async {
    final result = await _channel.invokeMapMethod<String, String>(
      'pickNotificationTone',
      {'currentUri': currentUri},
    );
    if (result == null) return null;
    return (result as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
  }
}
