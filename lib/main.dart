import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:videofi_mark2/notifiers/chat_notifier.dart';
import 'package:videofi_mark2/pc.dart';
import 'package:videofi_mark2/screens/connected_screen.dart';
import 'package:videofi_mark2/screens/idle_screen.dart';
import 'package:videofi_mark2/screens/outgoing_screen.dart';
import 'package:videofi_mark2/screens/incoming_screen.dart';
import 'package:videofi_mark2/socket.dart';

main() {
  runApp(ProviderScope(
    child: MaterialApp(
      title: 'Videofi',
      initialRoute: 'idle',
      routes: {
        'idle': (context) => const IdleScreen(),
        'outgoing': (context) => const OutgoingScreen(),
        'incoming': (context) => const IncomingScreen(),
        'connected': (context) => const ConnectedScreen(),
      },
    ),
  ));
}

class App extends StatefulWidget {
  const App({Key? key}) : super(key: key);

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int? localId;
  TextEditingController remoteIdController = TextEditingController();
  MediaStream? localStream;

  int? remoteId;

  CallState callState = CallState.idle;
  RTCSessionDescription? remoteDescription;

  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  String callEvent = '';
  bool isMuted = false;

  @override
  void initState() {
    super.initState();

    remoteRenderer.initialize();
    localRenderer.initialize();

    final socket = SocketConnection().socket;
    socket.on('connect', (_) {
      print("connected to ws server");
      socket.emit('get-id');
    });
    socket.on('get-id/callback', (id) {
      setState(() {
        localId = id;
      });
    });

    socket.on("offer", (data) async {
      print("ws: received event: offer");
      setState(() {
        callState = CallState.incoming;
        remoteId = data['remoteId'];

        final signal = data['signal'];
        remoteDescription = RTCSessionDescription(
          signal['sdp'],
          signal['type'],
        );
      });
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
      setState(() {
        callState = CallState.connected;
      });
    });

    socket.on("ice-candidate", (data) async {
      print("received ice-candidate");
      final signal = data['candidate'];
      final candidate = RTCIceCandidate(
        signal['candidate'],
        signal['sdpMid'],
        signal['sdpMLineIndex'],
      );
      final pc = await PeerConnection().pc;
      await pc.addCandidate(candidate).catchError((e) {/* ignore */});
    });

    socket.on("offer-rejected", (data) {
      print("ws: received event: offer-rejected");
      setState(() {
        callState = CallState.idle;
      });
      disposeCall();
    });

    socket.on("offer-ended", (data) {
      setState(() {
        callState = CallState.idle;
      });
      disposeCall();
    });

    socket.on("outgoing-time-out", (data) {
      print("outgoing timed out");
      setState(() {
        callState = CallState.idle;
      });
      disposeCall();
    });

    socket.on("incoming-time-out", (data) {
      print("incoming timed out");

      setState(() {
        callState = CallState.idle;
      });
      disposeCall();
    });

    socket.on("call-disconnected", (data) {
      setState(() {
        callState = CallState.idle;
      });
      disposeCall();
    });
  }

  void initializePeerConnection(RTCPeerConnection pc) async {
    pc.onIceCandidate = (RTCIceCandidate candidate) async {
      print("sending ice-candidate");
      final socket = SocketConnection().socket;
      socket.emit('ice-candidate', {
        'candidate': candidate.toMap(),
      });
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video') {
        remoteRenderer.srcObject = event.streams[0];
      }
      setState(() {
        callState = CallState.connected;
      });
    };

    pc.onConnectionState = (state) {
      print("connection state: $state");
    };

