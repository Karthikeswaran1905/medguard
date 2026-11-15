import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';

/// Caretaker Analytics (MedGuardian screen spec I9) — for each Caretaker
/// in this Incharge's organization, how many of *this Incharge's*
/// patients they're looking after and the combined 30-day adherence of
/// that group. Deliberately scoped to this Incharge's own `assignments`
/// (rather than every patient a Caretaker might have across other
/// Incharges) — this is the Incharge's own supervisory view of "are my
/// Caretakers' patients doing okay," not an org-wide Caretaker report.
class InchargeCaretakerAnalyticsScreen extends StatefulWidget {
  final Profile profile;
  const InchargeCaretakerAnalyticsScreen({super.key, required this.profile});

  @override
  State<InchargeCaretakerAnalyticsScreen> createState() => _InchargeCaretakerAnalyticsScreenState();
}

class _InchargeCaretakerAnalyticsScreenState extends State<InchargeCaretakerAnalyticsScreen> {
  final _peopleRepo = PeopleRepository();
  final _analyticsRepo = AnalyticsRepository();
  late Future<List<_CaretakerRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_CaretakerRow>> _load() async {
    final assignments = await _peopleRepo.fetchAssignmentsForIncharge(widget.profile.id);
    final caretakers =
        await _peopleRepo.fetchByRole(AppRole.caretaker, orgId: widget.profile.orgId);

    final rows = <_CaretakerRow>[];
    for (final c in caretakers) {
      final patientIds = assignments
          .where((a) => a.caretakerId == c.id)
          .map((a) => a.patientId)
          .toList();
      final stats = await _analyticsRepo.statsForPatients(patientIds, days: 30);
      rows.add(_CaretakerRow(caretaker: c, patientCount: patientIds.length, stats: stats));
    }
    return rows;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caretaker analytics')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<_CaretakerRow>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snapshot.data!;
            if (rows.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(
                    message: 'No caretakers yet. Add one from the Caretakers screen.',
                    icon: Icons.volunteer_activism_outlined,
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.volunteer_activism_outlined)),
                    title: Text(row.caretaker.fullName),
                    subtitle: Text(
                      row.patientCount == 0
                          ? 'No patients from you allocated'
                          : '${row.patientCount} patient${row.patientCount == 1 ? '' : 's'} · '
                              '${row.stats.scheduled} doses in last 30 days',
                    ),
                    trailing: row.patientCount == 0
                        ? null
                        : StatusChip(
                            status: row.stats.adherencePercent >= 80
                                ? 'consumed'
                                : (row.stats.adherencePercent >= 50 ? 'pending' : 'missed'),
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CaretakerRow {
  final Profile caretaker;
  final int patientCount;
  final DashboardStats stats;
  _CaretakerRow({required this.caretaker, required this.patientCount, required this.stats});
}
