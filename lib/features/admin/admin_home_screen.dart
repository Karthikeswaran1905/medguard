import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../shared/widgets.dart';
import 'add_doctor_screen.dart';
import 'alert_analytics_screen.dart';
import 'doctor_list_screen.dart';
import 'patient_overview_screen.dart';
import 'system_analytics_screen.dart';

/// Admin/Dean Dashboard (Section 10, 27; MedGuardian screen spec A1) — the
/// org-level overview and launch point for the other six Admin MVP
/// screens: Doctor List (-> Add Doctor -> Doctor Details), Patient
/// Overview, System Analytics, Alert Analytics.
///
/// Visually this follows a richer reference dashboard (stat cards, an
/// adherence donut, an alerts summary, a recent-activity feed, quick
/// actions and a recent-patients list) adapted to the app's normal mobile
/// layout rather than that reference's desktop sidebar — every other
/// screen here (including the ones this dashboard links to) uses the
/// standard scrollable single-column + app-bar shape, so a permanent
/// sidebar would only ever appear on this one screen.
///
/// What's real vs. illustrative:
///  - The four stat counts (Doctors/Incharges/Caretakers/Patients) are the
///    same live `AnalyticsRepository.orgCounts` query the old version of
///    this screen used — unchanged.
///  - "View all" only appears on Doctors and Patients, because those are
///    the only two with a real destination screen. There's no screen yet
///    that lists every Incharge or Caretaker org-wide (Admin only manages
///    Doctors directly — Doctors add Incharges, Incharges add
///    Caretakers), so those two cards show a count and nothing else.
///  - The adherence donut, alerts breakdown, recent-activity feed and
///    recent-patients list are all mock/sample data — MedGuard doesn't
///    have the aggregation queries those would need yet (see each
///    widget's doc comment below for specifics). Every button that
///    navigates somewhere (Add Doctor, Patients, System Analytics, Alert
///    Analytics, and both "View all" links) still goes to the same real
///    screens as before.
class AdminHomeScreen extends StatefulWidget {
  final Profile profile;
  const AdminHomeScreen({super.key, required this.profile});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _analyticsRepo = AnalyticsRepository();
  late Future<Map<String, int>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, int>> _load() => _analyticsRepo.orgCounts(widget.profile.orgId);

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RoleScaffold(
      title: 'Admin / Dean',
      profile: widget.profile,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Map<String, int>>(
          future: _future,
          builder: (context, snapshot) {
            final counts = snapshot.data ?? const {};
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Greeting(profile: widget.profile),
                const SizedBox(height: 20),
                _StatGrid(
                  counts: counts,
                  onViewDoctors: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminDoctorListScreen(profile: widget.profile),
                  )),
                  onViewPatients: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminPatientOverviewScreen(profile: widget.profile),
                  )),
                ),
                const SizedBox(height: 14),
                const _AdherenceCard(),
                const SizedBox(height: 14),
                _AlertsCard(
                  onViewAll: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminAlertAnalyticsScreen(profile: widget.profile),
                  )),
                ),
                const SectionHeader(title: 'Recent activity'),
                const _RecentActivityCard(),
                const SectionHeader(title: 'Quick actions'),
                _QuickActionsGrid(
                  onAddDoctor: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminAddDoctorScreen(profile: widget.profile),
                  )),
                  onPatients: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminPatientOverviewScreen(profile: widget.profile),
                  )),
                  onSystemAnalytics: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminSystemAnalyticsScreen(profile: widget.profile),
                  )),
                  onAlertAnalytics: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminAlertAnalyticsScreen(profile: widget.profile),
                  )),
                ),
                SectionHeader(
                  title: 'Recent patients',
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AdminPatientOverviewScreen(profile: widget.profile),
                    )),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('View all'),
                  ),
                ),
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

/// "Welcome, {first name} 👋" header with today's date — purely cosmetic,
/// drawing the name from the real signed-in profile.
class _Greeting extends StatelessWidget {
  final Profile profile;
  const _Greeting({required this.profile});

