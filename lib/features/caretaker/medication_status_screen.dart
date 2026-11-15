import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/medication_models.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/medication_repository.dart';
import '../../shared/widgets.dart';

/// Medication Status (MedGuardian screen spec C4) — this patient's recent
/// doses (`MedicationRepository.fetchHistory`, last 14 days) and their
/// outcome — consumed, missed, or still pending — so a Caretaker can see
/// the pattern at a glance rather than only the single dose that
/// triggered an alert. Read-only: verifying a specific pending dose
/// happens from Alert Center -> Alert Details, not here.
class CaretakerMedicationStatusScreen extends StatefulWidget {
  final Profile patient;
  const CaretakerMedicationStatusScreen({super.key, required this.patient});

  @override
  State<CaretakerMedicationStatusScreen> createState() => _CaretakerMedicationStatusScreenState();
}

class _CaretakerMedicationStatusScreenState extends State<CaretakerMedicationStatusScreen> {
  final _medicationRepo = MedicationRepository();
  late Future<List<MedicationEvent>> _future;

  @override
  void initState() {
    super.initState();
    _future = _medicationRepo.fetchHistory(widget.patient.id, days: 14);
  }

  Future<void> _refresh() async {
    setState(() => _future = _medicationRepo.fetchHistory(widget.patient.id, days: 14));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.patient.fullName}\'s medication status')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MedicationEvent>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final events = snapshot.data!;
            if (events.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(
                    message: 'No scheduled doses in the last 14 days yet.',
                    icon: Icons.medication_outlined,
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, i) {
                final e = events[i];
                return MedicineEventTile(
                  event: e,
                  subtitle: DateFormat.MMMd().add_jm().format(e.scheduledAt),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
