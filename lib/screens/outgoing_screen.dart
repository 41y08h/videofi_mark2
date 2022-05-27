import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:videofi_mark2/notifiers/chat_notifier.dart';
import 'package:videofi_mark2/pc.dart';
import 'package:videofi_mark2/socket.dart';

class OutgoingScreen extends ConsumerStatefulWidget {
  const OutgoingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _OutgoingScreenState();
}

class _OutgoingScreenState extends ConsumerState<OutgoingScreen> {
  void endOutgoingCall() {
    final chat = ref.read(chatProvider.notifier);
    final socket = SocketConnection().socket;
    socket.emit('end-offer');

    PeerConnection().dispose();
    // Dispose local stream
    chat.state.localStream?.getTracks().forEach((track) {
      track.stop();
    });
    chat.state.localStream?.dispose();

    chat.state = chat.state.copyWith(
      localStream: null,
      callState: CallState.idle,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final remoteId = ref.watch(chatProvider).remoteId;

    return Scaffold(
      body: Center(
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
              'Calling',
            ),
            const SizedBox(
              height: 4,
            ),
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
        ),
      ),
    );
  }
}
