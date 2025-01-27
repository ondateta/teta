import 'package:freezed_annotation/freezed_annotation.dart';

part 'cli_process.state.freezed.dart';
part 'cli_process.state.g.dart';

@freezed
class CliProcessState with _$CliProcessState {
  const factory CliProcessState({
    required List<int> pids,
  }) = _CliProcessState;

  factory CliProcessState.fromJson(Map<String, dynamic> json) =>
      _$CliProcessStateFromJson(json);
}

class CliProcessStateConverter
    implements JsonConverter<CliProcessState, Map<String, dynamic>> {
  const CliProcessStateConverter();

  @override
  CliProcessState fromJson(Map<String, dynamic> json) {
    return CliProcessState.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(CliProcessState object) {
    return object.toJson();
  }
}
