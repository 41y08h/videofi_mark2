import 'package:flutter_webrtc/flutter_webrtc.dart';

class PeerConnection {
  static final PeerConnection _instance = PeerConnection._();
  PeerConnection._();

  factory PeerConnection() {
    return _instance;
  }

  bool isInitialized = false;
  RTCPeerConnection? _pc;
  Future<RTCPeerConnection> get pc async => _pc ??= await initialize();

  Future<RTCPeerConnection> initialize() async {
    print("initialized pc");
    final pc = await createPeerConnection({
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    }, {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ]
    });
    _pc = pc;
    isInitialized = true;
    return _pc as RTCPeerConnection;
  }

  Future<void> dispose() async {
    _pc?.dispose();
    _pc = null;
    isInitialized = false;
  }
}
