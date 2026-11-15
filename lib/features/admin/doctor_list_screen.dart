import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';
import 'add_doctor_screen.dart';
import 'doctor_details_screen.dart';

/// Doctor List (MedGuardian screen spec A2) — every Doctor in the Admin's
/// organization. The FAB pushes [AdminAddDoctorScreen] (spec A3); tapping
/// a row pushes [AdminDoctorDetailsScreen] (spec A4). Used to be inline on
/// the Admin Dashboard — now its own screen so it matches the spec's
/// separate-screen-per-responsibility structure.
class AdminDoctorListScreen extends StatefulWidget {
  final Profile profile;
  const AdminDoctorListScreen({super.key, required this.profile});

  @override
  State<AdminDoctorListScreen> createState() => _AdminDoctorListScreenState();
}

class _AdminDoctorListScreenState extends State<AdminDoctorListScreen> {
  final _peopleRepo = PeopleRepository();
  late Future<List<Profile>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Profile>> _load() =>
      _peopleRepo.fetchByRole(AppRole.doctor, orgId: widget.profile.orgId);

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _addDoctor() async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AdminAddDoctorScreen(profile: widget.profile),
    ));
    if (added == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctors')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDoctor,
        icon: const Icon(Icons.add),
        label: const Text('Add doctor'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Profile>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final doctors = snapshot.data!;
            if (doctors.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(
                    message: 'No doctors yet. Add one with the button below.',
                    icon: Icons.medical_services_outlined,
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: doctors.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${doctors.length} ${doctors.length == 1 ? 'doctor' : 'doctors'}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                    ),
                  );
                }
                final d = doctors[i - 1];
                return PersonListCard(
                  name: d.fullName,
                  subtitle: d.email ?? d.phone ?? '',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminDoctorDetailsScreen(doctor: d),
                  )),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
