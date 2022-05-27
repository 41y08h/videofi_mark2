import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:videofi_mark2/notifiers/chat_notifier.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(builder: (context, orientation) {
        return Container(
          child: Stack(
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
                right: 20.0,
                bottom: 20.0,
                child: Container(
                  width: orientation == Orientation.portrait ? 90.0 : 120.0,
                  height: orientation == Orientation.portrait ? 120.0 : 90.0,
                  child: RTCVideoView(localRenderer, mirror: true),
                  decoration: const BoxDecoration(color: Colors.black54),
                ),
              )
            ],
          ),
        );
      }),
    );
  }
}
