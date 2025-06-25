import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:editor/core/constants.dart';
import 'package:editor/core/shortcuts.dart';
import 'package:editor/extensions/functions.ext.dart';
import 'package:editor/ui/editor/blocs/states/chat/chat.state.dart';
import 'package:editor/ui/editor/blocs/states/common/common_editor.state.dart';
import 'package:editor/ui/editor/blocs/states/editor/editor.state.dart'; // Will be ProjectContextState
import 'package:editor/ui/editor/blocs/states/repository/git/commit.entity.dart';
import 'package:editor/ui/editor/blocs/states/repository/git/git_command.result.dart';
import 'package:editor/ui/editor/blocs/states/repository/repository.state.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:http/http.dart' as http;
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:editor/entities/project.dart'; // Import the temporary Project entity

const errorAnalyzerLogPrefix = 'error •';
const warningAnalyzerLogPrefix = 'warning •';
const infoAnalyzerLogPrefix = 'info •';

class ProjectContextCubit extends HydratedCubit<ProjectContextState> {
  ProjectContextCubit(
    Project currentProject,
    this.serverUrl,
  ) : projectID = currentProject.id,
        super(
          ProjectContextState.notStarted(
            common: CommonEditorState(
              projectID: currentProject.id,
              projectPath: currentProject.path,
              sdkType: currentProject.sdkType,
            ),
          ),
        );

  final String projectID;
  final String serverUrl;
  late Process p;

  void init() async {
    logger.i('Initializing project at ${state.common.projectAppPath}, SDK: ${state.common.sdkType.name}');
    try {
      final appDir = Directory(state.common.projectAppPath);
      if (!await appDir.exists()) { // Use await for exists()
        await appDir.create(recursive: true); // Use await for create()
        if (state.common.sdkType == ProjectSDK.flutter) {
          await _createFlutterProject('app');
        } else if (state.common.sdkType == ProjectSDK.expo) {
          logger.i('Expo project creation: For MVP, ensure directory exists. `expo init` is future work.');
        }
      }

      if (state.common.sdkType == ProjectSDK.flutter) {
        await upgradeDependencies();
      } else if (state.common.sdkType == ProjectSDK.expo) {
        logger.i('Expo dependency installation (npm/yarn install) is manual for MVP.');
      }

      await _createGitRepo(state.common.projectAppPath);

      if (state.common.sdkType == ProjectSDK.flutter) {
        // No need for Future.wait if individual calls are awaited and independent enough
        await runApp();
        await analyzeProject();
      } else if (state.common.sdkType == ProjectSDK.expo) {
        logger.i('Expo project: Emitting .running state to trigger WebView load for Expo IDE.');
        if(!isClosed) emit(ProjectContextState.running(common: state.common, localhostPort: 0));
      }
    } catch (e, s) { // Add stacktrace to addError
      addError('Error initializing the project: $e', s);
    }
  }

  void _addConsoleLog(String log) {
    if(isClosed) return;
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
    if(isClosed) return;
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
    if(isClosed) return;
    final warnings = [...state.common.analyzerState.warnings, warning];
    emit(
      state.copyWith(
        common: state.common.copyWith.analyzerState(
          warnings: warnings,
        ),
      ),
    );
  }

