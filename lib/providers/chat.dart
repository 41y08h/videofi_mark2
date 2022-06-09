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
  List<RTCIceCandidate> remoteCandidates = [];

  Chat({
    this.localId,
    this.localStream,
    this.remoteId,
    this.remoteStream,
    this.callState = CallState.idle,
    this.remoteDescription,
    this.remoteCandidates = const [],
  });

  Chat copyWith({
    int? localId,
    MediaStream? localStream,
    int? remoteId,
    MediaStream? remoteStream,
    CallState? callState,
    RTCSessionDescription? remoteDescription,
    List<RTCIceCandidate>? remoteCandidates,
  }) {
    return Chat(
      localId: localId ?? this.localId,
      localStream: localStream ?? this.localStream,
      remoteId: remoteId ?? this.remoteId,
      remoteStream: remoteStream ?? this.remoteStream,
      callState: callState ?? this.callState,
      remoteDescription: remoteDescription ?? this.remoteDescription,
      remoteCandidates: remoteCandidates ?? this.remoteCandidates,
    );
  }
}

final chatProvider = StateProvider<Chat>((ref) {
  return Chat(remoteId: 545799, callState: CallState.incoming);
});
