import 'package:flutter_webrtc/flutter_webrtc.dart';

void disposeStream(MediaStream? stream) {
  stream?.getTracks().forEach((track) {
    track.stop();
  });
  stream?.dispose();
}
