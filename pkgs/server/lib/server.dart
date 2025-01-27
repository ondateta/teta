import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:openai_dart/openai_dart.dart';
import 'package:server/env/env.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

final _router = Router()..post('/dev', _dev);
late OpenAIClient _client;

Future<void> main() async {
  _client = OpenAIClient(apiKey: Env.openAIKey);

  final cascade = Cascade().add(_router.call);

  final server = await serve(
    logRequests().addHandler(cascade.handler),
    InternetAddress.anyIPv4,
    Env.port,
  );

  print('Serving at http://${server.address.host}:${server.port}');
}

Future<Response> _dev(Request req) async {
  String body = await req.readAsString();
  final Map<String, dynamic> json = jsonDecode(body);
  final request = json['request'] as String;
  final codeContent = json['codeContent'] as String;
  final errors = json['errors'] as List<dynamic>? ?? [];
  final last5UserMessages =
      List<String>.from(json['last5UserMessages'] as List<dynamic>? ?? [])
          .map((e) => ChatCompletionUserMessage(
              content: ChatCompletionUserMessageContent.string(e)))
          .toList();
  final stream = _client.createChatCompletionStream(
    request: CreateChatCompletionRequest(
      model: const ChatCompletionModel.model(ChatCompletionModels.gpt4oMini),
      messages: [
        ChatCompletionMessage.system(content: '''
Hi, you are a Flutter developer copilot. Help people to build their own ideas.
Work on the given code.

Use '@file /lib/main.dart' structure for splitting the code between different files.
Eg. @file /pubspec.yaml or @file /lib/utils.dart
It will be recognized as a new file. Be sure to add all propers imports to make the code work.

Use '@file /file/path
DELETE' to delete a file. 
Example:

@file /lib/utils.dart
DELETE

Respond only with the necessary updated files' code, and with no markdown formatting. Be sure the edited files have the entire code.
App code: 
$codeContent

${errors.isEmpty ? '' : 'Errors: ${errors.join('\n')}'}

Think step by step.
'''),
        ...last5UserMessages,
        ChatCompletionUserMessage(
          content: ChatCompletionUserMessageContent.string(request),
        )
      ],
      prediction: PredictionContent(
        content: PredictionContentContent.text(codeContent),
      ),
    ),
  );

  return Response.ok(
    stream.asyncMap((event) => event.choices.first.delta.content != null
        ? utf8.encode(event.choices.first.delta.content!)
        : utf8.encode('')),
    context: {"shelf.io.buffer_output": false},
    headers: {
      'Cache-Control': 'no-store',
      'Content-Type': 'application/json',
    },
  );
}
