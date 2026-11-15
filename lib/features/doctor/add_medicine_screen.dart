import 'package:flutter/material.dart';

import '../../data/models/profile.dart';
import 'medication_configuration_screen.dart';

/// Add Medicine (MedGuardian screen spec D4), step 1 of 3 in the
/// prescribing wizard — name, dose, instructions and duration. Step 2
/// ([DoctorMedicationConfigurationScreen]) collects the dose times; step 3
/// ([DoctorReviewMedicationScreen]) actually saves. This screen only
/// collects and forwards fields; nothing is written to Firestore until the
/// review step is confirmed.
class DoctorAddMedicineScreen extends StatefulWidget {
  final Profile patient;
  final Profile profile;
  const DoctorAddMedicineScreen({super.key, required this.patient, required this.profile});

  @override
  State<DoctorAddMedicineScreen> createState() => _DoctorAddMedicineScreenState();
}

class _DoctorAddMedicineScreenState extends State<DoctorAddMedicineScreen> {
  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _instructions = TextEditingController();
  final _duration = TextEditingController(text: '30');

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _instructions.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_name.text.trim().isEmpty || _dose.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter at least a name and dose.')));
      return;
    }
    final durationDays = int.tryParse(_duration.text.trim()) ?? 30;
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DoctorMedicationConfigurationScreen(
        patient: widget.patient,
        profile: widget.profile,
        name: _name.text.trim(),
        dose: _dose.text.trim(),
        instructions: _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
        durationDays: durationDays,
      ),
    ));
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add medicine for ${widget.patient.fullName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Medicine name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dose,
            decoration: const InputDecoration(labelText: 'Dose (e.g. 500mg)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instructions,
            decoration: const InputDecoration(labelText: 'Instructions (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Duration (days)'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _next,
              child: const Text('Next: set dose times'),
            ),
          ),
        ],
      ),
    );
  }
}
