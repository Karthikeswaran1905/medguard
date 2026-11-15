// MedGuard — core business-flow test.
//
// Scope (see the "Test scope" decision in the conversation this was
// requested in): this covers the single chain the app's whole escalation
// design revolves around — Auth/role -> Doctor prescribes -> reminder ->
// patient confirms -> no-response escalation -> Caretaker verifies ->
// Incharge escalation -> analytics — exercised against the *real*
// PeopleRepository / MedicationRepository / AnalyticsRepository classes,
// backed by an in-memory FakeFirebaseFirestore (see
// FirebaseService.debugOverride in lib/data/firebase_client.dart) instead
// of a live Firebase project. Per-model unit tests live alongside this in
// test/unit/models/.
//
// What this pass does NOT cover, and why:
//   - Widget/screen tests (e.g. "Patient Dashboard displays medicine") —
//     a separate tier from "core critical-flow tests" in the scope this
//     was scoped to.
//   - Firestore security-rule tests (firestore.rules) — these need the
//     Firebase Emulator Suite, a Node-based toolchain separate from
//     Flutter's test runner, out of scope for this pass.
//   - PeopleRepository.createStaffAccount (Admin/Doctor/Incharge
//     provisioning the next role down) — it spins up a real secondary
//     FirebaseApp + FirebaseAuth.instanceFor (see that method's doc
//     comment), which firebase_auth_mocks' MockFirebaseAuth doesn't
//     model. Covered instead by the constructor-call-site checks done
//     before each role's screens were delivered.
//   - The AI/OCR prescription pipeline and escalationEngine/
//     scheduleGenerator/sendNotification Cloud Functions — none of these
//     can run client-side, and Cloud Functions can't deploy at all on the
//     Spark plan this app runs on (see PeopleRepository.createStaffAccount's
//     doc comment for that constraint elsewhere). Where this test needs
//     an *escalated* event to exist, it writes the `escalationLevel` a
//     real escalationEngine run would have written, then tests what the
//     client is actually responsible for from there — see step 5 below.
//
// Honesty note: this file was authored by reading the actual repository
// and model source (lib/data/repositories/*, lib/data/models/*) rather
// than guessing at an API, but it has not been run — this sandbox has no
// Flutter/Dart toolchain to execute `flutter test` against. Run it after
// `flutter pub get` and report back anything that fails; fake_cloud_firestore
// version quirks (if any) are typically a quick, localized fix.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medguard/core/roles.dart';
import 'package:medguard/data/firebase_client.dart';
import 'package:medguard/data/models/medication_models.dart';
import 'package:medguard/data/repositories/analytics_repository.dart';
import 'package:medguard/data/repositories/medication_repository.dart';
import 'package:medguard/data/repositories/people_repository.dart';

import '../support/firestore_fixtures.dart';

