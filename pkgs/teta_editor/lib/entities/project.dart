// TEMPORARY DUPLICATION - This should eventually come from a shared package.

enum ProjectSDK { flutter, expo }

class Project {
  final String id;
  final String name;
  final String path;
  final ProjectSDK sdkType;
  final DateTime createdAt;
  final DateTime lastOpenedAt;

  Project({
    required this.id,
    required this.name,
    required this.path,
    required this.sdkType,
    required this.createdAt,
    required this.lastOpenedAt,
  });

  // Minimal implementation for usage within ProjectContextCubit
  // No toJson/fromJson needed here as it's for constructor passing.
}
