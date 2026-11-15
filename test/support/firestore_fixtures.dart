import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Shared fixture data for the tests under test/unit and test/flows: one
/// profile per role, all in the same organization, so a test can seed a
/// [FakeFirebaseFirestore] with a realistic Admin -> Doctor -> Incharge ->
/// Caretaker -> Patient chain (Section 11) in one call instead of
/// repeating the same five `profiles` documents in every test file.
class TestIds {
  TestIds._();

  static const orgId = 'org-1';
  static const adminId = 'admin-1';
  static const doctorId = 'doctor-1';
  static const inchargeId = 'incharge-1';
  static const caretakerId = 'caretaker-1';
  static const patientId = 'patient-1';
}

Future<void> seedCoreProfiles(FakeFirebaseFirestore db) async {
  Future<void> profile(String id, String role, String name) =>
      db.collection('profiles').doc(id).set({
        'orgId': TestIds.orgId,
        'role': role,
        'fullName': name,
        'phone': '555-0100',
        'email': '$id@example.com',
        'timezone': 'Asia/Kolkata',
        'createdAt': Timestamp.now(),
      });

  await profile(TestIds.adminId, 'admin', 'Ada Admin');
  await profile(TestIds.doctorId, 'doctor', 'Dana Doctor');
  await profile(TestIds.inchargeId, 'incharge', 'Ivan Incharge');
  await profile(TestIds.caretakerId, 'caretaker', 'Cara Caretaker');
  await profile(TestIds.patientId, 'patient', 'Pat Patient');
}
