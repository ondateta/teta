import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:editor/core/constants.dart';
import 'package:editor/core/shortcuts.dart';
import 'package:editor/extensions/functions.ext.dart';
import 'package:editor/ui/editor/blocs/states/chat/chat.state.dart';
import 'package:editor/ui/editor/blocs/states/common/common_editor.state.dart';
import 'package:editor/ui/editor/blocs/states/editor/editor.state.dart';
import 'package:editor/ui/editor/blocs/states/repository/git/commit.entity.dart';
import 'package:editor/ui/editor/blocs/states/repository/git/git_command.result.dart';
import 'package:editor/ui/editor/blocs/states/repository/repository.state.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:http/http.dart' as http;
import 'package:hydrated_bloc/hydrated_bloc.dart';

const errorAnalyzerLogPrefix = 'error •';
const warningAnalyzerLogPrefix = 'warning •';
const infoAnalyzerLogPrefix = 'info •';

class FlutterRunCubit extends HydratedCubit<FlutterRunState> {
  FlutterRunCubit(
    String tetaDocumentsPath,
    this.projectID,
  ) : super(
          FlutterRunState.notStarted(
            common: CommonEditorState(
              projectID: projectID,
              tetaDocumentsPath: tetaDocumentsPath,
            ),
          ),
        );

  String projectID;
  late Process p;

  /// * Initialize the project
  /// 1. Detect if the folder exists.
  /// 2. If not, create the folder running 'flutter create'
  /// 3. Run the project
  /// 4. Run the analysis to display the errors and warnings
  /// * Initialization entrypoint
  void init() async {
    logger.i('Initializing the project at ${state.common.projectAppPath}');
    try {
      // Check if the project folder exists
      final appDir = Directory(state.common.projectAppPath);
      if (!appDir.existsSync()) {
        appDir.createSync(recursive: true);
        await _createFlutterProject('app');
      }
      await upgradeDependencies();
      await _createGitRepo(state.common.projectAppPath);
      Future.wait([
        runApp(),
        analyzeProject(),
      ]);
    } catch (e) {
      addError('Error initializing the project: $e', StackTrace.current);
    }
  }

  /// Add a log to the console
  void _addConsoleLog(String log) {
    final logs = [...state.common.consoleState.logs, log];
    emit(
      state.copyWith(
        common: state.common.copyWith.consoleState(
          logs: logs,
        ),
      ),
    );
  }

  void _addAnalyzerError(String error) {
    final errors = [...state.common.analyzerState.errors, error];
    emit(
      state.copyWith(
        common: state.common.copyWith.analyzerState(
          errors: errors,
        ),
      ),
    );
  }

  void _addAnalyzerWarning(String warning) {
    final warnings = [...state.common.analyzerState.warnings, warning];
    emit(
      state.copyWith(
        common: state.common.copyWith.analyzerState(
          warnings: warnings,
        ),
      ),
    );
  }

  /// Add a message to the chat
  void addMessage(types.Message message) {
    final messages = [...state.common.chatState.messages, message];
    emit(
      state.copyWith(
        common: state.common.copyWith.chatState(
          messages: messages,
        ),
      ),
    );
  }

  void updateMessage(types.Message message) {
    final messages = state.common.chatState.messages.map((e) {
      if (e.id == message.id) {
        return message;
      }
      return e;
    }).toList();
    emit(
      state.copyWith(
        common: state.common.copyWith.chatState(
          messages: messages,
        ),
      ),
    );
  }

  /// Set the editing mode of the chat
  void setEditingMode(EditingMode mode) => emit(
        state.copyWith(
          common: state.common.copyWith.chatState(
            editingMode: mode,
          ),
        ),
      );

  /// Set the localhost port
  void setLocalhostPort(int localhostPort) {
    state.whenOrNull(running: (common, port) {
      emit(
        FlutterRunState.running(
          common: common,
          localhostPort: localhostPort,
        ),
      );
    });
  }

  /// Add a PID to the list of running processes
  void addPid(int pid) {
    emit(state.copyWith.common.cliProcessState(
      pids: [...state.common.cliProcessState.pids, pid],
    ));
  }

  void stopRequest() {
    emit(state.copyWith.common.chatState(
      requestState: RequestState.notStarted,
      productManager: state.common.chatState.productManager.copyWith(
        currentState: AIUserState.waiting,
      ),
      techLead: state.common.chatState.techLead.copyWith(
        currentState: AIUserState.waiting,
      ),
      developer: state.common.chatState.developer.copyWith(
        currentState: AIUserState.waiting,
      ),
      designer: state.common.chatState.designer.copyWith(
        currentState: AIUserState.waiting,
      ),
    ));
  }

