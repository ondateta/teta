// import 'package:editor/editor.dart'; // TetaEditor might not be needed here if context comes from Cubit
import 'package:editor/extensions/index.dart';
// import 'package:editor/ui/editor/blocs/project_context_cubit.dart'; // Cubit will be provided by a parent
import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart'; // BlocProvider removed from here

class EditorView extends StatelessWidget {
  const EditorView({super.key, /*required this.teta,*/ required this.child});

  // final TetaEditor teta; // This might become optional or removed
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The BlocProvider for ProjectContextCubit will be moved higher up,
    // likely in EditorShellScreen within the router.dart file.
    // ProjectContextCubit will be accessible via context.read or BlocBuilder/Listener.
    return Scaffold(
      body: child.padding(const EdgeInsets.only(top: 24)),
    );
  }
}
