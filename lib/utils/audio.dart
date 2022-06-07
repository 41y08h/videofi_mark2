import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

AudioSource assetToAudioSource(String assetPath) {
  return AudioSource.uri(Uri.parse('asset:///$assetPath'));
}

Future<String> getDefaultRingtoneUri() async {
  const channel = MethodChannel('videofi_common_channel');
  final String ringtone = await channel.invokeMethod('getDefaultRingtoneUri');
  return ringtone;
}
