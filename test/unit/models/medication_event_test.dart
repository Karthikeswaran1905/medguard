import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medguard/core/roles.dart';
import 'package:medguard/data/models/medication_models.dart';

/// MedGuard's core state machine (Section 9 of the spec pasted for these
/// tests): PENDING -> {TAKEN, MISSED} directly, or PENDING -> escalating
/// through CARETAKER_ALERT -> INCHARGE_ALERT the longer nobody responds.
/// These cover the shape of a `medication_events` document at each of
/// those states; the actual state *transitions* driven by repository
/// calls (confirmConsumed, verifyEvent, escalation) are exercised end to
/// end in test/flows/critical_flows_test.dart.
void main() {
  Future<DocumentSnapshot<Map<String, dynamic>>> seedEvent(
    FakeFirebaseFirestore db,
    String id,
    Map<String, dynamic> data,
  ) async {
    await db.collection('medication_events').doc(id).set(data);
    return db.collection('medication_events').doc(id).get();
  }

  group('MedicationEvent.fromDoc', () {
    test('a freshly scheduled dose starts pending and unresolved', () async {
      final db = FakeFirebaseFirestore();
      final doc = await seedEvent(db, 'e1', {
        'patientId': 'p1',
        'medicineId': 'm1',
        'scheduledAt': Timestamp.fromDate(DateTime(2026, 1, 1, 8)),
        'patientStatus': EventStatus.pending,
        'caretakerStatus': EventStatus.pending,
        'finalStatus': EventStatus.pending,
        'escalationLevel': EscalationLevel.patient,
        'createdAt': Timestamp.now(),
      });

      final event = MedicationEvent.fromDoc(doc);

      expect(event.finalStatus, EventStatus.pending);
      expect(event.escalationLevel, EscalationLevel.patient);
      expect(event.isResolved, isFalse);
    });

    test('isResolved is true once finalStatus is consumed', () async {
      final db = FakeFirebaseFirestore();
      final doc = await seedEvent(db, 'e2', {
        'patientId': 'p1',
        'medicineId': 'm1',
        'scheduledAt': Timestamp.now(),
        'patientStatus': EventStatus.consumed,
        'caretakerStatus': EventStatus.pending,
        'finalStatus': EventStatus.consumed,
        'escalationLevel': EscalationLevel.patient,
        'createdAt': Timestamp.now(),
      });

      expect(MedicationEvent.fromDoc(doc).isResolved, isTrue);
    });

    test('isResolved is also true for not_consumed (a caretaker-verified miss)', () async {
      final db = FakeFirebaseFirestore();
      final doc = await seedEvent(db, 'e3', {
        'patientId': 'p1',
        'medicineId': 'm1',
        'scheduledAt': Timestamp.now(),
        'patientStatus': EventStatus.pending,
        'caretakerStatus': EventStatus.notConsumed,
        'finalStatus': EventStatus.notConsumed,
        'escalationLevel': EscalationLevel.caretaker,
        'createdAt': Timestamp.now(),
      });

      expect(MedicationEvent.fromDoc(doc).isResolved, isTrue);
    });

    test('an escalated, still-open dose is not resolved even at incharge level', () async {
      final db = FakeFirebaseFirestore();
      final doc = await seedEvent(db, 'e4', {
        'patientId': 'p1',
        'medicineId': 'm1',
        'scheduledAt': Timestamp.now(),
        'patientStatus': EventStatus.pending,
        'caretakerStatus': EventStatus.pending,
        'finalStatus': EventStatus.pending,
        'escalationLevel': EscalationLevel.incharge,
        'createdAt': Timestamp.now(),
      });

      final event = MedicationEvent.fromDoc(doc);

      expect(event.escalationLevel, EscalationLevel.incharge);
      expect(event.isResolved, isFalse);
    });

    test('a bare document still parses without throwing (fail-safe defaults)', () async {
      final db = FakeFirebaseFirestore();
      final doc = await seedEvent(db, 'e5', {});

      final event = MedicationEvent.fromDoc(doc);

      expect(event.finalStatus, EventStatus.pending);
      expect(event.escalationLevel, EscalationLevel.patient);
      expect(event.isResolved, isFalse);
    });
  });
}
