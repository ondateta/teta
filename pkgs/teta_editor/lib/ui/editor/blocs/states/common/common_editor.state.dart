import 'package:editor/ui/editor/blocs/states/analyzer/analyzer.state.dart';
import 'package:editor/ui/editor/blocs/states/chat/chat.state.dart';
import 'package:editor/ui/editor/blocs/states/cli_process/cli_process.state.dart';
import 'package:editor/ui/editor/blocs/states/console/console.state.dart';
import 'package:editor/ui/editor/blocs/states/repository/repository.state.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'common_editor.state.freezed.dart';
part 'common_editor.state.g.dart';

@freezed
class CommonEditorState with _$CommonEditorState {
  factory CommonEditorState({
    required String tetaDocumentsPath,
    required String projectID,
    @ChatStateConverter()
    @Default(
      ChatState(
        messages: [],
        user: User(id: 'user'),
        productManager: AIUser(
          user: User(
            id: 'product_manager',
            firstName: 'Product Manager',
          ),
          currentState: AIUserState.waiting,
        ),
        techLead: AIUser(
          user: User(
            id: 'tech_lead',
            firstName: 'Tech Lead',
          ),
          currentState: AIUserState.waiting,
        ),
        developer: AIUser(
          user: User(
            id: 'developer',
            firstName: 'Developer',
          ),
          currentState: AIUserState.waiting,
        ),
        designer: AIUser(
          user: User(
            id: 'designer',
            firstName: 'Designer',
          ),
          currentState: AIUserState.waiting,
        ),
      ),
    )
    ChatState chatState,
    @RepositoryStateConverter()
    @Default(RepositoryState.initial(
      branches: [],
      currentBranch: 'main',
      commits: [],
      currentCommit: null,
    ))
    RepositoryState repositoryState,
    @CliProcessStateConverter()
    @Default(CliProcessState(pids: []))
    CliProcessState cliProcessState,
    @ConsoleStateConverter()
    @Default(ConsoleState(logs: []))
    ConsoleState consoleState,
    @AnalyzerStateConverter()
    @Default(AnalyzerState.initial())
    AnalyzerState analyzerState,
  }) = _CommonEditorState;
  CommonEditorState._();

  factory CommonEditorState.fromJson(Map<String, dynamic> json) =>
      _$CommonEditorStateFromJson(json);

  String get projectAppPath => '$tetaDocumentsPath/$projectID';
}

class CommonEditorStateConverter
    implements JsonConverter<CommonEditorState, Map<String, dynamic>> {
  const CommonEditorStateConverter();

  @override
  CommonEditorState fromJson(Map<String, dynamic> json) {
    return CommonEditorState.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(CommonEditorState object) {
    return object.toJson();
  }
}
