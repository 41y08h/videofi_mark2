import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:videofi_mark2/notifiers/chat_notifier.dart';
import 'package:videofi_mark2/components/connected_screen.dart';
import 'package:videofi_mark2/components/incoming_screen.dart';
import 'package:videofi_mark2/components/outgoing_screen.dart';

class CallScreen extends ConsumerStatefulWidget {
  static const routeName = '/call';
  const CallScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  @override
  Widget build(BuildContext context) {
    final callState =
        ref.watch(chatProvider.select((state) => state.callState));

    return Scaffold(body: Builder(builder: (context) {
      switch (callState) {
        case CallState.outgoing:
          return const OutgoingScreen();
        case CallState.incoming:
          return const IncomingScreen();
        case CallState.connected:
          return const ConnectedScreen();
        default:
          Future.microtask(() => Navigator.pop(context));
          return const SizedBox();
      }
    }));
  }
}
