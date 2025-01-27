import 'package:editor/extensions/index.dart';
import 'package:editor/typedefs.dart';
import 'package:editor/ui/editor/blocs/editor.cubit.dart';
import 'package:editor/ui/editor/blocs/states/chat/chat.state.dart';
import 'package:editor/ui/editor/blocs/states/editor/editor.state.dart';
import 'package:editor/ui/editor/widgets/pages/code.dart';
import 'package:editor/ui/editor/widgets/pages/ui/chat_input.dart';
import 'package:editor/ui/editor/widgets/pages/ui/webview_controller_inh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ChatArea extends StatefulWidget {
  const ChatArea({super.key});

  @override
  State<ChatArea> createState() => _ChatState();
}

class _ChatState extends State<ChatArea> {
  FlutterRunCubit get cubit => context.read<FlutterRunCubit>();
  WebViewController get webviewController =>
      EditorWebViewController.of(context).controller;

  bool typing(AIUser user) => user.currentState == AIUserState.typing;

  void sendMessage(types.PartialText data) => context.editor.makeRequest(
        request: data.text,
        onWebViewNeedsAReload: () => webviewController.reload(),
      );

  void cancelRequest() => context.editor.stopRequest();

  @override
  Widget build(BuildContext context) {
    final chatTheme = DefaultChatTheme(
      backgroundColor: Colors.transparent,
      inputBackgroundColor: Colors.black,
      primaryColor: context.theme.primaryColor,
    );
    return BlocBuilder<FlutterRunCubit, FlutterRunState>(
      builder: (context, state) {
        final chat = state.common.chatState;

        return Chat(
          typingIndicatorOptions: TypingIndicatorOptions(
            typingUsers: [
              if (typing(chat.productManager)) chat.productManager.user,
              if (typing(chat.techLead)) chat.techLead.user,
              if (typing(chat.developer)) chat.developer.user,
              if (typing(chat.designer)) chat.designer.user,
            ],
          ),
          user: chat.user,
          messages: chat.messages.reversed.toList(),
          onSendPressed: sendMessage,
          textMessageBuilder: (message,
                  {required messageWidth, required showName}) =>
              messageBuilder(
            context,
            userID: chat.user.id,
            message: message,
          ),
          theme: chatTheme,
          customBottomWidget: ChatInput(
            state: chat.requestState == RequestState.doing
                ? ChatInputState.inProgress
                : state.maybeWhen(
                    projectCreating: (common) => ChatInputState.disable,
                    orElse: () => ChatInputState.enable,
                  ),
            cancelRequest: cancelRequest,
            sendMessage: sendMessage,
          ),
        );
      },
    )
        .decorated(BoxDecoration(
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(8),
        ))
        .padding(const EdgeInsets.only(top: 8, bottom: 8));
  }

  Widget messageBuilder(
    BuildContext context, {
    required ID userID,
    required types.TextMessage message,
  }) {
    return [
      SelectableText(
        message.text,
        style: context.theme.textTheme.bodyMedium!.copyWith(
          color: message.author.id == userID
              ? context.theme.colorScheme.onSurface
              : context.theme.colorScheme.surface,
        ),
      ),
      if (message.metadata != null && message.metadata!.containsKey('files'))
        for (final file in (message.metadata!['files'] as Map).entries)
          if (file.value == 'DELETE')
            Text('❌ ${file.key} deleted').paddingH(16).paddingV(8).decorated(
                  BoxDecoration(
                    color: context.theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
          else
            [
              SelectableText(file.key).paddingH(16).paddingV(8),
              CodeWidget(
                code: file.value,
                language: CodeLanguages.dart,
                onCodeChange: (e) {},
                enabled: false,
              ).expanded(),
            ].column().height(300).decorated(
                  BoxDecoration(
                    color: context.theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
    ].spacing(8).column().paddingAll(12);
  }
}
