import 'package:flutter_chat_types/flutter_chat_types.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat.state.freezed.dart';
part 'chat.state.g.dart';

@freezed
class ChatState with _$ChatState {
  const factory ChatState({
    @ListMessagesConverter() required List<Message> messages,
    @Default(EditingMode.manual) EditingMode editingMode,
    @Default(RequestState.notStarted) RequestState requestState,
    @UserConverter() required User user,
    @AIUserConverter() required AIUser productManager,
    @AIUserConverter() required AIUser techLead,
    @AIUserConverter() required AIUser developer,
    @AIUserConverter() required AIUser designer,
  }) = _Chat;

  factory ChatState.fromJson(Map<String, dynamic> json) =>
      _$ChatStateFromJson(json);
}

@JsonEnum()
enum EditingMode { conversationOnly, manual, agent }

@JsonEnum()
enum RequestState { notStarted, doing }

class ListMessagesConverter
    implements JsonConverter<List<Message>, List<dynamic>> {
  const ListMessagesConverter();

  @override
  List<Message> fromJson(List<dynamic> json) {
    return json.map((e) => Message.fromJson(e)).toList();
  }

  @override
  List<dynamic> toJson(List<Message> object) {
    return object.map((e) => e.toJson()).toList();
  }
}

class ChatStateConverter
    implements JsonConverter<ChatState, Map<String, dynamic>> {
  const ChatStateConverter();

  @override
  ChatState fromJson(Map<String, dynamic> json) {
    return ChatState.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(ChatState object) {
    return object.toJson();
  }
}

@freezed
class AIUser with _$AIUser {
  const factory AIUser({
    @UserConverter() required User user,
    required AIUserState currentState,
  }) = _AIUser;

  factory AIUser.fromJson(Map<String, dynamic> json) => _$AIUserFromJson(json);
}

@JsonEnum()
enum AIUserState { waiting, typing }

class AIUserConverter implements JsonConverter<AIUser, Map<String, dynamic>> {
  const AIUserConverter();

  @override
  AIUser fromJson(Map<String, dynamic> json) {
    return AIUser.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(AIUser object) {
    return object.toJson();
  }
}

class UserConverter implements JsonConverter<User, Map<String, dynamic>> {
  const UserConverter();

  @override
  User fromJson(Map<String, dynamic> json) {
    return User.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(User object) {
    return object.toJson();
  }
}
