import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EditorWebViewController extends InheritedWidget {
  const EditorWebViewController({
    super.key,
    required this.controller,
    required super.child,
  });

  final WebViewController controller;

  static EditorWebViewController of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<EditorWebViewController>()!;
  }

  @override
  bool updateShouldNotify(EditorWebViewController oldWidget) {
    return true;
  }
}
