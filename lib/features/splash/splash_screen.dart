import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../auth/auth_gate.dart';

/// MedGuard's branded splash screen — shown first, right after the Flutter
/// engine draws its first frame (the native launch screen,
/// android/app/src/main/res/drawable/launch_background.xml, covers the
/// instant before that). Purely a brand moment: it holds the logo on
/// screen for a short beat, then hands off to [AuthGate], which does the
/// actual sign-in/role-routing work and has its own loading state for
/// that. Keeping those two responsibilities separate means AuthGate never
/// has to know it's sometimes the "first" screen and sometimes not.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _minimumDisplay = Duration(milliseconds: 1100);

  @override
  void initState() {
    super.initState();
    Future.delayed(_minimumDisplay, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF7F9F9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(
              image: AssetImage('assets/branding/logo.png'),
              width: 180,
              height: 180,
            ),
            SizedBox(height: 20),
            Text(
              'MedGuard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Smart Medication Adherence & Monitoring',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
