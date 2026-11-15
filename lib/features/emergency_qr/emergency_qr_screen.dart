import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models/patient_medical_info.dart';
import '../../data/models/profile.dart';
import '../../data/models/relationship_models.dart';
import '../../data/repositories/patient_medical_repository.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';

/// Emergency QR Health Card (MedGuardian AI BONUS feature): "Share
/// selected emergency information through a QR card." Fully local/offline
/// — the QR just encodes text, so this needs no backend beyond what's
/// already there (the patient's own `patients/{uid}` doc and their
/// existing `family_contacts`).
///
/// Patient view is editable; a caregiver opening a patient's card
/// ([readOnly]) only ever sees it, never edits someone else's medical
/// info from here.
class EmergencyQrScreen extends StatefulWidget {
  final Profile patient;
  final bool readOnly;

  const EmergencyQrScreen({super.key, required this.patient, this.readOnly = false});

  @override
  State<EmergencyQrScreen> createState() => _EmergencyQrScreenState();
}

class _EmergencyQrScreenState extends State<EmergencyQrScreen> {
  final _medicalRepo = PatientMedicalRepository();
  final _peopleRepo = PeopleRepository();

  final _bloodType = TextEditingController();
  final _allergies = TextEditingController();
  final _conditions = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  List<FamilyContact> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await _medicalRepo.fetch(widget.patient.id);
    final contacts = await _peopleRepo.fetchFamilyContacts(widget.patient.id);
    if (!mounted) return;
    setState(() {
      _bloodType.text = info.bloodType;
      _allergies.text = info.allergies;
      _conditions.text = info.conditions;
      _emergencyContacts = contacts.where((c) => c.isEmergency).toList();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _medicalRepo.save(PatientMedicalInfo(
      patientId: widget.patient.id,
      bloodType: _bloodType.text.trim(),
      allergies: _allergies.text.trim(),
      conditions: _conditions.text.trim(),
      updatedAt: null,
    ));
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Emergency card updated.')));
    }
  }

  String get _qrData {
    final buffer = StringBuffer()
      ..writeln('MEDGUARD EMERGENCY CARD')
      ..writeln('Name: ${widget.patient.fullName}');
    if (widget.patient.phone != null && widget.patient.phone!.isNotEmpty) {
      buffer.writeln('Phone: ${widget.patient.phone}');
    }
    if (_bloodType.text.trim().isNotEmpty) {
      buffer.writeln('Blood type: ${_bloodType.text.trim()}');
    }
    if (_allergies.text.trim().isNotEmpty) {
      buffer.writeln('Allergies: ${_allergies.text.trim()}');
    }
    if (_conditions.text.trim().isNotEmpty) {
      buffer.writeln('Conditions: ${_conditions.text.trim()}');
    }
    for (final c in _emergencyContacts) {
      buffer.writeln('Emergency contact: ${c.name} (${c.relationship}) ${c.phone}');
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _bloodType.dispose();
    _allergies.dispose();
    _conditions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency QR card')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: 220,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Scan to view ${widget.patient.fullName}\'s emergency info',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SectionHeader(title: 'Medical info on the card'),
                TextField(
                  controller: _bloodType,
                  enabled: !widget.readOnly,
                  decoration: const InputDecoration(labelText: 'Blood type (e.g. O+)'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _allergies,
                  enabled: !widget.readOnly,
                  decoration: const InputDecoration(labelText: 'Known allergies'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _conditions,
                  enabled: !widget.readOnly,
                  decoration: const InputDecoration(labelText: 'Conditions to know about'),
                  onChanged: (_) => setState(() {}),
                ),
                const SectionHeader(title: 'Emergency contacts on the card'),
                if (_emergencyContacts.isEmpty)
                  const EmptyState(
                    message: 'No contact is marked "notify in a critical, unresolved '
                        'escalation" yet — add one from your Incharge.',
                    icon: Icons.contact_emergency_outlined,
                  )
                else
                  ..._emergencyContacts.map(
                    (c) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.emergency_outlined),
                        title: Text(c.name),
                        subtitle: Text('${c.relationship} · ${c.phone}'),
                      ),
                    ),
                  ),
                if (!widget.readOnly) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ],
            ),
    );
  }
}
