import 'package:editor/editor.dart';
import 'package:editor/extensions/index.dart';
import 'package:editor/ui/editor/blocs/editor.cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EditorView extends StatelessWidget {
  const EditorView({super.key, required this.teta, required this.child});

  final TetaEditor teta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          FlutterRunCubit(teta.appPath, teta.projectID)..init(),
      child: Scaffold(
        body: child.padding(const EdgeInsets.only(top: 24)),
      ),
    );
  }
}
