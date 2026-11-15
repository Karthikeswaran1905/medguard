import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/roles.dart';
import '../firebase_client.dart';
import '../models/ai_insight.dart';
import '../models/medication_models.dart';

/// Read-only aggregate queries backing the dashboards in Section 18/27.
/// These compute figures on demand from `medication_events`; a production
/// deployment may instead read from a materialized `analytics` collection
/// kept warm by a scheduled Cloud Function, but the shape returned here is
/// the same either way, so screens don't need to change if that's added
/// later.
class DashboardStats {
  final int scheduled;
  final int consumed;
  final int missed;
  final int pending;

  const DashboardStats({
    required this.scheduled,
    required this.consumed,
    required this.missed,
    required this.pending,
  });

  double get adherencePercent =>
      scheduled == 0 ? 0 : (consumed / scheduled) * 100;
}

class AnalyticsRepository {
  final _db = FirebaseService.db;

  Future<DashboardStats> patientAdherence(String patientId, {int days = 30}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final snap = await _db
        .collection('medication_events')
        .where('patientId', isEqualTo: patientId)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();
    return _summarize(snap.docs);
  }

  Future<DashboardStats> statsForPatients(List<String> patientIds, {int days = 1}) async {
    if (patientIds.isEmpty) {
      return const DashboardStats(scheduled: 0, consumed: 0, missed: 0, pending: 0);
    }
    final since = DateTime.now().subtract(Duration(days: days));
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (var i = 0; i < patientIds.length; i += 30) {
      final chunk =
          patientIds.sublist(i, i + 30 > patientIds.length ? patientIds.length : i + 30);
      final snap = await _db
          .collection('medication_events')
          .where('patientId', whereIn: chunk)
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get();
      docs.addAll(snap.docs);
    }
    return _summarize(docs);
  }

  /// Firestore allows at most one `whereIn` clause per query, so this can't
  /// combine a `patientId whereIn [...]` with an `escalationLevel whereIn
  /// [...]` the way the original Postgres query did in one round trip.
  /// Instead it fetches every still-pending event for the patient chunk
  /// (one `whereIn`, on `patientId`) and counts the escalated ones
  /// client-side — the same total, at the cost of reading a few more
  /// small documents.
  Future<int> countEscalated(List<String> patientIds) async {
    if (patientIds.isEmpty) return 0;
    var total = 0;
    for (var i = 0; i < patientIds.length; i += 30) {
      final chunk =
          patientIds.sublist(i, i + 30 > patientIds.length ? patientIds.length : i + 30);
      final snap = await _db
          .collection('medication_events')
          .where('patientId', whereIn: chunk)
          .where('finalStatus', isEqualTo: EventStatus.pending)
          .get();
      total += snap.docs.where((d) {
        final level = d.data()['escalationLevel'] as String?;
        return level == EscalationLevel.incharge || level == EscalationLevel.criticalUnresolved;
      }).length;
    }
    return total;
  }

  /// The full-document counterpart to [countEscalated] — backs the
  /// Incharge dashboard's "Escalated" stat tile: tapping it opens the
  /// Alert Detail screen for each still-open, escalated event so an
  /// Incharge doesn't have to hunt through every patient individually to
  /// find what actually needs them (MedGuardian AI's "Caregiver Alerts" +
  /// "Alert detail" screen, Section 6 of that spec).
  Future<List<MedicationEvent>> fetchEscalatedEvents(List<String> patientIds) async {
    if (patientIds.isEmpty) return [];
    final escalated = <MedicationEvent>[];
    for (var i = 0; i < patientIds.length; i += 30) {
      final chunk =
          patientIds.sublist(i, i + 30 > patientIds.length ? patientIds.length : i + 30);
      final snap = await _db
          .collection('medication_events')
          .where('patientId', whereIn: chunk)
          .where('finalStatus', isEqualTo: EventStatus.pending)
          .get();
      escalated.addAll(snap.docs.map(MedicationEvent.fromDoc).where(
            (e) =>
                e.escalationLevel == EscalationLevel.incharge ||
                e.escalationLevel == EscalationLevel.criticalUnresolved,
          ));
    }
    escalated.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return escalated;
  }

  /// Section 44's dashboards read whatever `aiInsightsBatch` generated
  /// overnight rather than calling an AI provider themselves. Firestore has
  /// no "latest row per group" query, so this fetches every insight for the
  /// patient chunk within the lookback window and keeps only the newest
  /// one per patient client-side — the same one-insight-per-patient result
  /// the original Postgres version got from a single query, at the cost of
  /// reading a few extra small documents when a patient has more than one
  /// insight in range.
  Future<Map<String, AiInsight>> latestInsightsForPatients(
    List<String> patientIds, {
    int days = 2,
  }) async {
    if (patientIds.isEmpty) return {};
    final since = DateTime.now().subtract(Duration(days: days));
    final latest = <String, AiInsight>{};
    for (var i = 0; i < patientIds.length; i += 30) {
      final chunk =
          patientIds.sublist(i, i + 30 > patientIds.length ? patientIds.length : i + 30);
      final snap = await _db
          .collection('ai_insights')
          .where('scopeId', whereIn: chunk)
          .where('generatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get();
      for (final doc in snap.docs) {
        final insight = AiInsight.fromDoc(doc);
        final existing = latest[insight.scopeId];
        if (existing == null || insight.generatedAt.isAfter(existing.generatedAt)) {
          latest[insight.scopeId] = insight;
        }
      }
    }
    return latest;
  }

  Future<Map<String, int>> orgCounts(String? orgId) async {
    Future<int> countRole(String role) async {
      Query<Map<String, dynamic>> query =
          _db.collection('profiles').where('role', isEqualTo: role);
      if (orgId != null) query = query.where('orgId', isEqualTo: orgId);
      final snap = await query.count().get();
      return snap.count ?? 0;
    }

    final doctors = await countRole('doctor');
    final incharges = await countRole('incharge');
    final caretakers = await countRole('caretaker');
    final patients = await countRole('patient');
    return {
      'doctors': doctors,
      'incharges': incharges,
      'caretakers': caretakers,
      'patients': patients,
    };
  }

  DashboardStats _summarize(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    var consumed = 0;
    var missed = 0;
    var pending = 0;
    for (final d in docs) {
      switch (d.data()['finalStatus'] as String? ?? EventStatus.pending) {
        case EventStatus.consumed:
          consumed++;
          break;
        case EventStatus.notConsumed:
        case EventStatus.missed:
          missed++;
          break;
        default:
          pending++;
      }
    }
    return DashboardStats(
      scheduled: docs.length,
      consumed: consumed,
      missed: missed,
      pending: pending,
    );
  }
}
