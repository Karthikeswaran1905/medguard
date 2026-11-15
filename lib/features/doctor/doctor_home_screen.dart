import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';
import 'add_incharge_screen.dart';
import 'incharge_list_screen.dart';
import 'patient_list_screen.dart';

/// Doctor Dashboard (Section 9, 27; MedGuardian screen spec D1) — the
/// clinical-management hub and launch point for the other Doctor MVP
/// screens: Patient List (-> Patient Details -> Medication List -> Add
/// Medicine -> Medication Configuration -> Review Medication) and
/// Incharge List (-> Add Incharge; Allocate Incharge lives on Patient
/// Details, matching the spec's own Doctor workflow diagram).
///
/// Visually this follows the same reference dashboard style Admin's
/// screen (`AdminHomeScreen`) was built from — stat cards, today's
/// schedule, a medication-adherence donut, quick actions, recent patients
/// and recent alerts — adapted to the app's normal mobile single-column
/// layout rather than that reference's desktop sidebar, matching every
/// other screen in the app.
///
/// What's real vs. illustrative:
///  - "Total Patients" and "Pending Alerts" are live: patient count from
///    `PeopleRepository.fetchPatientsForDoctor`, alert count from
///    `AnalyticsRepository.countEscalated` (the same escalated-events
///    query Admin's Alert Analytics screen uses) over this Doctor's own
///    patients.
///  - "Active Prescriptions" and "Medications" are mock/sample — there's
///    no query yet that counts prescriptions/medicines across every one
///    of a Doctor's patients (`MedicationRepository.fetchMedicinesForPatient`
///    is per-patient only).
///  - Today's Schedule, the Medication Adherence donut, and Recent
///    Patients are all mock/sample, same as Admin's dashboard — no
///    appointment-schedule model, no org-wide taken/missed/skipped
///    breakdown query, and no single query joining a patient with a
///    recent-activity summary yet.
///  - Every Quick Action goes to a real screen or a real action (invite
///    code, prescribing via Patients, Incharges, Add Incharge) — nothing
///    here is a dead link.
class DoctorHomeScreen extends StatefulWidget {
  final Profile profile;
  const DoctorHomeScreen({super.key, required this.profile});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  final _peopleRepo = PeopleRepository();
  final _analyticsRepo = AnalyticsRepository();
  late Future<_DoctorSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DoctorSummary> _load() async {
    final patients = await _peopleRepo.fetchPatientsForDoctor(widget.profile.id);
    final incharges = await _peopleRepo.fetchByRole(AppRole.incharge, orgId: widget.profile.orgId);
    final patientIds = patients.map((p) => p.id).toList();
    final stats = await _analyticsRepo.statsForPatients(patientIds);
    final escalated = await _analyticsRepo.countEscalated(patientIds);
    return _DoctorSummary(
      patients: patients,
      inchargeCount: incharges.length,
      stats: stats,
      escalatedCount: escalated,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _showInviteCode() async {
    final code = await _peopleRepo.generateInviteCode(
      doctorId: widget.profile.id,
      orgId: widget.profile.orgId,
    );
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Patient invite code'),
        content: Text(
          'Share this code with your patient. They enter it during sign-up '
          'to be linked to you automatically (Section 39):\n\n$code',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _addIncharge() async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => DoctorAddInchargeScreen(profile: widget.profile),
    ));
    if (added == true) await _refresh();
  }

  void _openPatients() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DoctorPatientListScreen(profile: widget.profile),
      ));

  void _openIncharges() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DoctorInchargeListScreen(profile: widget.profile),
      ));

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Doctor',
      profile: widget.profile,
      actions: [
        IconButton(
          tooltip: 'Generate patient invite code',
          icon: const Icon(Icons.qr_code_2_outlined),
          onPressed: _showInviteCode,
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_DoctorSummary>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Greeting(profile: widget.profile),
                const SizedBox(height: 20),
                _StatGrid(data: data, onViewPatients: _openPatients),
                const SizedBox(height: 14),
                const _AdherenceCard(),
                const SizedBox(height: 14),
                const _TodayScheduleCard(),
                const SectionHeader(title: 'Recent alerts'),
                const _RecentAlertsCard(),
                const SectionHeader(title: 'Quick actions'),
                _QuickActionsGrid(
                  onInviteCode: _showInviteCode,
                  onPrescribe: _openPatients,
                  onIncharges: _openIncharges,
                  onAddIncharge: _addIncharge,
                ),
                SectionHeader(
                  title: 'Recent patients',
                  trailing: TextButton(
                    onPressed: _openPatients,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('View all patients'),
                  ),
                ),
                if (data.patients.isEmpty)
                  const EmptyState(
                    message: 'No patients yet. Share your invite code from the '
                        'button above so a patient can link to you.',
                    icon: Icons.people_outline,
                  )
                else
                  const _RecentPatientsCard(),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DoctorSummary {
  final List<Profile> patients;
  final int inchargeCount;
  final DashboardStats stats;
  final int escalatedCount;
  _DoctorSummary({
    required this.patients,
    required this.inchargeCount,
    required this.stats,
    required this.escalatedCount,
  });
}

/// "Good morning/afternoon/evening, Dr. {first name} 👋" header with
/// today's date — purely cosmetic, drawing the name from the real
/// signed-in profile.
class _Greeting extends StatelessWidget {
  final Profile profile;
  const _Greeting({required this.profile});

  static String _timeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = profile.fullName.trim();
    final firstName = trimmed.isEmpty ? '' : trimmed.split(' ').first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_timeOfDayGreeting()}, Dr. $firstName 👋',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Here's what's happening with your patients today.",
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.primary),
            const SizedBox(height: 4),
            Text(
              DateFormat.yMMMd().format(DateTime.now()),
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Four stat cards. Total Patients and Pending Alerts are live counts;
/// Active Prescriptions and Medications are mock/sample (see file header
/// for why) — mixed deliberately to match the reference layout, and
/// documented here so it's never mistaken for a real aggregate.
class _StatGrid extends StatelessWidget {
  final _DoctorSummary data;
  final VoidCallback onViewPatients;

  const _StatGrid({required this.data, required this.onViewPatients});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        MetricCard(
          icon: Icons.people_alt_outlined,
          color: AppTheme.primary,
          value: '${data.patients.length}',
          label: 'Total patients',
          onViewAll: onViewPatients,
        ),
        const MetricCard(
          icon: Icons.description_outlined,
          color: Color(0xFF2563EB),
          value: '24',
          label: 'Active prescriptions',
        ),
        const MetricCard(
          icon: Icons.medication_outlined,
          color: Color(0xFF7C3AED),
          value: '37',
          label: 'Medications',
        ),
        MetricCard(
          icon: Icons.notifications_active_outlined,
          color: data.escalatedCount == 0 ? AppTheme.success : AppTheme.critical,
          value: '${data.escalatedCount}',
          label: 'Pending alerts',
        ),
      ],
    );
  }
}

