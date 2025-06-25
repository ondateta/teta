import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
// import 'package:editor/editor.dart'; // TetaEditor will be instantiated differently
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:teta_oss/core/env/env.dart'; // Env.serverUrl might still be used, Env.projectPath removed
import 'package:teta_oss/core/project_management/project_service.dart'; // Import new service
import 'package:teta_oss/router.dart'; // Router will be adapted
import 'package:window_manager/window_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // For providing ProjectService

// late final TetaEditor teta; // Removed global TetaEditor instance

late final ProjectService projectService;
// Consider where serverUrl will come from. For now, let's assume it might still be from Env or a config.
// String serverUrl = Env.serverUrl; // Placeholder - decide how to get this. For now, can hardcode or use existing Env if it only contains serverUrl

Future<void> main() async {
  // if (!Platform.isMacOS) throw Exception('This app is only for macOS'); // Retaining for now, can be revisited
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationSupportDirectory();
  Hive.init(dir.path);
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(dir.path),
  );
  await Hive.openBox('teta'); // This might be generic, or specific to Teta's old single-project model. Review later.

  projectService = ProjectService(); // Instantiate ProjectService

  if (Platform.isMacOS) { // Window manager specific code for macOS
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: null, // null means use last saved size or default
      center: null, // null means let OS decide or use last saved position
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Removed TetaEditor instantiation from here
  // final targetDir = Directory(Env.projectPath.endsWith('/')
  //     ? Env.projectPath.substring(0, Env.projectPath.length - 1)
  //     : Env.projectPath);
  // teta = TetaEditor(
  //   targetDir.path,
  //   'app', // This 'app' projectID was hardcoded, now project IDs will be dynamic
  //   Env.serverUrl,
  // );

  runApp(_App());
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    // Provide ProjectService to the widget tree if needed by router or initial screens
    return RepositoryProvider<ProjectService>(
      create: (context) => projectService,
      child: AdaptiveTheme(
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
        builder: (lightTheme, darkTheme) {
          // AppRouter will be initialized here or its config passed to MaterialApp.router
          // For now, the old `router` is still used but will be adapted.
          final appRouter = AppRouter(projectService: projectService);
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: appRouter.router, // Use the new AppRouter instance
            title: 'FusionForge', // Updated title
            theme: lightTheme,
            darkTheme: darkTheme,
          );
        }
      ),
    );
  }
}
