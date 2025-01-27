import 'package:editor/extensions/lists.ext.dart';
import 'package:editor/extensions/widgets.ext.dart';
import 'package:editor/ui/editor/blocs/editor.cubit.dart';
import 'package:editor/ui/editor/blocs/states/editor/editor.state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Console extends StatelessWidget {
  const Console({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth - 100 < 800 ? screenWidth - 100.0 : 800.0;
    return Drawer(
      width: drawerWidth,
      backgroundColor: theme.colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: [
        const Text('Console').paddingV(8),
        BlocBuilder<FlutterRunCubit, FlutterRunState>(
                builder: (context, state) {
          return ListView.builder(
            padding: const EdgeInsets.all(32),
            itemCount: state.common.consoleState.logs.length,
            itemBuilder: (context, index) {
              return SelectableText(state.common.consoleState.logs[index]);
            },
          );
        })
            .color(theme.colorScheme.surface)
            .clippedRRect(BorderRadius.circular(16))
            .expanded(),
      ].column().paddingAll(16),
    );
  }
}
