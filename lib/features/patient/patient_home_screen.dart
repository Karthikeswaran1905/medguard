import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../data/models/medication_models.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/medication_repository.dart';
import 'today_schedule_screen.dart';

/// Patient Home tab — redesigned to match the MedGuardian AI UI plan:
/// greeting header, an "Adherence Today" ring card, a "Next Dose" action
/// card, and a Today's Schedule preview. This is tab content only (no
/// `Scaffold`/`AppBar` of its own) — [PatientShell] supplies those.
class PatientHomeScreen extends StatefulWidget {
  final Profile profile;
  const PatientHomeScreen({super.key, required this.profile});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final _medRepo = MedicationRepository();
  late Future<_PatientData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PatientData> _load() async {
    await _medRepo.ensureTodayEvents(widget.profile.id);
    final today = await _medRepo.fetchTodayEvents(widget.profile.id);
    return _PatientData(today: today);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _confirm(MedicationEvent event) async {
    await _medRepo.confirmConsumed(event.id);
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as taken. Thank you!')),
      );
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _firstName {
    final parts = widget.profile.fullName.trim().split(' ');
    return parts.isNotEmpty && parts.first.isNotEmpty ? parts.first : 'there';
  }

  void _openTodaySchedule() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TodayScheduleScreen(profile: widget.profile),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_PatientData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final pendingToday = data.today.where((e) => e.finalStatus == EventStatus.pending);
          final takenToday =
              data.today.where((e) => e.finalStatus == EventStatus.consumed).length;
          final nextDose = pendingToday.isEmpty
              ? null
              : (pendingToday.toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt)))
                  .first;
          final todayPercent =
              data.today.isEmpty ? 0.0 : takenToday / data.today.length * 100;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.health_and_safety, color: AppTheme.primary, size: 26),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MedGuardian AI',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Patient',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _NotificationBell(count: pendingToday.length),
                ],
              ),
              const SizedBox(height: 18),
              Text('$_greeting, $_firstName 👋', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Here is your health overview for today.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              _AdherenceTodayCard(
                percent: todayPercent,
                taken: takenToday,
                total: data.today.length,
                onViewDetails: _openTodaySchedule,
              ),
              const SizedBox(height: 14),
              if (nextDose != null)
                _NextDoseCard(event: nextDose, onMarkTaken: () => _confirm(nextDose))
              else
                const _AllDoneCard(),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Today's Schedule", style: Theme.of(context).textTheme.titleMedium),
                  TextButton(onPressed: _openTodaySchedule, child: const Text('View All')),
                ],
              ),
              if (data.today.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No medicines scheduled for today.'),
                )
              else
                ...data.today.take(3).map((e) => _ScheduleRow(event: e)),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int count;
  const _NotificationBell({required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: count == 0 ? 'No pending doses' : '$count dose(s) pending today',
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined),
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.critical,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdherenceTodayCard extends StatelessWidget {
  final double percent;
  final int taken;
  final int total;
  final VoidCallback onViewDetails;

  const _AdherenceTodayCard({
    required this.percent,
    required this.taken,
    required this.total,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final good = percent >= 80;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.success],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: total == 0 ? 0 : percent / 100,
                  strokeWidth: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
                Text(
                  '${percent.round()}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adherence Today',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  total == 0
                      ? 'Nothing scheduled today.'
                      : (good ? 'Great! You are doing well.' : 'Let\'s catch up on today\'s doses.'),
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                ),
                Text(
                  '$taken of $total doses taken',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onViewDetails,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View Details',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                      Icon(Icons.chevron_right, color: Colors.white, size: 16),
                    ],
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

class _NextDoseCard extends StatelessWidget {
  final MedicationEvent event;
  final VoidCallback onMarkTaken;
  const _NextDoseCard({required this.event, required this.onMarkTaken});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.jm().format(event.scheduledAt);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.medication_outlined, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Next Dose', style: Theme.of(context).textTheme.labelMedium),
                    Text(
                      '${event.medicineName ?? 'Medicine'} · $time',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (event.medicineDose != null && event.medicineDose!.isNotEmpty)
                      Text(event.medicineDose!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onMarkTaken, child: const Text('Mark as Taken')),
          ),
        ],
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppTheme.success),
          const SizedBox(width: 10),
          const Expanded(child: Text('All caught up — nothing pending right now.')),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final MedicationEvent event;
  const _ScheduleRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final taken = event.finalStatus == EventStatus.consumed;
    final missed =
        event.finalStatus == EventStatus.missed || event.finalStatus == EventStatus.notConsumed;
    final color = taken ? AppTheme.success : (missed ? AppTheme.critical : AppTheme.pending);
    final label = taken ? 'Taken' : (missed ? 'Missed' : 'Upcoming');
    final time = DateFormat.jm().format(event.scheduledAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: const [],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(time, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.medicineName ?? 'Medicine', style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (event.medicineDose != null && event.medicineDose!.isNotEmpty)
                    Text(event.medicineDose!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _PatientData {
  final List<MedicationEvent> today;
  _PatientData({required this.today});
}
