import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'OPENAI_KEY', obfuscate: true)
  static final String openAIKey = _Env.openAIKey;

  @EnviedField(varName: 'PORT')
  static const int port = _Env.port;
}
