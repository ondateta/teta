import 'package:editor/extensions/index.dart';
import 'package:editor/ui/editor/widgets/bars/top/topbar_design.dart';
import 'package:flutter/material.dart';

class EditorModeDesign extends StatelessWidget {
  const EditorModeDesign({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return [
      const TopBarDesign(),
      child.expanded(),
    ].row();
  }
}
