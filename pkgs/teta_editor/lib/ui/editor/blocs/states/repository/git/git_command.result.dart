class GitCommandResult {
  const GitCommandResult({
    required this.success,
    required this.output,
    required this.error,
  });

  final bool success;
  final String output;
  final String error;
}
