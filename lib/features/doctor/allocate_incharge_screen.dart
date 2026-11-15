import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';

/// Allocate Incharge (MedGuardian screen spec D10) — picks one of this
/// Doctor's org Incharges to monitor [patient], writing (or updating) the
/// `assignments/{patientId}` document (`PeopleRepository.allocateIncharge`).
/// That same document is what the Incharge later fills in with a Caretaker
/// (Section 11 step 5) — kept as its own document per the spec's explicit
/// guidance to store this relationship in `assignments/{assignmentId}`
/// rather than as ids scattered across every user document.
class DoctorAllocateInchargeScreen extends StatefulWidget {
  final Profile patient;
  final Profile profile;
  const DoctorAllocateInchargeScreen({super.key, required this.patient, required this.profile});

  @override
  State<DoctorAllocateInchargeScreen> createState() => _DoctorAllocateInchargeScreenState();
}

class _DoctorAllocateInchargeScreenState extends State<DoctorAllocateInchargeScreen> {
  final _peopleRepo = PeopleRepository();
  late Future<List<Profile>> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _peopleRepo.fetchByRole(AppRole.incharge, orgId: widget.profile.orgId);
  }

  Future<void> _allocate(Profile incharge) async {
    setState(() => _saving = true);
    try {
      await _peopleRepo.allocateIncharge(inchargeId: incharge.id, patientId: widget.patient.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${incharge.fullName} is now watching ${widget.patient.fullName}.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not allocate incharge: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Allocate incharge to ${widget.patient.fullName}')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: FutureBuilder<List<Profile>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final incharges = snapshot.data!;
            if (incharges.isEmpty) {
              return const EmptyState(
                message: 'No incharges in your organization yet. Add one from the '
                    'Incharges screen first.',
                icon: Icons.supervisor_account_outlined,
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
                    trailing: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _saving ? null : () => _allocate(inc),
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
