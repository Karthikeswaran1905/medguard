import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/roles.dart';
import '../../data/models/medication_models.dart';
import '../../data/models/relationship_models.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';

/// Alert detail (MedGuardian AI Caregiver UI, Section 6): "patient name/ID
/// -> medicine -> scheduled time -> status -> repeated-miss context ->
/// action/contact option." Shared by the Caretaker dashboard (tapping a
/// pending dose, with the verify action available) and the Incharge
/// dashboard (tapping an escalated alert, read-only — an Incharge doesn't
/// verify doses directly, only Caretakers do, per Section 15/16).
class AlertDetailScreen extends StatefulWidget {
  final MedicationEvent event;
  final String patientLabel;

  /// When non-null, shows Consumed/Not-consumed action buttons that call
  /// this and pop. Omit for a read-only view (e.g. from Incharge).
  final Future<void> Function(bool consumed)? onVerify;

  const AlertDetailScreen({
    super.key,
    required this.event,
    required this.patientLabel,
    this.onVerify,
  });

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  final _medRepo = MedicationRepository();
  final _peopleRepo = PeopleRepository();
  late Future<_Context> _future;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Context> _load() async {
    final history = await _medRepo.fetchHistory(widget.event.patientId, days: 7);
    final missedCount = history
        .where((e) =>
            e.finalStatus == EventStatus.missed || e.finalStatus == EventStatus.notConsumed)
        .length;
    final contacts = await _peopleRepo.fetchFamilyContacts(widget.event.patientId);
    return _Context(recentMissedCount: missedCount, contacts: contacts);
  }

  Future<void> _act(bool consumed) async {
    final onVerify = widget.onVerify;
    if (onVerify == null) return;
    setState(() => _acting = true);
    await onVerify(consumed);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Scaffold(
      appBar: AppBar(title: const Text('Alert detail')),
      body: FutureBuilder<_Context>(
        future: _future,
        builder: (context, snapshot) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.patientLabel,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          StatusChip(status: e.finalStatus),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _row(Icons.medication_outlined,
                          '${e.medicineName ?? 'Medicine'} · ${e.medicineDose ?? ''}'),
                      _row(Icons.schedule_outlined,
                          'Scheduled ${DateFormat.MMMd().add_jm().format(e.scheduledAt)}'),
                      _row(Icons.priority_high_outlined,
                          'Escalation level: ${e.escalationLevel.replaceAll('_', ' ')}'),
                    ],
                  ),
                ),
              ),
              const SectionHeader(title: 'Context'),
              if (!snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.history_outlined),
                    title: Text(
                      snapshot.data!.recentMissedCount == 0
                          ? 'No other missed or unconfirmed doses in the last 7 days'
                          : '${snapshot.data!.recentMissedCount} missed or unconfirmed '
                              'dose(s) in the last 7 days',
                    ),
                    subtitle: snapshot.data!.recentMissedCount > 1
                        ? const Text('This looks like a repeated pattern, not a one-off.')
                        : null,
                  ),
                ),
                const SectionHeader(title: 'Contact / action'),
                if (snapshot.data!.contacts.isEmpty)
                  const EmptyState(
                    message: 'No emergency contacts on file for this patient.',
                    icon: Icons.contact_emergency_outlined,
                  )
                else
                  ...snapshot.data!.contacts.map(
                    (c) => Card(
                      child: ListTile(
                        leading: Icon(
                          c.isEmergency ? Icons.emergency_outlined : Icons.people_outline,
                        ),
                        title: Text(c.name),
                        subtitle: Text('${c.relationship} · ${c.phone}'),
                      ),
                    ),
                  ),
              ],
              if (widget.onVerify != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _acting ? null : () => _act(false),
                        child: const Text('Not consumed'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _acting ? null : () => _act(true),
                        child: const Text('Consumed'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Context {
  final int recentMissedCount;
  final List<FamilyContact> contacts;
  _Context({required this.recentMissedCount, required this.contacts});
}
