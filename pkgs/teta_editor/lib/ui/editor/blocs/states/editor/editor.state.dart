import 'package:editor/ui/editor/blocs/states/common/common_editor.state.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'editor.state.freezed.dart';
part 'editor.state.g.dart';

@freezed
class FlutterRunState with _$FlutterRunState {
  const factory FlutterRunState.projectCreating({
    @CommonEditorStateConverter() required CommonEditorState common,
  }) = _ProjectCreating;
  const factory FlutterRunState.notStarted({
    @CommonEditorStateConverter() required CommonEditorState common,
  }) = _NotStarted;
  const factory FlutterRunState.starting({
    @CommonEditorStateConverter() required CommonEditorState common,
  }) = _Starting;
  const factory FlutterRunState.running({
    @CommonEditorStateConverter() required CommonEditorState common,
    required int localhostPort,
  }) = _Running;
  const factory FlutterRunState.exceptionProjectNotCreated({
    @CommonEditorStateConverter() required CommonEditorState common,
    required String errorMessage,
  }) = _ExceptionProjectNotCreated;
  const factory FlutterRunState.exceptionProjectNotRunned({
    @CommonEditorStateConverter() required CommonEditorState common,
    required String errorMessage,
  }) = _ExceptionProjectNotRunned;

  factory FlutterRunState.fromJson(Map<String, dynamic> json) =>
      _$FlutterRunStateFromJson(json);
}
