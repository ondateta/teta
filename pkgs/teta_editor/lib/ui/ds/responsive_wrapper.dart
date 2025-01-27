import 'package:flutter/material.dart';
import 'responsive_values.dart';

class ResponsiveWrapper extends StatelessWidget {
  const ResponsiveWrapper({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return responsiveValue(
      context,
      mobile: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: child,
      ),
      tablet: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: child,
      ),
      orElse: () => Center(
        child: SizedBox(
          width: 1000,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ),
      ),
    );
  }
}
