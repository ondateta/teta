import 'package:go_router/go_router.dart';
import 'package:teta_oss/main.dart';
import 'package:teta_oss/presentation/splash/splash.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashView(),
      redirect: (context, state) => '/project/app',
    ),
    ...teta.routes,
  ],
);
