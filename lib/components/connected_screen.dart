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
  final Color color;
  const CallActionButton(
      {Key? key,
      this.onPressed,
      required this.icon,
      this.color = Colors.transparent})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    const double size = 52;
    return ClipOval(
      child: Material(
        color: color,
        child: SizedBox(
          height: size,
          width: size,
          child: IconButton(
            color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            onPressed: onPressed,
            icon: Icon(icon),
          ),
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
  bool isMute = false;

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

  void switchCamera() {
    final chat = ref.read(chatProvider);
    Helper.switchCamera(chat.localStream!.getVideoTracks().first);
  }

  void toggleMute() {
    final chat = ref.read(chatProvider);
    Helper.setMicrophoneMute(!isMute, chat.localStream!.getAudioTracks().first);
    setState(() {
      isMute = !isMute;
    });
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
                color: Color(0xff541c42),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CallActionButton(
                    icon: Icons.cameraswitch,
                    onPressed: switchCamera,
                  ),
                  const SizedBox(width: 20),
                  CallActionButton(
                    color: isMute ? Colors.white : Colors.transparent,
                    icon: Icons.mic_off,
                    onPressed: toggleMute,
                  ),
                  const SizedBox(width: 20),
                  CallActionButton(
                    color: Colors.red,
                    icon: Icons.call_end,
                    onPressed: disconnectCall,
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