  @override
  Widget build(BuildContext context) {
    final trimmed = profile.fullName.trim();
    final firstName = trimmed.isEmpty ? 'Admin' : trimmed.split(' ').first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $firstName 👋',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Here's what's happening in MedGuard today.",
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

/// The four org-level counts — same live query the dashboard has always
/// used (`AnalyticsRepository.orgCounts`), just restyled as colored stat
/// cards. Only Doctors and Patients get a "View all" link; see the file
/// header for why Incharges/Caretakers don't.
class _StatGrid extends StatelessWidget {
  final Map<String, int> counts;
  final VoidCallback onViewDoctors;
  final VoidCallback onViewPatients;

  const _StatGrid({
    required this.counts,
    required this.onViewDoctors,
    required this.onViewPatients,
  });

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
        _StatCard(
          icon: Icons.medical_services_outlined,
          color: AppTheme.primary,
          value: '${counts['doctors'] ?? 0}',
          label: 'Doctors',
          onViewAll: onViewDoctors,
        ),
        _StatCard(
          icon: Icons.badge_outlined,
          color: const Color(0xFF7C3AED),
          value: '${counts['incharges'] ?? 0}',
          label: 'Incharges',
        ),
        _StatCard(
          icon: Icons.volunteer_activism_outlined,
          color: const Color(0xFFEA580C),
          value: '${counts['caretakers'] ?? 0}',
          label: 'Caretakers',
        ),
        _StatCard(
          icon: Icons.people_alt_outlined,
          color: const Color(0xFF16A34A),
          value: '${counts['patients'] ?? 0}',
          label: 'Patients',
          onViewAll: onViewPatients,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback? onViewAll;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          if (onViewAll != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onViewAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward, size: 11, color: color),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared white rounded-card shell used by the mock dashboard widgets
/// below (adherence, alerts, recent activity, recent patients).
class _DashboardCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _DashboardCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF))),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Medication Adherence Overview donut. Mock/sample numbers — there's no
/// org-wide "taken vs. missed vs. skipped" breakdown query yet;
/// [AdminSystemAnalyticsScreen] has the real adherence figure (a single
/// percentage from `AnalyticsRepository.statsForPatients`), just not
/// split into these three buckets. Wire this up to that (or a new query)
/// once that breakdown exists.
class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard();

  static const _taken = 78;
  static const _missed = 15;
  static const _skipped = 7;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      title: 'Medication Adherence Overview',
      subtitle: 'Sample data',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
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
                    Text('$_taken%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Adherence', style: TextStyle(fontSize: 10.5, color: Color(0xFF6B7280))),
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

/// Alerts Overview. Mock/sample breakdown — [AdminAlertAnalyticsScreen]
/// (the real screen "View all alerts" links to) tracks escalated /
/// critical-unresolved counts, not this three-way "who didn't respond"
/// split; that categorization doesn't exist as a query yet.
class _AlertsCard extends StatelessWidget {
  final VoidCallback onViewAll;
  const _AlertsCard({required this.onViewAll});

  static const _patientNoResponse = 14;
  static const _caretakerNoResponse = 7;
  static const _escalatedToIncharge = 3;
  static const _total = _patientNoResponse + _caretakerNoResponse + _escalatedToIncharge;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      title: 'Alerts Overview',
      subtitle: 'Sample data',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.critical.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_outlined, color: AppTheme.critical, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_total', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Total alerts', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _AlertRow(color: AppTheme.critical, label: 'Patient no response', value: _patientNoResponse),
          const SizedBox(height: 8),
          const _AlertRow(color: AppTheme.pending, label: 'Caretaker no response', value: _caretakerNoResponse),
          const SizedBox(height: 8),
          const _AlertRow(color: AppTheme.primary, label: 'Escalated to incharge', value: _escalatedToIncharge),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppTheme.critical,
              ),
              child: const Text('View all alerts →', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  const _AlertRow({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151)))),
        Text('$value', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}

/// Recent Activity feed. Mock/sample — there's no general activity-log
/// query yet (the `audit_logs` collection only records
/// `staff_account_created` events; see firestore.rules). Wire this to a
/// real feed if/when one gets built.
class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  static const _items = [
    _ActivityItem(
      icon: Icons.check_circle_outline,
      color: AppTheme.success,
      title: 'Patient marked medicine as Taken',
      subtitle: 'Paracetamol 500mg · 08:00 AM',
      time: '10 mins ago',
    ),
    _ActivityItem(
      icon: Icons.warning_amber_outlined,
      color: AppTheme.pending,
      title: 'Alert sent to caretaker',
      subtitle: 'No response for 08:00 AM medication',
      time: '35 mins ago',
    ),
    _ActivityItem(
      icon: Icons.person_add_alt_outlined,
      color: AppTheme.primary,
      title: 'New patient added',
      subtitle: 'By a Doctor in your organization',
      time: '1 hour ago',
    ),
    _ActivityItem(
      icon: Icons.groups_outlined,
      color: Color(0xFF7C3AED),
      title: 'Caretaker assigned to a patient',
      subtitle: 'By an Incharge in your organization',
      time: '2 hours ago',
    ),
    _ActivityItem(
      icon: Icons.description_outlined,
      color: AppTheme.success,
      title: 'New prescription uploaded',
      subtitle: 'By a Doctor in your organization',
      time: '3 hours ago',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      title: 'Recent Activity',
      subtitle: 'Sample data',
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            _ActivityRow(item: _items[i]),
            if (i != _items.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final _ActivityItem item;
  const _ActivityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              Text(item.subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(item.time, style: const TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF))),
      ],
    );
  }
}

