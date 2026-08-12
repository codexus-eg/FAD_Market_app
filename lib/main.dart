import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppController.init();

  runApp(const FceCncApp());
}

class FceCncApp extends StatelessWidget {
  const FceCncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppController.language,
      builder: (context, lang, child) {
        return MaterialApp(
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);

            return Directionality(
              textDirection: AppController.direction,
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: const TextScaler.linear(0.86),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          locale: Locale(lang),
          title: 'FAD Market',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFD4A02A),
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