  bool get canContinueWithRequest =>
      state.common.chatState.requestState == RequestState.doing;

  // ! Chat management ---------------------------------------------------------
  // here all the methods to manage the chat

  /// Gateway to the chat
  /// It manages the conversation between the user and the AI
  /// [EditingMode.conversationOnly] -> The AI will not make any changes, only chat
  /// [EditingMode.manual] -> The AI will only make one edit
  /// [EditingMode.agent] -> The AI will make several automatic changes by generating tasks
  Future<void> makeRequest({
    required String request,
    required Function() onWebViewNeedsAReload,
  }) async {
    emit(state.copyWith.common.chatState(
      requestState: RequestState.doing,
    ));
    final method = state.common.chatState.editingMode;
    switch (method) {
      case EditingMode.conversationOnly:
      case EditingMode.manual:
        await _writeCode(request);
        Future.delayed(const Duration(milliseconds: 300)).then((_) {
          onWebViewNeedsAReload();
        });
        commitChanges(
          state.common.projectAppPath,
          'update made for request "$request"',
        );
        break;
      case EditingMode.agent:
        await _writeCode(request);
        break;
    }
    emit(state.copyWith.common.chatState(
      requestState: RequestState.notStarted,
    ));
  }

  /// Ask the developer to write the code
  /// 1. take all the existing code in /lib and /pubspec.yaml and merge it in a single string
  /// 2. send the code to the AI and wait for the response
  /// 3. split the code in multiple files and write them in the project
  /// 4. analyze the project to find errors and warnings
  Future<void> _writeCode(
    String request, {
    List<String> errors = const [],
  }) async {
    if (!canContinueWithRequest) {
      logger.e('Cannot continue with the request');
      return;
    }
    addMessage(
      types.TextMessage(
        author: state.common.chatState.user,
        id: newID,
        text: request,
      ),
    );
    emit(state.copyWith.common.chatState.developer(
      currentState: AIUserState.typing,
    ));
    final projectAppPath = state.common.projectAppPath;
    final pubspecFileContent =
        File('$projectAppPath/pubspec.yaml').readAsStringSync();
    final mergeLibContent = _mergeCodeFiles('$projectAppPath/lib/');
    final codeContent = '''
@file $projectAppPath/pubspec.yaml
$pubspecFileContent

$mergeLibContent''';
    final last5UserMessages = state.common.chatState.messages
        .where((e) => e.author == state.common.chatState.user)
        .map(
          (e) => (e as types.TextMessage).text,
        )
        .toList()
        .reversed
        .take(5)
        .toList();
    logger.i('Ready to send request to the AI');
    final url = Uri.parse('http://localhost:3002/dev');
    final httpReq = http.Request("POST", url);
    httpReq.body = jsonEncode({
      "request": request,
      "codeContent": codeContent,
      "errors": errors,
      "last5UserMessages": last5UserMessages,
    });
    httpReq.headers.addAll({
      "Content-Type": "application/json",
    });

    final httpRes = await httpReq.send();

    logger.i('Request sent to the AI');

    /// Create a new message with the request
    final responseContent = StringBuffer();
    final replyMessageID = newID;
    addMessage(
      types.TextMessage(
        author: state.common.chatState.developer.user,
        id: replyMessageID,
        text: '🧑‍💻 Writing the code...',
        metadata: const {
          'files': <String, String>{},
        },
      ),
    );

    Map<String, String> parts = {};

    if (httpRes.statusCode != 200) {
      addError(
          'Failed to fetch stream: ${httpRes.statusCode}', StackTrace.current);
      return;
    }

    /// Wait for the response from the AI
    await for (final res in httpRes.stream.transform(utf8.decoder)) {
      if (!canContinueWithRequest) {
        logger.e('Cannot continue with the request');
        return;
      }
      logger.i(res);
      responseContent.write(res);
      parts = _splitCodeInEntriesPathAndContent(responseContent.toString());
      updateMessage(
        types.TextMessage(
          author: state.common.chatState.developer.user,
          id: replyMessageID,
          text: '🧑‍💻 Writing the code...',
          metadata: {
            'files': parts,
          },
        ),
      );
    }
    updateMessage(
      types.TextMessage(
        author: state.common.chatState.developer.user,
        id: replyMessageID,
        text: '✅ Code written',
        metadata: {
          'files': parts,
        },
      ),
    );
    _writeFiles(parts);
    emit(state.copyWith.common.chatState.developer(
      currentState: AIUserState.waiting,
    ));
  }

