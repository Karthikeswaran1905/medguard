import 'package:flutter/material.dart';

import '../../data/models/profile.dart';
import 'ai_insights_screen.dart';
import 'medications_list_screen.dart';
import 'patient_home_screen.dart';
import 'profile_screen.dart';

/// Bottom-navigation shell for the Patient role: Home / Medicines /
/// Adherence / Profile — matches the finalized MedGuardian screen spec's
/// 4-tab patient nav exactly (that doc gives Health Records no tab of its
/// own; it's a Profile quick-access link instead, alongside AI Assistant,
/// Drug Interaction Checker, Emergency QR and scanned prescriptions — see
/// `profile_screen.dart`). One `Scaffold` owns the bottom nav bar; each tab
/// is plain content (no nested `Scaffold`/`AppBar`) held alive in an
/// `IndexedStack` so switching tabs doesn't lose scroll position or
/// re-trigger a load.
class PatientShell extends StatefulWidget {
  final Profile profile;
  const PatientShell({super.key, required this.profile});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      PatientHomeScreen(profile: widget.profile),
      MedicationsListScreen(profile: widget.profile),
      AiInsightsScreen(profile: widget.profile),
      ProfileScreen(profile: widget.profile),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: tabs),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication),
              label: 'Medicines'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Adherence'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
