import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';

/// Patient Analytics (MedGuardian screen spec I8) — 30-day adherence for
/// every patient allocated to this Incharge. Read-only, same bottom-sheet
/// detail pattern as Admin's org-wide Patient Overview screen, just
/// scoped to this Incharge's own `assignments` instead of every patient
/// in the organization.
class InchargePatientAnalyticsScreen extends StatefulWidget {
  final Profile profile;
  const InchargePatientAnalyticsScreen({super.key, required this.profile});

  @override
  State<InchargePatientAnalyticsScreen> createState() => _InchargePatientAnalyticsScreenState();
}

class _InchargePatientAnalyticsScreenState extends State<InchargePatientAnalyticsScreen> {
  final _peopleRepo = PeopleRepository();
  final _analyticsRepo = AnalyticsRepository();
  late Future<List<Profile>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Profile>> _load() async {
    final assignments = await _peopleRepo.fetchAssignmentsForIncharge(widget.profile.id);
    final patients = <Profile>[];
    for (final a in assignments) {
      final p = await _peopleRepo.fetchProfile(a.patientId);
      if (p != null) patients.add(p);
    }
    return patients;
  }

  Future<void> _showDetail(Profile patient) async {
    final stats = await _analyticsRepo.patientAdherence(patient.id, days: 30);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(patient.fullName, style: Theme.of(context).textTheme.titleMedium),
            if (patient.phone != null && patient.phone!.isNotEmpty)
              Text(patient.phone!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                StatTile(
                  label: 'Adherence (30d)',
                  value: '${stats.adherencePercent.round()}%',
                  color: stats.adherencePercent >= 80 ? AppTheme.success : null,
                ),
                StatTile(label: 'Missed (30d)', value: '${stats.missed}'),
                StatTile(label: 'Pending', value: '${stats.pending}'),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient analytics')),
      body: FutureBuilder<List<Profile>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final patients = snapshot.data!;
          if (patients.isEmpty) {
            return const EmptyState(message: 'No patients allocated to you yet.');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: patients.length,
            itemBuilder: (context, i) {
              final p = patients[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(p.fullName),
                  subtitle: Text(p.phone ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDetail(p),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
