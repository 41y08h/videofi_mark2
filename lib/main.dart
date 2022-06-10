import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:videofi_mark2/screens/call_screen.dart';
import 'package:videofi_mark2/screens/idle_screen.dart';

main() async {
  await dotenv.load(fileName: ".env");
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xff000000),
  ));

  runApp(ProviderScope(
    child: MaterialApp(
      title: 'VideoFi',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xff300a24),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: CallScreen.routeName,
      routes: {
        '/': (context) => const IdleScreen(),
        CallScreen.routeName: (context) => const CallScreen(),
      },
    ),
  ));
}
