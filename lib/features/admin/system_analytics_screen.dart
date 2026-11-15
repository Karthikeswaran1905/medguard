import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';

/// System Analytics (MedGuardian screen spec A20, combined with A14
/// "Medication Analytics" for the MVP) — org-wide role counts plus 30-day
/// medication-event totals and overall adherence across every patient in
/// the organization. Reuses the same `AnalyticsRepository.statsForPatients`
/// query every other dashboard's adherence stat is built from, just fed
/// every patient in the org instead of one Doctor/Caretaker/Incharge's
/// slice of them.
class AdminSystemAnalyticsScreen extends StatefulWidget {
  final Profile profile;
  const AdminSystemAnalyticsScreen({super.key, required this.profile});

  @override
  State<AdminSystemAnalyticsScreen> createState() => _AdminSystemAnalyticsScreenState();
}

class _AdminSystemAnalyticsScreenState extends State<AdminSystemAnalyticsScreen> {
  final _peopleRepo = PeopleRepository();
  final _analyticsRepo = AnalyticsRepository();
  late Future<_SystemData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SystemData> _load() async {
    final counts = await _analyticsRepo.orgCounts(widget.profile.orgId);
    final patients = await _peopleRepo.fetchByRole(AppRole.patient, orgId: widget.profile.orgId);
    final stats = await _analyticsRepo.statsForPatients(
      patients.map((p) => p.id).toList(),
      days: 30,
    );
    return _SystemData(counts: counts, stats: stats);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System analytics')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_SystemData>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SectionHeader(title: 'Organization'),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    MetricCard(
                      icon: Icons.medical_services_outlined,
                      color: AppTheme.primary,
                      value: '${data.counts['doctors'] ?? 0}',
                      label: 'Doctors',
                    ),
                    MetricCard(
                      icon: Icons.badge_outlined,
                      color: const Color(0xFF7C3AED),
                      value: '${data.counts['incharges'] ?? 0}',
                      label: 'Incharges',
                    ),
                    MetricCard(
                      icon: Icons.volunteer_activism_outlined,
                      color: const Color(0xFFEA580C),
                      value: '${data.counts['caretakers'] ?? 0}',
                      label: 'Caretakers',
                    ),
                    MetricCard(
                      icon: Icons.people_alt_outlined,
                      color: const Color(0xFF16A34A),
                      value: '${data.counts['patients'] ?? 0}',
                      label: 'Patients',
                    ),
                  ],
                ),
                const SectionHeader(title: 'Medication events (last 30 days)'),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    MetricCard(
                      icon: Icons.insights_outlined,
                      color: data.stats.adherencePercent >= 80 ? AppTheme.success : AppTheme.pending,
                      value: '${data.stats.adherencePercent.round()}%',
                      label: 'Adherence',
                    ),
                    MetricCard(
                      icon: Icons.event_note_outlined,
                      color: AppTheme.primary,
                      value: '${data.stats.scheduled}',
                      label: 'Scheduled',
                    ),
                    MetricCard(
                      icon: Icons.check_circle_outline,
                      color: AppTheme.success,
                      value: '${data.stats.consumed}',
                      label: 'Consumed',
                    ),
                    MetricCard(
                      icon: Icons.cancel_outlined,
                      color: AppTheme.critical,
                      value: '${data.stats.missed}',
                      label: 'Missed',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 160,
                  child: MetricCard(
                    icon: Icons.hourglass_empty,
                    color: AppTheme.pending,
                    value: '${data.stats.pending}',
                    label: 'Pending',
                  ),
                ),
                if (data.stats.scheduled == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: EmptyState(
                      message: 'No medication events yet — this fills in once patients have '
                          'active prescriptions and doses start getting scheduled.',
                      icon: Icons.insights_outlined,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SystemData {
  final Map<String, int> counts;
  final DashboardStats stats;
  _SystemData({required this.counts, required this.stats});
}
