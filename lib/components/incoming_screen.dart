import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:simple_animations/simple_animations.dart';
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

    try {
      final localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': true,
      });
      chat.state = chat.state.copyWith(localStream: localStream);
      localStream.getTracks().forEach((element) {
        pc.addTrack(element, localStream);
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Camera permission denied"),
      ));

      return;
    }

    await pc.setRemoteDescription(
      chat.state.remoteDescription as RTCSessionDescription,
    );

    for (var candidate in chat.state.remoteCandidates) {
      await pc.addCandidate(candidate);
    }

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
    final remoteId =
        ref.watch(chatProvider.select((value) => value.remoteId.toString()));

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 60,
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
                'INCOMING',
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              VerticalSwipeButton(
                onPressed: () {},
                child: ClipOval(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    color: Colors.red,
                    child: const Icon(Icons.call_end),
                  ),
                ),
              ),
              const SizedBox(
                width: 24,
              ),
              VerticalSwipeButton(
                onPressed: () {
                  print("swiped");
                },
                child: ClipOval(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    color: Colors.blue,
                    child: const Icon(Icons.video_call),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VerticalSwipeButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  const VerticalSwipeButton(
      {Key? key, required this.onPressed, required this.child})
      : super(key: key);

  @override
  State<VerticalSwipeButton> createState() => _VerticalSwipeButtonState();
}

class _VerticalSwipeButtonState extends State<VerticalSwipeButton> {
  static const max = 240.0;
  static const min = 40.0;

  double position = min;
  bool hasSwiped = false;
  bool isTextVisible = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: max + 100,
      width: 60,
      child: Stack(
        fit: StackFit.loose,
        children: [
          MirrorAnimation<double>(
            tween: Tween(begin: 0, end: 20),
            builder: (context, child, value) {
              return Positioned.fill(
                bottom: value,
                child: const Opacity(
                  opacity: 0.4,
                  child: Align(
                    alignment: Alignment.center,
                    child: Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                ),
              );
            },
          ),
          AnimatedPositioned(
            curve: Curves.easeInOut,
            // Only animate when the position set instantly set to minimum
            duration: Duration(milliseconds: position == min ? 300 : 0),
            bottom: position,
            left: 0,
            right: 0,
            top: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onPanStart: (_) {
                      setState(() {
                        isTextVisible = true;
                      });
                    },
                    onPanUpdate: (details) {
                      final newPosition = position - details.delta.dy;
                      setState(() {
                        position = newPosition.clamp(min, max).toDouble();
                      });
                    },
                    onPanEnd: (_) {
                      setState(() {
                        isTextVisible = false;
                        if (position > (max * 0.8) && !hasSwiped) {
                          widget.onPressed();
                          hasSwiped = true;
                          return;
                        } else {
                          hasSwiped = false;
                        }
                        position = min;
                      });
                    },
                    child: widget.child,
                  ),
                ],
              ),
            ),
          ),
          if (isTextVisible)
            const Positioned(
              bottom: min - 20,
              child: SizedBox(
                width: 60,
                child: Center(
                  child: Text(
                    'Swipe up',
                    style: TextStyle(
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
