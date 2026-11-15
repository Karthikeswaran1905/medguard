import 'package:flutter/material.dart';

import '../../data/models/profile.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';
import 'patient_details_screen.dart';

/// Patient List (MedGuardian screen spec D2) — every patient linked to this
/// Doctor via `doctor_patient_links` (`PeopleRepository.fetchPatientsForDoctor`,
/// populated once a patient redeems the invite code from the Doctor
/// Dashboard — Section 39). Tapping a row pushes [DoctorPatientDetailsScreen]
/// (spec D3), the entry point for prescribing and allocating an Incharge.
class DoctorPatientListScreen extends StatefulWidget {
  final Profile profile;
  const DoctorPatientListScreen({super.key, required this.profile});

  @override
  State<DoctorPatientListScreen> createState() => _DoctorPatientListScreenState();
}

class _DoctorPatientListScreenState extends State<DoctorPatientListScreen> {
  final _peopleRepo = PeopleRepository();
  late Future<List<Profile>> _future;

  @override
  void initState() {
    super.initState();
    _future = _peopleRepo.fetchPatientsForDoctor(widget.profile.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = _peopleRepo.fetchPatientsForDoctor(widget.profile.id));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patients')),
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
                    message: 'No patients yet. Share your invite code from the '
                        'dashboard so a patient can link to you.',
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
                    subtitle: Text(p.phone ?? p.email ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DoctorPatientDetailsScreen(
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