void main() {
  late FakeFirebaseFirestore db;
  final peopleRepo = PeopleRepository();
  final medicationRepo = MedicationRepository();
  final analyticsRepo = AnalyticsRepository();

  setUp(() async {
    db = FakeFirebaseFirestore();
    FirebaseService.debugOverride(db: db, auth: MockFirebaseAuth(signedIn: true));
    await seedCoreProfiles(db);
  });

  tearDown(() {
    FirebaseService.debugOverride();
  });

  test(
    'medication moves prescribed -> reminder -> confirmed, and a separately '
    'escalated dose is surfaced correctly at every level up the chain '
    '(Patient -> Caretaker -> Incharge)',
    () async {
      // ---- 1. Auth / role access -------------------------------------------
      // AuthGate (lib/features/auth/auth_gate.dart) routes a signed-in user
      // to their role's dashboard via a switch on profile.role. That routing
      // decision is data-driven off exactly this: each seeded profile
      // reporting the role it was created with. (Verifying the widget
      // navigation itself needs a widget test — out of this pass's scope,
      // see the file header.)
      final doctorProfile = await peopleRepo.fetchProfile(TestIds.doctorId);
      final patientProfile = await peopleRepo.fetchProfile(TestIds.patientId);
      expect(doctorProfile?.role, AppRole.doctor);
      expect(patientProfile?.role, AppRole.patient);

      // ---- 2. Doctor prescribes ----------------------------------------------
      final prescriptionId = await medicationRepo.createPrescription(
        patientId: TestIds.patientId,
        doctorId: TestIds.doctorId,
      );
      await medicationRepo.addMedicineWithSchedule(
        prescriptionId: prescriptionId,
        patientId: TestIds.patientId,
        name: 'Metformin',
        dose: '500mg',
        frequencyPerDay: 1,
        timesOfDay: const ['08:00:00'],
        instructions: 'After food',
        durationDays: 30,
      );
      final medicines = await medicationRepo.fetchMedicinesForPatient(TestIds.patientId);
      expect(medicines, hasLength(1));
      expect(medicines.single.name, 'Metformin');
      expect(medicines.single.dose, '500mg');

      // ---- 3. Reminder: today's medication_events are generated -------------
      await medicationRepo.ensureTodayEvents(TestIds.patientId);
      final todayEvents = await medicationRepo.fetchTodayEvents(TestIds.patientId);
      expect(todayEvents, hasLength(1));
      final confirmedEvent = todayEvents.single;
      expect(confirmedEvent.finalStatus, EventStatus.pending);
      // Denormalized onto the event at creation (see ensureTodayEvents' doc
      // comment) so the Patient/Caretaker/Incharge UIs never need a join.
      expect(confirmedEvent.medicineName, 'Metformin');

      // ---- 4. Patient confirms -------------------------------------------------
      await medicationRepo.confirmConsumed(confirmedEvent.id);
      final afterConfirm =
          (await medicationRepo.fetchTodayEvents(TestIds.patientId)).single;
      expect(afterConfirm.patientStatus, EventStatus.consumed);
      // confirmConsumed only ever writes patientStatus/patientConfirmedAt —
      // finalStatus for a patient-confirmed dose is authoritative on the
      // server side in production (see that method's doc comment). This
      // asserts that actual boundary rather than a nicer-sounding one the
      // client code doesn't implement.
      expect(afterConfirm.finalStatus, EventStatus.pending);

      // ---- Set up the Incharge/Caretaker allocation the rest of the chain
      // needs (Section 11 steps 4-5) before the escalation scenario below.
      await peopleRepo.allocateIncharge(
        inchargeId: TestIds.inchargeId,
        patientId: TestIds.patientId,
      );
      final assignments = await peopleRepo.fetchAssignmentsForIncharge(TestIds.inchargeId);
      expect(assignments, hasLength(1));
      expect(assignments.single.patientId, TestIds.patientId);
      await peopleRepo.allocateCaretaker(
        assignmentId: assignments.single.id,
        caretakerId: TestIds.caretakerId,
      );

      // ---- 5/6/7. No-response escalation: Patient -> Caretaker -> Incharge --
      // This is the core MedGuard scenario. A second dose that the patient
      // never responds to: escalationEngine (Cloud Function, can't run
      // here or on this app's Spark plan — see file header) is what
      // actually bumps escalationLevel over time in production. This
      // simulates exactly that write, then tests what the client is
      // responsible for from each role's side.
      final escalatingRef = await db.collection('medication_events').add({
        'patientId': TestIds.patientId,
        'medicineId': 'm-escalating',
        'scheduledAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 2))),
        'medicineName': 'Metformin',
        'medicineDose': '500mg',
        'patientStatus': EventStatus.pending,
        'caretakerStatus': EventStatus.pending,
        'finalStatus': EventStatus.pending,
        'escalationLevel': EscalationLevel.patient,
        'createdAt': Timestamp.now(),
      });
      // "Patient does not respond" -> escalates to Caretaker level.
      await escalatingRef.update({'escalationLevel': EscalationLevel.caretaker});

      // ---- 5. Caretaker should receive the alert ------------------------------
      final caretakerPatients = await peopleRepo.fetchPatientsForCaretaker(TestIds.caretakerId);
      expect(caretakerPatients.map((p) => p.id), contains(TestIds.patientId));
      final caretakerPending = await medicationRepo.fetchPendingForPatients(
        caretakerPatients.map((p) => p.id).toList(),
      );
      expect(caretakerPending.map((e) => e.id), contains(escalatingRef.id));

      // ---- 6. Caretaker verifies -----------------------------------------------
      await medicationRepo.verifyEvent(escalatingRef.id, consumed: false);
      final verifiedDoc = await db.collection('medication_events').doc(escalatingRef.id).get();
      final verifiedEvent = MedicationEvent.fromDoc(verifiedDoc);
      expect(verifiedEvent.caretakerStatus, EventStatus.notConsumed);
      expect(verifiedEvent.finalStatus, EventStatus.notConsumed);
      expect(verifiedEvent.isResolved, isTrue);
      // Once resolved, it drops out of the pending/escalated queues —
      // Caretaker verifying it is what closes the loop.
      final stillPending = await medicationRepo.fetchPendingForPatients([TestIds.patientId]);
      expect(stillPending.map((e) => e.id), isNot(contains(escalatingRef.id)));

      // A second, still-open dose that nobody — Patient or Caretaker — acted
      // on in time: escalationEngine bumps this one all the way to Incharge.
      final unresolvedRef = await db.collection('medication_events').add({
        'patientId': TestIds.patientId,
        'medicineId': 'm-unresolved',
        'scheduledAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 4))),
        'medicineName': 'Metformin',
        'medicineDose': '500mg',
        'patientStatus': EventStatus.pending,
        'caretakerStatus': EventStatus.pending,
        'finalStatus': EventStatus.pending,
        'escalationLevel': EscalationLevel.incharge,
        'createdAt': Timestamp.now(),
      });

      // ---- 7. Incharge should receive the escalated alert ----------------------
      final inchargeEscalated = await analyticsRepo.fetchEscalatedEvents([TestIds.patientId]);
      expect(inchargeEscalated.map((e) => e.id), contains(unresolvedRef.id));
      expect(
        inchargeEscalated.every((e) => e.escalationLevel == EscalationLevel.incharge),
        isTrue,
        reason: 'a resolved (caretaker-verified) event must never show up as still escalated',
      );
      final escalatedCount = await analyticsRepo.countEscalated([TestIds.patientId]);
      expect(escalatedCount, 1); // only the still-pending, incharge-level one

      // ---- 8. Analytics reflect the whole picture -------------------------------
      final stats = await analyticsRepo.statsForPatients([TestIds.patientId], days: 1);
      // Three events scheduled today: the confirmed-but-not-yet-finalized
      // dose, the caretaker-resolved not_consumed dose, and the still-open
      // incharge-escalated dose.
      expect(stats.scheduled, 3);
      expect(stats.consumed, 0);
      expect(stats.missed, 1);
      expect(stats.pending, 2);
      expect(stats.adherencePercent, 0); // nothing has reached finalStatus == consumed yet
    },
  );
}
