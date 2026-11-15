import 'package:flutter/material.dart';

import '../../data/models/profile.dart';
import '../../data/models/relationship_models.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';
import 'patient_details_screen.dart';

/// Patient List (MedGuardian screen spec I2) — every patient allocated to
/// this Incharge via `assignments/{patientId}`
/// (`PeopleRepository.fetchAssignmentsForIncharge`, populated by the
/// Doctor's Allocate Incharge screen — Section 11 step 4). Resolves each
/// assignment's `patientId` to a full profile so the list shows names
/// instead of raw ids. Tapping a row pushes [InchargePatientDetailsScreen]
/// (spec I3), the entry point for reassigning a Caretaker.
class InchargePatientListScreen extends StatefulWidget {
  final Profile profile;
  const InchargePatientListScreen({super.key, required this.profile});

  @override
  State<InchargePatientListScreen> createState() => _InchargePatientListScreenState();
}

class _InchargePatientListScreenState extends State<InchargePatientListScreen> {
  final _peopleRepo = PeopleRepository();
  late Future<List<_PatientRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_PatientRow>> _load() async {
    final assignments = await _peopleRepo.fetchAssignmentsForIncharge(widget.profile.id);
    final rows = <_PatientRow>[];
    for (final a in assignments) {
      final patient = await _peopleRepo.fetchProfile(a.patientId);
      rows.add(_PatientRow(assignment: a, patient: patient));
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
      appBar: AppBar(title: const Text('Patients')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<_PatientRow>>(
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
                    message: 'No patients allocated to you yet. A Doctor allocates '
                        'patients to an Incharge after prescribing.',
                    icon: Icons.people_outline,
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                final label = row.patient?.fullName ?? 'Patient ${row.assignment.patientId.substring(0, 8)}';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(label),
                    subtitle: Text(
                      row.assignment.caretakerId == null
                          ? 'No caretaker allocated'
                          : 'Caretaker allocated',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => InchargePatientDetailsScreen(
                        assignment: row.assignment,
                        patient: row.patient,
                        profile: widget.profile,
                      ),
                    )),
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

class _PatientRow {
  final Assignment assignment;
  final Profile? patient;
  _PatientRow({required this.assignment, required this.patient});
}
