import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:videofi_mark2/notifiers/chat_notifier.dart';
import 'package:videofi_mark2/screens/connected_screen.dart';
import 'package:videofi_mark2/screens/incoming_screen.dart';
import 'package:videofi_mark2/screens/outgoing_screen.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);

    ref.listen<StateController<Chat>>(chatProvider.state, (previous, current) {
      if (current.state.callState == CallState.idle) {
        Navigator.pop(context);
      }
    });

    return Scaffold(body: Builder(builder: (context) {
      switch (chat.callState) {
        case CallState.outgoing:
          return const OutgoingScreen();
        case CallState.incoming:
          return const IncomingScreen();
        case CallState.connected:
          return const ConnectedScreen();
        default:
          return const SizedBox(
            child: Text("Something went wrong :("),
          );
      }
    }));
  }
}
