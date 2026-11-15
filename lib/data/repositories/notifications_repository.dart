import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

import '../firebase_client.dart';

/// Mirrors a `notifications/{id}` Firestore document (Section 43). Written
/// only by the `sendNotification` Cloud Function (Admin SDK) — see
/// [NotificationsRepository.fetchForUser]'s doc comment for what that
/// means on the Spark plan MedGuard currently runs on.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? type;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      title: map['title'] as String? ?? 'Notification',
      body: map['body'] as String? ?? '',
      type: map['type'] as String?,
      read: map['read'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Registers this device's FCM token in `device_tokens` (Section 43, 48) so
/// the `sendNotification` Cloud Function has somewhere to actually push
/// to. Until this repository existed, `device_tokens` and
/// `sendNotification` were both fully built server-side but nothing in the
/// Flutter app ever wrote a token — the escalation chain (Section 15, 40)
/// could compute *who* to notify but had no device to reach.
class NotificationsRepository {
  final _db = FirebaseService.db;
  final _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _refreshSub;

  /// Call once per signed-in session (see AuthGate) — requests
  /// notification permission, then registers the current token and keeps
  /// it current if FCM rotates it later.
  ///
  /// Web is skipped: web push needs a VAPID key plus a registered service
  /// worker, which is a separate piece of setup from the mobile-first MVP
  /// this report describes (Section 32) — left for a later iteration
  /// alongside the other stubs called out in SETUP.md.
  Future<void> registerForUser(String userId) async {
    if (kIsWeb) return;

    // On current firebase_messaging versions this also drives Android 13+'s
    // POST_NOTIFICATIONS runtime prompt, not just iOS/web — see
    // AndroidManifest.xml for the declared permission this relies on.
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(userId, token);
    }

    await _refreshSub?.cancel();
    _refreshSub = _messaging.onTokenRefresh.listen((newToken) => _saveToken(userId, newToken));
  }

  Future<void> _saveToken(String userId, String token) async {
    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    await _db.collection('device_tokens').doc(_tokenDocId(userId, token)).set({
      'userId': userId,
      'token': token,
      'platform': platform,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deterministic so re-registering the same token is an idempotent
  /// overwrite rather than a growing pile of duplicate documents — the
  /// Postgres schema enforced this with `unique (user_id, token)`;
  /// Firestore has no equivalent constraint, so the id does the job
  /// instead. Sanitized defensively since Firestore document ids can't
  /// contain '/'.
  String _tokenDocId(String userId, String token) => '${userId}_${token.replaceAll('/', '_')}';

  /// Called on sign-out so a stale token isn't left registered against an
  /// account that's no longer signed in on this device.
  Future<void> unregisterCurrentDevice(String userId) async {
    if (kIsWeb) return;
    await _refreshSub?.cancel();
    _refreshSub = null;
    final token = await _messaging.getToken();
    if (token == null) return;
    await _db.collection('device_tokens').doc(_tokenDocId(userId, token)).delete();
  }

  /// Backs the Notifications screen (MedGuardian screen spec C7). Reads
  /// `notifications` where `targetUserId == userId`, matching
  /// firestore.rules' read rule for that collection exactly.
  ///
  /// Nothing currently *writes* to this collection: per firestore.rules'
  /// own comment, `notifications` documents are only ever created by the
  /// `sendNotification` Cloud Function (Admin SDK) — and MedGuard runs on
  /// Firebase's Spark plan, which can't deploy Cloud Functions at all (see
  /// `PeopleRepository.createStaffAccount`'s doc comment for the same
  /// constraint elsewhere). So this reliably returns an empty list until
  /// the project upgrades to Blaze; [Alert Center] (backed by
  /// `MedicationRepository.fetchPendingForPatients`, entirely client-side)
  /// is the live equivalent in the meantime.
  Future<List<AppNotification>> fetchForUser(String userId, {int limit = 50}) async {
    final snap = await _db
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(AppNotification.fromDoc).toList();
  }
}
