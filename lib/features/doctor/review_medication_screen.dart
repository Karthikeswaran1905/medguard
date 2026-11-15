import 'package:flutter/material.dart';

import '../../data/models/profile.dart';
import '../../data/repositories/medication_repository.dart';

/// Review Medication Plan (MedGuardian screen spec D7), step 3 of 3 — the
/// only screen in this wizard that actually writes anything. Confirming
/// creates a `prescriptions` document (Section 45) and then the medicine +
/// its schedules in one call (`MedicationRepository.addMedicineWithSchedule`),
/// then pops `true` all the way back to the Medication List screen that
/// started the flow (each intermediate screen re-pops `true` on receiving
/// it — see `DoctorAddMedicineScreen`/`DoctorMedicationConfigurationScreen`).
class DoctorReviewMedicationScreen extends StatefulWidget {
  final Profile patient;
  final Profile profile;
  final String name;
  final String dose;
  final String? instructions;
  final int durationDays;
  final List<String> timesOfDay;

  const DoctorReviewMedicationScreen({
    super.key,
    required this.patient,
    required this.profile,
    required this.name,
    required this.dose,
    required this.instructions,
    required this.durationDays,
    required this.timesOfDay,
  });

  @override
  State<DoctorReviewMedicationScreen> createState() => _DoctorReviewMedicationScreenState();
}

class _DoctorReviewMedicationScreenState extends State<DoctorReviewMedicationScreen> {
  final _medicationRepo = MedicationRepository();
  bool _saving = false;

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      final prescriptionId = await _medicationRepo.createPrescription(
        patientId: widget.patient.id,
        doctorId: widget.profile.id,
      );
      await _medicationRepo.addMedicineWithSchedule(
        prescriptionId: prescriptionId,
        patientId: widget.patient.id,
        name: widget.name,
        dose: widget.dose,
        frequencyPerDay: widget.timesOfDay.length,
        timesOfDay: widget.timesOfDay,
        instructions: widget.instructions,
        durationDays: widget.durationDays,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${widget.name} added to ${widget.patient.fullName}\'s plan.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save medication: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review medication plan')),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patient', style: Theme.of(context).textTheme.bodySmall),
                Text(widget.patient.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('Medicine', style: Theme.of(context).textTheme.bodySmall),
                Text('${widget.name} · ${widget.dose}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (widget.instructions != null && widget.instructions!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Instructions', style: Theme.of(context).textTheme.bodySmall),
                  Text(widget.instructions!),
                ],
                const SizedBox(height: 12),
                Text('Duration', style: Theme.of(context).textTheme.bodySmall),
                Text('${widget.durationDays} days'),
                const SizedBox(height: 12),
                Text('Dose times', style: Theme.of(context).textTheme.bodySmall),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.timesOfDay
                      .map((t) => Chip(label: Text(t.substring(0, 5))))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _confirm,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Confirm medication plan'),
            ),
          ),
        ],
      ),
    );
  }
}
