import 'package:editor/ui/ds/constants/responsive_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';

T responsiveValue<T>(
  BuildContext context, {
  T Function()? mobile,
  T Function()? tablet,
  T Function()? laptop,
  T Function()? desktop,
  T Function()? orElse,
}) {
  final screenSize = MediaQuery.sizeOf(context);
  if (screenSize.width <= ResponsiveConstants.phoneSize) {
    return _getV('mobile', mobile, orElse);
  }
  if (screenSize.width <= ResponsiveConstants.tabletSize) {
    return _getV('tablet', tablet, orElse);
  }
  if (screenSize.width <= ResponsiveConstants.laptop) {
    return _getV('laptop', laptop, orElse);
  }
  return _getV('desktop', desktop, orElse);
}

T _getV<T>(String name, T Function()? value, T Function()? orElse) {
  assert(
    (value == null && orElse != null) || value != null,
    '$name or orElse must be provided',
  );
  return value?.call() ?? orElse?.call() as T;
}

T platformValue<T>(
  BuildContext context, {
  required T Function() orElse,
  T Function()? web,
  T Function()? ios,
  T Function()? android,
  T Function()? windows,
  T Function()? macos,
}) {
  if (kIsWeb) {
    return web?.call() ?? orElse.call();
  }
  if (Platform.isIOS) {
    return ios?.call() ?? orElse.call();
  }
  if (Platform.isAndroid) {
    return android?.call() ?? orElse.call();
  }
  if (Platform.isWindows) {
    return windows?.call() ?? orElse.call();
  }
  if (Platform.isMacOS) {
    return macos?.call() ?? orElse.call();
  }
  return orElse.call();
}

T orientationValue<T>(
  BuildContext context, {
  required T Function() portrait,
  required T Function() landscape,
}) {
  final orientation = MediaQuery.orientationOf(context);
  if (orientation == Orientation.portrait) {
    return portrait.call();
  }
  return landscape.call();
}

T? conditionalValue<T>({
  required bool condition,
  T Function()? ifTrue,
  T Function()? ifFalse,
}) {
  if (condition) {
    return ifTrue?.call();
  }
  return ifFalse?.call();
}
