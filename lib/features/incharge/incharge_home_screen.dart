import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';
import 'caretaker_analytics_screen.dart';
import 'caretaker_list_screen.dart';
import 'escalated_alerts_screen.dart';
import 'patient_analytics_screen.dart';
import 'patient_list_screen.dart';

/// Incharge Dashboard (Section 8, 27; MedGuardian screen spec I1) — the
/// supervisory hub and launch point for the other eight Incharge MVP
/// screens: Patients (-> Patient Details -> Allocate Caretaker) and
/// Caretakers (-> Add Caretaker), plus Escalated Alerts, Patient
/// Analytics and Caretaker Analytics.
///
/// This single screen used to hold every Incharge feature inline (an
/// allocations list with a popup-menu of actions, an "Add caretaker"
/// dialog, a caretaker list, AI insights, an escalated-events push
/// buried behind a stat tile). The finalized spec wants each
/// responsibility as its own screen instead, matching the Admin/Doctor
/// rebuilds — so this is now just the hub: stat counts plus a nav card
/// into each.
class InchargeHomeScreen extends StatefulWidget {
  final Profile profile;
  const InchargeHomeScreen({super.key, required this.profile});

  @override
  State<InchargeHomeScreen> createState() => _InchargeHomeScreenState();
}

class _InchargeHomeScreenState extends State<InchargeHomeScreen> {
  final _peopleRepo = PeopleRepository();
  final _analyticsRepo = AnalyticsRepository();
  late Future<_InchargeSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_InchargeSummary> _load() async {
    final assignments = await _peopleRepo.fetchAssignmentsForIncharge(widget.profile.id);
    final caretakers =
        await _peopleRepo.fetchByRole(AppRole.caretaker, orgId: widget.profile.orgId);
    final patientIds = assignments.map((a) => a.patientId).toList();
    final stats = await _analyticsRepo.statsForPatients(patientIds);
    final escalatedCount = await _analyticsRepo.countEscalated(patientIds);
    return _InchargeSummary(
      patientCount: assignments.length,
      caretakerCount: caretakers.length,
      stats: stats,
      escalatedCount: escalatedCount,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Incharge',
      profile: widget.profile,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_InchargeSummary>(
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
                    StatTile(label: 'Patients', value: '${data.patientCount}'),
                    StatTile(label: 'Caretakers', value: '${data.caretakerCount}'),
                    StatTile(label: 'Adherence', value: '${data.stats.adherencePercent.round()}%'),
                    StatTile(
                      label: 'Escalated',
                      value: '${data.escalatedCount}',
                      color: data.escalatedCount == 0 ? null : Colors.red.shade700,
                    ),
                  ],
                ),
                const SectionHeader(title: 'Manage'),
                _NavCard(
                  icon: Icons.people_outline,
                  title: 'Patients',
                  subtitle: 'View allocated patients, manage caretaker assignment',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => InchargePatientListScreen(profile: widget.profile),
                  )),
                ),
                _NavCard(
                  icon: Icons.volunteer_activism_outlined,
                  title: 'Caretakers',
                  subtitle: 'View and add Caretakers for your organization',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => InchargeCaretakerListScreen(profile: widget.profile),
                  )),
                ),
                _NavCard(
                  icon: Icons.warning_amber_outlined,
                  title: 'Escalated alerts',
                  subtitle: 'Doses that escalated past Caretaker level',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => InchargeEscalatedAlertsScreen(profile: widget.profile),
                  )),
                ),
                _NavCard(
                  icon: Icons.insights_outlined,
                  title: 'Patient analytics',
                  subtitle: '30-day adherence for every patient you supervise',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => InchargePatientAnalyticsScreen(profile: widget.profile),
                  )),
                ),
                _NavCard(
                  icon: Icons.query_stats_outlined,
                  title: 'Caretaker analytics',
                  subtitle: 'How each Caretaker\'s patients are adhering',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => InchargeCaretakerAnalyticsScreen(profile: widget.profile),
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

class _InchargeSummary {
  final int patientCount;
  final int caretakerCount;
  final DashboardStats stats;
  final int escalatedCount;
  _InchargeSummary({
    required this.patientCount,
    required this.caretakerCount,
    required this.stats,
    required this.escalatedCount,
  });
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
