import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/splash/splash_screen.dart';

class MedGuardApp extends StatelessWidget {
  const MedGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const SplashScreen(),
    );
  }
}
