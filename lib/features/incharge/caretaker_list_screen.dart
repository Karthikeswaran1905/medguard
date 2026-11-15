import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';
import 'add_caretaker_screen.dart';

/// Caretaker List (MedGuardian screen spec I4) — every Caretaker in this
/// Incharge's organization. The FAB pushes [InchargeAddCaretakerScreen]
/// (spec I5's provisioning counterpart, mirroring Admin's Add Doctor and
/// Doctor's Add Incharge screens). Allocating a specific Caretaker to a
/// patient happens from Patient Details -> Allocate Caretaker instead,
/// matching the pattern already used by Doctor's Allocate Incharge.
class InchargeCaretakerListScreen extends StatefulWidget {
  final Profile profile;
  const InchargeCaretakerListScreen({super.key, required this.profile});

  @override
  State<InchargeCaretakerListScreen> createState() => _InchargeCaretakerListScreenState();
}

class _InchargeCaretakerListScreenState extends State<InchargeCaretakerListScreen> {
  final _peopleRepo = PeopleRepository();
  late Future<List<Profile>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Profile>> _load() =>
      _peopleRepo.fetchByRole(AppRole.caretaker, orgId: widget.profile.orgId);

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _addCaretaker() async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => InchargeAddCaretakerScreen(profile: widget.profile),
    ));
    if (added == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caretakers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCaretaker,
        icon: const Icon(Icons.add),
        label: const Text('Add caretaker'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Profile>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final caretakers = snapshot.data!;
            if (caretakers.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(
                    message: 'No caretakers yet. Add one with the button below.',
                    icon: Icons.volunteer_activism_outlined,
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: caretakers.length,
              itemBuilder: (context, i) {
                final c = caretakers[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.volunteer_activism_outlined)),
                    title: Text(c.fullName),
                    subtitle: Text(c.email ?? c.phone ?? ''),
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
