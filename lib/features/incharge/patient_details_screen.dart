import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/profile.dart';
import '../../data/models/relationship_models.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';
import 'allocate_caretaker_screen.dart';

/// Patient Details (MedGuardian screen spec I3) — one allocated patient's
/// profile, a 30-day adherence snapshot, current Caretaker allocation
/// status, and family/emergency contacts (Section 8, wired into the final
/// escalation step in Section 40 — this is the Incharge's supervisory
/// responsibility, so it stays reachable from here rather than being
/// dropped along with the rest of the old inline dashboard).
class InchargePatientDetailsScreen extends StatefulWidget {
  final Assignment assignment;
  final Profile? patient;
  final Profile profile;
  const InchargePatientDetailsScreen({
    super.key,
    required this.assignment,
    required this.patient,
    required this.profile,
  });

  @override
  State<InchargePatientDetailsScreen> createState() => _InchargePatientDetailsScreenState();
}

class _InchargePatientDetailsScreenState extends State<InchargePatientDetailsScreen> {
  final _peopleRepo = PeopleRepository();
  final _analyticsRepo = AnalyticsRepository();
  late Future<DashboardStats> _statsFuture;
  late Assignment _assignment;

  @override
  void initState() {
    super.initState();
    _assignment = widget.assignment;
    _statsFuture = _analyticsRepo.patientAdherence(_assignment.patientId, days: 30);
  }

  String get _label => widget.patient?.fullName ?? 'Patient ${_assignment.patientId.substring(0, 8)}';

  Future<void> _reassignCaretaker() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => InchargeAllocateCaretakerScreen(
        assignment: _assignment,
        patientLabel: _label,
        profile: widget.profile,
      ),
    ));
    if (changed == true) {
      final assignments = await _peopleRepo.fetchAssignmentsForIncharge(widget.profile.id);
      final updated = assignments.where((a) => a.id == _assignment.id).toList();
      if (updated.isNotEmpty && mounted) setState(() => _assignment = updated.first);
    }
  }

  Future<void> _manageContacts() async {
    var contacts = await _peopleRepo.fetchFamilyContacts(_assignment.patientId);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Family & emergency contacts'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (contacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No contacts on file yet.'),
                    )
                  else
                    ...contacts.map(
                      (c) => ListTile(
                        dense: true,
                        leading: Icon(
                          c.isEmergency ? Icons.emergency_outlined : Icons.people_outline,
                        ),
                        title: Text(c.name),
                        subtitle: Text('${c.relationship} · ${c.phone}'),
                      ),
                    ),
                  const Divider(),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add contact'),
                    onPressed: () async {
                      final added = await showDialog<FamilyContact>(
                        context: dialogContext,
                        builder: (_) => _AddContactDialog(patientId: _assignment.patientId),
                      );
                      if (added == null) return;
                      await _peopleRepo.addFamilyContact(added);
                      contacts = await _peopleRepo.fetchFamilyContacts(_assignment.patientId);
                      setDialogState(() {});
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return Scaffold(
      appBar: AppBar(title: const Text('Patient details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    _label.isNotEmpty ? _label[0].toUpperCase() : '?',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (p?.phone != null && p!.phone!.isNotEmpty)
                        Text(p.phone!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Adherence (last 30 days)'),
          FutureBuilder<DashboardStats>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final stats = snapshot.data!;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  StatTile(
                    label: 'Adherence',
                    value: '${stats.adherencePercent.round()}%',
                    color: stats.adherencePercent >= 80 ? AppTheme.success : null,
                  ),
                  StatTile(label: 'Missed', value: '${stats.missed}', color: AppTheme.critical),
                  StatTile(label: 'Pending', value: '${stats.pending}', color: AppTheme.pending),
                ],
              );
            },
          ),
          const SectionHeader(title: 'Manage'),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.volunteer_activism_outlined)),
              title: Text(_assignment.caretakerId == null ? 'Allocate caretaker' : 'Reassign caretaker'),
              subtitle: Text(
                _assignment.caretakerId == null ? 'No caretaker allocated yet' : 'Caretaker allocated',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _reassignCaretaker,
            ),
          ),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.contacts_outlined)),
              title: const Text('Family & emergency contacts'),
              subtitle: const Text('Who to notify if escalation goes unresolved'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _manageContacts,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddContactDialog extends StatefulWidget {
  final String patientId;
  const _AddContactDialog({required this.patientId});

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _name = TextEditingController();
  final _relationship = TextEditingController();
  final _phone = TextEditingController();
  bool _isEmergency = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add contact'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          TextField(
            controller: _relationship,
            decoration: const InputDecoration(labelText: 'Relationship (e.g. Mother)'),
          ),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _isEmergency,
            onChanged: (v) => setState(() => _isEmergency = v ?? false),
            title: const Text('Notify in a critical, unresolved escalation'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) return;
            Navigator.of(context).pop(FamilyContact(
              id: '',
              patientId: widget.patientId,
              name: _name.text.trim(),
              relationship: _relationship.text.trim(),
              phone: _phone.text.trim(),
              isEmergency: _isEmergency,
            ));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
