import 'package:freezed_annotation/freezed_annotation.dart';

class CommitEntity {
  const CommitEntity({
    required this.hash,
    required this.message,
  });

  final String hash;
  final String message;

  factory CommitEntity.fromJson(Map<String, dynamic> json) {
    return CommitEntity(
      hash: json['hash'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hash': hash,
      'message': message,
    };
  }
}

class CommitEntityConverter
    implements JsonConverter<CommitEntity, Map<String, dynamic>> {
  const CommitEntityConverter();

  @override
  CommitEntity fromJson(Map<String, dynamic> json) {
    return CommitEntity.fromJson(json);
  }

  @override
  Map<String, dynamic> toJson(CommitEntity object) {
    return object.toJson();
  }
}

class ListCommitEntityConverter
    implements JsonConverter<List<CommitEntity>, List<dynamic>> {
  const ListCommitEntityConverter();

  @override
  List<CommitEntity> fromJson(List<dynamic> json) {
    return json.map((e) => CommitEntity.fromJson(e)).toList();
  }

  @override
  List<dynamic> toJson(List<CommitEntity> object) {
    return object.map((e) => e.toJson()).toList();
  }
}
