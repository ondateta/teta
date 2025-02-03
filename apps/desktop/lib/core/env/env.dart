import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'PROJECT_PATH')
  static const String projectPath = _Env.projectPath;

  @EnviedField(varName: 'SERVER_URL')
  static const String serverUrl = _Env.serverUrl;
}
