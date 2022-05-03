import 'package:socket_io_client/socket_io_client.dart' as IO;

const String kWebSocketURL = 'http://7b58-103-152-158-197.ngrok.io';

class SocketConnection {
  static final SocketConnection _instance = SocketConnection._();
  SocketConnection._();

  factory SocketConnection() {
    return _instance;
  }

  final _socket = IO.io(kWebSocketURL, <String, dynamic>{
    'transports': ['websocket'],
  });

  IO.Socket get socket => _socket;
}
