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

/// Escalated Alerts (MedGuardian screen spec I7) — every still-open dose
/// among this Incharge's allocated patients that has escalated to
/// Incharge level or beyond (Section 15/40's escalation chain: Patient ->
/// Caretaker -> Incharge). This used to be a stat tile you had to tap on
/// the old inline dashboard to see anything; the spec wants it as its own
/// screen instead, matching Admin's org-wide Alert Analytics screen but
/// scoped to just this Incharge's own patients.
class InchargeEscalatedAlertsScreen extends StatefulWidget {
  final Profile profile;
  const InchargeEscalatedAlertsScreen({super.key, required this.profile});

  @override
  State<InchargeEscalatedAlertsScreen> createState() => _InchargeEscalatedAlertsScreenState();
}

class _InchargeEscalatedAlertsScreenState extends State<InchargeEscalatedAlertsScreen> {
  final _peopleRepo = PeopleRepository();
  final _analyticsRepo = AnalyticsRepository();
  late Future<_AlertData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AlertData> _load() async {
    final assignments = await _peopleRepo.fetchAssignmentsForIncharge(widget.profile.id);
    final patientIds = assignments.map((a) => a.patientId).toList();
    final events = await _analyticsRepo.fetchEscalatedEvents(patientIds);
    final names = <String, String>{};
    for (final id in patientIds) {
      final profile = await _peopleRepo.fetchProfile(id);
      names[id] = profile?.fullName ?? 'Patient ${id.substring(0, 8)}';
    }
    return _AlertData(events: events, names: names);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escalated alerts')),
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
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    StatTile(
                      label: 'Escalated',
                      value: '${data.events.length}',
                      color: data.events.isEmpty ? null : AppTheme.pending,
                    ),
                    StatTile(
                      label: 'Critical unresolved',
                      value: '$critical',
                      color: critical == 0 ? null : AppTheme.critical,
                    ),
                  ],
                ),
                const SectionHeader(title: 'Escalated events'),
                if (data.events.isEmpty)
                  const EmptyState(
                    message: 'Nothing has escalated to you right now.',
                    icon: Icons.check_circle_outline,
                  )
                else
                  ...data.events.map(
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
