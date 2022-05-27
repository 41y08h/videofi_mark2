import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:videofi_mark2/notifiers/chat_notifier.dart';
import 'package:videofi_mark2/pc.dart';
import 'package:videofi_mark2/socket.dart';
import 'package:videofi_mark2/utils/disposeStream.dart';

class IdleScreen extends ConsumerStatefulWidget {
  const IdleScreen({
    Key? key,
  }) : super(key: key);

  @override
  _IdleScreenState createState() => _IdleScreenState();
}

class _IdleScreenState extends ConsumerState<IdleScreen> {
  TextEditingController remoteIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initialize();
  }

  void initialize() async {
    final socket = SocketConnection().socket;
    final chat = ref.read(chatProvider.notifier);

    socket.on('connect', (_) {
      print("connected to ws server");
      socket.emit('get-id');
    });
    socket.on('get-id/callback', (id) {
      setState(() {
        chat.state = chat.state.copyWith(
          localId: id,
        );
      });
    });

    socket.on("offer", (data) async {
      print("ws: received event: offer");

      final signal = data['signal'];
      chat.state = chat.state.copyWith(
        remoteDescription: RTCSessionDescription(
          signal['sdp'],
          signal['type'],
        ),
        remoteId: data['remoteId'],
        callState: CallState.incoming,
      );

      Navigator.pushNamed(context, 'incoming');
    });

    socket.on("offer-ended", (data) {
      final chat = ref.read(chatProvider.notifier);

      PeerConnection().dispose();

      chat.state = chat.state.copyWith(
        callState: CallState.idle,
        remoteId: null,
        remoteDescription: null,
      );
    });

    socket.on("offer-rejected", (data) {
      final chat = ref.read(chatProvider.notifier);

      PeerConnection().dispose();
      disposeStream(chat.state.localStream);

      chat.state = chat.state.copyWith(
        callState: CallState.idle,
        remoteId: null,
        localStream: null,
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    });

    socket.on("answer", (data) async {
      print("ws: received event: answer");

      final signal = data['signal'];
      final answer = RTCSessionDescription(
        signal['sdp'],
        signal['type'],
      );
      final pc = await PeerConnection().pc;
      await pc.setRemoteDescription(answer);
    });

    socket.on("outgoing-time-out", (data) {
      final chat = ref.read(chatProvider.notifier);

      PeerConnection().dispose();
      disposeStream(chat.state.localStream);

      chat.state = chat.state.copyWith(
        callState: CallState.idle,
        localStream: null,
      );
    });

    socket.on("incoming-time-out", (data) {
      final chat = ref.read(chatProvider.notifier);

      PeerConnection().dispose();

      chat.state = chat.state.copyWith(
        callState: CallState.idle,
      );
    });

    socket.on("call-disconnected", (data) {
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
      Navigator.pop(context);
    });

    final pc = await PeerConnection().pc;

    socket.on("ice-candidate", (data) async {
      print("received ice-candidate");
      final signal = data['candidate'];
      final candidate = RTCIceCandidate(
        signal['candidate'],
        signal['sdpMid'],
        signal['sdpMLineIndex'],
      );
      await pc.addCandidate(candidate).catchError((e) {/* ignore */});
    });

    pc.onIceCandidate = (candidate) async {
      socket.emit("ice-candidate", {
        'candidate': candidate.toMap(),
      });
    };
    pc.onTrack = (event) {
      if (event.track.kind != 'video') return;
      chat.state = chat.state.copyWith(
        remoteStream: event.streams.first,
        callState: CallState.connected,
      );
    };

    pc.onConnectionState = (state) {
      if (state != RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        return;
      }

      chat.state = chat.state.copyWith(
        callState: CallState.connected,
      );
      Navigator.pushNamedAndRemoveUntil(
          context, 'connected', (route) => route.isFirst);
    };
  }

  void onCallPressed() async {
    final chat = ref.read(chatProvider.notifier);
    final socket = SocketConnection().socket;
    final pc = await PeerConnection().pc;
    final remoteId = int.parse(remoteIdController.text);

    final localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true,
    });
    chat.state = chat.state.copyWith(localStream: localStream);

    localStream.getTracks().forEach((element) {
      pc.addTrack(element, localStream);
    });

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    chat.state = chat.state.copyWith(
      callState: CallState.outgoing,
      remoteId: remoteId,
    );
    Navigator.pushNamed(context, 'outgoing');

    socket.emitWithAck('offer', {
      'remoteId': remoteId,
      'signal': offer.toMap(),
    }, ack: (data) async {
      if (data['error'] == null) return;

      print('call failed: ${data['error']['code']}');

      PeerConnection().dispose();
      disposeStream(chat.state.localStream);

      chat.state = chat.state.copyWith(
        localStream: null,
        callState: CallState.idle,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final localId = ref.watch(chatProvider).localId;

    return Scaffold(
      body: Column(
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
                    localId.toString(),
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
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Remote ID',
              ),
            ),
          ),
          SizedBox(
            width: 160,
            child: ElevatedButton(
              child: const Text('Call'),
              onPressed: onCallPressed,
            ),
          ),
        ],
      ),
    );
  }
}
