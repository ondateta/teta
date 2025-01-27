import 'package:editor/extensions/index.dart';
import 'package:editor/ui/editor/widgets/bars/top/shared.dart';
import 'package:flutter/material.dart';

class TopBarDesign extends StatelessWidget {
  const TopBarDesign({super.key});

  @override
  Widget build(BuildContext context) {
    return [
      const TopBarShared(
        selected: TopBarSharedMenuItem.design,
      ),
    ].stack().paddingAll(8).aligned(Alignment.topCenter);
  }
}
