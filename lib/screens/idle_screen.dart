import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:videofi_mark2/constants.dart';
import 'package:videofi_mark2/pc.dart';
import 'package:videofi_mark2/providers/chat.dart';
import 'package:videofi_mark2/screens/call_screen.dart';
import 'package:videofi_mark2/socket.dart';
import 'package:videofi_mark2/utils/dispose_stream.dart';
import 'package:flutter_android_volume_keydown/flutter_android_volume_keydown.dart';

class IdleScreen extends ConsumerStatefulWidget {
  const IdleScreen({
    Key? key,
  }) : super(key: key);

  @override
  _IdleScreenState createState() => _IdleScreenState();
}

class _IdleScreenState extends ConsumerState<IdleScreen> {
  TextEditingController remoteIdController = TextEditingController();
  bool isTryingToCall = false;
  bool isWSConnected = false;
  final outgoingAudio = AudioPlayer();
  final incomingAudio = AudioPlayer();
  StreamSubscription<HardwareButton>? volumeButtonSubscription;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  void initialize() async {
    final socket = SocketConnection().socket;

    socket.on('connect', wsOnConnect);
    socket.on('get-id/callback', wsOnIdCallback);
    socket.on("disconnect", wsOnDisconnect);

    socket.on("offer", wsOnOffer);
    socket.on("offer-ended", wsOnOfferEnded);
    socket.on("offer-rejected", wsOnOfferRejected);
    socket.on("answer", wsOnAnswer);
    socket.on("outgoing-time-out", wsOnOutgoingTimeout);
    socket.on("incoming-time-out", wsOnIncomingTimeout);
    socket.on("ice-candidate", wsOnIceCandidate);
    socket.on("call-disconnected", wsOnCallDisconnected);

    PeerConnection().onConnectionState(pcOnConnectionState);
    PeerConnection().onIceCandidate(pcOnIceCandidate);
    PeerConnection().onTrack(pcOnTrack);
  }

  @override
  void dispose() {
    super.dispose();
    final chat = ref.read(chatProvider);
    disposeStream(chat.localStream);
    disposeStream(chat.remoteStream);
    SocketConnection().socket.dispose();
    PeerConnection().dispose();
    outgoingAudio.dispose();
    volumeButtonSubscription?.cancel();
  }

  void wsOnConnect(_) {
    final socket = SocketConnection().socket;
    socket.emit("get-id");
  }

  void wsOnIdCallback(dynamic id) {
    setState(() {
      final chat = ref.read(chatProvider.notifier);
      chat.state = chat.state.copyWith(
        localId: id,
      );
      isWSConnected = true;
    });
  }

  void wsOnDisconnect(_) {
    setState(() {
      isWSConnected = false;
    });
  }

  void wsOnOffer(data) async {
    final chat = ref.read(chatProvider.notifier);
    final signal = data['signal'];
    chat.state = chat.state.copyWith(
      remoteDescription: RTCSessionDescription(
        signal['sdp'],
        signal['type'],
      ),
      remoteId: data['remoteId'],
      callState: CallState.incoming,
    );

    Navigator.pushNamed(context, CallScreen.routeName);
  }

