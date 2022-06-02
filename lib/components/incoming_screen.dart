import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:videofi_mark2/pc.dart';
import 'package:videofi_mark2/providers/chat.dart';
import 'package:videofi_mark2/socket.dart';
import 'package:videofi_mark2/utils/dispose_stream.dart';

class IncomingScreen extends ConsumerStatefulWidget {
  const IncomingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _IncomingScreenState();
}

class _IncomingScreenState extends ConsumerState<IncomingScreen> {
  void rejectIncomingCall() {
    final chat = ref.read(chatProvider.notifier);
    final socket = SocketConnection().socket;
    socket.emit('reject-offer');

    PeerConnection().dispose();
    chat.state = chat.state.copyWith(
      callState: CallState.idle,
    );
  }

  void onAnswerPressed() async {
    final chat = ref.read(chatProvider.notifier);
    final socket = SocketConnection().socket;
    final pc = await PeerConnection().pc;

    final localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true,
    });
    localStream.getTracks().forEach((element) {
      pc.addTrack(element, localStream);
    });
    chat.state = chat.state.copyWith(localStream: localStream);

    await pc.setRemoteDescription(
      chat.state.remoteDescription as RTCSessionDescription,
    );

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    socket.emitWithAck('answer', {
      'signal': answer.toMap(),
    }, ack: (data) {
      if (data['error'] == null) return;

      PeerConnection().dispose();
      disposeStream(chat.state.localStream);
      disposeStream(chat.state.remoteStream);

      chat.state = chat.state.copyWith(
        localStream: null,
        remoteStream: null,
        callState: CallState.idle,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final remoteId = ref.watch(chatProvider.select((value) => value.remoteId));

    return Center(
      child: Column(
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
      ),
    );
  }
}
