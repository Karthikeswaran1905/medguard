import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../data/models/profile.dart';
import '../../data/models/relationship_models.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';

/// Allocate Caretaker (MedGuardian screen spec I6) — picks one of this
/// Incharge's org Caretakers to look after [assignment]'s patient,
/// updating the existing `assignments/{patientId}` document
/// (`PeopleRepository.allocateCaretaker`, Section 11 step 5) that the
/// Doctor originally created when allocating this Incharge.
class InchargeAllocateCaretakerScreen extends StatefulWidget {
  final Assignment assignment;
  final String patientLabel;
  final Profile profile;
  const InchargeAllocateCaretakerScreen({
    super.key,
    required this.assignment,
    required this.patientLabel,
    required this.profile,
  });

  @override
  State<InchargeAllocateCaretakerScreen> createState() => _InchargeAllocateCaretakerScreenState();
}

class _InchargeAllocateCaretakerScreenState extends State<InchargeAllocateCaretakerScreen> {
  final _peopleRepo = PeopleRepository();
  late Future<List<Profile>> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _peopleRepo.fetchByRole(AppRole.caretaker, orgId: widget.profile.orgId);
  }

  Future<void> _allocate(Profile caretaker) async {
    setState(() => _saving = true);
    try {
      await _peopleRepo.allocateCaretaker(
        assignmentId: widget.assignment.id,
        caretakerId: caretaker.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${caretaker.fullName} is now looking after ${widget.patientLabel}.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not allocate caretaker: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Allocate caretaker to ${widget.patientLabel}')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: FutureBuilder<List<Profile>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final caretakers = snapshot.data!;
            if (caretakers.isEmpty) {
              return const EmptyState(
                message: 'No caretakers in your organization yet. Add one from the '
                    'Caretakers screen first.',
                icon: Icons.volunteer_activism_outlined,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: caretakers.length,
              itemBuilder: (context, i) {
                final c = caretakers[i];
                final isCurrent = c.id == widget.assignment.caretakerId;
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.volunteer_activism_outlined)),
                    title: Text(c.fullName),
                    subtitle: Text(isCurrent ? 'Currently allocated' : (c.email ?? c.phone ?? '')),
                    trailing: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : (isCurrent ? const Icon(Icons.check_circle_outline) : const Icon(Icons.chevron_right)),
                    onTap: _saving || isCurrent ? null : () => _allocate(c),
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
