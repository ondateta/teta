import 'package:editor/ui/editor/blocs/states/repository/git/commit.entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'repository.state.freezed.dart';
part 'repository.state.g.dart';

@freezed
class RepositoryState with _$RepositoryState {
  const factory RepositoryState.initial({
    required List<String> branches,
    required String currentBranch,
    @CommitEntityConverter() required CommitEntity? currentCommit,
    @ListCommitEntityConverter() required List<CommitEntity> commits,
  }) = _RepositoryStateInitial;
  const factory RepositoryState.creating({
    required List<String> branches,
    required String currentBranch,
    @CommitEntityConverter() required CommitEntity? currentCommit,
    @ListCommitEntityConverter() required List<CommitEntity> commits,
  }) = _RepositoryStateCreating;
  const factory RepositoryState.loading({
    required List<String> branches,
    required String currentBranch,
    @CommitEntityConverter() required CommitEntity? currentCommit,
    @ListCommitEntityConverter() required List<CommitEntity> commits,
  }) = _RepositoryStateLoading;
  const factory RepositoryState.created({
    required List<String> branches,
    required String currentBranch,
    @CommitEntityConverter() required CommitEntity? currentCommit,
    @ListCommitEntityConverter() required List<CommitEntity> commits,
  }) = _RepositoryStateCreated;
  const factory RepositoryState.exception({
    required List<String> branches,
    required String currentBranch,
    @CommitEntityConverter() required CommitEntity? currentCommit,
    @ListCommitEntityConverter() required List<CommitEntity> commits,
    required String message,
  }) = _RepositoryStateException;
  const factory RepositoryState.gitNotInstalled({
    required List<String> branches,
    required String currentBranch,
    @CommitEntityConverter() required CommitEntity? currentCommit,
    @ListCommitEntityConverter() required List<CommitEntity> commits,
  }) = _RepositoryGitNotInstalled;

  factory RepositoryState.fromJson(Map<String, dynamic> json) =>
      _$RepositoryStateFromJson(json);
}

class RepositoryStateConverter
    implements JsonConverter<RepositoryState, Map<String, dynamic>> {
  const RepositoryStateConverter();

  @override
  RepositoryState fromJson(Map<String, dynamic> json) {
    return RepositoryState.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(RepositoryState object) {
    return object.toJson();
  }
}