  // End chat management -------------------------------------------------------

  // ! Folder / code management ------------------------------------------------
  // here all the methods to manage the code

  /// Create the project using the 'flutter create' command
  Future<void> _createFlutterProject(String appPackageName) async {
    emit(
      FlutterRunState.projectCreating(
        common: state.common,
      ),
    );
    var process = await Process.start(
      'flutter',
      ['create', '.', '--project-name', appPackageName],
      workingDirectory: state.common.projectAppPath,
    );
    var exitCode = await process.exitCode;
    if (exitCode != 0) {
      emit(
        FlutterRunState.exceptionProjectNotCreated(
          common: state.common,
          errorMessage: 'Failed to create the project $exitCode',
        ),
      );
    }
  }

  /// Given a directory path, merge all the dart files in a single string
  String _mergeCodeFiles(String directoryPath) {
    final directory = Directory(directoryPath);
    final codeUnited = StringBuffer();

    for (final entity in directory.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final content = entity.readAsStringSync();
        codeUnited.write('@file ${entity.absolute.path}\n$content\n\n');
      }
    }
    return codeUnited.toString();
  }

  /// Given a Map with the path of the file as key and the content as value,
  /// write the content in the respective file
  void _writeFiles(
    Map<String, String> parts, {
    bool rebuild = true,
  }) {
    if (!canContinueWithRequest) {
      logger.e('Cannot continue with the request');
      return;
    }
    logger.i('Parts: $parts');
    bool haveDependenciesChanged = false;
    for (final part in parts.entries) {
      final filePath = '${state.common.projectAppPath}${part.key}';
      final file = File(filePath);

      // check if the file is pubspec and check if dependencies have changed
      if (part.key.contains('pubspec.yaml')) {
        final oldContent = file.readAsStringSync();
        final newContent = part.value;
        if (oldContent != newContent) {
          haveDependenciesChanged = true;
        }
      }

      if (part.value == 'DELETE') {
        file.createSync(recursive: true);
        file.deleteSync();
        continue;
      }

      file.createSync(recursive: true);
      file.writeAsStringSync(part.value);
    }
    if (haveDependenciesChanged) {
      upgradeDependencies().then((_) => killProcessAndRestart());
    } else if (rebuild) {
      reloadProcess();
    }
  }

  /// Split the code in multiple files
  /// It returns a map with the path of the file as key and the content as value
  Map<String, String> _splitCodeInEntriesPathAndContent(String code) {
    final entries = code.split('@file');
    final map = <String, String>{};
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i].trim();
      final newlineIndex = entry.indexOf('\n');
      if (newlineIndex != -1) {
        final rawPath = entry.substring(0, newlineIndex).trim();
        final path =
            rawPath.split(' ').first.split(state.common.projectID).last;
        final content = entry.substring(newlineIndex).trim();
        map[path] = content;
      }
    }
    return map;
  }

  Future<void> upgradeDependencies() async {
    final process = await Process.start(
      'flutter',
      ['packages', 'upgrade'],
      workingDirectory: state.common.projectAppPath,
    );
    final log = StringBuffer();
    process.stdout.transform(utf8.decoder).listen((event) {
      log.write(event);
      _addConsoleLog(event);
    });
    process.stderr.transform(utf8.decoder).listen((event) {
      log.write(event);
      _addConsoleLog(event);
    });
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      addError('Error upgrading dependencies', StackTrace.current);
      logger.i('Error upgrading dependencies: $log');
      _addAnalyzerError(log.toString());
    }
  }

  // End folder / code management ----------------------------------------------

  // ! Analyzer management -----------------------------------------------------
  // here all the methods to manage the analyzer

  /// Analyze the project to find errors and warnings
  Future<void> analyzeProject() async {
    final info = <String>[];
    final warnings = <String>[];
    final errors = <String>[];
    try {
      final process = await Process.start(
        'flutter',
        ['analyze'],
        workingDirectory: state.common.projectAppPath,
      );
      process.stdout.transform(utf8.decoder).listen((data) {
        final log = _analyzeLog(data);
        if (log.error != null) {
          errors.add(log.error!);
        } else if (log.warning != null) {
          warnings.add(log.warning!);
        } else {
          info.add(log.info!);
        }
      });
      process.stderr.transform(utf8.decoder).listen((error) {
        final log = _analyzeLog(error);
        if (log.error != null) {
          errors.add(log.error!);
        } else if (log.warning != null) {
          warnings.add(log.warning!);
        } else {
          info.add(log.info!);
        }
      });
    } catch (e) {
      addError(e, StackTrace.current);
    }
    emit(state.copyWith.common.analyzerState(
      errors: [
        ...state.common.analyzerState.errors,
        ...errors,
      ],
      warnings: [
        ...state.common.analyzerState.warnings,
        ...warnings,
      ],
    ));
  }

  /// Analyze the log to find errors and warnings
  ({String? info, String? warning, String? error}) _analyzeLog(String log) {
    if (log.contains(errorAnalyzerLogPrefix)) {
      return (info: null, warning: null, error: log);
    } else if (log.contains(warningAnalyzerLogPrefix)) {
      return (info: null, warning: log, error: null);
    } else {
      return (info: log, warning: null, error: null);
    }
  }

  // End analyzer management --------------------------------------------------

  // ! Git management ----------------------------------------------------------
  // here all the methods to manage the git repository

  /// Commit changes to the git repository
  /// This serves as a way to save the changes made to the project
  ///
  /// [repoPath] is the path to the repository
  /// [message] is the commit message
  ///
  /// For this to work, the git command must be available in the system
  Future<void> commitChanges(String repoPath, String message) async {
    try {
      // Esegui `git add`
      final addProcess =
          await Process.start('git', ['add', '.'], workingDirectory: repoPath);
      final addError = await addProcess.stderr
          .transform(const SystemEncoding().decoder)
          .join();
      final addExitCode = await addProcess.exitCode;

      if (addExitCode != 0) {
        throw Exception('Errore durante git add: $addError');
      }

      // Esegui `git commit`
      final commitProcess = await Process.start(
          'git', ['commit', '-m', message],
          workingDirectory: repoPath);
      final commitError = await commitProcess.stderr
          .transform(const SystemEncoding().decoder)
          .join();
      final commitExitCode = await commitProcess.exitCode;

      if (commitExitCode != 0) {
        throw Exception('Error committing changes: $commitError');
      }

      final commit = await _getCurrentCommit(repoPath);

      emit(state.copyWith.common.repositoryState(
        commits: [
          commit,
          ...state.common.repositoryState.commits,
        ],
        currentCommit: commit,
      ));
    } catch (e) {
      addError('Error committing changes: $e', StackTrace.current);
    }
  }

  /// Create a git repository in the project folder
  Future<void> _createGitRepo(String folderPath) async {
    try {
      // Check if the folder is already a git repository
      final isRepo = await _isGitRepository(folderPath);
      if (isRepo) {
        await loadRepository(folderPath);
        return;
      }

      // Create the git repository, update the UI for a loading state
      emit(state.copyWith.common(
        repositoryState: const RepositoryState.creating(
          branches: [],
          currentBranch: 'main',
          commits: [],
          currentCommit: null,
        ),
      ));

      // Check if git is installed
      final isGitInstalled = await runGitCommand(['--version'], folderPath);
      if (!isGitInstalled.success) {
        emit(
          state.copyWith.common(
            repositoryState: const RepositoryState.exception(
              message: 'Git is not installed',
              branches: [],
              currentBranch: 'main',
              commits: [],
              currentCommit: null,
            ),
          ),
        );
        addError('Error checking if git is installed: ${isGitInstalled.error}',
            StackTrace.current);
        return;
      }

      // Initialize the git repository
      final initResult = await runGitCommand(['init'], folderPath);
      if (!initResult.success) {
        emit(
          state.copyWith.common(
            repositoryState: const RepositoryState.exception(
              message: 'Failed to initialize the repository',
              branches: [],
              currentBranch: 'main',
              commits: [],
              currentCommit: null,
            ),
          ),
        );
        addError('Error initializing the git repository: ${initResult.error}');
        return;
      }

      // Commit the initial changes
      await commitChanges(folderPath, 'Initial commit');

      await loadRepository(folderPath);
      logger.i('Repository initialized:\n${initResult.output}');
    } catch (e) {
      print('Errore: ${e.toString()}');
    }
  }

  Future<void> loadRepository(String folderPath) async {
    final branches = await _getBranches(folderPath);
    logger.i('Branches: $branches');
    final commits = await _getCommits(folderPath, branches.first);
    logger.i('Commits: $commits');
    final currentBranch = await _getCurrentBranch(folderPath);
    logger.i('Current branch: $currentBranch');
    final currentCommit = await _getCurrentCommit(folderPath);
    logger.i('Current commit: $currentCommit');
    emit(state.copyWith.common(
      repositoryState: RepositoryState.created(
        branches: branches,
        currentBranch: currentBranch,
        commits: commits,
        currentCommit: currentCommit,
      ),
    ));
  }

  /// Run a git command
  Future<GitCommandResult> runGitCommand(
      List<String> args, String workingDir) async {
    final process =
        await Process.start('git', args, workingDirectory: workingDir);
    final output =
        await process.stdout.transform(const SystemEncoding().decoder).join();
    final error =
        await process.stderr.transform(const SystemEncoding().decoder).join();
    final exitCode = await process.exitCode;

    return GitCommandResult(
      success: exitCode == 0,
      output: output.trim(),
      error: error.trim(),
    );
  }

  /// Check if the folder is a git repository
  Future<bool> _isGitRepository(String folderPath) async {
    final gitFolder = Directory('$folderPath/.git');
    return await gitFolder.exists();
  }

  /// Get all branches in the repository
  Future<List<String>> _getBranches(String folderPath) async {
    final result = await runGitCommand(['branch', '-a'], folderPath);
    if (!result.success) {
      addError('Error retrieving branches: ${result.error}');
      return [];
    }

    // Process the branch output
    final branches = result.output
        .split('\n')
        .map((branch) => branch.replaceAll('*', '').trim())
        .where((branch) => branch.isNotEmpty)
        .toList();

    return branches;
  }

  /// Get all commits in a branch
  Future<List<CommitEntity>> _getCommits(
      String folderPath, String branch) async {
    final result = await runGitCommand(
      ['log', '--pretty=format:%H %s', branch],
      folderPath,
    );
    if (!result.success) {
      addError('Error retrieving commits: ${result.error}');
      return [];
    }

    // Process the commit output
    final commits = result.output.split('\n').map((line) {
      final parts = line.split(' ');
      final hash = parts.isNotEmpty ? parts[0] : '';
      final message = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      return CommitEntity(hash: hash, message: message);
    }).toList();

    return commits;
  }

  /// Get the current branch in the repository
  Future<String> _getCurrentBranch(String folderPath) async {
    final result =
        await runGitCommand(['rev-parse', '--abbrev-ref', 'HEAD'], folderPath);
    if (!result.success) {
      addError('Error retrieving the current branch: ${result.error}');
      return '';
    }

    final currentBranch = result.output.trim();

    // Check if in detached HEAD state
    if (currentBranch == 'HEAD') {
      final detachedResult = await runGitCommand(
        ['describe', '--always', '--dirty'],
        folderPath,
      );
      if (detachedResult.success) {
        return '(HEAD detached at ${detachedResult.output.trim()})';
      }
    }

    return currentBranch;
  }

  Future<CommitEntity> _getCurrentCommit(String folderPath) async {
    final result = await runGitCommand(
      ['rev-parse', 'HEAD'],
      folderPath,
    );
    if (!result.success) {
      addError('Error retrieving the current commit: ${result.error}');
      return const CommitEntity(hash: '', message: '');
    }

    final hash = result.output.trim();

    final messageResult = await runGitCommand(
      ['log', '--pretty=format:%s', '-n', '1', hash],
      folderPath,
    );
    if (!messageResult.success) {
      addError('Error retrieving the current commit message: ${result.error}');
      return CommitEntity(hash: hash, message: '');
    }

    final message = messageResult.output.trim();

    return CommitEntity(hash: hash, message: message);
  }

  Future<void> changeBranch(String branch) async {
    final projectPath = state.common.projectAppPath;
    final result = await runGitCommand(['checkout', branch], projectPath);
    if (!result.success) {
      addError('Error changing branch: ${result.error}');
      return;
    }

    final commits = await _getCommits(projectPath, branch);
    emit(state.copyWith.common.repositoryState(
      currentBranch: branch,
      commits: commits,
    ));
  }

  void createBranch(String projectPath, String branch) async {
    final result = await runGitCommand(['checkout', '-b', branch], projectPath);
    if (!result.success) {
      addError('Error creating branch: ${result.error}');
      return;
    }

    final branches = await _getBranches(projectPath);
    emit(state.copyWith.common.repositoryState(
      branches: branches,
      currentBranch: branch,
    ));
  }

  void deleteBranch(String projectPath, String branch) async {
    final result = await runGitCommand(['branch', '-D', branch], projectPath);
    if (!result.success) {
      addError('Error deleting branch: ${result.error}');
      return;
    }

    final branches = await _getBranches(projectPath);
    emit(state.copyWith.common.repositoryState(
      branches: branches,
    ));
  }

  Future<void> changeCommit(String commitHash) async {
    final projectPath = state.common.projectAppPath;
    final result = await runGitCommand(['checkout', commitHash], projectPath);
    if (!result.success) {
      addError('Error changing commit: ${result.error}');
      return;
    }

    // Get the current branch or detached HEAD state
    final currentBranch = await _getCurrentBranch(projectPath);

    // Get commits for the current branch or HEAD
    final commits = await _getCommits(projectPath, 'HEAD');
    emit(state.copyWith.common.repositoryState(
      currentBranch: currentBranch,
      commits: commits,
    ));
  }

  // End git management --------------------------------------------------------

  // ! Process management ------------------------------------------------------
  // here all the methods to manage the process

  /// Run the project
  Future<void> runApp({
    int port = 8080,
  }) async {
    emit(FlutterRunState.starting(
      common: state.common,
    ));
    // Kill the process if it's already running
    tryCatch(() => p.kill());
    p = await Process.start(
      'flutter',
      ['run', '-d', 'web-server', '--web-port', port.toString()],
      workingDirectory: state.common.projectAppPath,
      runInShell: true,
    );
    addPid(p.pid);
    p.stdout.listen((event) {
      final output = utf8.decode(event);
      if (utf8.decode(event).contains('is being served at http://localhost:')) {
        emit(
          FlutterRunState.running(
            common: state.common,
            localhostPort: port,
          ),
        );
        _addConsoleLog(utf8.decode(event));
        return;
      }
      _addConsoleLog(utf8.decode(event));
      if (output.contains('Error') || output.contains('Exception')) {
        emit(state.copyWith.common.analyzerState(
          errors: [...state.common.analyzerState.errors, output],
        ));
      }
    });
    p.stderr.listen((event) {
      _addConsoleLog('error ${utf8.decode(event)}');
    });
    final exitCode = await p.exitCode;
    if (exitCode != 0) {
      emit(
        FlutterRunState.exceptionProjectNotRunned(
          common: state.common.copyWith.consoleState(
            logs: [...state.common.consoleState.logs, 'Failed to run the code'],
          ),
          errorMessage: 'Failed to run the project',
        ),
      );
    }
  }

  /// Run the project or reload it if it's already running
  void runOrReload() {
    try {
      p.pid; // Check if the process exists
      reloadProcess();
    } catch (e) {
      runApp();
    }
  }

  /// Reload the project
  Future<void> reloadProcess() async {
    try {
      p.stdin.writeln('r'); // 'r' -> hot reload
      analyzeProject();
    } catch (e) {
      addError('Error reloading the app: $e', StackTrace.current);
    }
  }

  /// Stop the project
  void stopProcess() {
    p.kill();
    emit(FlutterRunState.notStarted(common: state.common));
  }

  /// Kill the app and restart it
  Future<void> killProcessAndRestart() async {
    try {
      p.kill();
      emit(FlutterRunState.notStarted(common: state.common));
    } catch (e) {
      addError('Error killing app: $e', StackTrace.current);
    }
    runApp();
  }

  // End process management --------------------------------------------------

  @override
  void onError(Object error, StackTrace stackTrace) {
    logger.e(
      'Error in FlutterRunCubit',
      error: error.toString(),
      stackTrace: stackTrace,
    );
    _addConsoleLog(error.toString());
    super.onError(error, stackTrace);
  }

  @override
  FlutterRunState? fromJson(Map<String, dynamic> json) {
    final pids = json['pids'];
    for (final p in pids) {
      Process.killPid(p);
    }
    final messagesData = json[projectID] as List<dynamic>? ?? [];
    final messages =
        messagesData.map((e) => types.Message.fromJson(e)).toList();
    return state.copyWith.common.chatState(
      messages: messages,
    );
  }

  @override
  Map<String, dynamic>? toJson(FlutterRunState state) {
    final pids = state.common.cliProcessState.pids;
    final messages = state.common.chatState.messages;
    final projectID = state.common.projectID;
    return {
      'pids': pids,
      projectID: messages.map((e) => e.toJson()).toList(),
    };
  }
}
