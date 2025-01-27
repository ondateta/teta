import 'package:editor/extensions/index.dart';
import 'package:editor/ui/editor/blocs/editor.cubit.dart';
import 'package:editor/ui/editor/blocs/states/chat/chat.state.dart';
import 'package:editor/ui/editor/blocs/states/editor/editor.state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum ChatInputState {
  enable,
  disable,
  inProgress,
}

class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.state,
    required this.sendMessage,
    required this.cancelRequest,
  });

  final ChatInputState state;
  final Function(PartialText) sendMessage;
  final Function() cancelRequest;

  @override
  State<ChatInput> createState() => _InputState();
}

class _InputState extends State<ChatInput> {
  late final TextEditingController _textController;
  late final FocusNode _inputFocusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController()
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _inputFocusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event.physicalKey == PhysicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.physicalKeysPressed.any(
              (el) => <PhysicalKeyboardKey>{
                PhysicalKeyboardKey.shiftLeft,
                PhysicalKeyboardKey.shiftRight,
              }.contains(el),
            )) {
          if (kIsWeb && _textController.value.isComposingRangeValid) {
            return KeyEventResult.ignored;
          }
          if (event is KeyDownEvent) {
            _handleSendPressed();
          }
          return KeyEventResult.handled;
        } else {
          return KeyEventResult.ignored;
        }
      },
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _handleSendPressed() {
    if (_textController.text.isNotEmpty) {
      widget.sendMessage(PartialText(text: _textController.text));
      _textController.clear();
    }
  }

  void _handleStopPressed() {
    widget.cancelRequest();
  }

  @override
  Widget build(BuildContext context) {
    return <Widget>[
      [
        CupertinoTextField(
          controller: _textController,
          focusNode: _inputFocusNode,
          placeholder: 'Build...',
          placeholderStyle: context.bodyMedium.copyWith(
              color: context.theme.colorScheme.onSurface.withOpacity(0.5)),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          enabled: widget.state == ChatInputState.enable,
          style: context.bodyMedium,
          padding: const EdgeInsets.only(
            left: 0,
            top: 16,
            bottom: 16,
            right: 48,
          ),
          maxLines: 5,
          minLines: 1,
        ),
        Visibility(
          visible: _textController.text.isNotEmpty &&
              widget.state == ChatInputState.enable,
          child: IconButton.filled(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                context.theme.colorScheme.inverseSurface,
              ),
            ),
            iconSize: 20,
            padding: EdgeInsets.zero,
            onPressed: _handleSendPressed,
            icon: Icon(
              LucideIcons.arrowUp,
              color: context.theme.colorScheme.surface,
            ),
          ),
        ).square(38).positioned(
              right: 4,
              bottom: 4,
            ),
        Visibility(
          visible: widget.state == ChatInputState.inProgress,
          child: IconButton.filled(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                context.theme.colorScheme.inverseSurface,
              ),
            ),
            iconSize: 20,
            padding: EdgeInsets.zero,
            onPressed: _handleStopPressed,
            icon: Icon(
              LucideIcons.square,
              color: context.theme.colorScheme.surface,
            ),
          ),
        ).square(38).positioned(
              right: 4,
              bottom: 4,
            ),
      ].stack(),
      BlocBuilder<FlutterRunCubit, FlutterRunState>(
        builder: (context, state) {
          return CupertinoSlidingSegmentedControl(
            thumbColor: context.theme.colorScheme.primary,
            groupValue: state.common.chatState.editingMode,
            children: <EditingMode, Widget>{
              EditingMode.conversationOnly: const Tooltip(
                message: 'Conversation only (No edits)',
                child: Icon(
                  LucideIcons.messageCircle,
                  size: 16,
                ),
              ).pointer(),
              EditingMode.manual: const Tooltip(
                message: 'Manual mode (Step by step)',
                child: Icon(
                  LucideIcons.pencil,
                  size: 16,
                ),
              ).pointer(),
              EditingMode.agent: const Tooltip(
                message: 'Agent mode (Several automatic edits)',
                child: Icon(
                  LucideIcons.botMessageSquare,
                  size: 16,
                ),
              ).pointer(),
            },
            onValueChanged: (e) => context
                .read<FlutterRunCubit>()
                .setEditingMode(e as EditingMode),
          );
        },
      ),
    ]
        .spacing(8)
        .column()
        .paddingAll(8)
        .decorated(BoxDecoration(
          color: context.theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ))
        .paddingAll(8);
  }
}
