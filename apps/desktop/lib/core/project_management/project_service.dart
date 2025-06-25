import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'project_model.dart';

class ProjectService {
  static const String _fileName = '.fusionforge_projects.json';
  String? _cachedProjectsPath; // Cache the path to avoid repeated lookups

  Future<String> _getProjectsFilePath() async {
    if (_cachedProjectsPath != null) return _cachedProjectsPath!;
    // Use getApplicationSupportDirectory for cross-platform compatibility,
    // though Teta was macOS only, FusionForge might not be.
    final directory = await getApplicationSupportDirectory();
    _cachedProjectsPath = '${directory.path}/$_fileName';
    return _cachedProjectsPath!;
  }

  Future<List<Project>> getAllProjects() async {
    try {
      final filePath = await _getProjectsFilePath();
      final file = File(filePath);
      if (!await file.exists()) {
        return [];
      }
      final content = await file.readAsString();
      if (content.isEmpty) {
        return [];
      }
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((json) => Project.fromJson(json)).toList();
    } catch (e) {
      print('Error reading projects: $e');
      return [];
    }
  }

  Future<void> _saveProjects(List<Project> projects) async {
    try {
      final filePath = await _getProjectsFilePath();
      final file = File(filePath);
      final jsonList = projects.map((project) => project.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error saving projects: $e');
    }
  }

  Future<Project?> getProjectById(String id) async {
    final projects = await getAllProjects();
    try {
      return projects.firstWhere((project) => project.id == id);
    } catch (e) {
      return null; // Not found
    }
  }

  Future<void> addProject(Project project) async {
    final projects = await getAllProjects();
    // Ensure no project with the same path exists to avoid conflicts
    if (projects.any((p) => p.path == project.path)) {
        // Or handle this with a more specific error/user feedback
        print('Error: Project with path ${project.path} already exists.');
        return;
    }
    projects.add(project);
    await _saveProjects(projects);
  }

  Future<void> updateProject(Project updatedProject) async {
    final projects = await getAllProjects();
    final index = projects.indexWhere((project) => project.id == updatedProject.id);
    if (index != -1) {
      projects[index] = updatedProject;
      await _saveProjects(projects);
    } else {
      print('Error: Project with id ${updatedProject.id} not found for update.');
    }
  }

  Future<void> deleteProject(String id) async {
    final projects = await getAllProjects();
    projects.removeWhere((project) => project.id == id);
    await _saveProjects(projects);
    // Note: This does not delete the actual project files from disk.
    // That might be a separate, more dangerous operation to add later.
  }

  Future<void> recordProjectOpened(String id) async {
    final project = await getProjectById(id);
    if (project != null) {
      project.lastOpenedAt = DateTime.now();
      await updateProject(project);
    }
  }
}
