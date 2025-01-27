// Dart imports:
import 'dart:ui';

extension StringUtils on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }

  Color get c {
    assert(
      length == 6 || length == 7 || length == 3 || length == 8,
      'Invalid hex color',
    );
    final hexColor = (length == 3)
        ? 'FF$this$this'
        : (length == 6 || (length == 7 && this[0] == '#'))
            ? 'FF${contains('#') ? substring(1) : this}'
            : this;
    return Color(int.parse(hexColor, radix: 16));
  }
}