/// Medication Adherence donut. Mock/sample numbers — this Doctor's real
/// adherence figure (a single percentage) is available via
/// `AnalyticsRepository.statsForPatients`, just not split into a
/// taken/missed/skipped breakdown yet; wire this up to that (or a new
/// query) if that breakdown gets built.
class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard();

  static const _taken = 74;
  static const _missed = 18;
  static const _skipped = 8;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Medication Adherence',
      subtitle: 'Sample data',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: _DonutPainter(segments: [
                    _DonutSegment(_taken / 100, AppTheme.success),
                    _DonutSegment(_missed / 100, AppTheme.pending),
                    _DonutSegment(_skipped / 100, AppTheme.critical),
                  ]),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$_taken%', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                        Text('Overall', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _LegendRow(color: AppTheme.success, label: 'Taken', value: '$_taken%'),
                    SizedBox(height: 10),
                    _LegendRow(color: AppTheme.pending, label: 'Missed', value: '$_missed%'),
                    SizedBox(height: 10),
                    _LegendRow(color: AppTheme.critical, label: 'Skipped', value: '$_skipped%'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(Icons.trending_up, color: AppTheme.success, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Adherence is better than last month (+6%)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _LegendRow({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151)))),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _DonutSegment {
  final double fraction;
  final Color color;
  const _DonutSegment(this.fraction, this.color);
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  const _DonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.18;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    var startAngle = -math.pi / 2;
    for (final segment in segments) {
      final sweep = segment.fraction * 2 * math.pi;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.segments != segments;
}

class _ScheduleItem {
  final IconData icon;
  final String time;
  final String patientName;
  final String type;
  const _ScheduleItem({
    required this.icon,
    required this.time,
    required this.patientName,
    required this.type,
  });
}

/// Today's Schedule. Mock/sample data — MedGuard doesn't have an
/// appointment or visit-schedule collection yet, so these rows are
/// illustrative only; nothing here reads or writes real data.
class _TodayScheduleCard extends StatelessWidget {
  const _TodayScheduleCard();

  static const _items = [
    _ScheduleItem(icon: Icons.medication_outlined, time: '9:00 AM', patientName: 'Rajesh Kumar', type: 'Dose review'),
    _ScheduleItem(icon: Icons.call_outlined, time: '10:30 AM', patientName: 'Anitha Subramani', type: 'Follow-up call'),
    _ScheduleItem(
      icon: Icons.description_outlined,
      time: '12:00 PM',
      patientName: 'Ramesh Babu',
      type: 'Prescription renewal',
    ),
    _ScheduleItem(icon: Icons.medication_outlined, time: '2:30 PM', patientName: 'Suresh Kumar', type: 'Dose review'),
    _ScheduleItem(icon: Icons.call_outlined, time: '4:00 PM', patientName: 'Lakshmi Nair', type: 'Follow-up call'),
  ];

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: "Today's Schedule",
      subtitle: 'Sample data',
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            _ScheduleRow(item: _items[i]),
            if (i != _items.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final _ScheduleItem item;
  const _ScheduleRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(item.icon, color: AppTheme.primary, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.patientName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 2),
              Text(item.type, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(item.time, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
      ],
    );
  }
}

class _AlertItem {
  final IconData icon;
  final Color color;
  final String title;
  final String patientName;
  final String time;
  const _AlertItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.patientName,
    required this.time,
  });
}

