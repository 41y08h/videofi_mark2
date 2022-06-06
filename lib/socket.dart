import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

final kWebSocketURL = dotenv.env['WEBSOCKETS_SERVER_URL'];

class SocketConnection {
  static final SocketConnection _instance = SocketConnection._();
  SocketConnection._();

  factory SocketConnection() {
    return _instance;
  }

  final _socket = io.io(
    kWebSocketURL,
    io.OptionBuilder()
        .setTransports(['websocket'])
        .setReconnectionDelay(500)
        .setReconnectionAttempts(10000)
        .build(),
  );

  io.Socket get socket => _socket;
}
