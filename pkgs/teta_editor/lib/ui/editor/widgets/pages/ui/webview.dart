import 'package:editor/core/constants.dart';
import 'package:editor/extensions/index.dart';
import 'package:editor/ui/editor/blocs/editor.cubit.dart';
import 'package:editor/ui/editor/blocs/states/editor/editor.state.dart';
import 'package:editor/ui/editor/widgets/pages/ui/webview_controller_inh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:open_file_macos/open_file_macos.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewArea extends StatefulWidget {
  const WebViewArea({super.key});

  @override
  State<WebViewArea> createState() => _WebViewState();
}

class _WebViewState extends State<WebViewArea> {
  int? currentPort;
  final TextEditingController controller = TextEditingController();

  FlutterRunCubit get cubit => context.read<FlutterRunCubit>();

  void update(int port, String params) {
    currentPort = port;
    EditorWebViewController.of(context).controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onUrlChange: (change) {
            logger.i('onPageStarted: ${change.url}');
            controller.text = change.url!.split('http://localhost:$port/').last;
            setState(() {});
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onHttpError: (HttpResponseError error) {},
          onWebResourceError: (WebResourceError error) {},
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

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        ].row(cross: CrossAxisAlignment.center),
        CupertinoTextField(
          controller: controller,
          padding: const EdgeInsets.all(0),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              'localhost/',
              style: context.bodyMedium.copyWith(color: Colors.black),
            ),
          ),
          style: context.bodyMedium.copyWith(color: Colors.black),
          onSubmitted: (e) {
            update(currentPort!, e);
          },
        ).height(40).expanded(),
        [
          IconButton(
            tooltip: 'Rebuild',
            onPressed: () async {
              context.read<FlutterRunCubit>().reloadProcess().then((e) async {
                await Future.delayed(const Duration(milliseconds: 300));
                await EditorWebViewController.of(context).controller.reload();
              });
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
                context.projectAppPath,
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
          BlocBuilder<FlutterRunCubit, FlutterRunState>(
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
      BlocListener<FlutterRunCubit, FlutterRunState>(
        listenWhen: (previous, current) =>
            current.maybeMap(running: (_) => true, orElse: () => false) &&
            previous.maybeMap(
              running: (_) => false,
              orElse: () => true,
            ),
        listener: (context, state) {
          state.whenOrNull(running: (common, port) {
            update(port, '');
          });
        },
        child: BlocBuilder<FlutterRunCubit, FlutterRunState>(
          buildWhen: (previous, current) =>
              current.runtimeType != previous.runtimeType,
          builder: (context, state) {
            return state.mapOrNull(
              projectCreating: (_) => projectCreating(context),
              notStarted: (_) => notStarted(context),
              starting: (_) => starting(context),
              exceptionProjectNotRunned: (e) =>
                  expectionNotRunned(context, e.errorMessage),
              running: (_) {
                return WebViewWidget(
                  controller: EditorWebViewController.of(context).controller,
                ).clippedRRect(BorderRadius.circular(8));
              },
            )!;
          },
        ),
      ).expanded(),
    ]
        .column()
        .padding(const EdgeInsets.only(top: 8, bottom: 8, right: 8))
        .expanded();
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
    return const Center(
      child: Text('Press the button to run the code'),
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
        const Text('Building the project...'),
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
            context.read<FlutterRunCubit>().runApp();
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
  const _TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
