import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';

/// Doctor Details (MedGuardian screen spec A4) — a Doctor's own profile
/// plus how many patients are currently linked to them via
/// `doctor_patient_links` (`PeopleRepository.fetchPatientsForDoctor`).
/// Read-only in this MVP pass — Edit Doctor isn't in the spec's 7-screen
/// Admin MVP list, only the full 26-screen catalog.
class AdminDoctorDetailsScreen extends StatefulWidget {
  final Profile doctor;
  const AdminDoctorDetailsScreen({super.key, required this.doctor});

  @override
  State<AdminDoctorDetailsScreen> createState() => _AdminDoctorDetailsScreenState();
}

class _AdminDoctorDetailsScreenState extends State<AdminDoctorDetailsScreen> {
  final _peopleRepo = PeopleRepository();
  late Future<List<Profile>> _future;

  @override
  void initState() {
    super.initState();
    _future = _peopleRepo.fetchPatientsForDoctor(widget.doctor.id);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doctor;
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor details')),
      backgroundColor: const Color(0xFFF7F9F9),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Row(
              children: [
                PersonAvatar(name: d.fullName, radius: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF111827)),
                      ),
                      const SizedBox(height: 4),
                      if (d.email != null && d.email!.isNotEmpty)
                        _DetailLine(icon: Icons.mail_outline, text: d.email!),
                      if (d.phone != null && d.phone!.isNotEmpty)
                        _DetailLine(icon: Icons.call_outlined, text: d.phone!),
                      _DetailLine(
                        icon: Icons.calendar_today_outlined,
                        text: 'Joined ${DateFormat.yMMMd().format(d.createdAt)}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Patients'),
          FutureBuilder<List<Profile>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final patients = snapshot.data!;
              if (patients.isEmpty) {
                return const EmptyState(message: 'No patients linked to this doctor yet.');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: MetricCard(
                      icon: Icons.people_alt_outlined,
                      color: AppTheme.primary,
                      value: '${patients.length}',
                      label: patients.length == 1 ? 'Patient' : 'Patients',
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...patients.map(
                    (p) => PersonListCard(name: p.fullName, subtitle: p.phone ?? ''),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Small icon + text row used for the profile header's email/phone/joined
/// lines — a bit more polished than plain stacked `Text` widgets.
class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
