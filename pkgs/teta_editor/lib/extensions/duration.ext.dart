extension DurationUtils on Duration {
  Future<void> delay() => Future.delayed(this);
}
