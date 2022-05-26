import 'package:flutter_riverpod/flutter_riverpod.dart';

class Chat {
  int? localId;
  Chat({this.localId});

  Chat copyWith({int? localId}) {
    return Chat(
      localId: localId ?? this.localId,
    );
  }
}

class ChatNotifier extends StateNotifier<Chat> {
  ChatNotifier() : super(Chat());

  void setLocalId(int? localId) {
    state = state.copyWith(localId: localId);
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, Chat>((ref) => ChatNotifier());
