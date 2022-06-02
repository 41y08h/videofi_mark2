import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:videofi_mark2/screens/call_screen.dart';
import 'package:videofi_mark2/screens/idle_screen.dart';

main() {
  runApp(ProviderScope(
    child: MaterialApp(
      title: 'Videofi',
      initialRoute: '/',
      routes: {
        '/': (context) => const IdleScreen(),
        CallScreen.routeName: (context) => const CallScreen(),
      },
    ),
  ));
}
