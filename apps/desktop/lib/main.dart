import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:editor/editor.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:teta_oss/core/env/env.dart';
import 'package:teta_oss/router.dart';
import 'package:window_manager/window_manager.dart';

late final TetaEditor teta;

Future<void> main() async {
  if (!Platform.isMacOS) throw Exception('This app is only for macOS');
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationSupportDirectory();
  Hive.init(dir.path);
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(dir.path),
  );
  await Hive.openBox('teta');
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: null,
    center: null,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  final targetDir = Directory(Env.projectPath.endsWith('/')
      ? Env.projectPath.substring(0, Env.projectPath.length - 1)
      : Env.projectPath);
  teta = TetaEditor(targetDir.path, 'app');
  runApp(_App());
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      debugShowFloatingThemeButton: false,
      initial: AdaptiveThemeMode.dark,
      light: ThemeData(
        fontFamily: 'Wanted Sans',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A84FF),
          primary: const Color(0xFF0A84FF),
          surface: Colors.white,
          onSurface: Colors.black,
          inverseSurface: Colors.black,
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F1F1),
      ),
      dark: ThemeData(
        fontFamily: 'Wanted Sans',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A84FF),
          primary: const Color(0xFF0A84FF),
          surface: Colors.black,
          onSurface: Colors.white,
          inverseSurface: Colors.white,
          surfaceContainer: const Color(0xFF333333),
        ),
        scaffoldBackgroundColor: const Color(0xFF222222),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      builder: (lightTheme, darkTheme) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        title: 'Flutter Demo',
        theme: lightTheme,
        darkTheme: darkTheme,
      ),
    );
  }
}