/// Recent Alerts. Mock/sample — Doctor doesn't have an alerts feed or
/// screen yet (Alert Analytics is Admin-only, in `AdminAlertAnalyticsScreen`);
/// this mirrors that screen's escalation language without linking
/// anywhere, since there's no real destination to send a Doctor to yet.
class _RecentAlertsCard extends StatelessWidget {
  const _RecentAlertsCard();

  static const _items = [
    _AlertItem(
      icon: Icons.notifications_active_outlined,
      color: AppTheme.critical,
      title: 'No response from patient',
      patientName: 'Anitha Subramani',
      time: '20m ago',
    ),
    _AlertItem(
      icon: Icons.warning_amber_outlined,
      color: AppTheme.pending,
      title: 'Caretaker did not respond',
      patientName: 'Ramesh Babu',
      time: '55m ago',
    ),
    _AlertItem(
      icon: Icons.supervisor_account_outlined,
      color: AppTheme.primary,
      title: 'Escalated to Incharge',
      patientName: 'Lakshmi Nair',
      time: '3h ago',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Recent Alerts',
      subtitle: 'Sample data',
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            _AlertRow(item: _items[i]),
            if (i != _items.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final _AlertItem item;
  const _AlertRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: item.color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(item.icon, color: item.color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 2),
              Text(item.patientName, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(item.time, style: const TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF))),
      ],
    );
  }
}

/// Quick Actions — every tile goes to a real screen or a real action.
/// "Prescribe medicine" opens Patients rather than a standalone screen,
/// since prescribing always starts with picking a patient
/// (Patient Details -> Medications -> Add Medicine).
class _QuickActionsGrid extends StatelessWidget {
  final VoidCallback onInviteCode;
  final VoidCallback onPrescribe;
  final VoidCallback onIncharges;
  final VoidCallback onAddIncharge;

