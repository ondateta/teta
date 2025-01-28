import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:openai_dart/openai_dart.dart';
import 'package:server/env/env.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_gzip/shelf_gzip.dart';
import 'package:shelf_router/shelf_router.dart';

final _router = Router()
  ..post('/dev', _dev)
  ..get('/doctor', _doctor)
  ..get('/ls', _ls)
  ..get('/lsShell', _lsShell);
late OpenAIClient _client;

Future<void> main() async {
  _client = OpenAIClient(apiKey: Env.llmKey, baseUrl: Env.llmBaseUrl);

  print(
      'Env files, port: ${Env.port}, llmKey: ${Env.llmKey}, llmBaseUrl ${Env.llmBaseUrl}, llmModel: ${Env.llmModel}');

  final cascade = Pipeline()
      .addMiddleware(gzipMiddleware)
      .addMiddleware(
        createCustomCorsHeadersMiddleware(),
      )
      .addHandler(_router.call);

  final server = await serve(
    logRequests().addHandler(cascade),
    InternetAddress.anyIPv4,
    Env.port,
  );

  print('Serving at http://${server.address.host}:${server.port}');
}

Middleware _createCorsHeadersMiddleware({
  Map<String, String> corsHeaders = const {'Access-Control-Allow-Origin': '*'},
}) {
  // Handle preflight (OPTIONS) requests by just adding headers and an empty
  // response.
  FutureOr<Response?> handleOptionsRequest(Request request) {
    if (request.method == 'OPTIONS') {
      return Response.ok(null, headers: corsHeaders);
    } else {
      return null;
    }
  }

  FutureOr<Response> addCorsHeaders(Response response) =>
      response.change(headers: corsHeaders);

  return createMiddleware(
      requestHandler: handleOptionsRequest, responseHandler: addCorsHeaders);
}

Middleware createCustomCorsHeadersMiddleware() {
  return _createCorsHeadersMiddleware(corsHeaders: <String, String>{
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers':
        'Origin, X-Requested-With, Content-Type, Accept, x-goog-api-client, Authorization',
  });
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
  print('Sending request: $request');
  final stream = _client.createChatCompletionStream(
    request: CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(Env.llmModel),
      temperature: 0,
      messages: [
        ChatCompletionMessage.system(content: '''
You are a Flutter developer copilot. Your task is to help build Flutter applications by providing only the necessary code updates. Do not include any comments, explanations, or additional text in your response. Only provide the code for the files that need to be updated or created.

Use the following structure to specify files:

To create or update a file:
@file /file/path
[Code content]
To delete a file:
@file /file/path DELETE
Ensure that all necessary imports are included in the code to make it functional. Do not add any extra text or comments outside of the code blocks.

Example:

@file /lib/main.dart
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Flutter App'),
        ),
        body: Center(
          child: Text('Hello, World!'),
        ),
      ),
    );
  }
}

@file /pubspec.yaml
name: my_flutter_app
description: A new Flutter project.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=2.12.0 <3.0.0'

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true

App code:
$codeContent

${errors.join('\n')}'}

Instructions:

Analyze the provided code.
Identify changes needed.
Provide only the updated or created code, without additional comments or phrases.
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
    stream.asyncMap(
      (event) {
        print('${event.choices.first.delta.content}');
        return event.choices.first.delta.content != null
            ? utf8.encode(event.choices.first.delta.content!)
            : utf8.encode('');
      },
    ),
    context: {"shelf.io.buffer_output": false},
    headers: {
      'Cache-Control': 'no-store',
      'Content-Type': 'application/json',
    },
  );
}

Future<Response> _ls(Request req) async {
  final process = await Process.start(
    'ls',
    [],
    workingDirectory: Directory.current.path,
  );
  return Response.ok(
    process.stdout,
    context: {"shelf.io.buffer_output": false},
    headers: {
      'Cache-Control': 'no-store',
      'Content-Type': 'application/json',
    },
  );
}

Future<Response> _lsShell(Request req) async {
  final process = await Process.start('ls', [], runInShell: true);
  return Response.ok(
    process.stdout,
    context: {"shelf.io.buffer_output": false},
    headers: {
      'Cache-Control': 'no-store',
      'Content-Type': 'application/json',
    },
  );
}

Future<Response> _doctor(Request req) async {
  final process = await Process.start(
    'flutter',
    ['doctor'],
    workingDirectory: Directory.current.path,
  );
  return Response.ok(
    process.stdout,
    context: {"shelf.io.buffer_output": false},
    headers: {
      'Cache-Control': 'no-store',
      'Content-Type': 'application/json',
    },
  );
}
