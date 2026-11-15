import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/profile.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../shared/widgets.dart';

/// Notifications (MedGuardian screen spec C7) — this Caretaker's
/// `notifications` history (`NotificationsRepository.fetchForUser`,
/// Section 43). See that method's doc comment: nothing writes to this
/// collection yet on the Spark plan MedGuard currently runs on (only the
/// `sendNotification` Cloud Function does, and Cloud Functions can't
/// deploy on Spark at all), so this screen is expected to show its empty
/// state until the project upgrades to Blaze — Alert Center is the live,
/// entirely client-side equivalent in the meantime.
class CaretakerNotificationsScreen extends StatefulWidget {
  final Profile profile;
  const CaretakerNotificationsScreen({super.key, required this.profile});

  @override
  State<CaretakerNotificationsScreen> createState() => _CaretakerNotificationsScreenState();
}

class _CaretakerNotificationsScreenState extends State<CaretakerNotificationsScreen> {
  final _notificationsRepo = NotificationsRepository();
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _notificationsRepo.fetchForUser(widget.profile.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = _notificationsRepo.fetchForUser(widget.profile.id));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AppNotification>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final notifications = snapshot.data!;
            if (notifications.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(
                    message: 'No notifications yet. Pending doses that need your attention '
                        'show up in Alert Center in the meantime.',
                    icon: Icons.notifications_none_outlined,
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, i) {
                final n = notifications[i];
                return Card(
                  color: n.read ? null : Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: Icon(
                      n.read ? Icons.notifications_none_outlined : Icons.notifications_active_outlined,
                    ),
                    title: Text(n.title),
                    subtitle: Text(n.body),
                    trailing: Text(
                      DateFormat.MMMd().add_jm().format(n.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
