class TaskModel {
  final String name;
  final bool shouldBeSplitted;
  final TaskStatus status;
  final List<TaskModel> subTasks;

  TaskModel({
    required this.name,
    required this.shouldBeSplitted,
    this.status = TaskStatus.pending,
    this.subTasks = const [],
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
        name: json['name'],
        shouldBeSplitted: json['should_be_splitted'],
      );

  TaskModel copyWith({
    String? name,
    bool? shouldBeSplitted,
    TaskStatus? status,
    List<TaskModel>? subTasks,
  }) {
    return TaskModel(
      name: name ?? this.name,
      shouldBeSplitted: shouldBeSplitted ?? this.shouldBeSplitted,
      status: status ?? this.status,
      subTasks: subTasks ?? this.subTasks,
    );
  }
}

enum TaskStatus {
  pending,
  completed,
  inProgress,
  stopped,
}