  void addMessage(types.Message message) {
    if(isClosed) return;
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
    if(isClosed) return;
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

  void removeMessage(String id) {
    if(isClosed) return;
    final messages =
        state.common.chatState.messages.where((e) => e.id != id).toList();
    emit(
      state.copyWith(
        common: state.common.copyWith.chatState(
          messages: messages,
        ),
      ),
    );
  }

  void setEditingMode(EditingMode mode) {
    if(isClosed) return;
    emit(
      state.copyWith(
        common: state.common.copyWith.chatState(
          editingMode: mode,
        ),
      ),
    );
  }

  void setLocalhostPort(int localhostPort) {
    if(isClosed) return;
    state.whenOrNull(running: (common, port) {
      if(isClosed) return;
      emit(
        ProjectContextState.running(
          common: common,
          localhostPort: localhostPort,
        ),
      );
    });
  }

  void addPid(int pid) {
    if(isClosed) return;
    emit(state.copyWith.common.cliProcessState(
      pids: [...state.common.cliProcessState.pids, pid],
    ));
  }

  void stopRequest() {
    if(isClosed) return;
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

  Future<void> makeRequest({
    required String request,
    // required Function() onWebViewNeedsAReload, // Removed callback
  }) async {
    if(isClosed) return;
    emit(state.copyWith.common.chatState(
      requestState: RequestState.doing,
    ));
    final method = state.common.chatState.editingMode;
    try {
      switch (method) {
        case EditingMode.conversationOnly:
        case EditingMode.manual:
          await _writeCode(request);
          // Future.delayed(const Duration(milliseconds: 300)).then((_) { // Removed direct call
          //   onWebViewNeedsAReload();
          // });
          // filesUpdated state will be emitted by _writeCode or its callers
          await commitChanges(
            state.common.projectAppPath,
            'update made for request "$request"',
          );
          break;
        case EditingMode.agent:
          await _writeCode(request);
          break;
      }
    } catch (e, s) {
       addError('Error in makeRequest: $e', s);
    } finally {
      if(!isClosed) {
        emit(state.copyWith.common.chatState(
          requestState: RequestState.notStarted,
        ));
      }
    }
  }

  Future<void> _writeCode(
    String request, {
    List<String> errors = const [],
    void Function(String)? onError,
  }) async {
    if (!canContinueWithRequest) {
      logger.e('Cannot continue with the request, current requestState: ${state.common.chatState.requestState}');
      return;
    }
    addMessage(
      types.TextMessage(
        author: state.common.chatState.user,
        id: newID,
        text: request,
      ),
    );
    if(isClosed) return;
    emit(state.copyWith.common.chatState.developer(
      currentState: AIUserState.typing,
    ));

    final projectAppPath = state.common.projectAppPath;
    String pubspecEquivalentPath;
    String libEquivalentPath;
    List<String> fileExtensionsToScan; // For merging multiple file types

    if (state.common.sdkType == ProjectSDK.flutter) {
      pubspecEquivalentPath = '$projectAppPath/pubspec.yaml';
      libEquivalentPath = '$projectAppPath/lib/';
      fileExtensionsToScan = ['.dart'];
    } else {
      pubspecEquivalentPath = '$projectAppPath/package.json';
      final srcDir = Directory('$projectAppPath/src/');
      libEquivalentPath = await srcDir.exists() ? srcDir.path : '$projectAppPath/';
      fileExtensionsToScan = ['.js', '.jsx', '.ts', '.tsx'];
    }

    final pubspecFile = File(pubspecEquivalentPath);
    final pubspecFileContent = await pubspecFile.exists()
        ? await pubspecFile.readAsString()
        : '';

    final mergeLibContent = await _mergeCodeFiles(libEquivalentPath, fileExtensionsToScan);

    final codeContent = '''
@file ${pubspecEquivalentPath.replaceFirst(projectAppPath, '')}
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
    logger.i('Ready to send request to the AI for SDK: ${state.common.sdkType.name}');
    final url = Uri.parse('$serverUrl/dev');
    final httpReq = http.Request("POST", url);
    httpReq.body = jsonEncode({
      "request": request,
      "codeContent": codeContent,
      "errors": errors,
      "last5UserMessages": last5UserMessages,
      "sdk_type": state.common.sdkType.name,
    });
    httpReq.headers.addAll({
      "Content-Type": "application/json",
    });

    try { // Added try-catch for HTTP request
      final httpRes = await httpReq.send();

      if (httpRes.statusCode != 200) {
        final responseBody = await httpRes.stream.bytesToString();
        addError('Failed to send request to the AI: ${httpRes.statusCode}, Body: $responseBody',
            StackTrace.current);
        onError?.call('Failed to send request to the AI: ${httpRes.statusCode}');
        if(isClosed) return;
        emit(state.copyWith.common.chatState.developer(currentState: AIUserState.waiting));
        return;
      }

      logger.i('Request sent to the AI');

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

      await for (final res in httpRes.stream.transform(utf8.decoder)) {
        if (!canContinueWithRequest) {
          logger.e('Request cancelled by user during AI response streaming.');
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
      await _writeFiles(parts);
    } catch (e, s) {
      addError('Error during AI communication or file writing: $e', s);
      onError?.call('Error during AI communication: $e');
    } finally {
      if(!isClosed) {
        emit(state.copyWith.common.chatState.developer(
          currentState: AIUserState.waiting,
        ));
      }
    }
  }

  Future<void> _createFlutterProject(String appPackageName) async {
    if(isClosed) return;
    emit(
      ProjectContextState.projectCreating(
        common: state.common,
      ),
    );
    // TODO: Ensure flutter command is available. For now, assuming it is.
    var process = await Process.start(
      'flutter',
      ['create', '.', '--project-name', appPackageName],
      workingDirectory: state.common.projectAppPath,
    );
    var exitCode = await process.exitCode;
    if (exitCode != 0) {
      if(isClosed) return;
      emit(
        ProjectContextState.exceptionProjectNotCreated(
          common: state.common,
          errorMessage: 'Failed to create the project $exitCode',
        ),
      );
    }
  }

  Future<String> _mergeCodeFiles(String directoryPath, List<String> fileExtensions) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      logger.w('Directory not found for merging code: $directoryPath');
      return '';
    }
    final codeUnited = StringBuffer();

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        bool extensionMatch = false;
        for (final ext in fileExtensions) {
          if (entity.path.toLowerCase().endsWith(ext)) {
            extensionMatch = true;
            break;
          }
        }
        if (extensionMatch) {
            final content = await entity.readAsString();
            final relativePath = entity.absolute.path.replaceFirst(state.common.projectAppPath, '');
            codeUnited.write('@file $relativePath\n$content\n\n');
        }
      }
    }
    return codeUnited.toString();
  }

  Future<void> _writeFiles(
    Map<String, String> parts, {
    bool rebuild = true,
  }) async {
    if (!canContinueWithRequest) {
      logger.e('Cannot continue with the request in _writeFiles');
      return;
    }
    logger.i('Writing files: $parts');
    bool haveDependenciesChanged = false;
    for (final part in parts.entries) {
      final filePath = '${state.common.projectAppPath}${part.key}';
      final file = File(filePath);

      if (part.key.contains('pubspec.yaml') || part.key.contains('package.json')) {
         if (await file.exists()){
            final oldContent = await file.readAsString();
            final newContent = part.value;
            if (oldContent != newContent) {
              haveDependenciesChanged = true;
            }
         } else {
           haveDependenciesChanged = true;
         }
      }

      if (part.value == 'DELETE') {
        if (await file.exists()) {
            await file.delete();
            logger.i('Deleted file: $filePath');
        }
        continue;
      }

      await file.create(recursive: true);
      await file.writeAsString(part.value);
      logger.i('Wrote file: $filePath');
    }

    if (haveDependenciesChanged) {
      if (state.common.sdkType == ProjectSDK.flutter) {
        await upgradeDependencies();
        await killProcessAndRestart();
      } else {
        logger.i('Expo dependencies changed. Manual install might be needed or signal IDE via JSChannel.');
        if (rebuild) await reloadProcess();
      }
    } else if (rebuild) {
      await reloadProcess();
    }
  }

  Map<String, String> _splitCodeInEntriesPathAndContent(String code) {
    final entries = code.split('@file');
    final map = <String, String>{};
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i].trim();
      final newlineIndex = entry.indexOf('\n');
      if (newlineIndex != -1) {
        final rawPath = entry.substring(0, newlineIndex).trim();
        final path = rawPath.split(' ').first;
        final content = entry.substring(newlineIndex).trim();
        map[path] = content;
      }
    }
    return map;
  }

  Future<void> upgradeDependencies() async {
    if (state.common.sdkType != ProjectSDK.flutter) {
      logger.i('UpgradeDependencies: Skipped for non-Flutter project.');
      return;
    }
    logger.i('Upgrading Flutter dependencies...');
    // TODO: Ensure flutter command is available
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
      addError('Error upgrading Flutter dependencies', StackTrace.current);
      logger.i('Error upgrading Flutter dependencies: $log');
      _addAnalyzerError(log.toString());
    } else {
      logger.i('Flutter dependencies upgraded successfully.');
    }
  }

  Future<void> analyzeProject() async {
    if (state.common.sdkType != ProjectSDK.flutter) {
      logger.i('AnalyzeProject: Skipped for non-Flutter project. Expo analysis (ESLint/TSC) is future work.');
      // Clear previous errors/warnings for non-flutter projects if any were there
      if(!isClosed) emit(state.copyWith.common.analyzerState(errors: [], warnings: []));
      return;
    }
    logger.i('Analyzing Flutter project...');
    final info = <String>[];
    final warnings = <String>[];
    final errors = <String>[];
    try {
      // TODO: Ensure flutter command is available
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
      await process.exitCode;
      logger.i('Flutter analysis complete.');
    } catch (e,s) {
      addError('Error during Flutter analysis: $e', s);
    }
    if (!isClosed) {
      emit(state.copyWith.common.analyzerState(
        errors: errors, // Replace with new errors
        warnings: warnings, // Replace with new warnings
      ));
    }
  }

  ({String? info, String? warning, String? error}) _analyzeLog(String log) {
    if (log.contains(errorAnalyzerLogPrefix)) {
      return (info: null, warning: null, error: log);
    } else if (log.contains(warningAnalyzerLogPrefix)) {
      return (info: null, warning: log, error: null);
    } else {
      return (info: log, warning: null, error: null);
    }
  }

  Future<void> commitChanges(String repoPath, String message) async {
    logger.i('Attempting to commit changes with message: "$message" in $repoPath');
    try {
      final addProcess =
          await Process.start('git', ['add', '.'], workingDirectory: repoPath);
      final addStdOut = await addProcess.stdout.transform(utf8.decoder).join();
      final addStdErr = await addProcess.stderr.transform(utf8.decoder).join();
      final addExitCode = await addProcess.exitCode;

      logger.i('Git add stdout: $addStdOut');
      logger.i('Git add stderr: $addStdErr');
      logger.i('Git add exitCode: $addExitCode');

      if (addExitCode != 0) {
        if (!addStdErr.toLowerCase().contains('lf will be replaced by crlf')) {
            throw Exception('Errore durante git add: $addStdErr');
        } else {
            logger.w('Git add warning: $addStdErr');
        }
      }

      final commitProcess = await Process.start(
          'git', ['commit', '-m', message, '--allow-empty'], // Allow empty for initial/automated commits
          workingDirectory: repoPath);
      final commitStdOut = await commitProcess.stdout.transform(utf8.decoder).join();
      final commitStdErr = await commitProcess.stderr.transform(utf8.decoder).join();
      final commitExitCode = await commitProcess.exitCode;

      logger.i('Git commit stdout: $commitStdOut');
      logger.i('Git commit stderr: $commitStdErr');
      logger.i('Git commit exitCode: $commitExitCode');

      if (commitExitCode != 0) {
        // "nothing to commit" is not an error for an automated system if --allow-empty is not used.
        // With --allow-empty, this specific check might not be needed, but good to be aware.
        if (commitStdErr.contains('nothing to commit') || commitStdErr.contains('no changes added to commit')) {
          logger.i('No actual changes to commit, but --allow-empty might have created an empty commit.');
        } else if (commitStdOut.contains('nothing to commit')){
           logger.i('No changes to commit (checked via stdout).');
        }
        else {
          //throw Exception('Error committing changes: $commitStdErr');
           logger.e('Error committing changes: $commitStdErr'); // Log as error but don't throw to allow UI update
        }
      }

      final currentCommit = await _getCurrentCommit(repoPath);
      if (!isClosed) {
        final existingCommits = state.common.repositoryState.commits;
        List<CommitEntity> newCommits = [currentCommit, ...existingCommits];
        // Avoid duplicate commits if currentCommit is already the head of existingCommits
        if (existingCommits.isNotEmpty && existingCommits.first.hash == currentCommit.hash) {
            newCommits = existingCommits;
        }

        emit(state.copyWith.common.repositoryState(
          commits: newCommits,
          currentCommit: currentCommit,
        ));
      }
      logger.i('Commit successful (or no changes). Current commit: ${currentCommit.hash}');
    } catch (e,s) {
      addError('Error committing changes: $e',s);
    }
  }

  Future<void> _createGitRepo(String folderPath) async {
    try {
      final isRepo = await _isGitRepository(folderPath);
      if (isRepo) {
        logger.i('Git repository already exists at $folderPath. Loading existing repository.');
        await loadRepository(folderPath);
        return;
      }
      if(isClosed) return;
      logger.i('Creating new Git repository at $folderPath.');
      emit(state.copyWith.common(
        repositoryState: const RepositoryState.creating(
          branches: [],
          currentBranch: 'main',
          commits: [],
          currentCommit: null,
        ),
      ));

      final isGitInstalled = await runGitCommand(['--version'], folderPath);
      if (!isGitInstalled.success) {
        if(isClosed) return;
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
        addError('Git is not installed: ${isGitInstalled.error}', StackTrace.current);
        return;
      }

      final initResult = await runGitCommand(['init', '-b', 'main'], folderPath); // Initialize with main branch
      if (!initResult.success) {
         if(isClosed) return;
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
        addError('Error initializing the git repository: ${initResult.error}', StackTrace.current);
        return;
      }
      await runGitCommand(['config', 'core.autocrlf', 'input'], folderPath);
      await File('$folderPath/.gitattributes').writeAsString('* text=auto eol=lf');
      // Create an initial empty commit so the branch 'main' exists.
      await commitChanges(folderPath, 'Initial commit (FusionForge)');
      await loadRepository(folderPath);
      logger.i('Repository initialized: ${initResult.output}');
    } catch (e,s) {
       addError('Error creating git repo: $e',s);
    }
  }

  Future<void> loadRepository(String folderPath) async {
    if (!await _isGitRepository(folderPath)) {
      logger.w('Attempted to load non-git repository: $folderPath');
      return;
    }
    if (isClosed) return;
    logger.i('Loading repository from $folderPath');
    final branches = await _getBranches(folderPath);
    final currentBranch = await _getCurrentBranch(folderPath);
    final String branchForCommits = branches.contains(currentBranch)
        ? currentBranch
        : (branches.isNotEmpty ? branches.first : 'main');

    final commits = await _getCommits(folderPath, branchForCommits);
    final currentCommit = await _getCurrentCommit(folderPath);

    logger.i('Loaded Branches: $branches, Current Branch: $currentBranch, Commits: ${commits.length}, Current Commit: ${currentCommit.hash}');
    if (isClosed) return;
    emit(state.copyWith.common(
      repositoryState: RepositoryState.created(
        branches: branches,
        currentBranch: currentBranch,
        commits: commits,
        currentCommit: currentCommit,
      ),
    ));
  }

  Future<GitCommandResult> runGitCommand(
      List<String> args, String workingDir) async {
    // Ensure workingDir exists before running git command
    final dir = Directory(workingDir);
    if (!await dir.exists()) {
      return GitCommandResult(success: false, output: '', error: 'Working directory $workingDir not found.');
    }
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

  Future<bool> _isGitRepository(String folderPath) async {
    final gitFolder = Directory('$folderPath/.git');
    return await gitFolder.exists();
  }

  Future<List<String>> _getBranches(String folderPath) async {
    final result = await runGitCommand(['branch', '--format=%(refname:short)'], folderPath);
    if (!result.success) {
      addError('Error retrieving branches: ${result.error}', StackTrace.current);
      return [];
    }
    return result.output.split('\n').where((b) => b.isNotEmpty).toList();
  }

  Future<List<CommitEntity>> _getCommits(
      String folderPath, String branch) async {
    if (branch.isEmpty) {
      logger.w('Attempted to get commits for an empty branch name.');
      return [];
    }
    // Check if branch exists before trying to get logs
    final branches = await _getBranches(folderPath);
    if (!branches.contains(branch) && branch != 'HEAD') { // HEAD is a valid ref for commits
        logger.w('Branch "$branch" does not exist in repository $folderPath. Known branches: $branches');
        // Try to get commits from current HEAD if specified branch not found
        final headResult = await runGitCommand(['log', '--pretty=format:%H %s', 'HEAD'], folderPath);
        if (headResult.success) {
            return headResult.output.split('\n').where((l) => l.isNotEmpty).map((line) {
                final parts = line.split(' ');
                final hash = parts.isNotEmpty ? parts[0] : '';
                final message = parts.length > 1 ? parts.sublist(1).join(' ') : '';
                return CommitEntity(hash: hash, message: message);
            }).toList();
        }
        return []; // Still no commits if HEAD fails
    }

    final result = await runGitCommand(
      ['log', '--pretty=format:%H %s', branch],
      folderPath,
    );
    if (!result.success) {
      logger.w('Error retrieving commits for branch "$branch": ${result.error}');
      return [];
    }
    return result.output.split('\n').where((l) => l.isNotEmpty).map((line) {
      final parts = line.split(' ');
      final hash = parts.isNotEmpty ? parts[0] : '';
      final message = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      return CommitEntity(hash: hash, message: message);
    }).toList();
  }

  Future<String> _getCurrentBranch(String folderPath) async {
    final result =
        await runGitCommand(['rev-parse', '--abbrev-ref', 'HEAD'], folderPath);
    if (!result.success) {
      addError('Error retrieving the current branch: ${result.error}', StackTrace.current);
      return '';
    }
    final currentBranch = result.output.trim();
    if (currentBranch == 'HEAD') { // Indicates detached HEAD
      final detachedResult = await runGitCommand(
        ['describe', '--tags', '--always', '--dirty'],
        folderPath,
      );
      if (detachedResult.success) {
        return '(HEAD detached at ${detachedResult.output.trim()})';
      }
       // Fallback if describe fails
      final commitHash = await runGitCommand(['rev-parse', '--short', 'HEAD'], folderPath);
      if (commitHash.success) {
        return '(HEAD detached at ${commitHash.output.trim()})';
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
      addError('Error retrieving the current commit hash: ${result.error}', StackTrace.current);
      return const CommitEntity(hash: '', message: '');
    }
    final hash = result.output.trim();
    if (hash.isEmpty) return const CommitEntity(hash: '', message: '');

    final messageResult = await runGitCommand(
      ['log', '--pretty=format:%s', '-n', '1', hash],
      folderPath,
    );
    if (!messageResult.success) {
      addError('Error retrieving the current commit message: ${messageResult.error}', StackTrace.current);
      return CommitEntity(hash: hash, message: '');
    }
    final message = messageResult.output.trim();
    return CommitEntity(hash: hash, message: message);
  }

  Future<void> changeBranch(String branch) async {
    final projectPath = state.common.projectAppPath;
    final result = await runGitCommand(['checkout', branch], projectPath);
    if (!result.success) {
      addError('Error changing branch: ${result.error}', StackTrace.current);
      return;
    }
    await loadRepository(projectPath); // Reload repository state
  }

  void createBranch(String projectPath, String branch) async {
    final result = await runGitCommand(['checkout', '-b', branch], projectPath);
    if (!result.success) {
      addError('Error creating branch: ${result.error}', StackTrace.current);
      return;
    }
    await loadRepository(projectPath); // Reload repository state
  }

  void deleteBranch(String projectPath, String branch) async {
    final currentBranch = await _getCurrentBranch(projectPath);
    if (branch == currentBranch) {
      // Cannot delete current branch directly, checkout to another first
      final branches = await _getBranches(projectPath);
      final otherBranch = branches.firstWhere((b) => b != branch, orElse: () => '');
      if (otherBranch.isNotEmpty) {
        await runGitCommand(['checkout', otherBranch], projectPath);
      } else {
        addError('Cannot delete branch "$branch" as it is the current and only branch.', StackTrace.current);
        return;
      }
    }
    final result = await runGitCommand(['branch', '-D', branch], projectPath);
    if (!result.success) {
      addError('Error deleting branch: ${result.error}', StackTrace.current);
      return;
    }
    await loadRepository(projectPath); // Reload repository state
  }

  Future<void> changeCommit(String commitHash) async {
    final projectPath = state.common.projectAppPath;
    final result = await runGitCommand(['checkout', commitHash], projectPath);
    if (!result.success) {
      addError('Error changing commit: ${result.error}', StackTrace.current);
      return;
    }
    await loadRepository(projectPath); // Reload repository state
  }

  Future<void> runApp({
    int port = 8080,
  }) async {
    if (state.common.sdkType != ProjectSDK.flutter) {
      logger.i('RunApp: Skipped for non-Flutter project. Expo IDE is managed via WebView.');
      if(isClosed) return;
      // Ensure state reflects that Expo "run" means IDE is ready/loading
      emit(ProjectContextState.running(common: state.common, localhostPort: 0));
      return;
    }
    if(isClosed) return;
    logger.i('Running Flutter project for web server preview...');
    emit(ProjectContextState.starting(
      common: state.common,
    ));
    try { // Added try for p.kill()
      if (::p.toString().contains('pid')) { // A bit hacky check if p was initialized
         tryCatch(() => p.kill());
      }
    } catch(e) {
        logger.w('Error trying to kill previous process (might not exist): $e');
    }
    p = await Process.start(
      'flutter',
      ['run', '-d', 'web-server', '--web-port', port.toString()],
      workingDirectory: state.common.projectAppPath,
      runInShell: true,
    );
    addPid(p.pid);
    p.stdout.transform(utf8.decoder).listen((output) { // Changed event to output
      if (output.contains('is being served at http://localhost:')) {
        if (isClosed) return;
        emit(
          ProjectContextState.running(
            common: state.common,
            localhostPort: port,
          ),
        );
        _addConsoleLog(output);
        return;
      }
      _addConsoleLog(output);
      if (output.contains('Error') || output.contains('Exception')) {
        if (isClosed) return;
        _addAnalyzerError(output); // Use specific method for analyzer errors
      }
    });
    p.stderr.transform(utf8.decoder).listen((error) { // Changed event to error
      _addConsoleLog('error $error');
      _addAnalyzerError('error $error'); // Also log stderr to analyzer errors
    });
    final exitCode = await p.exitCode;
    if (exitCode != 0) {
      if (isClosed) return;
      emit(
        ProjectContextState.exceptionProjectNotRunned(
          common: state.common.copyWith.consoleState(
            logs: [...state.common.consoleState.logs, 'Failed to run the Flutter project'],
          ),
          errorMessage: 'Failed to run the Flutter project (exit code: $exitCode)',
        ),
      );
    }
  }

  void runOrReload() {
    if (state.common.sdkType == ProjectSDK.flutter) {
      try {
        p.pid; // Check if p is initialized and process is likely running
        reloadProcess();
      } catch (e) { // p.pid might throw if process not started or p not assigned
        runApp();
      }
    } else {
      logger.i('RunOrReload for Expo: This should trigger a state for WebViewArea to load/refresh Expo IDE.');
      // For Expo, this means the WebView should load the Expo IDE URL.
      // Emitting .running state signals WebViewArea to load its URL.
      if(!isClosed) emit(ProjectContextState.running(common: state.common, localhostPort: 0));
    }
  }

  Future<void> reloadProcess() async {
    if (state.common.sdkType == ProjectSDK.flutter) {
      try {
        logger.i('Attempting Flutter hot reload...');
        p.stdin.writeln('r');
        await analyzeProject();
      } catch (e,s) {
        addError('Error reloading the Flutter app: $e',s);
      }
    } else {
      logger.i('ReloadProcess for Expo: This should signal WebView IDE to refresh its preview (e.g., via JSChannel).');
      // Action for Step 3: Send JS message to WebView to trigger Expo IDE refresh
      // For now, this log indicates the intent.
    }
  }

  void stopProcess() {
     if (state.common.sdkType == ProjectSDK.flutter) {
        try { // Added try for p.kill()
            if (::p.toString().contains('pid')) tryCatch(() => p.kill());
        } catch(e) {
            logger.w('Error trying to kill Flutter process (might not exist): $e');
        }
     } else {
        logger.i('StopProcess for Expo: No direct process to kill from here. May involve clearing WebView.');
     }
    if(isClosed) return;
    emit(ProjectContextState.notStarted(common: state.common));
  }

  Future<void> killProcessAndRestart() async {
    if (state.common.sdkType == ProjectSDK.flutter) {
      logger.i('Killing and restarting Flutter process...');
      try {
         if (::p.toString().contains('pid')) await p.kill(); // await kill
         if(isClosed) return;
        emit(ProjectContextState.notStarted(common: state.common));
      } catch (e,s) {
        addError('Error killing Flutter app: $e',s);
      }
      await runApp();
    } else {
      logger.i('KillAndRestart for Expo: Signal WebView IDE to perform a full project reload/rebuild.');
      // Action for Step 3: Send JS message to WebView to trigger Expo IDE full reload.
      // For now, this could re-emit the running state to force WebViewArea to reload URL.
      if(!isClosed) emit(ProjectContextState.running(common: state.common, localhostPort: 0));
    }
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    logger.e(
      'Error in ProjectContextCubit',
      error: error.toString(),
      stackTrace: stackTrace,
    );
    _addConsoleLog(error.toString()); // Also log to in-app console
    super.onError(error, stackTrace);
  }

  @override
  ProjectContextState? fromJson(Map<String, dynamic> json) {
    final pids = json['pids'] as List<dynamic>? ?? [];
    for (final pid in pids) {
      if (pid is int) {
          try {
             Process.killPid(pid);
          } catch (e) {
            logger.w('Error killing PID $pid from persisted state: $e');
          }
      }
    }

    if (json.containsKey(this.projectID)) {
      final messagesDataForCurrentProject = json[this.projectID] as List<dynamic>? ?? [];
      final rehydratedMessages = messagesDataForCurrentProject
          .map((e) => types.Message.fromJson(e as Map<String, dynamic>))
          .toList();

      // Create a new CommonEditorState with rehydrated messages, but keep current projectPath & sdkType
      // The initial state of the cubit (from constructor) provides the correct projectPath, projectID, sdkType.
      // We only want to overlay the chat messages.
      final initialCommonState = ProjectContextState.notStarted(
                                  common: CommonEditorState(
                                    projectID: this.projectID, // from instance
                                    projectPath: this.state.common.projectPath, // from current initial state
                                    sdkType: this.state.common.sdkType, // from current initial state
                                  )).common;

      return ProjectContextState.notStarted(
        common: initialCommonState.copyWith.chatState(messages: rehydratedMessages),
      );
    }
    return null;
  }

  @override
  Map<String, dynamic>? toJson(ProjectContextState state) {
    final pids = state.common.cliProcessState.pids;
    final messages = state.common.chatState.messages;
    return {
      'pids': pids,
      this.projectID: messages.map((e) => e.toJson()).toList(),
    };
  }
}
