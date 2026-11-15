import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../data/models/ai_insight.dart';
import '../../data/models/medication_models.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../ai/ai_assistant_screen.dart';

/// AI Insights tab (MedGuardian AI UI plan): Overview (this week's
/// adherence + the nightly `aiInsightsBatch` insight + missed-dose stats)
/// and Trends (adherence over the last few weeks).
class AiInsightsScreen extends StatefulWidget {
  final Profile profile;
  const AiInsightsScreen({super.key, required this.profile});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen>
    with SingleTickerProviderStateMixin {
  final _medRepo = MedicationRepository();
  final _analyticsRepo = AnalyticsRepository();
  late TabController _tabController;
  late Future<_InsightsData> _future;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_InsightsData> _load() async {
    final week = await _medRepo.fetchHistory(widget.profile.id, days: 7);
    final month = await _medRepo.fetchHistory(widget.profile.id, days: 28);
    final insights = await _analyticsRepo.latestInsightsForPatients([widget.profile.id]);
    return _InsightsData(week: week, month: month, insight: insights[widget.profile.id]);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(child: Text('AI Insights', style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                tooltip: 'About AI Insights',
                icon: const Icon(Icons.info_outline),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('About AI Insights'),
                    content: const Text(
                      'Generated nightly from your dose history. These are explanations '
                      'and suggestions, not medical advice — always check anything '
                      'important with your doctor or caregiver.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: AppTheme.primary,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Trends')],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<_InsightsData>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(data: data),
                    _TrendsTab(month: data.month),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final _InsightsData data;
  const _OverviewTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final byDay = <DateTime, List<MedicationEvent>>{};
    final today = DateTime.now();
    for (var i = 6; i >= 0; i--) {
      final d = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      byDay[d] = [];
    }
    for (final e in data.week) {
      final d = DateTime(e.scheduledAt.year, e.scheduledAt.month, e.scheduledAt.day);
      byDay[d]?.add(e);
    }

    final totalScheduled = data.week.length;
    final totalConsumed =
        data.week.where((e) => e.finalStatus == EventStatus.consumed).length;
    final missed = data.week
        .where((e) =>
            e.finalStatus == EventStatus.missed || e.finalStatus == EventStatus.notConsumed)
        .toList();
    final weekPercent = totalScheduled == 0 ? 0.0 : totalConsumed / totalScheduled * 100;

    String mostMissedTime = '—';
    if (missed.isNotEmpty) {
      final hourCounts = <int, int>{};
      for (final e in missed) {
        hourCounts[e.scheduledAt.hour] = (hourCounts[e.scheduledAt.hour] ?? 0) + 1;
      }
      final topHour = hourCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      mostMissedTime = DateFormat.jm().format(DateTime(2000, 1, 1, topHour));
    }

    return ListView(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Adherence This Week', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${weekPercent.round()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Chip(
                      label: Text(weekPercent >= 80 ? 'Good' : (weekPercent >= 50 ? 'Fair' : 'Needs focus')),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: (weekPercent >= 80 ? AppTheme.success : AppTheme.pending)
                          .withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        color: weekPercent >= 80 ? AppTheme.success : AppTheme.pending,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                totalScheduled == 0
                    ? 'Nothing scheduled this week yet.'
                    : 'You missed ${missed.length} dose(s) this week.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 90,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: byDay.entries.map((entry) {
                    final events = entry.value;
                    final total = events.length;
                    final consumed =
                        events.where((e) => e.finalStatus == EventStatus.consumed).length;
                    final pct = total == 0 ? 0.0 : consumed / total;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 6 + 64 * pct,
                              decoration: BoxDecoration(
                                color: total == 0
                                    ? Theme.of(context).colorScheme.outlineVariant
                                    : AppTheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(DateFormat.E().format(entry.key).substring(0, 1),
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_outlined,
                      color: Theme.of(context).colorScheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Text('AI Insight',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      )),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data.insight?.insightText ??
                    'No insight yet — these are generated nightly once you have a few '
                        'days of dose history.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AiAssistantScreen(),
                  )),
                  child: const Text('View Recommendations'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Missed Doses', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('This Week', style: Theme.of(context).textTheme.bodySmall),
                        Text('${missed.length}',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.critical)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Most missed', style: Theme.of(context).textTheme.bodySmall),
                        Text(mostMissedTime,
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.critical)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendsTab extends StatelessWidget {
  final List<MedicationEvent> month;
  const _TrendsTab({required this.month});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final buckets = List.generate(4, (i) => <MedicationEvent>[]);
    for (final e in month) {
      final daysAgo = DateTime(today.year, today.month, today.day)
          .difference(DateTime(e.scheduledAt.year, e.scheduledAt.month, e.scheduledAt.day))
          .inDays;
      final bucket = (daysAgo / 7).floor();
      if (bucket >= 0 && bucket < 4) buckets[bucket].add(e);
    }
    final labels = ['This week', 'Last week', '2 weeks ago', '3 weeks ago'];

    return ListView(
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
              const Text('4-week adherence trend', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 18),
              ...List.generate(4, (i) {
                final events = buckets[i];
                final total = events.length;
                final consumed =
                    events.where((e) => e.finalStatus == EventStatus.consumed).length;
                final pct = total == 0 ? 0.0 : consumed / total * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(labels[i], style: Theme.of(context).textTheme.bodySmall),
                          Text('${pct.round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : pct / 100,
                          minHeight: 8,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(
                            pct >= 80 ? AppTheme.success : AppTheme.pending,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightsData {
  final List<MedicationEvent> week;
  final List<MedicationEvent> month;
  final AiInsight? insight;
  _InsightsData({required this.week, required this.month, required this.insight});
}
