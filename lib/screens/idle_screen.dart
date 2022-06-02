import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:videofi_mark2/pc.dart';
import 'package:videofi_mark2/providers/chat.dart';
import 'package:videofi_mark2/screens/call_screen.dart';
import 'package:videofi_mark2/socket.dart';
import 'package:videofi_mark2/utils/dispose_stream.dart';

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

  @override
  void initState() {
    super.initState();
    initialize();
  }

  void initialize() async {
    final socket = SocketConnection().socket;
    final chat = ref.read(chatProvider.notifier);

    socket.on('connect', wsOnConnect);
    socket.on('get-id/callback', wsOnIdCallback);
    socket.on("disconnect", wsOnDisconnect);

    socket.on("offer", (data) async {
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
    });

    socket.on("answer", (data) async {
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
    });

    socket.on("ice-candidate", (data) async {
      final pc = await PeerConnection().pc;

      final signal = data['candidate'];
      final candidate = RTCIceCandidate(
        signal['candidate'],
        signal['sdpMid'],
        signal['sdpMLineIndex'],
      );
      await pc.addCandidate(candidate).catchError((e) {/* ignore */});
    });

    PeerConnection().onIceCandidate((candidate) async {
      socket.emit("ice-candidate", {
        'candidate': candidate.toMap(),
      });
    });
    PeerConnection().onTrack((event) {
      if (event.track.kind != 'video') return;
      chat.state = chat.state.copyWith(
        remoteStream: event.streams.first,
        callState: CallState.connected,
      );
    });

    PeerConnection().onConnectionState((state) {
      if (state != RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        return;
      }

      chat.state = chat.state.copyWith(
        callState: CallState.connected,
      );
    });
  }

  void wsOnConnect(dynamic _) {
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

  void wsOnDisconnect(dynamic _) {
    setState(() {
      isWSConnected = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final localId = ref.watch(
      chatProvider.select((value) => value.localId.toString()),
    );
    final isCallInProgress = ref.watch(
      chatProvider.select((value) => value.callState != CallState.idle),
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
