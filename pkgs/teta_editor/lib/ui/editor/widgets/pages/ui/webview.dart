import 'package:editor/core/constants.dart';
import 'package:editor/extensions/index.dart';
import 'package:editor/ui/editor/blocs/project_context_cubit.dart'; // Updated import
import 'package:editor/ui/editor/blocs/states/editor/editor.state.dart'; // Updated import (ProjectContextState)
import 'package:editor/ui/editor/widgets/pages/ui/webview_controller_inh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:open_file_macos/open_file_macos.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:editor/entities/project.dart'; // Temporary project entity import

class WebViewArea extends StatefulWidget {
  const WebViewArea({super.key});

  @override
  State<WebViewArea> createState() => _WebViewState();
}

class _WebViewState extends State<WebViewArea> {
  int? currentPort;
  String? currentExpoIdeUrl; // For Expo IDE URL
  final TextEditingController controller = TextEditingController();

  ProjectContextCubit get cubit => context.read<ProjectContextCubit>(); // Updated Cubit type

  // Updated to handle both Flutter web and Expo IDE URLs
  void updatePreview(ProjectContextState state) {
    final commonState = state.common;
    if (commonState.sdkType == ProjectSDK.flutter) {
      state.whenOrNull(running: (common, port) {
        if (port != 0 && (currentPort != port || currentExpoIdeUrl != null)) { // Check if port changed or switched from Expo
          currentPort = port;
          currentExpoIdeUrl = null; // Clear Expo URL
          final initialFlutterPath = ''; // Or load from some persisted state for this project
          controller.text = initialFlutterPath;
          _loadFlutterUrl(port, initialFlutterPath);
        } else if (port == 0 && currentPort != 0) { // Stopped or not yet running
            // Potentially clear the webview or show a placeholder
        }
      });
    } else if (commonState.sdkType == ProjectSDK.expo) {
      // Construct the Expo IDE URL (this will be dynamic in a real setup)
      // For MVP, it could be a fixed URL or configured.
      // Example: "https://your-fusionforge-expo-ide.com/?projectId=${commonState.projectID}"
      // This URL construction will be refined in Step 3.
      final expoIdeUrl = "http://localhost:3000/?projectId=${commonState.projectID}&theme=${Theme.of(context).brightness.name}"; // Placeholder
      if (currentExpoIdeUrl != expoIdeUrl || currentPort != null) {
        currentExpoIdeUrl = expoIdeUrl;
        currentPort = null; // Clear Flutter port
        controller.text = expoIdeUrl; // Display the Expo IDE URL
        _loadGenericUrl(expoIdeUrl);
      }
    }
  }

