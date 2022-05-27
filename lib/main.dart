import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:videofi_mark2/screens/connected_screen.dart';
import 'package:videofi_mark2/screens/idle_screen.dart';
import 'package:videofi_mark2/screens/outgoing_screen.dart';
import 'package:videofi_mark2/screens/incoming_screen.dart';

main() {
  runApp(ProviderScope(
    child: MaterialApp(
      title: 'Videofi',
      initialRoute: 'idle',
      routes: {
        'idle': (context) => const IdleScreen(),
        'outgoing': (context) => const OutgoingScreen(),
        'incoming': (context) => const IncomingScreen(),
        'connected': (context) => const ConnectedScreen(),
      },
    ),
  ));
}
