import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:videofi_mark2/pc.dart';
import 'package:videofi_mark2/socket.dart';

main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({Key? key}) : super(key: key);

  @override
  State<App> createState() => _AppState();
}

enum CallStatus {
  idle,
  calling,
  incoming,
  connected,
}

class _AppState extends State<App> {
  int? localId;
  TextEditingController remoteIdController = TextEditingController();
  MediaStream? localStream;

  int? remoteId;

  CallStatus callStatus = CallStatus.idle;
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
        callStatus = CallStatus.incoming;
        remoteId = data['remoteId'];

        final signal = data['data'];
        remoteDescription = RTCSessionDescription(
          signal['sdp'],
          signal['type'],
        );
      });
    });

    socket.on("answer", (data) async {
      print("ws: received event: answer");

      final signal = data['data'];
      final answer = RTCSessionDescription(
        signal['sdp'],
        signal['type'],
      );
      final pc = await PeerConnection().pc;
      await pc.setRemoteDescription(answer);
      setState(() {
        callStatus = CallStatus.connected;
      });
    });

    socket.on("ice-candidate", (data) async {
      print("received ice-candidate");
      final signal = data['data'];
      final candidate = RTCIceCandidate(
        signal['candidate'],
        signal['sdpMid'],
        signal['sdpMLineIndex'],
      );
      final pc = await PeerConnection().pc;
      await pc.addCandidate(candidate).catchError((e) {/* ignore */});
    });

    socket.on("disconnect-call", (data) async {
      print("ws: received event: disconnect-call");

      if (callStatus == CallStatus.calling) {
        setState(() {
          callEvent = 'Call Rejected';
        });
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          callEvent = '';
          callStatus = CallStatus.idle;
        });
      } else {
        setState(() {
          callStatus = CallStatus.idle;
        });
      }
      disposeCall();
    });

    socket.on("offer/timeout", (data) {
      setState(() {
        callStatus = CallStatus.idle;
      });
      disposeCall();
    });

    socket.on("offer-ended", (data) {
      setState(() {
        callStatus = CallStatus.idle;
      });
      disposeCall();
    });
  }

  void initializePeerConnection(RTCPeerConnection pc) async {
    pc.onIceCandidate = (RTCIceCandidate candidate) async {
      print("sending ice-candidate");
      final socket = SocketConnection().socket;
      socket.emit('ice-candidate', {
        'remoteId': remoteId,
        'data': candidate.toMap(),
      });
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video') {
        remoteRenderer.srcObject = event.streams[0];
      }
      setState(() {
        callStatus = CallStatus.connected;
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
    setState(() {
      remoteId = int.parse(remoteIdController.text);
      callStatus = CallStatus.calling;
    });
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
      'data': offer.toMap(),
    }, ack: (data) async {
      if (data['error'] == null) return;

      // Call failed
      setState(() {
        callStatus = CallStatus.idle;
      });
      disposeCall();
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
    socket.emit('answer', {
      'remoteId': remoteId,
      'data': answer.toMap(),
    });
  }

  void endCall() {
    final socket = SocketConnection().socket;
    socket.emit('disconnect-call', {
      'remoteId': remoteId,
    });
    setState(() {
      callStatus = CallStatus.idle;
    });
    // disposeCall();
  }

  void endOutgoingCall() {
    final socket = SocketConnection().socket;
    socket.emit('end-offer');
    setState(() {
      callStatus = CallStatus.idle;
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VideoFi',
      home: Scaffold(
        body: Center(child: Builder(
          builder: (context) {
            switch (callStatus) {
              case CallStatus.idle:
                return Column(
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
                );

              case CallStatus.calling:
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
              case CallStatus.incoming:
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
                              onPressed: endCall,
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
              case CallStatus.connected:
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
      ),
    );
  }
}
