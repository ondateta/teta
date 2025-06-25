import 'dart:convert';
import 'package:editor/ui/editor/blocs/project_context_cubit.dart';
import 'package:editor/ui/editor/blocs/states/editor/editor.state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:editor/core/constants.dart'; // For logger
import 'package:editor/entities/project.dart'; // Temporary project entity

// Placeholder for the Expo IDE URL. This should be configurable.
// For local development of the Expo IDE, it might be http://localhost:3000 or similar.
const String _defaultExpoIdeUrl = 'http://localhost:3001'; // Example port for local Expo IDE dev

class EditorModeExpo extends StatefulWidget {
  const EditorModeExpo({super.key});

  @override
  State<EditorModeExpo> createState() => _EditorModeExpoState();
}

class _EditorModeExpoState extends State<EditorModeExpo> {
  late final WebViewController _webViewController;
  bool _isWebViewReady = false;
  String _currentExpoIdeUrl = _defaultExpoIdeUrl;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<ProjectContextCubit>();
    final projectState = cubit.state.common;

    _currentExpoIdeUrl = _buildExpoIdeUrl(projectState.projectID, Theme.of(context).brightness);

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000)) // Transparent background
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            logger.i('Expo IDE WebView loading progress: $progress%');
          },
          onPageStarted: (String url) {
            logger.i('Expo IDE WebView page started loading: $url');
            setState(() {
              _isWebViewReady = false;
            });
          },
          onPageFinished: (String url) {
            logger.i('Expo IDE WebView page finished loading: $url');
            setState(() {
              _isWebViewReady = true;
            });
            // Optionally, call a JS function in the IDE to let it know it's embedded
            _webViewController.runJavaScript('window.isEmbeddedInFusionForge = true;');
            _webViewController.runJavaScript('console.log("FusionForge Host: Expo IDE Loaded.");');
          },
          onWebResourceError: (WebResourceError error) {
            logger.e(
              'Expo IDE WebView Error: ${error.description}',
              error: error.errorCode,
              stackTrace: StackTrace.current,
            );
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow navigation only within the Expo IDE's domain or subdomains.
            // This needs to be robust. For now, a simple check.
            if (request.url.startsWith('http://localhost:') || request.url.startsWith('https://localhost:')) {
                 // Allow localhost for local dev of the IDE itself
                return NavigationDecision.navigate;
            }
            // TODO: Make this configurable based on the actual deployed Expo IDE URL
            // if (request.url.startsWith(_currentExpoIdeUrl)) {
            //   return NavigationDecision.navigate;
            // }
            // logger.w('Expo IDE WebView: Navigation to ${request.url} prevented.');
            // return NavigationDecision.prevent;
            return NavigationDecision.navigate; // Temporarily allow all for easier dev
          },
        ),
      )
      ..addJavaScriptChannel(
        'ExpoIDEToFusionForge', // Channel for messages from Expo IDE to Flutter
        onMessageReceived: (JavaScriptMessage message) {
          logger.i('Message from Expo IDE: ${message.message}');
          // Handle messages: e.g., save requests, errors, UI events
          // final data = jsonDecode(message.message);
          // if (data['type'] == 'requestSave') {
          //   cubit.saveCodeFromExpoIDE(data['files']);
          // }
        },
      )
      ..loadRequest(Uri.parse(_currentExpoIdeUrl));
  }

  String _buildExpoIdeUrl(String projectId, Brightness brightness) {
    // This should eventually come from a config or settings
    final baseUrl = Uri.parse(_defaultExpoIdeUrl);
    return baseUrl.replace(queryParameters: {
      'projectId': projectId,
      'theme': brightness == Brightness.dark ? 'dark' : 'light',
      // Add any other parameters your Expo IDE needs
    }).toString();
  }

  void _refreshExpoIDEPreview() {
    if (_isWebViewReady) {
      _webViewController.runJavaScript(
          'if(window.fusionForgeExpoIDE && window.fusionForgeExpoIDE.refreshPreviewAfterChange) { window.fusionForgeExpoIDE.refreshPreviewAfterChange(); } else { console.warn("FusionForge: refreshPreviewAfterChange not found on window.fusionForgeExpoIDE"); }');
    } else {
      logger.w('Expo IDE WebView not ready, cannot refresh preview.');
    }
  }

  void _sendCodeToExpoIDE(Map<String, String> codeFiles) {
     if (_isWebViewReady) {
      final String codeFilesJson = jsonEncode(codeFiles);
      // Escape the JSON string properly for JavaScript
      final String escapedJson = codeFilesJson.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
      _webViewController.runJavaScript(
          'if(window.fusionForgeExpoIDE && window.fusionForgeExpoIDE.loadCode) { window.fusionForgeExpoIDE.loadCode(\'$escapedJson\'); } else { console.warn("FusionForge: loadCode not found on window.fusionForgeExpoIDE"); }');
    } else {
      logger.w('Expo IDE WebView not ready, cannot send code.');
    }
  }


  @override
  Widget build(BuildContext context) {
    return BlocListener<ProjectContextCubit, ProjectContextState>(
      listener: (context, state) {
        if (state.mapOrNull(filesUpdated: (_) => true) ?? false) {
          if (state.common.sdkType == ProjectSDK.expo) {
            logger.i('Project files updated for Expo project, signaling Expo IDE to refresh.');
            // This assumes the AI has written files and now the IDE needs to know.
            // The actual file content might need to be sent if the IDE doesn't watch the disk.
            // For now, just a generic refresh signal.
            _refreshExpoIDEPreview();
            // TODO: If your Expo IDE needs the new code explicitly sent, call _sendCodeToExpoIDE here
            // with the relevant file contents from the cubit or a service.
          }
        }
        // Potentially handle other states, e.g., if project changes, reload the URL.
        final currentProjectState = state.common;
        final newUrl = _buildExpoIdeUrl(currentProjectState.projectID, Theme.of(context).brightness);
        if (newUrl != _currentExpoIdeUrl && _isWebViewReady) { // Check if URL needs update, e.g. theme change
            logger.i("Expo IDE URL changed or needs update (e.g. theme). Reloading: $newUrl");
            _currentExpoIdeUrl = newUrl;
            _webViewController.loadRequest(Uri.parse(_currentExpoIdeUrl));
        }
      },
      child: Column(
        children: [
          // TODO: Add a simple control bar for the Expo IDE WebView (Refresh, DevTools)
          // For now, just the WebView
          Expanded(
            child: _isWebViewReady
                ? WebViewWidget(controller: _webViewController)
                : const Center(child: CircularProgressIndicator(semanticsLabel: "Loading Expo IDE...",)),
          ),
        ],
      ),
    );
  }
}
