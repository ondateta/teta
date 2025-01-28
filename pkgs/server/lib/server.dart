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
  ..get('/current', _currentProcesses)
  ..get('/ls', _ls)
  ..get('/lsShell', _lsShell)
  ..post('/create', _createApp)
  ..post('/pubGet', _pubGet)
  ..post('/build', _buildApp)
  ..post('/buildWasm', _buildAppWasm)
  ..post('/run', _runApp);
late OpenAIClient _client;

class ProcessesManager {
  final Map<int, ProcessEntity> _processes = {};

  int get length => _processes.length;

  void addProcess(int pid, String? projectID) {
    _processes[pid] = ProcessEntity(
      pid,
      projectID,
      DateTime.now(),
    );
  }

  void removeProcess(int pid) {
    _processes.remove(pid);
  }

  void removeOldProcesses() {
    final now = DateTime.now();
    _processes.removeWhere((key, value) {
      return now.difference(value.updatedAt).inMinutes > 5;
    });
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

  ProcessEntity(this.pid, this.projectID, this.updatedAt);

  Map<String, dynamic> toJson() {
    return {
      'pid': pid,
      'projectID': projectID,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

final manager = ProcessesManager();

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
  process.exitCode.then((e) => manager.removeProcess(process.pid));
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
  manager.addProcess(process.pid, null);
  process.exitCode.then((e) => manager.removeProcess(process.pid));
  return Response.ok(
    process.stdout,
    context: {"shelf.io.buffer_output": false},
    headers: {
      'Cache-Control': 'no-store',
      'Content-Type': 'application/json',
    },
  );
}

Future<Response> _createApp(Request req) async {
  final json = jsonDecode(await req.readAsString());
  final id = json['id'] as String;
  final buildPath = '${Directory.current.path}/apps/$id';
  await Directory(buildPath).create(recursive: true);
  final process = await Process.start(
    'flutter',
    ['create', '.'],
    workingDirectory: buildPath,
  );
  manager.addProcess(process.pid, null);
  process.exitCode.then((e) => manager.removeProcess(process.pid));
  return Response.ok(
    process.stdout,
    context: {"shelf.io.buffer_output": false},
    headers: {
      'Cache-Control': 'no-store',
      'Content-Type': 'text/plain',
    },
  );
}

Future<Response> _pubGet(Request req) async {
  final json = jsonDecode(await req.readAsString());
  final id = json['id'] as String;
  final buildPath = '${Directory.current.path}/apps/$id';
  print(Directory(buildPath).existsSync());
  final process = await Process.start(
    'flutter',
    [
      'pub',
      'get',
      '--verbose',
    ],
    workingDirectory: buildPath,
  );
  process.stderr.listen((event) {
    print(event);
  });
  manager.addProcess(process.pid, id);
  process.exitCode.then((e) => manager.removeProcess(process.pid));
  return Response.ok(
    process.stdout,
    context: {"shelf.io.buffer_output": false},
    headers: {
      'Cache-Control': 'no-store',
      'Content-Type': 'text/plain',
    },
  );
}

Future<Response> _runApp(Request req) async {
  final json = jsonDecode(await req.readAsString());
  final id = json['id'] as String;
  final buildPath = '${Directory.current.path}/apps/$id';
  print(Directory(buildPath).existsSync());
  final process = await Process.start(
    'flutter',
    [
      'run',
      '-d',
      'web-server',
      '--web-hostname',
      '0.0.0.0',
      '--web-port',
      '8081',
      '--verbose',
    ],
    workingDirectory: buildPath,
  );
  process.stderr.listen((event) {
    print(event);
  });
  manager.addProcess(process.pid, id);
  process.exitCode.then((e) => manager.removeProcess(process.pid));
  return Response.ok(
    process.stdout,
    context: {"shelf.io.buffer_output": false},
    headers: {
      'Cache-Control': 'no-store',
      'Content-Encoding': 'identity',
      'Content-Type': 'text/plain',
    },
  );
}

Future<Response> _buildApp(Request req) async {
  final json = jsonDecode(await req.readAsString());
  final id = json['id'] as String;
  final buildPath = '${Directory.current.path}/apps/$id';
  print(Directory(buildPath).existsSync());
  final process = await Process.start(
    'flutter',
    [
      'build',
      'web',
      '--verbose',
    ],
    workingDirectory: buildPath,
  );
  process.stderr.listen((event) {
    print(event);
  });
  manager.addProcess(process.pid, id);
  process.exitCode.then((e) => manager.removeProcess(process.pid));
  return Response.ok(
    process.stdout,
    context: {"shelf.io.buffer_output": false},
    headers: {
      'Cache-Control': 'no-store',
      'Content-Encoding': 'identity',
      'Content-Type': 'text/plain',
    },
  );
}

Future<Response> _buildAppWasm(Request req) async {
  final json = jsonDecode(await req.readAsString());
  final id = json['id'] as String;
  final buildPath = '${Directory.current.path}/apps/$id';
  print(Directory(buildPath).existsSync());
  final process = await Process.start(
    'flutter',
    [
      'build',
      'web',
      '--wasm',
      '--verbose',
    ],
    workingDirectory: buildPath,
  );
  process.stderr.listen((event) {
    print(event);
  });
  manager.addProcess(process.pid, id);
  process.exitCode.then((e) => manager.removeProcess(process.pid));
  return Response.ok(
    process.stdout,
    context: {"shelf.io.buffer_output": false},
    headers: {
      'Cache-Control': 'no-store',
      'Content-Encoding': 'identity',
      'Content-Type': 'text/plain',
    },
  );
}

Future<Response> _currentProcesses(Request req) async {
  return Response.ok(
    jsonEncode(manager.toJson()),
    headers: {
      'Cache-Control': 'no-store',
      'Content-Type': 'application/json',
    },
  );
}
