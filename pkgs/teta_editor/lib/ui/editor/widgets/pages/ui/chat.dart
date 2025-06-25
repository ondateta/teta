import 'package:editor/extensions/index.dart';
import 'package:editor/typedefs.dart';
import 'package:editor/ui/editor/blocs/project_context_cubit.dart'; // Updated import
import 'package:editor/ui/editor/blocs/states/chat/chat.state.dart';
import 'package:editor/ui/editor/blocs/states/editor/editor.state.dart'; // Updated import (ProjectContextState)
import 'package:editor/ui/editor/widgets/pages/code.dart';
import 'package:editor/ui/editor/widgets/pages/ui/chat_input.dart';
import 'package:editor/ui/editor/widgets/pages/ui/webview_controller_inh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:editor/entities/project.dart'; // Temporary project entity import

class ChatArea extends StatefulWidget {
  const ChatArea({super.key});

  @override
  State<ChatArea> createState() => _ChatState();
}

class _ChatState extends State<ChatArea> {
  ProjectContextCubit get cubit => context.read<ProjectContextCubit>(); // Updated Cubit type
  WebViewController get webviewController =>
      EditorWebViewController.of(context).controller;

  bool typing(AIUser user) => user.currentState == AIUserState.typing;

  void sendMessage(types.PartialText data) {
    // final currentSdkType = cubit.state.common.sdkType; // No longer needed here
    cubit.makeRequest(
      request: data.text,
      // onWebViewNeedsAReload callback is removed.
      // Reload/refresh is now handled by WebViewArea/EditorModeExpo listening to filesUpdated state.
    );
  }

  void cancelRequest() => cubit.stopRequest(); // cubit is now ProjectContextCubit

  @override
  Widget build(BuildContext context) {
    final chatTheme = DefaultChatTheme(
      backgroundColor: Colors.transparent,
      inputBackgroundColor: Colors.black, // Consider theming this based on AdaptiveTheme
      primaryColor: context.theme.primaryColor,
      messageInsetsHorizontal: 12,
      messageInsetsVertical: 12,
      sendButtonIcon: const Icon(Icons.send, color: Colors.white),
      inputTextStyle: context.theme.textTheme.bodyMedium!.copyWith(color: Colors.white),
      inputBorderRadius: BorderRadius.circular(12),

    );
    return BlocBuilder<ProjectContextCubit, ProjectContextState>( // Updated Cubit/State
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
            sdkType: state.common.sdkType, // Pass SDK type for CodeWidget language
          ),
          theme: chatTheme,
          customBottomWidget: ChatInput(
            state: chat.requestState == RequestState.doing
                ? ChatInputState.inProgress
                : state.maybeWhen( // state is ProjectContextState
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
          color: const Color(0xFF333333), // Consider AdaptiveTheme for this
          borderRadius: BorderRadius.circular(8),
        ))
        .padding(const EdgeInsets.only(top: 8, bottom: 8));
  }

  Widget messageBuilder(
    BuildContext context, {
    required ID userID,
    required types.TextMessage message,
    required ProjectSDK sdkType, // Added to determine CodeWidget language
  }) {
    final codeLanguage = (sdkType == ProjectSDK.flutter) ? CodeLanguages.dart : CodeLanguages.javascript;

    return Container( // Added a container for better padding and theming
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: message.author.id == userID
            ? context.theme.colorScheme.primary.withOpacity(0.1)
            : context.theme.colorScheme.surfaceVariant.withOpacity(0.1), // Differentiate user/AI messages
        borderRadius: BorderRadius.circular(12),
      ),
      child: [
        SelectableText(
          message.text,
          style: context.theme.textTheme.bodyMedium!.copyWith(
            color: context.theme.colorScheme.onSurface, // Use onSurface for better contrast
          ),
        ),
        if (message.metadata != null && message.metadata!.containsKey('files'))
          for (final file in (message.metadata!['files'] as Map).entries)
            Container( // Wrap each file display in a container for margin
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.surface, // Use surface for code blocks
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.theme.colorScheme.outlineVariant)
              ),
              child: [
                if (file.value == 'DELETE')
                  Text('❌ ${file.key} deleted', style: TextStyle(color: context.theme.colorScheme.error))
                else ...[
                    SelectableText(file.key, style: context.theme.textTheme.labelSmall?.copyWith(color: context.theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    CodeWidget(
                      code: file.value,
                      language: codeLanguage, // Use dynamic language
                      onCodeChange: (e) {}, // Read-only
                      enabled: false,
                    ).height(300).expanded(), // Ensure CodeWidget can expand
                ]
              ].column(crossAxisAlignment: CrossAxisAlignment.start),
            )
      ].spacing(8).column(crossAxisAlignment: CrossAxisAlignment.start), // Align content left
    );
  }
}
