import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../shared/widgets.dart';
import 'allocate_incharge_screen.dart';
import 'medication_list_screen.dart';

/// Patient Details (MedGuardian screen spec D3) — one patient's profile
/// plus a 30-day adherence snapshot, and the launch point for the rest of
/// the Doctor's per-patient workflow: Medications (-> Add Medicine ->
/// Medication Configuration -> Review Medication, spec D4-D7) and Allocate
/// Incharge (spec D9, matching the spec's own Doctor workflow diagram,
/// which puts incharge allocation right after prescribing).
class DoctorPatientDetailsScreen extends StatefulWidget {
  final Profile patient;
  final Profile profile;
  const DoctorPatientDetailsScreen({super.key, required this.patient, required this.profile});

  @override
  State<DoctorPatientDetailsScreen> createState() => _DoctorPatientDetailsScreenState();
}

class _DoctorPatientDetailsScreenState extends State<DoctorPatientDetailsScreen> {
  final _analyticsRepo = AnalyticsRepository();
  late Future<DashboardStats> _future;

  @override
  void initState() {
    super.initState();
    _future = _analyticsRepo.patientAdherence(widget.patient.id, days: 30);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return Scaffold(
      appBar: AppBar(title: const Text('Patient details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : '?',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (p.email != null && p.email!.isNotEmpty)
                        Text(p.email!, style: Theme.of(context).textTheme.bodySmall),
                      if (p.phone != null && p.phone!.isNotEmpty)
                        Text(p.phone!, style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        'Linked ${DateFormat.yMMMd().format(p.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Adherence (last 30 days)'),
          FutureBuilder<DashboardStats>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final stats = snapshot.data!;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  StatTile(
                    label: 'Adherence',
                    value: '${stats.adherencePercent.round()}%',
                    color: stats.adherencePercent >= 80 ? AppTheme.success : null,
                  ),
                  StatTile(label: 'Scheduled', value: '${stats.scheduled}'),
                  StatTile(label: 'Consumed', value: '${stats.consumed}', color: AppTheme.success),
                  StatTile(label: 'Missed', value: '${stats.missed}', color: AppTheme.critical),
                  StatTile(label: 'Pending', value: '${stats.pending}', color: AppTheme.pending),
                ],
              );
            },
          ),
          const SectionHeader(title: 'Manage'),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.medication_outlined)),
              title: const Text('Medications'),
              subtitle: const Text('View prescriptions, add a new medicine'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DoctorMedicationListScreen(patient: p, profile: widget.profile),
              )),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.supervisor_account_outlined)),
              title: const Text('Allocate Incharge'),
              subtitle: const Text('Assign an Incharge to monitor this patient'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DoctorAllocateInchargeScreen(patient: p, profile: widget.profile),
              )),
            ),
          ),
        ],
      ),
    );
  }
}
