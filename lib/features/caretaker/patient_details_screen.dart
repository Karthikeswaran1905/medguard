import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../shared/widgets.dart';
import '../emergency_qr/emergency_qr_screen.dart';
import '../health_records/health_records_screen.dart';
import '../interactions/drug_interaction_screen.dart';
import 'medication_status_screen.dart';

/// Patient Details (MedGuardian screen spec C3) — one assigned patient's
/// profile, a 30-day adherence snapshot, and the launch point for
/// Medication Status (spec C4) plus the quick actions the old inline
/// dashboard's popup menu used to hold (Health records, Drug
/// interactions, Emergency QR) — those already have their own dedicated
/// screens elsewhere in the catalog, so they stay reachable from here
/// rather than needing separate MVP-list slots of their own.
class CaretakerPatientDetailsScreen extends StatefulWidget {
  final Profile patient;
  final Profile profile;
  const CaretakerPatientDetailsScreen({super.key, required this.patient, required this.profile});

  @override
  State<CaretakerPatientDetailsScreen> createState() => _CaretakerPatientDetailsScreenState();
}

class _CaretakerPatientDetailsScreenState extends State<CaretakerPatientDetailsScreen> {
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
                      if (p.phone != null && p.phone!.isNotEmpty)
                        Text(p.phone!, style: Theme.of(context).textTheme.bodySmall),
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
              title: const Text('Medication status'),
              subtitle: const Text('Recent doses and their outcomes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CaretakerMedicationStatusScreen(patient: p),
              )),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.folder_shared_outlined)),
              title: const Text('Health records'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => HealthRecordsScreen(
                  patientId: p.id,
                  patientLabel: p.fullName,
                  viewerRole: AppRole.caretaker,
                  readOnly: true,
                ),
              )),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.warning_amber_outlined)),
              title: const Text('Drug interactions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DrugInteractionScreen(patientId: p.id, patientLabel: p.fullName),
              )),
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.qr_code_2_outlined)),
              title: const Text('Emergency QR'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => EmergencyQrScreen(patient: p, readOnly: true),
              )),
            ),
          ),
        ],
      ),
    );
  }
}
