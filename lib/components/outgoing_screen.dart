import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:simple_animations/stateless_animation/play_animation.dart';
import 'package:videofi_mark2/pc.dart';
import 'package:videofi_mark2/providers/chat.dart';
import 'package:videofi_mark2/socket.dart';
import 'package:videofi_mark2/utils/dispose_stream.dart';

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
    disposeStream(chat.state.localStream);

    chat.state = chat.state.copyWith(
      localStream: null,
      callState: CallState.idle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final remoteId =
        ref.watch(chatProvider.select((value) => value.remoteId.toString()));

    return Stack(
      alignment: Alignment.center,
      children: [
        PlayAnimation<double>(
          tween: Tween(begin: -100, end: 60),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutBack,
          builder: (context, child, value) {
            return Positioned(
              top: value,
              child: ClipOval(
                child: Container(
                  color: Colors.grey.shade800,
                  padding: const EdgeInsets.all(14),
                  child: Icon(
                    Icons.person_rounded,
                    size: 60,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          top: 180,
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.black,
                ),
                child: Text(
                  remoteId,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'CALLING',
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 40,
          child: RawMaterialButton(
            onPressed: endOutgoingCall,
            fillColor: Colors.red,
            shape: const CircleBorder(
              side: BorderSide(),
            ),
            padding: const EdgeInsets.all(16),
            child: const Icon(
              Icons.call_end,
              size: 30,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
