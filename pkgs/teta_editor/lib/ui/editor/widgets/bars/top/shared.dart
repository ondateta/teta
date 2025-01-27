import 'package:editor/extensions/index.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum TopBarSharedMenuItem {
  home,
  design,
  code,
  prototype,
}

class TopBarShared extends StatelessWidget {
  const TopBarShared({super.key, required this.selected});

  final TopBarSharedMenuItem selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return <Widget>[
      Image.asset(
        'assets/logo.png',
        width: 40,
        height: 40,
      ).centered().square(48).tooltip('Back to home').pointer().onTap(
            () => context.go('/home'),
          ),
      nil.color(theme.colorScheme.onSurface.withOpacity(0.2)).size(48, 1),
      IconButton(
        tooltip: 'Design',
        onPressed: () => context.go('/project/${context.projectID}/design'),
        icon: Icon(
          LucideIcons.bot,
          size: 20,
          color: selected == TopBarSharedMenuItem.design
              ? null
              : theme.colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
      IconButton(
        tooltip: 'Code',
        onPressed: () => context.go('/project/${context.projectID}/code'),
        icon: Icon(
          LucideIcons.code,
          size: 20,
          color: selected == TopBarSharedMenuItem.code
              ? null
              : theme.colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    ]
        .spacing(4)
        .column(cross: CrossAxisAlignment.center)
        .paddingH(0)
        .paddingV(4)
        .decorated(
          BoxDecoration(
            color: context.theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
        )
        .aligned(Alignment.topLeft);
  }
}
