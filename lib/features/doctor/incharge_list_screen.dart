import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';
import 'add_incharge_screen.dart';

/// Incharge List (MedGuardian screen spec D8) — every Incharge in this
/// Doctor's organization. The FAB pushes [DoctorAddInchargeScreen] (spec
/// D9's provisioning counterpart, mirroring Admin's Add Doctor screen).
/// Allocating a specific Incharge to a patient happens from Patient
/// Details -> Allocate Incharge instead, matching the spec's own Doctor
/// workflow diagram (prescribe first, then allocate).
class DoctorInchargeListScreen extends StatefulWidget {
  final Profile profile;
  const DoctorInchargeListScreen({super.key, required this.profile});

  @override
  State<DoctorInchargeListScreen> createState() => _DoctorInchargeListScreenState();
}

class _DoctorInchargeListScreenState extends State<DoctorInchargeListScreen> {
  final _peopleRepo = PeopleRepository();
  late Future<List<Profile>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Profile>> _load() =>
      _peopleRepo.fetchByRole(AppRole.incharge, orgId: widget.profile.orgId);

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _addIncharge() async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DoctorAddInchargeScreen(profile: widget.profile),
    ));
    if (added == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incharges')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addIncharge,
        icon: const Icon(Icons.add),
        label: const Text('Add incharge'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Profile>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final incharges = snapshot.data!;
            if (incharges.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(
                    message: 'No incharges yet. Add one with the button below.',
                    icon: Icons.supervisor_account_outlined,
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: incharges.length,
              itemBuilder: (context, i) {
                final inc = incharges[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.supervisor_account_outlined)),
                    title: Text(inc.fullName),
                    subtitle: Text(inc.email ?? inc.phone ?? ''),
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
