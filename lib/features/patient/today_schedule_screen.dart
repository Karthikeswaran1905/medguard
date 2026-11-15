import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../data/models/medication_models.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/medication_repository.dart';
import '../../shared/widgets.dart';

/// Today's Schedule (MedGuardian AI UI plan): a day picker (Sun–Sat) over
/// the week containing [initialDate] (defaults to today) plus that day's
/// doses, each expandable into "Mark as Taken" / "Mark as Missed".
class TodayScheduleScreen extends StatefulWidget {
  final Profile profile;
  final DateTime? initialDate;
  const TodayScheduleScreen({super.key, required this.profile, this.initialDate});

  @override
  State<TodayScheduleScreen> createState() => _TodayScheduleScreenState();
}

class _TodayScheduleScreenState extends State<TodayScheduleScreen> {
  final _medRepo = MedicationRepository();
  late DateTime _selected;
  late List<DateTime> _week;
  late Future<List<MedicationEvent>> _future;
  String? _expandedEventId;

  @override
  void initState() {
    super.initState();
    _selected = _dateOnly(widget.initialDate ?? DateTime.now());
    _week = _weekFor(_selected);
    _future = _load();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DateTime> _weekFor(DateTime d) {
    // Sunday-start week, matching the mockup's Sun..Sat header.
    final sunday = d.subtract(Duration(days: d.weekday % 7));
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

  Future<List<MedicationEvent>> _load() {
    return _medRepo.fetchEventsForDate(widget.profile.id, _selected);
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selected = day;
      _expandedEventId = null;
      _future = _load();
    });
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _markTaken(MedicationEvent e) async {
    await _medRepo.confirmConsumed(e.id);
    if (mounted) setState(() => _expandedEventId = null);
    await _refresh();
  }

  Future<void> _markMissed(MedicationEvent e) async {
    await _medRepo.markMissed(e.id);
    if (mounted) setState(() => _expandedEventId = null);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _dateOnly(DateTime.now()) == _selected;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Schedule"),
        actions: [
          IconButton(
            tooltip: 'Jump to today',
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () => _selectDay(_dateOnly(DateTime.now())),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _week.map((d) {
                final selected = d == _selected;
                final today = d == _dateOnly(DateTime.now());
                return GestureDetector(
                  onTap: () => _selectDay(d),
                  child: Container(
                    width: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: today && !selected
                          ? Border.all(color: AppTheme.primary)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat.E().format(d).substring(0, 3),
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? Colors.white70 : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<MedicationEvent>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final events = snapshot.data!;
                  if (events.isEmpty) {
                    return ListView(
                      children: [
                        EmptyState(
                          message: isToday
                              ? 'Nothing scheduled today.'
                              : 'Nothing scheduled on ${DateFormat.MMMd().format(_selected)}.',
                          icon: Icons.event_available_outlined,
                        ),
                      ],
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...events.map((e) => _DayEventCard(
                            event: e,
                            expanded: _expandedEventId == e.id,
                            onTap: () => setState(
                              () => _expandedEventId = _expandedEventId == e.id ? null : e.id,
                            ),
                            onMarkTaken: () => _markTaken(e),
                            onMarkMissed: () => _markMissed(e),
                          )),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_drink_outlined),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text("Don't forget to drink water — stay hydrated!"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayEventCard extends StatelessWidget {
  final MedicationEvent event;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onMarkTaken;
  final VoidCallback onMarkMissed;

  const _DayEventCard({
    required this.event,
    required this.expanded,
    required this.onTap,
    required this.onMarkTaken,
    required this.onMarkMissed,
  });

  @override
  Widget build(BuildContext context) {
    final taken = event.finalStatus == EventStatus.consumed;
    final missed =
        event.finalStatus == EventStatus.missed || event.finalStatus == EventStatus.notConsumed;
    final pending = event.finalStatus == EventStatus.pending;
    final color = taken ? AppTheme.success : (missed ? AppTheme.critical : AppTheme.pending);
    final label = taken ? 'Taken' : (missed ? 'Missed' : 'Upcoming');
    final time = DateFormat.jm().format(event.scheduledAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: InkWell(
        onTap: pending ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(time, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                        const SizedBox(height: 2),
                        Text(event.medicineName ?? 'Medicine',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (event.medicineDose != null && event.medicineDose!.isNotEmpty)
                          Text(event.medicineDose!, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
                ],
              ),
              if (expanded && pending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: onMarkMissed, child: const Text('Mark as Missed')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(onPressed: onMarkTaken, child: const Text('Mark as Taken')),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
