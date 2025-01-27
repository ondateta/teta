import 'dart:io';

import 'package:editor/core/constants.dart';
import 'package:editor/extensions/index.dart';
import 'package:editor/ui/ds/hover_builder.dart';
import 'package:editor/ui/editor/blocs/editor.cubit.dart';
import 'package:editor/ui/editor/blocs/states/editor/editor.state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class EditorPageCode extends StatefulWidget {
  const EditorPageCode({
    super.key,
    required this.id,
    required this.fileRef,
    required this.commitHash,
  });
  final String id;
  final String? fileRef;
  final String? commitHash;

  @override
  State<EditorPageCode> createState() => _EditorPageCodeState();
}

class _EditorPageCodeState extends State<EditorPageCode> {
  late Map<String, String Function()> files;
  late ValueNotifier<String> editorCodeCurrentFilePath;
  CodeLanguages language = CodeLanguages.dart;
  String code = '';
  late String commitHash;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    editorCodeCurrentFilePath = ValueNotifier(widget.fileRef ?? 'pubspec.yaml');
    if (widget.commitHash == null) {
      commitHash =
          context.editor.state.common.repositoryState.currentCommit?.hash ??
              'HEAD';
    } else {
      commitHash = widget.commitHash!;
    }
    loadFiles().then((value) {
      setCodeField();
      isLoading = false;
      setState(() {});
    });

    editorCodeCurrentFilePath.addListener(() {
      setCodeField();
    });
  }

  @override
  void didUpdateWidget(EditorPageCode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileRef != widget.fileRef ||
        oldWidget.commitHash != widget.commitHash) {
      if (widget.commitHash == null) {
        commitHash =
            context.editor.state.common.repositoryState.currentCommit?.hash ??
                'HEAD';
      } else {
        commitHash = widget.commitHash!;
      }
      loadFiles().then((value) {
        setState(() {});
        editorCodeCurrentFilePath.value = widget.fileRef ?? files.keys.first;
        setCodeField();
        isLoading = false;
      });
    }
  }

  Future<Map<String, String>> viewAllFilesInCommit(String commitHash) async {
    final projectPath = context.editor.state.common.projectAppPath;

    // Ottieni la lista completa di file presenti nel commit
    final fileListResult = await context.editor.runGitCommand(
      ['ls-tree', '-r', '--name-only', commitHash],
      projectPath,
    );

    if (!fileListResult.success) {
      logger.e('Error retrieving all files in commit: ${fileListResult.error}');
      return {};
    }

    // Lista di file nel commit
    final files = fileListResult.output
        .split('\n')
        .map((file) => file.trim())
        .where((file) => file.isNotEmpty)
        .toList();

    logger.i('Found ${files.length} files for commit $commitHash');

    // Ottieni il contenuto di ciascun file
    final fileContents = <String, String>{};
    for (final file in files) {
      final admitted = file.startsWith('lib/') ||
          file.startsWith('test/') ||
          file.contains('pubspec.yaml');
      if (!admitted) {
        continue;
      }
      logger.i('Loading content for file $file');

      final fileContentResult = await context.editor.runGitCommand(
        ['show', '$commitHash:$file'],
        projectPath,
      );

      if (!fileContentResult.success) {
        logger.e(
            'Error retrieving content for file $file: ${fileContentResult.error}');
        continue;
      }

      fileContents[file] = fileContentResult.output;
    }

    logger.i('Loaded ${fileContents.length} files for commit $commitHash');

    return fileContents;
  }

  Future<void> loadFiles() async {
    logger.i('Loading files for commit $commitHash');
    final tempFiles = await viewAllFilesInCommit(widget.commitHash ?? 'HEAD');
    files = {};
    logger.i('Loaded $tempFiles from viewAllFilesInCommit');
    for (final e in tempFiles.entries) {
      final path = e.key;
      final relativePath = path.split(context.editor.projectID).last;
      files[relativePath] = () => e.value;
    }
    if (!files.containsKey(editorCodeCurrentFilePath.value)) {
      editorCodeCurrentFilePath.value = files.keys.first;
      editorCodeCurrentFilePath.notifyListeners();
    }
    setState(() {});
  }

  void setCodeField() {
    final fileFormat = editorCodeCurrentFilePath.value.split('.').last;
    switch (fileFormat) {
      case 'dart':
        language = CodeLanguages.dart;
        break;
      case 'yaml':
        language = CodeLanguages.yaml;
        break;
    }
    code = files[editorCodeCurrentFilePath.value]!();
    setState(() {});
  }

  @override
  void dispose() {
    editorCodeCurrentFilePath.dispose();
    super.dispose();
  }

  void changeCommit(String hash) {
    logger.i('Changing commit to $hash');
    context.go('/project/${widget.id}/code/file?hash=$hash');
  }

  Future<void> changeBranch(String branch) async {
    await context.editor.changeBranch(branch);
    loadFiles();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    const sidebarSize = 300.0;
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return <Widget>[
      ValueListenableBuilder(
        valueListenable: editorCodeCurrentFilePath,
        builder: (context, state, child) {
          return CodeWidget(
            code: code,
            language: language,
            onCodeChange: (code) {
              logger.i(
                  'Saving code to file at ${context.projectAppPath}/${editorCodeCurrentFilePath.value}');
              File('${context.projectAppPath}/${editorCodeCurrentFilePath.value}')
                  .writeAsStringSync(code);
            },
          );
        },
      ).positioned(
        left: sidebarSize,
        top: 0,
        right: 0,
        bottom: 0,
      ),
      <Widget>[
        BlocBuilder<FlutterRunCubit, FlutterRunState>(
          builder: (context, state) {
            return [
              const Text('Branches'),
              state.common.repositoryState.maybeMap(
                orElse: () => nil,
                created: (e) => ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: e.branches.length,
                  itemBuilder: (context, index) {
                    return HoverBuilder(
                      builder: (context, isHovered) => [
                        const Icon(LucideIcons.gitBranch, size: 18),
                        Text('Branch ${e.branches[index]}',
                            style: context.bodyMedium.copyWith(
                              color: e.currentBranch == e.branches[index]
                                  ? theme.primaryColor
                                  : isHovered
                                      ? Colors.grey
                                      : null,
                            )).expanded()
                      ].spacing(8).row().paddingV(8).pointer().onTap(
                            () => changeBranch(e.branches[index]),
                          ),
                    );
                  },
                ),
              ),
            ].column();
          },
        ),
        16.gap,
        BlocBuilder<FlutterRunCubit, FlutterRunState>(
          builder: (context, state) {
            return DropdownButton<String>(
              isExpanded: true,
              menuWidth: 600,
              value: state.common.repositoryState.commits
                      .map((e) => e.hash)
                      .toSet()
                      .contains(commitHash)
                  ? commitHash
                  : null,
              items: [
                for (final e in state.common.repositoryState.commits) ...[
                  DropdownMenuItem(
                    value: e.hash,
                    child: [
                      [
                        const Icon(LucideIcons.gitBranch, size: 18),
                        if (state.common.repositoryState.currentCommit?.hash ==
                            e.hash)
                          Text(
                            'CURRENT',
                            style: context.labelMedium.copyWith(
                              color: Colors.yellow,
                            ),
                          ).paddingV(4).paddingH(8).decorated(
                                BoxDecoration(
                                  color: Colors.yellow.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                        Text(
                          'Commit ${e.message}',
                          style: context.bodyMedium.copyWith(
                            color: commitHash == e.hash
                                ? theme.primaryColor
                                : theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ).expanded(),
                      ].spacing(8).row(cross: CrossAxisAlignment.start)
                    ].column(),
                  ),
                ],
              ],
              onChanged: (e) {
                changeCommit(e!);
              },
            );
          },
        ),
        16.gap,
        const Text('Files'),
        ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files.keys.toList()[index];
            return HoverBuilder(
              builder: (context, isHovered) => ValueListenableBuilder(
                  valueListenable: editorCodeCurrentFilePath,
                  builder: (context, currentPath, child) {
                    final bool selected = currentPath == file;
                    return [
                      const Icon(LucideIcons.fileCode, size: 18),
                      Text(file,
                          style: context.bodyMedium.copyWith(
                            color: selected
                                ? theme.colorScheme.primary
                                : isHovered
                                    ? Colors.grey
                                    : null,
                          )).expanded()
                    ]
                        .spacing(8)
                        .row()
                        .paddingV(8)
                        .pointer(disable: selected)
                        .onTap(() => context.go(
                            '/project/${widget.id}/code/file?ref=$file&hash=$commitHash'));
                  }),
            );
          },
        ),
      ]
          .listView()
          .paddingAll(16)
          .width(sidebarSize)
          .decorated(
            BoxDecoration(
              color: context.theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
          )
          .positioned(left: 0, top: 8, bottom: 8),
    ].stack();
  }
}