  void wsOnOfferEnded(data) async {
    final chat = ref.read(chatProvider.notifier);

    PeerConnection().dispose();

    chat.state = chat.state.copyWith(
      callState: CallState.idle,
      remoteId: null,
      remoteDescription: null,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Missed call'),
      ),
    );
  }

  void wsOnOfferRejected(data) async {
    final chat = ref.read(chatProvider.notifier);

    PeerConnection().dispose();
    disposeStream(chat.state.localStream);

    chat.state = chat.state.copyWith(
      callState: CallState.idle,
      remoteId: null,
      localStream: null,
    );
  }

  void wsOnAnswer(data) async {
    final signal = data['signal'];
    final answer = RTCSessionDescription(
      signal['sdp'],
      signal['type'],
    );
    final pc = await PeerConnection().pc;
    await pc.setRemoteDescription(answer);
  }

  void wsOnOutgoingTimeout(data) async {
    final chat = ref.read(chatProvider.notifier);

    PeerConnection().dispose();
    disposeStream(chat.state.localStream);

    chat.state = chat.state.copyWith(
      callState: CallState.idle,
      localStream: null,
    );
  }

  void wsOnIncomingTimeout(data) async {
    final chat = ref.read(chatProvider.notifier);

    PeerConnection().dispose();

    chat.state = chat.state.copyWith(
      callState: CallState.idle,
    );
  }

  void wsOnCallDisconnected(_) async {
    final chat = ref.read(chatProvider.notifier);

    PeerConnection().dispose();
    disposeStream(chat.state.localStream);
    disposeStream(chat.state.remoteStream);

    chat.state = chat.state.copyWith(
      localStream: null,
      remoteStream: null,
      remoteId: null,
      callState: CallState.idle,
      remoteDescription: null,
    );
  }

  void wsOnIceCandidate(data) async {
    final chat = ref.read(chatProvider.notifier);

    final signal = data['candidate'];
    final candidate = RTCIceCandidate(
      signal['candidate'],
      signal['sdpMid'],
      signal['sdpMLineIndex'],
    );
    chat.state = chat.state.copyWith(
      remoteCandidates: [...chat.state.remoteCandidates, candidate],
    );
  }

  void onCallPressed() async {
    setState(() {
      isTryingToCall = true;
    });

    final chat = ref.read(chatProvider.notifier);
    final socket = SocketConnection().socket;
    final pc = await PeerConnection().pc;
    final remoteId = int.tryParse(remoteIdController.text);

    try {
      final localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': true,
      });

      chat.state = chat.state.copyWith(localStream: localStream);
      localStream.getTracks().forEach((element) {
        pc.addTrack(element, localStream);
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Camera permission denied"),
      ));

      return;
    }

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    socket.emitWithAck('offer', {
      'remoteId': remoteId,
      'signal': offer.toMap(),
    }, ack: (data) async {
      if (data['error'] == null) {
        chat.state = chat.state.copyWith(
          callState: CallState.outgoing,
          remoteId: remoteId,
        );
        Navigator.pushNamed(context, CallScreen.routeName);
        setState(() {
          isTryingToCall = false;
        });
      } else {
        setState(() {
          isTryingToCall = false;
        });
        final errorMessage = data['error']['message'];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMessage),
        ));

        PeerConnection().dispose();
        disposeStream(chat.state.localStream);

        chat.state = chat.state.copyWith(
          localStream: null,
          callState: CallState.idle,
        );
      }
    });
  }

  void pcOnIceCandidate(RTCIceCandidate candidate) {
    final socket = SocketConnection().socket;
    socket.emit("ice-candidate", {
      'candidate': candidate.toMap(),
    });
  }

  void pcOnTrack(event) {
    final chat = ref.read(chatProvider.notifier);

    if (event.track.kind != 'video') return;
    chat.state = chat.state.copyWith(
      remoteStream: event.streams.first,
      callState: CallState.connected,
    );
  }

  void pcOnConnectionState(RTCPeerConnectionState state) {
    final chat = ref.read(chatProvider.notifier);

    if (state != RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      return;
    }

    chat.state = chat.state.copyWith(
      callState: CallState.connected,
    );
  }

  Future<void> playOutgoingRingtone() async {
    final player = outgoingAudio;

    await player.setAsset('assets/dial-ring.mp3');
    await player.setLoopMode(LoopMode.all);
    await player.setVolume(0.1);
    await player.setAndroidAudioAttributes(kRingtoneAndroidAudioAttributes);
    await player.play();
  }

  Future<String> getDefaultRingtoneUri() async {
    const channel = MethodChannel('videofi_common_channel');
    final String ringtone = await channel.invokeMethod('getDefaultRingtoneUri');
    return ringtone;
  }

  Future<void> playIncomingRingtone() async {
    // Silent when volume buttons are pressed
    volumeButtonSubscription = FlutterAndroidVolumeKeydown.stream
        .listen((event) => incomingAudio.stop());

    // Get the default ringtone in android
    var uri = Uri.parse(await getDefaultRingtoneUri());
    final ringtone = AudioSource.uri(uri);

    final player = incomingAudio;
    await player.setAudioSource(ringtone);
    await player.setLoopMode(LoopMode.all);
    await player.setVolume(1);
    await player.setAndroidAudioAttributes(kRingtoneAndroidAudioAttributes);
    await player.play();
  }

  void onCallStateChanged(CallState? previous, CallState current) {
    if (current == CallState.outgoing) {
      playOutgoingRingtone();
    } else if (current == CallState.incoming) {
      playIncomingRingtone();
    } else {
      outgoingAudio.stop();
      incomingAudio.stop();
      volumeButtonSubscription?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localId = ref.watch(
      chatProvider.select((value) => value.localId.toString()),
    );
    final isCallInProgress = ref.watch(
      chatProvider.select((value) => value.callState != CallState.idle),
    );
    ref.listen<CallState>(
      chatProvider.select((value) => value.callState),
      onCallStateChanged,
    );

    if (isWSConnected == false) {
      return const Scaffold(
        body: Center(
          child: Text("Connecting..."),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          if (isCallInProgress)
            Positioned(
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, CallScreen.routeName);
                },
                child: Container(
                  height: 50,
                  width: MediaQuery.of(context).size.width,
                  color: Colors.green,
                  child: const Center(
                    child: Text(
                      "Tap to view call",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // A green dot
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Your ID",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        localId,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 160,
                height: 50,
                child: TextField(
                  keyboardType: TextInputType.number,
                  controller: remoteIdController,
                  onChanged: (_) {
                    // To update the state of the button
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Remote ID',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 160,
                child: ElevatedButton(
                  child: Text(isTryingToCall ? '...' : 'Call'),
                  onPressed: remoteIdController.text.isEmpty || isTryingToCall
                      ? null
                      : onCallPressed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
