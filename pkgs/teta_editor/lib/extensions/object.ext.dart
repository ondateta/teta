extension ObjectUtils on Object? {
  bool exists() => this != null;
  bool notExists() => this == null;
  T Function() lazy<T>() => () => this as T;
}