enum CodeLanguages {
  dart,
  yaml,
}

class CodeWidget extends StatefulWidget {
  const CodeWidget({
    super.key,
    required this.code,
    required this.language,
    required this.onCodeChange,
    this.enabled = true,
  });

  final String code;
  final CodeLanguages language;
  final Function(String) onCodeChange;
  final bool enabled;

  @override
  State<CodeWidget> createState() => _CodeWidgetState();
}

class _CodeWidgetState extends State<CodeWidget> {
  CodeController controller = CodeController(
    language: dart,
  );

  @override
  void initState() {
    super.initState();
    setField();
  }

  @override
  void didUpdateWidget(covariant CodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code ||
        oldWidget.language != widget.language) {
      setField();
    }
  }

  void setField() {
    switch (widget.language) {
      case CodeLanguages.dart:
        controller = CodeController(
          language: dart,
        );
        break;
      case CodeLanguages.yaml:
        controller = CodeController(
          language: yaml,
        );
        break;
    }
    controller.fullText = widget.code;
  }

  @override
  Widget build(BuildContext context) {
    return CodeTheme(
      data: CodeThemeData(styles: monokaiSublimeTheme),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 0,
          top: 16,
          right: 8,
          bottom: 8,
        ),
        child: CodeField(
          enabled: widget.enabled,
          controller: controller,
          onChanged: (e) {
            widget.onCodeChange(e);
          },
          background: Colors.transparent,
          textStyle: context.bodyMedium,
          lineNumberStyle: GutterStyle(
            textStyle: context.bodyLarge.copyWith(
              color: context.theme.colorScheme.inverseSurface.withOpacity(0.2),
            ),
          ),
        ),
      ),
    );
  }
}
