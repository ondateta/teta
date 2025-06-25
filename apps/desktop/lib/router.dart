import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:editor/editor.dart';
import 'package:teta_oss/core/project_management/project_model.dart';
import 'package:teta_oss/core/project_management/project_service.dart';
import 'package:teta_oss/presentation/screens/project_selection_screen.dart';
import 'package:teta_oss/presentation/screens/create_project_screen.dart';
import 'package:teta_oss/core/env/env.dart';
import 'package:pkgs/teta_editor/lib/ui/editor/blocs/project_context_cubit.dart';
import 'package:pkgs/teta_editor/lib/entities/project.dart' as editor_project_entities;
// Import new Expo mode and existing Flutter modes/pages
import 'package:pkgs/teta_editor/lib/ui/editor/widgets/modes/design.dart';
import 'package:pkgs/teta_editor/lib/ui/editor/widgets/modes/code.dart';
import 'package:pkgs/teta_editor/lib/ui/editor/widgets/modes/expo.dart';
import 'package:pkgs/teta_editor/lib/ui/editor/widgets/pages/ui.dart'; // For EditorPageUI (Flutter design content)
// EditorView is already imported via editor/editor.dart


// EditorShellScreen now provides ProjectContextCubit
class EditorShellScreen extends StatefulWidget {
  final String projectId;
  final Widget child;
  final ProjectService projectService;

  const EditorShellScreen({
    super.key,
    required this.projectId,
    required this.child,
    required this.projectService,
  });

  @override
  State<EditorShellScreen> createState() => _EditorShellScreenState();
}

class _EditorShellScreenState extends State<EditorShellScreen> {
  late Future<Project?> _projectFuture;
  ProjectContextCubit? _projectContextCubit;

  @override
  void initState() {
    super.initState();
    _projectFuture = _loadProjectAndInitCubit();
  }

  Future<Project?> _loadProjectAndInitCubit() async {
    final project = await widget.projectService.getProjectById(widget.projectId);
    if (project != null) {
      final serverUrl = Env.serverUrl;

      final editorProject = editor_project_entities.Project(
        id: project.id,
        name: project.name,
        path: project.path,
        sdkType: project.sdkType == ProjectSDK.flutter
                   ? editor_project_entities.ProjectSDK.flutter
                   : editor_project_entities.ProjectSDK.expo,
        createdAt: project.createdAt,
        lastOpenedAt: project.lastOpenedAt,
      );

      _projectContextCubit = ProjectContextCubit(editorProject, serverUrl)..init();
    }
    return project;
  }

  @override
  void dispose() {
    _projectContextCubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Project?>(
      future: _projectFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null || _projectContextCubit == null) {
          return Scaffold(body: Center(child: Text('Error loading project or initializing context: ${snapshot.error}')));
        }

        return BlocProvider<ProjectContextCubit>.value(
          value: _projectContextCubit!,
          child: widget.child,
        );
      },
    );
  }
}


class AppRouter {
  final ProjectService projectService;
  late final GoRouter router;

  AppRouter({required this.projectService}) {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const ProjectSelectionScreen(),
        ),
        GoRoute(
          path: '/create-project',
          builder: (context, state) => const CreateProjectScreen(),
        ),
        ShellRoute( // Outer Shell - Provides ProjectContextCubit via EditorShellScreen
          builder: (BuildContext context, GoRouterState state, Widget child) {
            final projectId = state.pathParameters['projectId']!;
            return EditorShellScreen(
              projectId: projectId,
              projectService: projectService,
              child: child,
            );
          },
          routes: <RouteBase>[
            ShellRoute( // Inner Shell - Wraps content with EditorView (the general editor scaffold)
              pageBuilder: (context, state, child) {
                return NoTransitionPage(child: EditorView(child: child));
              },
              routes: [
                GoRoute(
                  name: 'flutter-design',
                  path: '/project/:projectId/flutter/design',
                  pageBuilder: (context, state) => const NoTransitionPage(
                    // EditorPageUI is the content for Flutter's design mode
                    child: EditorModeDesign(child: EditorPageUI()),
                  ),
                ),
                GoRoute(
                  name: 'flutter-code',
                  path: '/project/:projectId/flutter/code',
                  pageBuilder: (context, state) => NoTransitionPage(
                    child: EditorModeCode(
                      id: state.pathParameters['projectId']!,
                      fileRef: state.uri.queryParameters['ref'],
                      commitHash: state.uri.queryParameters['hash'],
                    ),
                  ),
                ),
                GoRoute(
                  name: 'flutter-code-file',
                  path: '/project/:projectId/flutter/code/file',
                  pageBuilder: (context, state) => NoTransitionPage(
                     child: EditorModeCode(
                      id: state.pathParameters['projectId']!,
                      fileRef: state.uri.queryParameters['ref'],
                      commitHash: state.uri.queryParameters['hash'],
                    ),
                  ),
                ),
                GoRoute(
                  name: 'expo-ide',
                  path: '/project/:projectId/expo/ide',
                  pageBuilder: (context, state) => const NoTransitionPage(
                    child: EditorModeExpo(), // New mode for Expo
                  ),
                ),
              ]
            ),
             GoRoute( // Catch-all for /project/:projectId and redirect
                path: '/project/:projectId',
                redirect: (context, state) async {
                  final projectId = state.pathParameters['projectId']!;
                  // Ensure projectService is accessible, e.g. passed to AppRouter or globally
                  final project = await projectService.getProjectById(projectId);
                  if (project != null) {
                    if (project.sdkType == ProjectSDK.flutter) {
                      return '/project/$projectId/flutter/design';
                    } else {
                      return '/project/$projectId/expo/ide';
                    }
                  }
                  return '/'; // Fallback
                },
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text('Page not found: ${state.error}'),
        ),
      ),
    );
  }
}

// _getTetaEditor helper is removed as it's no longer the primary way to get routes.
// The routes are now explicitly defined in AppRouter, and EditorShellScreen provides context.
