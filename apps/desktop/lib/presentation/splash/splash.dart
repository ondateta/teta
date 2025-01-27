import 'package:editor/extensions/index.dart';
import 'package:flutter/material.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: [
        Image.asset(
          'assets/logo_macos.png',
          width: 200,
          height: 200,
        ),
        Text(
          'Teta',
          style: context.displayLarge.copyWith(
            letterSpacing: -2.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ].spacing(16).column(cross: CrossAxisAlignment.center).centered(),
    );
  }
}
