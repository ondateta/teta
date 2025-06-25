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

class ProcessesManager {
  final Map<int, ProcessEntity> _processes = {};

  int get length => _processes.length;

  /// return a free port (8080 is taken by default)
  int get findNewPort {
    int port = 8081;
    // Crea un insieme con tutte le porte in uso dai processi
    final usedPorts = _processes.values.map((process) => process.port).toSet();
    // Cerca la prima porta non usata
    while (usedPorts.contains(port)) {
      port++;
    }
    return port;
  }

  int getAppPort(String id) {
    final process =
        _processes.values.firstWhere((element) => element.projectID == id);
    return process.port!;
  }

  void addProcess(int pid, String? projectID, int? port) {
    _processes[pid] = ProcessEntity(
      pid,
      projectID,
      DateTime.now(),
      port,
    );
  }

  void removeProcess(int pid) {
    _processes.remove(pid);
  }

  void removeOldProcesses() {
    final now = DateTime.now();
    final deletingProjectsQueue = [];
    _processes.removeWhere((key, value) {
      final flag = now.difference(value.updatedAt).inMinutes > 5;
      if (flag) {
        deletingProjectsQueue.add(value.projectID);
      }
      return flag;
    });
    for (final projectID in deletingProjectsQueue) {
      Directory('${Directory.current.path}/apps/$projectID').deleteSync(
        recursive: true,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'processes': _processes.values.map((e) => e.toJson()).toList(),
    };
  }
}

class ProcessEntity {
  final int pid;
  final String? projectID;
  final DateTime updatedAt;
  final int? port;

  ProcessEntity(
    this.pid,
    this.projectID,
    this.updatedAt,
    this.port,
  );

  Map<String, dynamic> toJson() {
    return {
      'pid': pid,
      'projectID': projectID,
      'updatedAt': updatedAt.toIso8601String(),
      'port': port,
    };
  }
}

final manager = ProcessesManager();

Future<void> main() async {
  _client = OpenAIClient(apiKey: Env.llmKey, baseUrl: Env.llmBaseUrl);

  print(
      'Env files, port: ${Env.port}, llmKey: ${Env.llmKey}, llmBaseUrl ${Env.llmBaseUrl}, llmModel: ${Env.llmModel}');

  final cascade = Cascade()..add(_router.call);

  final server = await serve(
    _router.call,
    InternetAddress.anyIPv4,
    Env.port,
  );

  print('Serving at http://${server.address.host}:${server.port}');

  Timer.periodic(Duration(minutes: 1), (timer) {
    manager.removeOldProcesses();
  });
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

  // Extract sdk_type, default to "flutter" if not provided for backward compatibility
  final sdkType = json['sdk_type'] as String? ?? 'flutter';

  print('Received /dev request for SDK type: $sdkType, User request: "$request"');

  String systemPrompt;

  if (sdkType == 'expo') {
    systemPrompt = '''
You are an Expo (React Native) developer copilot. Your task is to help build mobile applications using Expo and React Native with JavaScript or TypeScript, by providing only the necessary code updates. Do not include any comments, explanations, or additional text in your response. Only provide the code for the files that need to be updated or created. Use functional components with hooks.

Use the following structure to specify files:

To create or update a file (e.g., .js, .jsx, .ts, .tsx, package.json):
@file /file/path.js
[Code content]

To delete a file:
@file /file/path.js DELETE

Ensure that all necessary imports are included. For styling, use StyleSheet.create.

Example for a simple component:

@file /components/MyButton.js
import React from 'react';
import { TouchableOpacity, Text, StyleSheet } from 'react-native';

const MyButton = ({ title, onPress }) => (
  <TouchableOpacity style={styles.button} onPress={onPress}>
    <Text style={styles.text}>{title}</Text>
  </TouchableOpacity>
);

const styles = StyleSheet.create({
  button: {
    backgroundColor: '#007AFF',
    padding: 10,
    borderRadius: 5,
  },
  text: {
    color: 'white',
    textAlign: 'center',
  }
});

export default MyButton;

@file /App.js
import React from 'react';
import { View, StyleSheet } from 'react-native';
import MyButton from './components/MyButton';

export default function App() {
  return (
    <View style={styles.container}>
      <MyButton title="Press Me" onPress={() => alert('Button Pressed!')} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  }
});

Current App code structure and content:
$codeContent

${errors.join('\n')}

Instructions:
Analyze the provided code and user request.
Identify changes needed for an Expo (React Native) application.
Provide only the updated or created JavaScript/TypeScript code for the specified files, without additional comments or phrases.
Remember to include all necessary imports and use StyleSheet.create for styles.
''';
  } else { // Default to Flutter
    systemPrompt = '''
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
''';
  }

  print('Sending request to LLM with system prompt for $sdkType.');
  final stream = _client.createChatCompletionStream(
    request: CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(Env.llmModel), // Use model from Env
      messages: [
        ChatCompletionMessage.system(content: systemPrompt),
        ...last5UserMessages,
        ChatCompletionUserMessage(
          content: ChatCompletionUserMessageContent.string(request),
        )
      ],
    ),
  );

  return Response.ok(
    stream.asyncMap(
      (event) {
        final content = event.choices.first.delta.content;
        if (content != null) {
          // print('LLM Delta: $content'); // Verbose logging for delta
          return utf8.encode(content);
        }
        return utf8.encode('');
      },
    ),
    context: {"shelf.io.buffer_output": false}, // Ensure streaming
    headers: {
      'Cache-Control': 'no-store',
      'Content-Type': 'application/json', // This should be 'text/event-stream' for SSE typically, but client handles JSON chunks
      'X-Accel-Buffering': 'no', // Useful for Nginx reverse proxy
    },
  );
}
