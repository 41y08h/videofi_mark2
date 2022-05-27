import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum CallState {
  idle,
  outgoing,
  incoming,
  connected,
}

class Chat {
  int? localId;
  MediaStream? localStream;
  int? remoteId;
  MediaStream? remoteStream;
  CallState callState = CallState.idle;

  RTCSessionDescription? remoteDescription;

  Chat({
    this.localId,
    this.localStream,
    this.remoteId,
    this.remoteStream,
    this.callState = CallState.idle,
    this.remoteDescription,
  });

  Chat copyWith({
    int? localId,
    MediaStream? localStream,
    int? remoteId,
    MediaStream? remoteStream,
    CallState callState = CallState.idle,
    RTCSessionDescription? remoteDescription,
  }) {
    return Chat(
      localId: localId ?? this.localId,
      localStream: localStream ?? this.localStream,
      remoteId: remoteId ?? this.remoteId,
      remoteStream: remoteStream ?? this.remoteStream,
      callState: callState,
      remoteDescription: remoteDescription ?? this.remoteDescription,
    );
  }
}

final chatProvider = StateProvider<Chat>((ref) {
  return Chat();
});