    pc.onSignalingState = (state) {
      print("signaling state: $state");
    };
  }

  Future<MediaStream> getUserStream() {
    return navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true,
    });
  }

  void onCallPressed() async {
    await initializeLocalStream();
    final pc = await PeerConnection().pc;
    initializePeerConnection(pc);
    localStream?.getTracks().forEach((track) {
      pc.addTrack(track, localStream as MediaStream);
    });

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    final socket = SocketConnection().socket;
    print('ws: sending event: offer');
    socket.emitWithAck("offer", {
      'remoteId': remoteIdController.text,
      'signal': offer.toMap(),
    }, ack: (data) async {
      if (data['error'] == null) return;

      // Call failed
      print("call failed: ${data['error']['code']}");
      setState(() {
        callState = CallState.idle;
      });
      disposeCall();
    });
    setState(() {
      remoteId = int.parse(remoteIdController.text);
      callState = CallState.outgoing;
    });
  }

  Future<void> initializeLocalStream() async {
    if (localStream != null) return;
    localStream = await getUserStream();
    localRenderer.srcObject = localStream;
  }

  void onAnswerPressed() async {
    await initializeLocalStream();

    final pc = await PeerConnection().pc;
    initializePeerConnection(pc);

    localStream?.getTracks().forEach((track) {
      pc.addTrack(track, localStream as MediaStream);
    });

    await pc.setRemoteDescription(remoteDescription as RTCSessionDescription);

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    final socket = SocketConnection().socket;
    print("sending answer");
    socket.emitWithAck('answer', {
      'signal': answer.toMap(),
    }, ack: (data) {
      if (data['error'] == null) return;

      // Call failed
      print("amswer failed: ${data['error']['code']}");
      setState(() {
        callState = CallState.idle;
      });
      disposeCall();
    });
  }

  void endCall() {
    final socket = SocketConnection().socket;
    socket.emit('disconnect-call');
    setState(() {
      callState = CallState.idle;
    });
    disposeCall();
  }

  void endOutgoingCall() {
    print("ws: sending event: end-offer");
    final socket = SocketConnection().socket;
    socket.emit('end-offer');
    setState(() {
      callState = CallState.idle;
    });
    disposeCall();
  }

  void disposeCall() {
    PeerConnection().dispose();
    localStream?.getTracks().forEach((element) {
      element.stop();
    });
    localStream?.dispose();
    setState(() {
      localStream = null;
    });
  }

  void rejectIncomingCall() {
    final socket = SocketConnection().socket;
    socket.emit('reject-offer');
    setState(() {
      callState = CallState.idle;
    });
    disposeCall();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Builder(
        builder: (context) {
          switch (callState) {
            case CallState.idle:
              return const IdleScreen();

            case CallState.outgoing:
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.face,
                    size: 60,
                    color: Colors.green,
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    remoteId.toString(),
                    style: const TextStyle(
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  const Text(
                    'Calling',
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(callEvent),
                  const SizedBox(
                    height: 4,
                  ),
                  ClipOval(
                    child: Container(
                      color: Colors.red,
                      child: IconButton(
                        color: Colors.white,
                        onPressed: endOutgoingCall,
                        icon: const Icon(Icons.call_end),
                      ),
                    ),
                  ),
                ],
              );
            case CallState.incoming:
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.face,
                    size: 60,
                    color: Colors.green,
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    remoteId.toString(),
                    style: const TextStyle(
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  const Text(
                    'Incoming',
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(callEvent),
                  const SizedBox(
                    height: 4,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipOval(
                        child: Container(
                          color: Colors.red,
                          child: IconButton(
                            color: Colors.white,
                            onPressed: rejectIncomingCall,
                            icon: const Icon(Icons.call_end),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      ClipOval(
                        child: Container(
                          color: Colors.lightGreen,
                          child: IconButton(
                            color: Colors.white,
                            onPressed: onAnswerPressed,
                            icon: const Icon(Icons.call),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            case CallState.connected:
              return Column(
                children: [
                  Expanded(
                    child: Stack(children: [
                      Expanded(child: RTCVideoView(remoteRenderer)),
                      SizedBox(
                        width: 200,
                        child: Expanded(child: RTCVideoView(localRenderer)),
                      ),
                    ]),
                  ),
                  Row(
                    children: [
                      TextButton(
                          onPressed: endCall, child: const Text("Hang up")),
                      TextButton(
                          onPressed: () {
                            Helper.setMicrophoneMute(
                                !isMuted,
                                localStream?.getAudioTracks().first
                                    as MediaStreamTrack);
                            setState(() {
                              isMuted = !isMuted;
                            });
                          },
                          child: Text(isMuted ? "Unmute" : "Mute")),
                    ],
                  )
                ],
              );
          }
        },
      )),
    );
  }
}
