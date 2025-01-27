import 'package:freezed_annotation/freezed_annotation.dart';

part 'analyzer.state.freezed.dart';
part 'analyzer.state.g.dart';

@freezed
class AnalyzerState with _$AnalyzerState {
  const factory AnalyzerState.initial({
    @Default([]) List<String> infos,
    @Default([]) List<String> warnings,
    @Default([]) List<String> errors,
  }) = _AnalyzerInitial;
  const factory AnalyzerState.analyzing({
    @Default([]) List<String> infos,
    @Default([]) List<String> warnings,
    @Default([]) List<String> errors,
  }) = _AnalyzerAnalyzing;
  const factory AnalyzerState.success({
    @Default([]) List<String> infos,
    @Default([]) List<String> warnings,
    @Default([]) List<String> errors,
  }) = _AnalyzerSuccess;
  const factory AnalyzerState.hasErrors({
    @Default([]) List<String> infos,
    @Default([]) List<String> warnings,
    @Default([]) List<String> errors,
  }) = _AnalyzerHasErrors;

  factory AnalyzerState.fromJson(Map<String, dynamic> json) =>
      _$AnalyzerStateFromJson(json);
}

class AnalyzerStateConverter
    implements JsonConverter<AnalyzerState, Map<String, dynamic>> {
  const AnalyzerStateConverter();

  @override
  AnalyzerState fromJson(Map<String, dynamic> json) {
    return AnalyzerState.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(AnalyzerState object) {
    return object.toJson();
  }
}
