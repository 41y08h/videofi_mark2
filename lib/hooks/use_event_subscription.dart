import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:videofi_mark2/socket.dart';

void useEventSubscription(String event, dynamic Function(dynamic) handler) {
  useEffect(() {
    final socket = SocketConnection().socket;
    socket.on(event, handler);
    return () => socket.off(event, handler);
  }, []);
}
