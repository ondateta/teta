import 'package:editor/extensions/index.dart';
import 'package:editor/ui/editor/widgets/bars/top/topbar_code.dart';
import 'package:editor/ui/editor/widgets/pages/code.dart';
import 'package:flutter/material.dart';

class EditorModeCode extends StatelessWidget {
  const EditorModeCode({
    super.key,
    required this.id,
    this.fileRef,
    this.commitHash,
  });

  final String id;
  final String? fileRef;
  final String? commitHash;

  @override
  Widget build(BuildContext context) {
    return [
      const TopBarCode(),
      EditorPageCode(
        id: id,
        fileRef: fileRef,
        commitHash: commitHash,
      ).expanded(),
    ].row();
  }
}
