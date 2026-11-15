import 'package:flutter/material.dart';

import '../../data/models/profile.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';
import 'alert_center_screen.dart';
import 'notifications_screen.dart';
import 'patient_list_screen.dart';

/// Caretaker Dashboard (Section 7, 27; MedGuardian screen spec C1) — the
/// day-to-day monitoring hub and launch point for the other six Caretaker
/// MVP screens: Assigned Patients (-> Patient Details -> Medication
/// Status), Alert Center (-> Alert Details/Verify, reusing
/// [AlertDetailScreen] from `alert_detail_screen.dart`) and Notifications.
///
/// This single screen used to hold every Caretaker feature inline (an
/// assigned-patients list with a popup-menu of actions, a "needs
/// verification" list with inline verify buttons, AI insights). The
/// finalized spec wants each responsibility as its own screen instead,
/// matching the Admin/Doctor/Incharge rebuilds — so this is now just the
/// hub: stat counts plus a nav card into each.
class CaretakerHomeScreen extends StatefulWidget {
  final Profile profile;
  const CaretakerHomeScreen({super.key, required this.profile});

  @override
  State<CaretakerHomeScreen> createState() => _CaretakerHomeScreenState();
}

class _CaretakerHomeScreenState extends State<CaretakerHomeScreen> {
  final _peopleRepo = PeopleRepository();
  final _medRepo = MedicationRepository();
  final _analyticsRepo = AnalyticsRepository();
  late Future<_CaretakerSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CaretakerSummary> _load() async {
    final patients = await _peopleRepo.fetchPatientsForCaretaker(widget.profile.id);
    final patientIds = patients.map((p) => p.id).toList();
    final pending = await _medRepo.fetchPendingForPatients(patientIds);
    final stats = await _analyticsRepo.statsForPatients(patientIds);
    return _CaretakerSummary(
      patientCount: patients.length,
      pendingCount: pending.length,
      stats: stats,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Caretaker',
      profile: widget.profile,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_CaretakerSummary>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    StatTile(label: 'Assigned patients', value: '${data.patientCount}'),
                    StatTile(
                      label: 'Pending alerts',
                      value: '${data.pendingCount}',
                      color: data.pendingCount == 0 ? null : Colors.red.shade700,
                    ),
                    StatTile(label: 'Adherence', value: '${data.stats.adherencePercent.round()}%'),
                  ],
                ),
                const SectionHeader(title: 'Manage'),
                _NavCard(
                  icon: Icons.people_outline,
                  title: 'Assigned patients',
                  subtitle: 'View your patients and their medication status',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CaretakerPatientListScreen(profile: widget.profile),
                  )),
                ),
                _NavCard(
                  icon: Icons.notification_important_outlined,
                  title: 'Alert center',
                  subtitle: 'Doses that need your verification',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CaretakerAlertCenterScreen(profile: widget.profile),
                  )),
                ),
                _NavCard(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Your notification history',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CaretakerNotificationsScreen(profile: widget.profile),
                  )),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CaretakerSummary {
  final int patientCount;
  final int pendingCount;
  final DashboardStats stats;
  _CaretakerSummary({required this.patientCount, required this.pendingCount, required this.stats});
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
