import 'package:flutter/material.dart';

import '../../data/interactions/drug_interaction_checker.dart';
import '../../data/models/medication_models.dart';
import '../../data/repositories/medication_repository.dart';
import '../../shared/widgets.dart';

/// Drug Interaction Checker (MedGuardian AI SUPPORT feature): checks the
/// patient's active medication list against a small local reference
/// dataset and shows safety warnings. See
/// `lib/data/interactions/drug_interaction_checker.dart` for why this is
/// reference-only and how it could later be swapped for a real drug
/// database API.
class DrugInteractionScreen extends StatefulWidget {
  final String patientId;
  final String patientLabel;

  const DrugInteractionScreen({
    super.key,
    required this.patientId,
    required this.patientLabel,
  });

  @override
  State<DrugInteractionScreen> createState() => _DrugInteractionScreenState();
}

class _DrugInteractionScreenState extends State<DrugInteractionScreen> {
  final _medRepo = MedicationRepository();
  late Future<_Data> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final medicines = await _medRepo.fetchMedicinesForPatient(widget.patientId);
    final warnings = DrugInteractionChecker.check(medicines.map((m) => m.name).toList());
    return _Data(medicines: medicines, warnings: warnings);
  }

  Color _severityColor(BuildContext context, String severity) {
    return severity == 'high'
        ? Theme.of(context).colorScheme.error
        : const Color(0xFFB45309); // amber-700, matches AppTheme.pending
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Drug interactions · ${widget.patientLabel}')),
      body: FutureBuilder<_Data>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const DisclaimerBanner(
                message: 'This is a small, reference-only checklist — not exhaustive, '
                    'and not a substitute for a pharmacist or doctor. Always '
                    'confirm any concern with them directly.',
              ),
              const SectionHeader(title: 'Active medicines checked'),
              if (data.medicines.isEmpty)
                const EmptyState(message: 'No active medicines on file to check.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: data.medicines
                      .map((m) => Chip(label: Text('${m.name} ${m.dose}')))
                      .toList(),
                ),
              const SectionHeader(title: 'Warnings'),
              if (data.warnings.isEmpty)
                const EmptyState(
                  message: 'No known interactions found among the medicines checked.',
                  icon: Icons.verified_outlined,
                )
              else
                ...data.warnings.map(
                  (w) => Card(
                    child: ListTile(
                      leading: Icon(Icons.warning_amber_outlined,
                          color: _severityColor(context, w.severity)),
                      title: Text(
                        '${w.medicineA} + ${w.medicineB}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(w.note),
                      isThreeLine: true,
                      trailing: Chip(
                        label: Text(w.severity == 'high' ? 'High' : 'Moderate'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor:
                            _severityColor(context, w.severity).withValues(alpha: 0.12),
                        labelStyle: TextStyle(color: _severityColor(context, w.severity)),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Data {
  final List<Medicine> medicines;
  final List<InteractionWarning> warnings;
  _Data({required this.medicines, required this.warnings});
}
