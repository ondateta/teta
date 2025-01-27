// Flutter imports:
import 'package:editor/ui/ds/controller_builder.dart';
import 'package:flutter/material.dart';

class HoverBuilder extends StatelessWidget {
  const HoverBuilder({
    required this.builder,
    this.onEnter,
    this.onExit,
    super.key,
  });

  final void Function(BuildContext)? onEnter;
  final void Function(BuildContext)? onExit;
  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  Widget build(BuildContext context) {
    return ControllerBuilder(
      create: () => ValueNotifier(false),
      builder: (context, controller) => MouseRegion(
        onEnter: (event) => {
          onEnter?.call(context),
          controller.value = true,
        },
        onExit: (event) => {
          onExit?.call(context),
          controller.value = false,
        },
        child: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) => builder(context, value),
        ),
      ),
    );
  }
}
