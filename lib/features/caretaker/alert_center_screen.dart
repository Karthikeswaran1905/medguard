import 'package:flutter/material.dart';

import '../../data/models/medication_models.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';
import 'alert_detail_screen.dart';

/// Alert Center (MedGuardian screen spec C5) — every dose among this
/// Caretaker's assigned patients that the patient hasn't confirmed yet
/// (`MedicationRepository.fetchPendingForPatients`, Section 15.2/16).
/// Tapping a row, or one of its two quick-action icons, pushes/uses
/// [AlertDetailScreen] (spec C6, `alert_detail_screen.dart`) with
/// `onVerify` wired to `MedicationRepository.verifyEvent` — the
/// Caretaker's core job in the escalation chain (Section 40).
class CaretakerAlertCenterScreen extends StatefulWidget {
  final Profile profile;
  const CaretakerAlertCenterScreen({super.key, required this.profile});

  @override
  State<CaretakerAlertCenterScreen> createState() => _CaretakerAlertCenterScreenState();
}

class _CaretakerAlertCenterScreenState extends State<CaretakerAlertCenterScreen> {
  final _peopleRepo = PeopleRepository();
  final _medRepo = MedicationRepository();
  late Future<_AlertCenterData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AlertCenterData> _load() async {
    final patients = await _peopleRepo.fetchPatientsForCaretaker(widget.profile.id);
    final pending = await _medRepo.fetchPendingForPatients(patients.map((p) => p.id).toList());
    final names = {for (final p in patients) p.id: p.fullName};
    return _AlertCenterData(pending: pending, names: names);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _verify(MedicationEvent event, {required bool consumed}) async {
    await _medRepo.verifyEvent(event.id, consumed: consumed);
    await _refresh();
  }

  void _openDetail(MedicationEvent event, String label) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AlertDetailScreen(
        event: event,
        patientLabel: label,
        onVerify: (consumed) => _verify(event, consumed: consumed),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert center')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_AlertCenterData>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            if (data.pending.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(
                    message: 'Nothing needs your attention right now.',
                    icon: Icons.check_circle_outline,
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: data.pending.length,
              itemBuilder: (context, i) {
                final e = data.pending[i];
                final label = data.names[e.patientId] ?? 'Unknown patient';
                return MedicineEventTile(
                  event: e,
                  subtitle: '$label · has not confirmed this dose · tap for detail',
                  onTap: () => _openDetail(e, label),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Not consumed',
                        icon: const Icon(Icons.close),
                        onPressed: () => _verify(e, consumed: false),
                      ),
                      IconButton(
                        tooltip: 'Consumed',
                        icon: const Icon(Icons.check),
                        onPressed: () => _verify(e, consumed: true),
                      ),
                    ],
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

class _AlertCenterData {
  final List<MedicationEvent> pending;
  final Map<String, String> names;
  _AlertCenterData({required this.pending, required this.names});
}
