import 'package:editor/extensions/index.dart';
import 'package:editor/ui/editor/widgets/pages/ui/chat.dart';
import 'package:editor/ui/editor/widgets/pages/ui/console.dart';
import 'package:editor/ui/editor/widgets/pages/ui/webview.dart';
import 'package:editor/ui/editor/widgets/pages/ui/webview_controller_inh.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EditorPageUI extends StatelessWidget {
  const EditorPageUI({super.key});

  static final MultiSplitViewController _controller = MultiSplitViewController(
    areas: [
      Area(data: 'chat', flex: 1),
      Area(data: 'webview', flex: 2),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EditorWebViewController(
        controller: WebViewController(),
        child: MultiSplitView(
          controller: _controller,
          builder: (context, area) {
            switch (area.data) {
              case 'chat':
                return const ChatArea();
              case 'webview':
                return const WebViewArea();
              default:
                return nil;
            }
          },
        ),
      ),
      endDrawer: const Console(),
    );
  }
}
