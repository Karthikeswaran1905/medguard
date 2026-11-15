import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/medication_models.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/medication_repository.dart';
import '../../shared/widgets.dart';
import 'add_medicine_screen.dart';

/// Medication List (MedGuardian screen spec D5, "Prescriptions") — every
/// medicine this Doctor's org has ever prescribed this patient
/// (`MedicationRepository.fetchMedicinesForPatient`), newest first. The FAB
/// starts the three-screen "Add Medicine" wizard (spec D4 -> D6 -> D7); a
/// `true` pop result from that chain means a save happened, so the list
/// refreshes once the whole flow completes.
class DoctorMedicationListScreen extends StatefulWidget {
  final Profile patient;
  final Profile profile;
  const DoctorMedicationListScreen({super.key, required this.patient, required this.profile});

  @override
  State<DoctorMedicationListScreen> createState() => _DoctorMedicationListScreenState();
}

class _DoctorMedicationListScreenState extends State<DoctorMedicationListScreen> {
  final _medicationRepo = MedicationRepository();
  late Future<List<Medicine>> _future;

  @override
  void initState() {
    super.initState();
    _future = _medicationRepo.fetchMedicinesForPatient(widget.patient.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = _medicationRepo.fetchMedicinesForPatient(widget.patient.id));
    await _future;
  }

  Future<void> _addMedicine() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DoctorAddMedicineScreen(patient: widget.patient, profile: widget.profile),
    ));
    if (saved == true) await _refresh();
  }

  Future<void> _showSchedule(Medicine m) async {
    final schedules = await _medicationRepo.fetchSchedulesForMedicine(m.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${m.name} · ${m.dose}', style: Theme.of(context).textTheme.titleMedium),
            if (m.instructions != null && m.instructions!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(m.instructions!, style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            Text('${m.durationDays} days · started ${DateFormat.yMMMd().format(m.startDate)}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: schedules
                  .map((s) => Chip(label: Text(s.timeOfDay.substring(0, 5))))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.patient.fullName}\'s medications')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMedicine,
        icon: const Icon(Icons.add),
        label: const Text('Add medicine'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Medicine>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final medicines = snapshot.data!;
            if (medicines.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(
                    message: 'No medicines prescribed yet. Add one with the button below.',
                    icon: Icons.medication_outlined,
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: medicines.length,
              itemBuilder: (context, i) {
                final m = medicines[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.medication_outlined)),
                    title: Text('${m.name} · ${m.dose}'),
                    subtitle: Text('${m.frequencyPerDay}x/day · ${m.durationDays} days'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showSchedule(m),
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
