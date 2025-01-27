import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'PORT')
  static const int port = _Env.port;

  @EnviedField(varName: 'LLM_KEY', obfuscate: true)
  static final String llmKey = _Env.llmKey;

  @EnviedField(varName: 'LLM_BASE_URL')
  static final String llmBaseUrl = _Env.llmBaseUrl;

  @EnviedField(varName: 'LLM_MODEL')
  static final String llmModel = _Env.llmModel;
}
