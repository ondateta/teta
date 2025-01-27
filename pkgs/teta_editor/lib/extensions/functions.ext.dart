void tryCatch(
  void Function() function, {
  void Function(dynamic)? onError,
}) {
  try {
    function();
  } catch (e) {
    onError?.call(e);
  }
}
