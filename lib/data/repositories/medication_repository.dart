import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/roles.dart';
import '../firebase_client.dart';
import '../models/medication_models.dart';

/// Prescriptions, medicines, schedules and medication events — the
/// medicine-side of MedGuard (Sections 9, 13, 14, 24, 45).
///
/// `medication_events` documents for *future* scheduled doses are normally
/// materialized by the `scheduleGenerator` Cloud Function running on Cloud
/// Scheduler (Section 41, 48). [ensureTodayEvents] additionally generates
/// today's documents on demand from the client, so the app is usable
/// end-to-end even before the schedule runs.
class MedicationRepository {
  final _db = FirebaseService.db;

  // ---- Doctor: prescribe -------------------------------------------------

  Future<String> createPrescription({
    required String patientId,
    required String doctorId,
  }) async {
    final doc = await _db.collection('prescriptions').add({
      'patientId': patientId,
      'doctorId': doctorId,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> addMedicineWithSchedule({
    required String prescriptionId,
    required String patientId,
    required String name,
    required String dose,
    required int frequencyPerDay,
    required List<String> timesOfDay, // e.g. ["08:00:00", "20:00:00"]
    String? instructions,
    int durationDays = 30,
  }) async {
    final medicine = await _db.collection('medicines').add({
      'prescriptionId': prescriptionId,
      'name': name,
      'dose': dose,
      'frequencyPerDay': frequencyPerDay,
      'instructions': instructions,
      'durationDays': durationDays,
      'startDate': Timestamp.now(),
    });

    final batch = _db.batch();
    for (final time in timesOfDay) {
      final scheduleRef = _db.collection('medication_schedules').doc();
      batch.set(scheduleRef, {
        'medicineId': medicine.id,
        'patientId': patientId,
        'timeOfDay': time,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Firestore has no server-side join like Postgres's
  /// `medicines!inner(patient_id)` — this does it in two steps: every
  /// prescription id for the patient, then every medicine on any of those
  /// prescriptions.
  Future<List<Medicine>> fetchMedicinesForPatient(String patientId) async {
    final prescriptions = await _db
        .collection('prescriptions')
        .where('patientId', isEqualTo: patientId)
        .get();
    final prescriptionIds = prescriptions.docs.map((d) => d.id).toList();
    if (prescriptionIds.isEmpty) return [];

    final medicines = <Medicine>[];
    for (var i = 0; i < prescriptionIds.length; i += 30) {
      final chunk = prescriptionIds.sublist(
          i, i + 30 > prescriptionIds.length ? prescriptionIds.length : i + 30);
      final snap = await _db
          .collection('medicines')
          .where('prescriptionId', whereIn: chunk)
          .get();
      medicines.addAll(snap.docs.map(Medicine.fromDoc));
    }
    medicines.sort((a, b) => b.startDate.compareTo(a.startDate));
    return medicines;
  }

  // ---- Scheduling (client-side convenience; see class doc) --------------

  /// Idempotently creates today's `medication_events` for [patientId] from
  /// its active `medication_schedules`, mirroring what `scheduleGenerator`
  /// does server-side every minute (Section 41, 48). Denormalizes the
  /// medicine's name/dose onto the event, matching how `scheduleGenerator`
  /// creates them, since Firestore has no read-time join to fall back on.
  Future<void> ensureTodayEvents(String patientId) async {
    final schedules = await _db
        .collection('medication_schedules')
        .where('patientId', isEqualTo: patientId)
        .get();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    for (final s in schedules.docs) {
      final data = s.data();
      final timeParts = (data['timeOfDay'] as String).split(':');
      final scheduledAt = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      final existing = await _db
          .collection('medication_events')
          .where('scheduleId', isEqualTo: s.id)
          .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) continue;

      final medicineId = data['medicineId'] as String;
      final medicineDoc = await _db.collection('medicines').doc(medicineId).get();
      final medicineData = medicineDoc.data();

      await _db.collection('medication_events').add({
        'patientId': patientId,
        'medicineId': medicineId,
        'scheduleId': s.id,
        'medicineName': medicineData?['name'],
        'medicineDose': medicineData?['dose'],
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'patientStatus': EventStatus.pending,
        'caretakerStatus': EventStatus.pending,
        'finalStatus': EventStatus.pending,
        'escalationLevel': EscalationLevel.patient,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ---- Patient: confirm ---------------------------------------------------

  Future<List<MedicationEvent>> fetchTodayEvents(String patientId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final snap = await _db
        .collection('medication_events')
        .where('patientId', isEqualTo: patientId)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .orderBy('scheduledAt')
        .get();
    return snap.docs.map(MedicationEvent.fromDoc).toList();
  }

  Future<List<MedicationEvent>> fetchHistory(String patientId, {int days = 14}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final snap = await _db
        .collection('medication_events')
        .where('patientId', isEqualTo: patientId)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('scheduledAt', descending: true)
        .get();
    return snap.docs.map(MedicationEvent.fromDoc).toList();
  }

  /// Patient taps "Confirm" (Section 6.2, 14). Firestore Security Rules
  /// only allow a patient to touch `patientStatus` / `patientConfirmedAt`
  /// on their own events (Section 46's original RLS behavior) — never
  /// `caretakerStatus` or `finalStatus`.
  Future<void> confirmConsumed(String eventId) async {
    final now = Timestamp.now();
    await _db.collection('medication_events').doc(eventId).update({
      'patientStatus': EventStatus.consumed,
      'patientConfirmedAt': now,
      'serverReceivedAt': now, // set by the client for MVP; a Cloud
      // Function is the authoritative writer once offline sync (Section 42)
      // ships, since it can distinguish device time from receipt time.
    });
  }

  /// Patient self-reports a dose they knowingly skipped ("Mark as Missed"
  /// on the Today's Schedule screen) — the honest counterpart to
  /// [confirmConsumed]. Left unresolved doses instead escalate on their
  /// own via `escalationEngine`; this is only for a patient actively
  /// saying "I didn't take this," which is why it's worth recording
  /// separately from silence.
  Future<void> markMissed(String eventId) async {
    final now = Timestamp.now();
    await _db.collection('medication_events').doc(eventId).update({
      'patientStatus': EventStatus.missed,
      'patientConfirmedAt': now,
      'serverReceivedAt': now,
    });
  }

  /// A single day's events for the Today's Schedule screen's day picker
  /// (Sun–Sat). Unlike [fetchTodayEvents]/[ensureTodayEvents], this never
  /// materializes anything — a day with no `medication_events` yet (a
  /// future day `scheduleGenerator` hasn't reached, or a past day nothing
  /// was scheduled on) just comes back empty rather than being invented
  /// client-side.
  Future<List<MedicationEvent>> fetchEventsForDate(String patientId, DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final snap = await _db
        .collection('medication_events')
        .where('patientId', isEqualTo: patientId)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(dayEnd))
        .orderBy('scheduledAt')
        .get();
    return snap.docs.map(MedicationEvent.fromDoc).toList();
  }

  /// Backs the Medication Details screen's "Prescribed by" row.
  Future<Prescription?> fetchPrescription(String prescriptionId) async {
    final doc = await _db.collection('prescriptions').doc(prescriptionId).get();
    if (!doc.exists) return null;
    return Prescription.fromDoc(doc);
  }

  /// Every dose time for one medicine — Medication Details shows all of
  /// them (a medicine can have more than one `medication_schedules`
  /// document, one per time of day), not just the single time a
  /// particular `medication_events` document happens to carry.
  Future<List<MedicationSchedule>> fetchSchedulesForMedicine(String medicineId) async {
    final snap = await _db
        .collection('medication_schedules')
        .where('medicineId', isEqualTo: medicineId)
        .get();
    final schedules = snap.docs.map(MedicationSchedule.fromDoc).toList();
    schedules.sort((a, b) => a.timeOfDay.compareTo(b.timeOfDay));
    return schedules;
  }

  // ---- Caretaker: verify ---------------------------------------------------

  /// Events needing caretaker attention: the patient hasn't confirmed and
  /// the event has been open for a while (Section 15.2, 16).
  Future<List<MedicationEvent>> fetchPendingForPatients(
    List<String> patientIds,
  ) async {
    if (patientIds.isEmpty) return [];
    final events = <MedicationEvent>[];
    for (var i = 0; i < patientIds.length; i += 30) {
      final chunk =
          patientIds.sublist(i, i + 30 > patientIds.length ? patientIds.length : i + 30);
      final snap = await _db
          .collection('medication_events')
          .where('patientId', whereIn: chunk)
          .where('finalStatus', isEqualTo: EventStatus.pending)
          .orderBy('scheduledAt')
          .get();
      events.addAll(snap.docs.map(MedicationEvent.fromDoc));
    }
    return events;
  }

  /// Caretaker records the verified outcome (Section 16). Only
  /// `caretakerStatus` is writable by the caretaker role — `finalStatus`
  /// mirrors it here for MVP simplicity; in production that write belongs
  /// to a service-account Cloud Function (Section 46) so a caretaker can
  /// never forge a "consumed" outcome the patient never gave.
  Future<void> verifyEvent(String eventId, {required bool consumed}) async {
    final status = consumed ? EventStatus.consumed : EventStatus.notConsumed;
    await _db.collection('medication_events').doc(eventId).update({
      'caretakerStatus': status,
      'caretakerConfirmedAt': Timestamp.now(),
      'finalStatus': status,
    });
  }
}
