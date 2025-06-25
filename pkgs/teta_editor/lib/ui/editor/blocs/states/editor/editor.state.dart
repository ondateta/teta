import 'package:editor/ui/editor/blocs/states/common/common_editor.state.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'editor.state.freezed.dart';
part 'editor.state.g.dart';

@freezed
class ProjectContextState with _$ProjectContextState {
  const factory ProjectContextState.projectCreating({
    @CommonEditorStateConverter() required CommonEditorState common,
  }) = _ProjectCreating;
  const factory ProjectContextState.notStarted({
    @CommonEditorStateConverter() required CommonEditorState common,
  }) = _NotStarted;
  const factory ProjectContextState.starting({
    @CommonEditorStateConverter() required CommonEditorState common,
  }) = _Starting;
  const factory ProjectContextState.running({
    @CommonEditorStateConverter() required CommonEditorState common,
    required int localhostPort,
  }) = _Running;
  const factory ProjectContextState.exceptionProjectNotCreated({
    @CommonEditorStateConverter() required CommonEditorState common,
    required String errorMessage,
  }) = _ExceptionProjectNotCreated;
  const factory ProjectContextState.exceptionProjectNotRunned({
    @CommonEditorStateConverter() required CommonEditorState common,
    required String errorMessage,
  }) = _ExceptionProjectNotRunned;
  // New state for when AI finishes writing files
  const factory ProjectContextState.filesUpdated({
    @CommonEditorStateConverter() required CommonEditorState common,
  }) = _FilesUpdated;

  factory ProjectContextState.fromJson(Map<String, dynamic> json) =>
      _$ProjectContextStateFromJson(json);
}
