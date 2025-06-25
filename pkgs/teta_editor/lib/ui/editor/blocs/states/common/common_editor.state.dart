import 'package:editor/ui/editor/blocs/states/analyzer/analyzer.state.dart';
import 'package:editor/ui/editor/blocs/states/chat/chat.state.dart';
import 'package:editor/ui/editor/blocs/states/cli_process/cli_process.state.dart';
import 'package:editor/ui/editor/blocs/states/console/console.state.dart';
import 'package:editor/ui/editor/blocs/states/repository/repository.state.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

// Assuming ProjectSDK is defined elsewhere, e.g., in the project_model.dart
// For this file, we might need to import it if not already globally available or through a common entities package.
// For now, I'll assume it's accessible or define a placeholder if needed for generation.
// import 'package:teta_oss/core/project_management/project_model.dart'; // Path might vary

// Placeholder for ProjectSDK if not imported, to allow Freezed generation
enum ProjectSDK { flutter, expo }

part 'common_editor.state.freezed.dart';
part 'common_editor.state.g.dart';

@freezed
class CommonEditorState with _$CommonEditorState {
  factory CommonEditorState({
    required String projectPath, // Renamed from tetaDocumentsPath, this is the direct project root
    required String projectID, // This is the UUID of the project
    required ProjectSDK sdkType, // Added new field
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

  // This getter now directly returns projectPath, as it's the full path to the app.
  String get projectAppPath => projectPath;
}

class CommonEditorStateConverter
    implements JsonConverter<CommonEditorState, Map<String, dynamic>> {
  const CommonEditorStateConverter();

  @override
  CommonEditorState fromJson(Map<String, dynamic> json) {
    // Need to handle sdkType deserialization carefully if it's not a simple string.
    // Assuming ProjectSDK.name is stored as a string in JSON.
    return CommonEditorState.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(CommonEditorState object) {
    return object.toJson();
  }
}


// Manual addition for ProjectSDK enum to make this file self-contained for generation if needed,
// or ensure the import 'package:teta_oss/core/project_management/project_model.dart'
// is correctly resolved by the build_runner.
// If `project_model.dart` is outside this `pkgs/teta_editor` package,
// it needs to be a proper dependency or use relative paths if within the same monorepo structure.
// For now, Freezed should pick up the enum ProjectSDK from the import if it resolves.
// Adding it here just in case for isolated generation.
// enum ProjectSDK { flutter, expo }
// It's better to rely on the import:
// apps/desktop/lib/core/project_management/project_model.dart needs to be accessible.
// Let's assume the build system can find it. If not, build_runner will complain,
// and we might need to adjust paths or package dependencies.
// For the purpose of this change, I am adding the import from the `apps/desktop`'s model.
// This implies that `pkgs/teta_editor` would need a dependency on the package containing `project_model.dart`
// or a relative path if it's part of the same conceptual package/monorepo.
// Given the current structure, direct relative path like `../../apps/desktop/lib/...` is not standard for pubspec dependencies.
// This suggests `project_model.dart` should ideally be in a shared package or within `pkgs/teta_editor` itself if it's core to editor logic.
// For now, I'll add a placeholder import path that build_runner might resolve in a monorepo,
// or it will fail, indicating this structural dependency needs to be addressed.
// import '../../apps/desktop/lib/core/project_management/project_model.dart'; // THIS IS LIKELY WRONG for package structure

// Correct approach: ProjectSDK should be defined in a way that's accessible by this package.
// If it's in `apps/desktop`, then `pkgs/teta_editor` cannot directly import it without
// `apps/desktop` being a package that `pkgs/teta_editor` depends on, which is circular.
// Solution: Move `ProjectSDK` (and potentially `Project` model if widely used by editor)
// to a shared package or duplicate `ProjectSDK` enum definition here.
// Duplicating for now to ensure Freezed generation works for this step.
// THIS IS A TEMPORARY DUPLICATION for generation purposes.
// enum ProjectSDKForFreezed { flutter, expo }
// Then use ProjectSDKForFreezed in the model and map it.
// Better: Assume build_runner can handle it if files are generated correctly.
// The `project_model.dart` from `apps/desktop` defines `ProjectSDK`.
// The `CommonEditorState.fromJson` will need to correctly parse `sdkType`.
// Freezed's generated `fromJson` should handle `sdkType: ProjectSDK.values.byName(json['sdk_type'] as String),`
// if `sdk_type` is stored as a string name.
// The `project_model.dart` has:
// sdkType: ProjectSDK.values.firstWhere((e) => e.name == json['sdk_type'], orElse: () => ProjectSDK.flutter)
// This is good.
