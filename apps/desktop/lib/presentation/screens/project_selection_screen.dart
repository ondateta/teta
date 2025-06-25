import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:teta_oss/core/project_management/project_service.dart';
import 'package:teta_oss/core/project_management/project_model.dart';

class ProjectSelectionScreen extends StatefulWidget {
  const ProjectSelectionScreen({super.key});

  @override
  State<ProjectSelectionScreen> createState() => _ProjectSelectionScreenState();
}

class _ProjectSelectionScreenState extends State<ProjectSelectionScreen> {
  late Future<List<Project>> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  void _loadProjects() {
    // Use context.read safely if initState is guaranteed to run after provider is available.
    // If not, consider passing projectService or using a FutureBuilder directly with the service call.
    _projectsFuture = context.read<ProjectService>().getAllProjects();
  }

  void _navigateToCreateProject() {
    context.go('/create-project');
  }

  void _openProject(BuildContext context, Project project) {
    // Before navigating, update last opened time
    context.read<ProjectService>().recordProjectOpened(project.id).then((_) {
      // Navigate to the project's default view (e.g., design)
      // The router will handle creating TetaEditor instance via EditorShellScreen
      context.go('/project/${project.id}');
    }).catchError((error) {
      // Handle error, e.g., show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording project open: $error')),
      );
    });
  }

  void _deleteProject(BuildContext context, String projectId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: const Text('Are you sure you want to delete this project? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // User canceled
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // User confirmed
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await context.read<ProjectService>().deleteProject(projectId);
        setState(() {
          _loadProjects(); // Refresh the list
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting project: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FusionForge Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create New Project',
            onPressed: _navigateToCreateProject,
          ),
        ],
      ),
      body: FutureBuilder<List<Project>>(
        future: _projectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading projects: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No projects found.'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _navigateToCreateProject,
                    child: const Text('Create Your First Project'),
                  ),
                ],
              ),
            );
          }

          final projects = snapshot.data!;
          // Sort projects by lastOpenedAt in descending order
          projects.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));

          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return ListTile(
                title: Text(project.name),
                subtitle: Text('SDK: ${project.sdkType.name}\nPath: ${project.path}\nLast Opened: ${project.lastOpenedAt.toLocal()}'),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Delete Project',
                  onPressed: () => _deleteProject(context, project.id),
                ),
                onTap: () => _openProject(context, project),
              );
            },
          );
        },
      ),
    );
  }
}
