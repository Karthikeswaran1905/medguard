import 'package:flutter/material.dart';

import '../../data/models/profile.dart';
import 'review_medication_screen.dart';

/// Medication Configuration (MedGuardian screen spec D6), step 2 of 3 —
/// how many times a day and at what wall-clock times the dose is taken.
/// Times are stored as local "HH:mm:ss" strings (Section 13/41), matching
/// `MedicationRepository.addMedicineWithSchedule`'s `timesOfDay` param, so
/// each `TimeOfDay` picked here is formatted before being forwarded to the
/// review step.
class DoctorMedicationConfigurationScreen extends StatefulWidget {
  final Profile patient;
  final Profile profile;
  final String name;
  final String dose;
  final String? instructions;
  final int durationDays;

  const DoctorMedicationConfigurationScreen({
    super.key,
    required this.patient,
    required this.profile,
    required this.name,
    required this.dose,
    required this.instructions,
    required this.durationDays,
  });

  @override
  State<DoctorMedicationConfigurationScreen> createState() =>
      _DoctorMedicationConfigurationScreenState();
}

class _DoctorMedicationConfigurationScreenState
    extends State<DoctorMedicationConfigurationScreen> {
  final List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _addTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _times.add(picked));
  }

  void _removeAt(int i) => setState(() => _times.removeAt(i));

  Future<void> _next() async {
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least one dose time.')));
      return;
    }
    final sorted = [..._times]..sort((a, b) => _fmt(a).compareTo(_fmt(b)));
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DoctorReviewMedicationScreen(
        patient: widget.patient,
        profile: widget.profile,
        name: widget.name,
        dose: widget.dose,
        instructions: widget.instructions,
        durationDays: widget.durationDays,
        timesOfDay: sorted.map(_fmt).toList(),
      ),
    ));
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set dose times')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${widget.name} · ${widget.dose}', style: Theme.of(context).textTheme.titleMedium),
          Text('${_times.length}x per day', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ..._times.asMap().entries.map(
                (entry) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.access_time),
                    title: Text(entry.value.format(context)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeAt(entry.key),
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addTime,
            icon: const Icon(Icons.add),
            label: const Text('Add a dose time'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _next,
              child: const Text('Next: review'),
            ),
          ),
        ],
      ),
    );
  }
}