  void _loadFlutterUrl(int port, String params) {
    EditorWebViewController.of(context).controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onUrlChange: (change) {
            logger.i('Flutter URL change: ${change.url}');
            if (change.url != null && change.url!.startsWith('http://localhost:$port/')) {
              controller.text = change.url!.split('http://localhost:$port/').last;
            }
            setState(() {});
          },
          onPageFinished: (String url) {},
          onNavigationRequest: (NavigationRequest request) {
            if (!request.url.startsWith('http://localhost:')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('http://localhost:$port/$params'));
  }

  void _loadGenericUrl(String url) { // For Expo IDE
    EditorWebViewController.of(context).controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // Crucial for JS-heavy IDEs
       // Consider if a different user agent is needed for Expo IDE, or none.
      ..setUserAgent(null) // Default user agent
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onUrlChange: (change) {
            logger.i('Expo IDE URL change: ${change.url}');
            controller.text = change.url ?? '';
             setState(() {});
          },
          onPageFinished: (String url) {
            // Potentially setup JS channels here if this is the Expo IDE loading
            _setupJavascriptChannelsForExpo();
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow navigation within the Expo IDE's domain or subdomains
            // This needs to be configured based on your Expo IDE's URL structure
            // For now, allow all for simplicity during development of this part.
            // if (!request.url.startsWith(currentExpoIdeUrl!)) {
            //   return NavigationDecision.prevent;
            // }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  void _setupJavascriptChannelsForExpo() {
    if (cubit.state.common.sdkType == ProjectSDK.expo) {
      logger.i("Setting up JS channels for Expo IDE");
      EditorWebViewController.of(context).controller
        ..addJavaScriptChannel(
          'FusionForgeHost', // Channel name Expo IDE will use
          onMessageReceived: (JavaScriptMessage message) {
            logger.i('Message from Expo IDE: ${message.message}');
            // Handle messages from Expo IDE (e.g., save requests, errors)
            // Example: if (message.message == "saveCode") cubit.saveExpoCode(...);
          },
        );
    }
  }


  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSdkType = cubit.state.common.sdkType;

    return [
      <Widget>[
        [
          IconButton(
            tooltip: 'Back',
            onPressed: () async {
              EditorWebViewController.of(context).controller.goBack();
            },
            icon: const Icon(
              LucideIcons.arrowLeft,
              size: 20,
            ),
          ),
          IconButton(
            onPressed: () {
              EditorWebViewController.of(context).controller.reload();
            },
            icon: const Icon(
              CupertinoIcons.refresh,
              size: 20,
            ),
          ),
        ].row(crossAxisAlignment: CrossAxisAlignment.center),
        CupertinoTextField(
          controller: controller,
          padding: const EdgeInsets.all(0),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
             currentSdkType == ProjectSDK.flutter ? 'localhost:${currentPort ?? ""}/' : '', // Only show for Flutter
              style: context.bodyMedium.copyWith(color: Colors.black),
            ),
          ),
          style: context.bodyMedium.copyWith(color: Colors.black),
          onSubmitted: (e) {
            if (currentSdkType == ProjectSDK.flutter && currentPort != null) {
              _loadFlutterUrl(currentPort!, e);
            } else if (currentSdkType == ProjectSDK.expo && currentExpoIdeUrl != null) {
              // Potentially navigate within Expo IDE if it supports URL changes,
              // or this field might be read-only for Expo.
              // For now, let's assume it might try to load if user changes URL.
              _loadGenericUrl(e);
            }
          },
        ).height(40).expanded(),
        [
          IconButton(
            tooltip: 'Rebuild/Refresh',
            onPressed: () async {
              if (currentSdkType == ProjectSDK.flutter) {
                cubit.reloadProcess().then((e) async {
                  await Future.delayed(const Duration(milliseconds: 300));
                  await EditorWebViewController.of(context).controller.reload();
                });
              } else { // Expo
                // Send command to Expo IDE to refresh its preview via JSChannel
                EditorWebViewController.of(context).controller.runJavaScript(
                  'if(window.fusionForgeExpoIDE && window.fusionForgeExpoIDE.refreshPreview) { window.fusionForgeExpoIDE.refreshPreview(); } else { console.error("Expo IDE refresh function not found"); }'
                );
              }
            },
            icon: const Icon(
              LucideIcons.bolt,
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'Open in Finder',
            onPressed: () async {
              final openFileMacosPlugin = OpenFileMacos();
              await openFileMacosPlugin.open(
                cubit.state.common.projectAppPath, // Use cubit's path
                viewInFinder: true,
              );
            },
            icon: const Icon(
              LucideIcons.folderInput,
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'Terminal',
            onPressed: () async {
              Scaffold.of(context).openEndDrawer();
            },
            icon: const Icon(
              LucideIcons.terminal,
              size: 20,
            ),
          ),
          BlocBuilder<ProjectContextCubit, ProjectContextState>( // Updated Cubit/State
            builder: (context, state) {
              return IconButton(
                tooltip: 'Errors & Warnings',
                onPressed: () async {
                  Scaffold.of(context).openEndDrawer();
                },
                icon: [
                  Badge(
                    isLabelVisible:
                        state.common.analyzerState.errors.isNotEmpty,
                    backgroundColor: context.theme.colorScheme.inverseSurface,
                    label: Text(
                      state.common.analyzerState.errors.length.toString(),
                      style: context.labelSmall
                          .copyWith(color: context.theme.colorScheme.surface),
                    ),
                    child: const Icon(
                      LucideIcons.octagonX,
                      size: 20,
                      color: Colors.red,
                    ),
                  ),
                  Badge(
                    isLabelVisible:
                        state.common.analyzerState.warnings.isNotEmpty,
                    backgroundColor: context.theme.colorScheme.inverseSurface,
                    label: Text(
                      state.common.analyzerState.warnings.length.toString(),
                      style: context.labelSmall
                          .copyWith(color: context.theme.colorScheme.surface),
                    ),
                    child: const Icon(
                      LucideIcons.messageSquareWarning,
                      size: 20,
                      color: Colors.yellow,
                    ),
                  ),
                ].spacing(8).row(),
              );
            },
          ),
        ].row(),
      ]
          .spacing(8)
          .row(
            cross: CrossAxisAlignment.center,
            size: MainAxisSize.max,
          )
          .paddingAll(4)
          .paddingH(4)
          .decorated(
            BoxDecoration(
              color: context.theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      8.gap,
      BlocListener<ProjectContextCubit, ProjectContextState>(
         listener: (context, state) {
          // This listener will now drive URL updates for both Flutter and Expo
          updatePreview(state);

          // Listen for filesUpdated state to reload Flutter preview
          state.mapOrNull(filesUpdated: (filesUpdatedState) {
            if (filesUpdatedState.common.sdkType == ProjectSDK.flutter) {
              logger.i('Flutter project files updated, reloading WebView for Flutter preview.');
              EditorWebViewController.of(context).controller.reload();
            }
          });
        },
        child: BlocBuilder<ProjectContextCubit, ProjectContextState>(
          buildWhen: (previous, current) =>
              current.runtimeType != previous.runtimeType ||
              (current.mapOrNull(running: (r) => r.common.sdkType) != previous.mapOrNull(running: (r) => r.common.sdkType)) ||
              (current.runtimeType is _FilesUpdated && previous.runtimeType != current.runtimeType), // Rebuild if filesUpdated
          builder: (context, state) {
            // Handle filesUpdated state to ensure UI doesn't get stuck if it was the last state
            if (state is _FilesUpdated) {
              // Fallback to a running or notStarted view after filesUpdated
              // This assumes filesUpdated is transient and should resolve to another visual state.
              // For simplicity, we can just show the WebViewWidget part from the 'running' state.
              // Or, better, make filesUpdated not a primary view state but an event.
              // For now, let's assume it should show the webview.
              if (cubit.state.common.sdkType == ProjectSDK.flutter && currentPort != null) {
                 return WebViewWidget(
                  controller: EditorWebViewController.of(context).controller,
                ).clippedRRect(BorderRadius.circular(8));
              } else if (cubit.state.common.sdkType == ProjectSDK.expo && currentExpoIdeUrl != null) {
                 return WebViewWidget(
                  controller: EditorWebViewController.of(context).controller,
                ).clippedRRect(BorderRadius.circular(8));
              }
              // If not running, show notStarted or loading.
              // This part needs care. filesUpdated should ideally be an event, not a view state.
              // For now, let's default to showing the WebView if possible, or notStarted.
               return notStarted(context); // Fallback if not running
            }

            return state.mapOrNull(
              projectCreating: (_) => projectCreating(context),
              notStarted: (_) => notStarted(context),
              starting: (_) => starting(context),
              exceptionProjectNotRunned: (e) =>
                  expectionNotRunned(context, e.errorMessage),
              running: (runningState) { // runningState now has common.sdkType
                // WebViewWidget is always used, but its content URL is determined by updatePreview
                return WebViewWidget(
                  controller: EditorWebViewController.of(context).controller,
                ).clippedRRect(BorderRadius.circular(8));
              },
            )!;
          },
        ),
      ).expanded(),
    ].column().padding(const EdgeInsets.only(top: 8, bottom: 8, right: 8));
  }

  Widget projectCreating(BuildContext context) {
    return Center(
      child: [
        const CircularProgressIndicator(),
        const Text('Initializing project...'),
      ].column(cross: CrossAxisAlignment.center),
    ).decorated(
      BoxDecoration(
        color: context.theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget notStarted(BuildContext context) {
    final cubit = context.read<ProjectContextCubit>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Project not running. Press play to start.'),
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 48),
            onPressed: () {
              cubit.runOrReload();
            },
          ),
        ],
      ),
    ).decorated(
      BoxDecoration(
        color: context.theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget starting(BuildContext context) {
    return Center(
      child: [
        const CircularProgressIndicator(),
        Text('Building the ${cubit.state.common.sdkType.name} project...'),
      ].column(cross: CrossAxisAlignment.center),
    ).decorated(
      BoxDecoration(
        color: context.theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget expectionNotRunned(BuildContext context, String errorMessage) {
    return Center(
      child: [
        Text(errorMessage),
        ElevatedButton(
          onPressed: () {
            context.read<ProjectContextCubit>().runApp(); // Updated Cubit
          },
          child: const Text('Retry'),
        ),
      ].column(cross: CrossAxisAlignment.center),
    ).decorated(
      BoxDecoration(
        color: context.theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
