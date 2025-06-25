import 'package:uuid/uuid.dart';

enum ProjectSDK { flutter, expo }

class Project {
  final String id;
  final String name;
  final String path;
  final ProjectSDK sdkType;
  final DateTime createdAt;
  DateTime lastOpenedAt;

  Project({
    required this.id,
    required this.name,
    required this.path,
    required this.sdkType,
    required this.createdAt,
    required this.lastOpenedAt,
  });

  factory Project.create({
    required String name,
    required String path,
    required ProjectSDK sdkType,
  }) {
    final now = DateTime.now();
    return Project(
      id: Uuid().v4(),
      name: name,
      path: path,
      sdkType: sdkType,
      createdAt: now,
      lastOpenedAt: now,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'sdk_type': sdkType.name,
      'created_at': createdAt.toIso8601String(),
      'last_opened_at': lastOpenedAt.toIso8601String(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      sdkType: ProjectSDK.values.firstWhere(
        (e) => e.name == json['sdk_type'],
        orElse: () => ProjectSDK.flutter, // Default to flutter if parsing fails
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastOpenedAt: DateTime.parse(json['last_opened_at'] as String),
    );
  }
}
