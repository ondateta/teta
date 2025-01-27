import 'package:freezed_annotation/freezed_annotation.dart';

part 'console.state.freezed.dart';
part 'console.state.g.dart';

@freezed
class ConsoleState with _$ConsoleState {
  const factory ConsoleState({
    required List<String> logs,
  }) = _ConsoleState;

  factory ConsoleState.fromJson(Map<String, dynamic> json) =>
      _$ConsoleStateFromJson(json);
}

class ConsoleStateConverter
    implements JsonConverter<ConsoleState, Map<String, dynamic>> {
  const ConsoleStateConverter();

  @override
  ConsoleState fromJson(Map<String, dynamic> json) {
    return ConsoleState.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(ConsoleState object) {
    return object.toJson();
  }
}
