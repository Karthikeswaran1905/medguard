import 'package:flutter/material.dart';

import '../../data/models/profile.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';
import 'patient_details_screen.dart';

/// Assigned Patients (MedGuardian screen spec C2) — every patient
/// assigned to this Caretaker via `assignments/{patientId}`
/// (`PeopleRepository.fetchPatientsForCaretaker`, populated by the
/// Incharge's Allocate Caretaker screen — Section 11 step 5). Tapping a
/// row pushes [CaretakerPatientDetailsScreen] (spec C3), the entry point
/// for that patient's medication status and quick actions.
class CaretakerPatientListScreen extends StatefulWidget {
  final Profile profile;
  const CaretakerPatientListScreen({super.key, required this.profile});

  @override
  State<CaretakerPatientListScreen> createState() => _CaretakerPatientListScreenState();
}

class _CaretakerPatientListScreenState extends State<CaretakerPatientListScreen> {
  final _peopleRepo = PeopleRepository();
  late Future<List<Profile>> _future;

  @override
  void initState() {
    super.initState();
    _future = _peopleRepo.fetchPatientsForCaretaker(widget.profile.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = _peopleRepo.fetchPatientsForCaretaker(widget.profile.id));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assigned patients')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Profile>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final patients = snapshot.data!;
            if (patients.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(
                    message: 'No patients assigned to you yet. An Incharge allocates '
                        'patients to a Caretaker.',
                    icon: Icons.people_outline,
                  ),
                ],
              );
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
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CaretakerPatientDetailsScreen(
                        patient: p,
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
