import 'package:editor/ui/editor/editor.view.dart';
import 'package:editor/ui/editor/widgets/modes/code.dart';
import 'package:editor/ui/editor/widgets/modes/design.dart';
import 'package:editor/ui/editor/widgets/pages/ui.dart';
import 'package:go_router/go_router.dart';

class TetaEditor {
  final String appPath;
  final String projectID;
  final String serverUrl;

  String get appFolderName => projectID;

  const TetaEditor(
    this.appPath,
    this.projectID,
    this.serverUrl,
  );

  List<RouteBase> get routes => [
        ShellRoute(
          pageBuilder: (context, state, child) => NoTransitionPage(
            child: EditorView(
              teta: this,
              child: child,
            ),
          ),
          routes: [
            GoRoute(
              path: '/project/:id',
              redirect: (context, state) =>
                  '/project/${state.pathParameters['id']!}/design',
            ),
            ShellRoute(
              routes: [
                GoRoute(
                  path: '/project/:id/design',
                  pageBuilder: (context, state) => const NoTransitionPage(
                    child: EditorModeDesign(
                      child: EditorPageUI(),
                    ),
                  ),
                ),
              ],
              pageBuilder: (context, state, child) => NoTransitionPage(
                child: child,
              ),
            ),
            ShellRoute(
              routes: [
                GoRoute(
                  path: '/project/:id/code',
                  pageBuilder: (context, state) => NoTransitionPage(
                    child: EditorModeCode(id: state.pathParameters['id']!),
                  ),
                ),
                GoRoute(
                  path: '/project/:id/code/file',
                  pageBuilder: (context, state) => NoTransitionPage(
                    child: EditorModeCode(
                      id: state.pathParameters['id']!,
                      fileRef: state.uri.queryParameters['ref'],
                      commitHash: state.uri.queryParameters['hash'],
                    ),
                  ),
                  redirect: (context, state) {
                    return null;
                  },
                ),
              ],
              pageBuilder: (context, state, child) => NoTransitionPage(
                child: child,
              ),
            ),
          ],
        ),
      ];
}
