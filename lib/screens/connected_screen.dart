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
  _ConnectedScreenState createState() => _ConnectedScreenState();
}

class _ConnectedScreenState extends ConsumerState<ConnectedScreen> {
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  RTCVideoRenderer localRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    initializeStreams();
  }

  @override
  void dispose() {
    super.dispose();
    remoteRenderer.dispose();
    localRenderer.dispose();
  }

  void initializeStreams() async {
    final chat = ref.read(chatProvider);

    await remoteRenderer.initialize();
    await localRenderer.initialize();

    remoteRenderer.srcObject = chat.remoteStream;
    localRenderer.srcObject = chat.localStream;

    setState(() {});
  }

  void disconnectCall() {
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
    print("set state to idle");
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          right: 0,
          child: SizedBox(
            width: 90,
            height: 160,
            child: RTCVideoView(localRenderer),
          ),
        ),
        RTCVideoView(remoteRenderer),
        Positioned(
          bottom: 0,
          right: 0,
          child: SizedBox(
            width: 90,
            height: 90,
            child: IconButton(
              onPressed: disconnectCall,
              icon: const Icon(Icons.call_end),
            ),
          ),
        ),
      ],
    );
  }
}
