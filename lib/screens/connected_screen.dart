import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:videofi_mark2/notifiers/chat_notifier.dart';
import 'package:videofi_mark2/pc.dart';
import 'package:videofi_mark2/socket.dart';
import 'package:videofi_mark2/utils/disposeStream.dart';

class ConnectedScreen extends ConsumerStatefulWidget {
  const ConnectedScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ConnectedScreenState();
}

class _ConnectedScreenState extends ConsumerState<ConnectedScreen> {
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  RTCVideoRenderer localRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    initializeStreams();
  }

  void initializeStreams() async {
    final chat = ref.read(chatProvider.notifier);
    await remoteRenderer.initialize();
    await localRenderer.initialize();

    remoteRenderer.srcObject = chat.state.remoteStream;
    localRenderer.srcObject = chat.state.localStream;
  }

  void disconnectCall() {
    Navigator.popUntil(context, (route) => route.isFirst);

    final chat = ref.read(chatProvider.state);
    final socket = SocketConnection().socket;
    socket.emit("disconnect-call");

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

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(builder: (context, orientation) {
      return Stack(
        children: [
          Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: RTCVideoView(remoteRenderer),
                decoration: const BoxDecoration(color: Colors.black54),
              )),
          Positioned(
            left: 20.0,
            top: 20.0,
            child: Container(
              width: orientation == Orientation.portrait ? 90.0 : 120.0,
              height: orientation == Orientation.portrait ? 120.0 : 90.0,
              child: RTCVideoView(localRenderer, mirror: true),
              decoration: const BoxDecoration(color: Colors.black54),
            ),
          ),
          // Hang up icon buttion
          Positioned(
            right: 20.0,
            bottom: 20.0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.call_end),
                onPressed: disconnectCall,
              ),
            ),
          ),
        ],
      );
    });
  }
}
