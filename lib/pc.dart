import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:videofi_mark2/utils/call_all.dart';

class PeerConnection {
  static final PeerConnection _instance = PeerConnection._();
  PeerConnection._();

  factory PeerConnection() {
    return _instance;
  }

  Future<RTCPeerConnection>? _initFuture;
  bool isInitialized = false;
  RTCPeerConnection? _pc;
  Future<RTCPeerConnection> get pc async => _pc ??= await initialize();

  final List<Function(RTCIceCandidate candidate)> _onIceCandidate = [];
  final List<Function(RTCTrackEvent)> _onTrack = [];
  final List<Function(RTCPeerConnectionState state)> _onConnectionState = [];

  Future<RTCPeerConnection> initialize() async {
    if (isInitialized) return pc;
    if (_initFuture != null) {
      return _initFuture as Future<RTCPeerConnection>;
    }

    _initFuture = createPeerConnection({
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    }, {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ]
    }).then((pc) {
      // Set event listeners
      pc.onIceCandidate = callAll(_onIceCandidate);
      pc.onTrack = callAll(_onTrack);
      pc.onConnectionState = callAll(_onConnectionState);

      _pc = pc;
      isInitialized = true;

      return _pc as RTCPeerConnection;
    });

    return _initFuture as Future<RTCPeerConnection>;
  }

  Future<void> dispose() async {
    _pc?.dispose();
    _pc = null;
    isInitialized = false;
    _initFuture = null;
  }

  void onIceCandidate(Function(RTCIceCandidate candidate) callback) {
    _onIceCandidate.add(callback);
    _pc?.onIceCandidate = callAll(_onIceCandidate);
  }

  void onTrack(Function(RTCTrackEvent event) callback) {
    _onTrack.add(callback);
    _pc?.onTrack = callAll(_onTrack);
  }

  void onConnectionState(Function(RTCPeerConnectionState state) callback) {
    _onConnectionState.add(callback);
    _pc?.onConnectionState = callAll(_onConnectionState);
  }
}
