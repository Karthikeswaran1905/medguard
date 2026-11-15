import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/models/medication_models.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/medication_repository.dart';
import '../../shared/widgets.dart';
import '../prescriptions/prescription_scanner_screen.dart';
import 'medication_details_screen.dart';

/// Medications tab: every medicine on the patient's active prescriptions,
/// with the "Add Prescription" (Prescription Scanner) flow one tap away.
class MedicationsListScreen extends StatefulWidget {
  final Profile profile;
  const MedicationsListScreen({super.key, required this.profile});

  @override
  State<MedicationsListScreen> createState() => _MedicationsListScreenState();
}

class _MedicationsListScreenState extends State<MedicationsListScreen> {
  final _medRepo = MedicationRepository();
  late Future<List<Medicine>> _future;

  @override
  void initState() {
    super.initState();
    _future = _medRepo.fetchMedicinesForPatient(widget.profile.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = _medRepo.fetchMedicinesForPatient(widget.profile.id));
    await _future;
  }

  Future<void> _addPrescription() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PrescriptionScannerScreen(patientId: widget.profile.id),
    ));
    _refresh();
  }

  bool _isActive(Medicine m) =>
      DateTime.now().isBefore(m.startDate.add(Duration(days: m.durationDays)));

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Medications', style: Theme.of(context).textTheme.titleLarge)),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
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
                            message: 'No medicines yet — scan a prescription to add one.',
                            icon: Icons.medication_outlined,
                          ),
                        ],
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                      children: medicines.map((m) {
                        final active = _isActive(m);
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: (active ? AppTheme.primary : Colors.grey)
                                  .withValues(alpha: 0.12),
                              child: Icon(Icons.medication_outlined,
                                  color: active ? AppTheme.primary : Colors.grey),
                            ),
                            title: Text(m.name),
                            subtitle: Text(
                              '${m.dose} · ${m.frequencyPerDay}x/day · '
                              'started ${DateFormat.MMMd().format(m.startDate)}',
                            ),
                            trailing: Chip(
                              label: Text(active ? 'Active' : 'Completed'),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: (active ? AppTheme.success : Colors.grey)
                                  .withValues(alpha: 0.12),
                              labelStyle: TextStyle(color: active ? AppTheme.success : Colors.grey.shade700),
                            ),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => MedicationDetailsScreen(medicine: m),
                            )),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _addPrescription,
            icon: const Icon(Icons.add),
            label: const Text('Add Prescription'),
          ),
        ),
      ],
    );
  }
}
