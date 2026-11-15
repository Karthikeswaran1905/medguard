import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../data/models/medication_models.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';
import '../caretaker/alert_detail_screen.dart';

/// Alert Analytics (MedGuardian screen spec A18/A19, combined for the
/// MVP) — every still-open event that has escalated all the way to
/// Incharge level or beyond (`critical_unresolved`), across the whole
/// organization. This is deliberately narrower than "every alert" —
/// Caretaker and Incharge already see and act on alerts at their own
/// level; what Admin/Dean needs is the ones that got past both of them
/// unresolved (Section 40's escalation chain).
class AdminAlertAnalyticsScreen extends StatefulWidget {
  final Profile profile;
  const AdminAlertAnalyticsScreen({super.key, required this.profile});

  @override
  State<AdminAlertAnalyticsScreen> createState() => _AdminAlertAnalyticsScreenState();
}

class _AdminAlertAnalyticsScreenState extends State<AdminAlertAnalyticsScreen> {
  final _peopleRepo = PeopleRepository();
  final _analyticsRepo = AnalyticsRepository();
  late Future<_AlertData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AlertData> _load() async {
    final patients = await _peopleRepo.fetchByRole(AppRole.patient, orgId: widget.profile.orgId);
    final patientIds = patients.map((p) => p.id).toList();
    final events = await _analyticsRepo.fetchEscalatedEvents(patientIds);
    final names = {for (final p in patients) p.id: p.fullName};
    return _AlertData(events: events, names: names);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert analytics')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_AlertData>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            final critical = data.events
                .where((e) => e.escalationLevel == EscalationLevel.criticalUnresolved)
                .length;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        icon: Icons.trending_up,
                        color: data.events.isEmpty ? AppTheme.success : AppTheme.pending,
                        value: '${data.events.length}',
                        label: 'Escalated',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        icon: Icons.report_gmailerrorred_outlined,
                        color: critical == 0 ? AppTheme.success : AppTheme.critical,
                        value: '$critical',
                        label: 'Critical unresolved',
                      ),
                    ),
                  ],
                ),
                const SectionHeader(title: 'Escalated events'),
                if (data.events.isEmpty)
                  const EmptyState(
                    message: 'Nothing has escalated to Incharge level or beyond right now.',
                    icon: Icons.check_circle_outline,
                  )
                else
                  SectionCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: data.events
                          .map(
                            (e) => MedicineEventTile(
                              event: e,
                              subtitle: '${data.names[e.patientId] ?? 'Unknown patient'} · '
                                  '${DateFormat.MMMd().add_jm().format(e.scheduledAt)}',
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => AlertDetailScreen(
                                  event: e,
                                  patientLabel: data.names[e.patientId] ?? 'Unknown patient',
                                ),
                              )),
                            ),
                          )
                          .toList(),
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

class _AlertData {
  final List<MedicationEvent> events;
  final Map<String, String> names;
  _AlertData({required this.events, required this.names});
}