/// Quick Actions — only real destinations (per the file header, Admin's
/// actual four capabilities), styled as the reference's colored action
/// chips rather than the old plain nav-card list.
class _QuickActionsGrid extends StatelessWidget {
  final VoidCallback onAddDoctor;
  final VoidCallback onPatients;
  final VoidCallback onSystemAnalytics;
  final VoidCallback onAlertAnalytics;

  const _QuickActionsGrid({
    required this.onAddDoctor,
    required this.onPatients,
    required this.onSystemAnalytics,
    required this.onAlertAnalytics,
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
          icon: Icons.person_add_alt_1_outlined,
          color: AppTheme.primary,
          label: 'Add Doctor',
          onTap: onAddDoctor,
        ),
        _QuickActionTile(
          icon: Icons.people_outline,
          color: const Color(0xFF16A34A),
          label: 'Patients',
          onTap: onPatients,
        ),
        _QuickActionTile(
          icon: Icons.insights_outlined,
          color: const Color(0xFF7C3AED),
          label: 'System Analytics',
          onTap: onSystemAnalytics,
        ),
        _QuickActionTile(
          icon: Icons.warning_amber_outlined,
          color: AppTheme.critical,
          label: 'Alert Analytics',
          onTap: onAlertAnalytics,
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
  final String incharge;
  final String caretaker;
  final int adherence;
  final String status;
  final Color statusColor;

  const _MockPatientRow({
    required this.initials,
    required this.avatarColor,
    required this.name,
    required this.meta,
    required this.incharge,
    required this.caretaker,
    required this.adherence,
    required this.status,
    required this.statusColor,
  });
}

/// Recent Patients. Mock/sample rows, adapted from the reference's
/// desktop table into mobile-friendly cards — there's no live query yet
/// that joins a patient with their incharge/caretaker names and a recent
/// adherence figure in one row; [AdminPatientOverviewScreen] (the real
/// screen "View all" links to) lists every real patient in the org, just
/// without this particular summary shape.
class _RecentPatientsCard extends StatelessWidget {
  const _RecentPatientsCard();

  static const _rows = [
    _MockPatientRow(
      initials: 'RK',
      avatarColor: Color(0xFF2563EB),
      name: 'Rajesh Kumar',
      meta: '45 · Male',
      incharge: 'Priya Sharma',
      caretaker: 'Manoj Kumar',
      adherence: 85,
      status: 'Good',
      statusColor: AppTheme.success,
    ),
    _MockPatientRow(
      initials: 'AS',
      avatarColor: Color(0xFF7C3AED),
      name: 'Anitha Subramani',
      meta: '38 · Female',
      incharge: 'Priya Sharma',
      caretaker: 'Manoj Kumar',
      adherence: 62,
      status: 'Medium',
      statusColor: AppTheme.pending,
    ),
    _MockPatientRow(
      initials: 'RB',
      avatarColor: Color(0xFFEA580C),
      name: 'Ramesh Babu',
      meta: '60 · Male',
      incharge: 'Sanjay Patel',
      caretaker: 'Kavitha R',
      adherence: 40,
      status: 'Low',
      statusColor: AppTheme.critical,
    ),
    _MockPatientRow(
      initials: 'SK',
      avatarColor: Color(0xFF16A34A),
      name: 'Suresh Kumar',
      meta: '50 · Male',
      incharge: 'Sanjay Patel',
      caretaker: 'Kavitha R',
      adherence: 90,
      status: 'Good',
      statusColor: AppTheme.success,
    ),
    _MockPatientRow(
      initials: 'LN',
      avatarColor: Color(0xFFDB2777),
      name: 'Lakshmi Nair',
      meta: '55 · Female',
      incharge: 'Meena Iyer',
      caretaker: 'Arun Das',
      adherence: 75,
      status: 'Good',
      statusColor: AppTheme.success,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
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
                '${row.meta} · Incharge ${row.incharge} · Caretaker ${row.caretaker}',
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
