import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/notifications_repository.dart';
import '../admin/admin_home_screen.dart';
import '../caretaker/caretaker_home_screen.dart';
import '../doctor/doctor_home_screen.dart';
import '../incharge/incharge_home_screen.dart';
import '../patient/patient_shell.dart';
import 'sign_in_screen.dart';

/// Routes the signed-in user to the dashboard for their role (Section 26:
/// "Role-based navigation should expose only the features appropriate to
/// the logged-in role"). This is a UX convenience only — the real
/// enforcement is Firestore Security Rules on the Firebase side
/// (replacing Section 46's RLS); nothing here should be treated as a
/// security boundary.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authRepo = AuthRepository();
  final _notificationsRepo = NotificationsRepository();

  // Tracks which signed-in user we've already requested notification
  // permission and registered a device token for, so re-registering isn't
  // retried on every rebuild this widget happens to go through — only
  // once per session, and again if a different account signs in.
  String? _tokenRegisteredFor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authRepo.onAuthStateChange,
      builder: (context, snapshot) {
        final user = _authRepo.currentUser;
        if (user == null) {
          return const SignInScreen();
        }
        return FutureBuilder<Profile?>(
          // Re-fetch on every auth event so switching accounts or a fresh
          // sign-up reflects immediately.
          future: _authRepo.fetchCurrentProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final profile = profileSnapshot.data;
            if (profile == null) {
              return const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Your account was created but has no profile yet. '
                      'Please contact the person who set up your MedGuard access.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }
            // Fire-and-forget: request permission and register this
            // device's FCM token once per signed-in profile (Section 43) —
            // never blocks routing to the dashboard, and re-registering is
            // a harmless no-op if it somehow fires more than once.
            if (_tokenRegisteredFor != profile.id) {
              _tokenRegisteredFor = profile.id;
              _notificationsRepo.registerForUser(profile.id);
            }
            switch (profile.role) {
              case AppRole.admin:
                return AdminHomeScreen(profile: profile);
              case AppRole.doctor:
                return DoctorHomeScreen(profile: profile);
              case AppRole.incharge:
                return InchargeHomeScreen(profile: profile);
              case AppRole.caretaker:
                return CaretakerHomeScreen(profile: profile);
              case AppRole.patient:
                return PatientShell(profile: profile);
            }
          },
        );
      },
    );
  }
}
