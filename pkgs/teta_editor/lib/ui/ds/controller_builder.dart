// Flutter imports:
import 'package:flutter/material.dart';

class ControllerBuilder<T extends ChangeNotifier> extends StatefulWidget {
  const ControllerBuilder({
    required this.create,
    required this.builder,
    this.initState,
    super.key,
  });

  final T Function() create;
  final void Function(BuildContext, T)? initState;
  final Widget Function(BuildContext, T) builder;

  @override
  State<ControllerBuilder<T>> createState() => _ControllerDisposerState<T>();
}

class _ControllerDisposerState<T extends ChangeNotifier>
    extends State<ControllerBuilder<T>> {
  late final T controller;

  @override
  void initState() {
    super.initState();
    controller = widget.create();
    if (widget.initState != null) {
      widget.initState?.call(context, controller);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, controller);
  }
}
