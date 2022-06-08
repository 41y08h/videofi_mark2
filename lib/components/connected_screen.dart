import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:videofi_mark2/providers/chat.dart';
import 'package:videofi_mark2/pc.dart';
import 'package:videofi_mark2/socket.dart';
import 'package:videofi_mark2/utils/dispose_stream.dart';

class CallActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  const CallActionButton({Key? key, this.onPressed, required this.icon})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        color: Colors.red,
        child: IconButton(
          color: Colors.white,
          onPressed: onPressed,
          icon: Icon(icon),
          splashColor: Colors.blue,
        ),
      ),
    );
  }
}

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
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RTCVideoView(remoteRenderer),
        Positioned(
          top: 20,
          right: 20,
          child: SizedBox(
            width: 90,
            height: 160,
            child: RTCVideoView(localRenderer),
          ),
        ),
        Positioned.fill(
          bottom: 0,
          right: 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
                color: Color(0xff300a24),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipOval(
                    child: Material(
                      color: Colors.red,
                      child: SizedBox(
                        height: 60,
                        width: 60,
                        child: IconButton(
                          color: Colors.white,
                          onPressed: disconnectCall,
                          icon: const Icon(Icons.call_end),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
