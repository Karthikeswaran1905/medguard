import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';

/// Patient Overview (MedGuardian screen spec A11/A12, combined into one
/// MVP screen) — every patient across the Admin's organization, with a
/// quick 30-day adherence snapshot on tap. Read-only: Admin doesn't
/// prescribe or verify doses directly (that's Doctor/Caretaker), just
/// monitors at the org level (Section 25 permission matrix).
class AdminPatientOverviewScreen extends StatefulWidget {
  final Profile profile;
  const AdminPatientOverviewScreen({super.key, required this.profile});

  @override
  State<AdminPatientOverviewScreen> createState() => _AdminPatientOverviewScreenState();
}

class _AdminPatientOverviewScreenState extends State<AdminPatientOverviewScreen> {
  final _peopleRepo = PeopleRepository();
  final _analyticsRepo = AnalyticsRepository();
  late Future<List<Profile>> _future;

  @override
  void initState() {
    super.initState();
    _future = _peopleRepo.fetchByRole(AppRole.patient, orgId: widget.profile.orgId);
  }

  Future<void> _showDetail(Profile patient) async {
    final stats = await _analyticsRepo.patientAdherence(patient.id, days: 30);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                PersonAvatar(name: patient.fullName, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                      if ((patient.email ?? '').isNotEmpty || (patient.phone ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if ((patient.email ?? '').isNotEmpty) patient.email,
                            if ((patient.phone ?? '').isNotEmpty) patient.phone,
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    icon: Icons.favorite_border,
                    color: stats.adherencePercent >= 80 ? AppTheme.success : AppTheme.pending,
                    value: '${stats.adherencePercent.round()}%',
                    label: 'Adherence (30d)',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricCard(
                    icon: Icons.event_busy_outlined,
                    color: AppTheme.critical,
                    value: '${stats.missed}',
                    label: 'Missed (30d)',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricCard(
                    icon: Icons.hourglass_empty,
                    color: AppTheme.pending,
                    value: '${stats.pending}',
                    label: 'Pending',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patients')),
      body: FutureBuilder<List<Profile>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final patients = snapshot.data!;
          if (patients.isEmpty) {
            return const EmptyState(message: 'No patients in this organization yet.');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: patients.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${patients.length} ${patients.length == 1 ? 'patient' : 'patients'}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                  ),
                );
              }
              final p = patients[i - 1];
              return PersonListCard(
                name: p.fullName,
                subtitle: p.phone ?? '',
                onTap: () => _showDetail(p),
              );
            },
          );
        },
      ),
    );
  }
}
