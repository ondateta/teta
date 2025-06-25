import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:teta_oss/core/project_management/project_service.dart';
import 'package:teta_oss/core/project_management/project_model.dart';
import 'dart:io'; // For Directory operations
// import 'package:file_picker/file_picker.dart'; // For directory picker

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  String _projectName = '';
  String _projectPath = ''; // We might use a directory picker for this
  ProjectSDK _sdkType = ProjectSDK.flutter; // Default SDK

  // TODO: Implement a directory picker. For now, manual path input.
  // Future<void> _pickDirectory() async {
  //   String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
  //   if (selectedDirectory != null) {
  //     setState(() {
  //       _projectPath = selectedDirectory;
  //     });
  //   }
  // }

  Future<void> _createProject() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Validate project path and create directory if it doesn't exist
      if (_projectPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project path cannot be empty.')),
        );
        return;
      }

      final projectDir = Directory(_projectPath);
      try {
        if (!await projectDir.exists()) {
          await projectDir.create(recursive: true);
        }
        // Check if directory is empty or suitable for a new project
        // For now, we assume it's okay if it exists or is newly created.
        // More checks could be added (e.g., if it's already a Teta/FusionForge project).

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error with project directory: $e')),
        );
        return;
      }

      final newProject = Project.create(
        name: _projectName,
        path: _projectPath,
        sdkType: _sdkType,
      );

      try {
        final projectService = context.read<ProjectService>();
        await projectService.addProject(newProject);

        // Navigate to the new project's editor view
        // The router will handle creating TetaEditor instance via EditorShellScreen
        if (mounted) {
          context.go('/project/${newProject.id}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating project: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Project')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( // Changed to ListView to prevent overflow with keyboard
            children: <Widget>[
              TextFormField(
                decoration: const InputDecoration(labelText: 'Project Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a project name';
                  }
                  return null;
                },
                onSaved: (value) => _projectName = value!,
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Project Path (Full Directory Path)',
                  hintText: 'e.g., /Users/yourname/FusionForgeProjects/MyNewApp',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a project path';
                  }
                  // Basic path validation (optional, can be more complex)
                  // For now, just ensuring it's not empty.
                  // Directory existence is checked in _createProject
                  return null;
                },
                onSaved: (value) => _projectPath = value!,
                // TODO: Add a button to trigger _pickDirectory here
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<ProjectSDK>(
                decoration: const InputDecoration(labelText: 'Select SDK'),
                value: _sdkType,
                items: ProjectSDK.values.map((ProjectSDK sdk) {
                  return DropdownMenuItem<ProjectSDK>(
                    value: sdk,
                    child: Text(sdk.name),
                  );
                }).toList(),
                onChanged: (ProjectSDK? newValue) {
                  setState(() {
                    _sdkType = newValue!;
                  });
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _createProject,
                child: const Text('Create Project'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
