import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/medicine_info.dart';
import '../../data/models/medication_models.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/repositories/people_repository.dart';

/// Medication Details (MedGuardian AI UI plan): dose/frequency/time/
/// duration/prescriber, a short reference "About this medicine" blurb, and
/// Edit/Delete actions.
///
/// Edit/Delete are shown for visual/UX parity with the design, but only
/// the prescribing Doctor can actually change a `medicines` document
/// (Firestore Security Rules — no `update`/`delete` rule exists for a
/// patient on this collection, matching the same "only a Doctor
/// prescribes" safety boundary used throughout this app). Tapping either
/// explains that rather than silently failing or pretending to work.
class MedicationDetailsScreen extends StatefulWidget {
  final Medicine medicine;
  const MedicationDetailsScreen({super.key, required this.medicine});

  @override
  State<MedicationDetailsScreen> createState() => _MedicationDetailsScreenState();
}

class _MedicationDetailsScreenState extends State<MedicationDetailsScreen> {
  final _medRepo = MedicationRepository();
  final _peopleRepo = PeopleRepository();
  late Future<_Details> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Details> _load() async {
    final schedules = await _medRepo.fetchSchedulesForMedicine(widget.medicine.id);
    final prescription = await _medRepo.fetchPrescription(widget.medicine.prescriptionId);
    Profile? doctor;
    if (prescription != null) {
      doctor = await _peopleRepo.fetchProfile(prescription.doctorId);
    }
    return _Details(times: schedules.map((s) => s.timeOfDay).toList(), doctorName: doctor?.fullName);
  }

  void _explainReadOnly(String action) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(action),
        content: Text(
          'Only your prescribing doctor can $action this medicine. Contact '
          'them if something needs to be corrected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.medicine;
    final endDate = m.startDate.add(Duration(days: m.durationDays));
    return Scaffold(
      appBar: AppBar(title: const Text('Medication Details')),
      body: FutureBuilder<_Details>(
        future: _future,
        builder: (context, snapshot) {
          final details = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.medication, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${m.name} ${m.dose}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          if (m.instructions != null && m.instructions!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(m.instructions!,
                                  style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _DetailRow(icon: Icons.local_pharmacy_outlined, label: 'Dose', value: m.dose),
                      _DetailRow(
                        icon: Icons.repeat_outlined,
                        label: 'Frequency',
                        value: '${m.frequencyPerDay}x a day',
                      ),
                      _DetailRow(
                        icon: Icons.schedule_outlined,
                        label: 'Time',
                        value: details == null || details.times.isEmpty
                            ? '—'
                            : details.times.map(_formatTime).join(', '),
                      ),
                      _DetailRow(
                        icon: Icons.event_outlined,
                        label: 'Duration',
                        value:
                            '${m.durationDays} Days (${DateFormat.MMMd().format(m.startDate)} – '
                            '${DateFormat.MMMd().format(endDate)})',
                      ),
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: 'Prescribed by',
                        value: details?.doctorName ?? '—',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('About this medicine', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                MedicineInfo.describe(m.name),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _explainReadOnly('edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _explainReadOnly('delete'),
                      icon: Icon(Icons.delete_outline, color: AppTheme.critical),
                      label: Text('Delete', style: TextStyle(color: AppTheme.critical)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: AppTheme.critical)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTime(String hhmmss) {
    final parts = hhmmss.split(':');
    final t = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(label)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

class _Details {
  final List<String> times;
  final String? doctorName;
  _Details({required this.times, required this.doctorName});
}
