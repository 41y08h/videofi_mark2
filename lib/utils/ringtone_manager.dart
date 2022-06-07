import 'package:flutter/services.dart';

class RingtoneManager {
  static const _channel = MethodChannel('videofi_common_channel');

  static Future<String> getDefaultRingtoneUri() async {
    final String ringtone =
        await _channel.invokeMethod('getDefaultRingtoneUri');
    return ringtone;
  }
}
