import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/theme/app_theme.dart';
import 'router.dart';

class BennetApp extends ConsumerWidget {
  const BennetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: bennetTheme(Brightness.light),
      darkTheme: bennetTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