  const _QuickActionsGrid({
    required this.onInviteCode,
    required this.onPrescribe,
    required this.onIncharges,
    required this.onAddIncharge,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.6,
      children: [
        _QuickActionTile(
          icon: Icons.person_add_alt_outlined,
          color: AppTheme.primary,
          label: 'Invite patient',
          onTap: onInviteCode,
        ),
        _QuickActionTile(
          icon: Icons.medication_outlined,
          color: const Color(0xFF2563EB),
          label: 'Prescribe medicine',
          onTap: onPrescribe,
        ),
        _QuickActionTile(
          icon: Icons.supervisor_account_outlined,
          color: const Color(0xFF7C3AED),
          label: 'Manage incharges',
          onTap: onIncharges,
        ),
        _QuickActionTile(
          icon: Icons.add,
          color: const Color(0xFFEA580C),
          label: 'Add incharge',
          onTap: onAddIncharge,
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockPatientRow {
  final String initials;
  final Color avatarColor;
  final String name;
  final String meta;
  final String lastActivity;
  final int adherence;
  final String status;
  final Color statusColor;

  const _MockPatientRow({
    required this.initials,
    required this.avatarColor,
    required this.name,
    required this.meta,
    required this.lastActivity,
    required this.adherence,
    required this.status,
    required this.statusColor,
  });
}

/// Recent Patients. Mock/sample rows — there's no live query yet that
/// joins a patient with a recent-activity summary and a 30-day adherence
/// figure in one row; [DoctorPatientListScreen] ("View all patients"
/// above) lists every real patient linked to this Doctor, just without
/// this particular summary shape. Uses the same mock names/figures as
/// Admin's Recent Patients card so both dashboards' sample data agree.
class _RecentPatientsCard extends StatelessWidget {
  const _RecentPatientsCard();

  static const _rows = [
    _MockPatientRow(
      initials: 'RK',
      avatarColor: Color(0xFF2563EB),
      name: 'Rajesh Kumar',
      meta: '45 · Male',
      lastActivity: 'Marked as Taken · 10 mins ago',
      adherence: 85,
      status: 'Good',
      statusColor: AppTheme.success,
    ),
    _MockPatientRow(
      initials: 'AS',
      avatarColor: Color(0xFF7C3AED),
      name: 'Anitha Subramani',
      meta: '38 · Female',
      lastActivity: 'No response · 35 mins ago',
      adherence: 62,
      status: 'Medium',
      statusColor: AppTheme.pending,
    ),
    _MockPatientRow(
      initials: 'RB',
      avatarColor: Color(0xFFEA580C),
      name: 'Ramesh Babu',
      meta: '60 · Male',
      lastActivity: 'Caretaker alerted · 1 hour ago',
      adherence: 40,
      status: 'Low',
      statusColor: AppTheme.critical,
    ),
    _MockPatientRow(
      initials: 'SK',
      avatarColor: Color(0xFF16A34A),
      name: 'Suresh Kumar',
      meta: '50 · Male',
      lastActivity: 'Marked as Taken · 2 hours ago',
      adherence: 90,
      status: 'Good',
      statusColor: AppTheme.success,
    ),
    _MockPatientRow(
      initials: 'LN',
      avatarColor: Color(0xFFDB2777),
      name: 'Lakshmi Nair',
      meta: '55 · Female',
      lastActivity: 'Marked as Taken · 3 hours ago',
      adherence: 75,
      status: 'Good',
      statusColor: AppTheme.success,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Recent Patients',
      subtitle: 'Sample data',
      child: Column(
        children: [
          for (var i = 0; i < _rows.length; i++) ...[
            _PatientRow(row: _rows[i]),
            if (i != _rows.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _PatientRow extends StatelessWidget {
  final _MockPatientRow row;
  const _PatientRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: row.avatarColor.withValues(alpha: 0.15),
          child: Text(
            row.initials,
            style: TextStyle(color: row.avatarColor, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                '${row.meta} · ${row.lastActivity}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: row.adherence / 100,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFF1F5F4),
                  valueColor: AlwaysStoppedAnimation<Color>(row.statusColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: row.statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            row.status,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: row.statusColor),
          ),
        ),
      ],
    );
  }
}
