import 'package:editor/extensions/lists.ext.dart';
import 'package:editor/extensions/widgets.ext.dart';
import 'package:editor/ui/editor/widgets/bars/top/shared.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TopBarCode extends StatelessWidget {
  const TopBarCode({super.key});

  @override
  Widget build(BuildContext context) {
    return [
      const TopBarShared(
        selected: TopBarSharedMenuItem.code,
      ),
    ].stack().paddingAll(8).aligned(Alignment.topLeft);
  }
}
