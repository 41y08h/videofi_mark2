import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectedScreen extends ConsumerStatefulWidget {
  const ConnectedScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ConnectedScreenState();
}

class _ConnectedScreenState extends ConsumerState<ConnectedScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Connected'),
      ),
    );
  }
}
