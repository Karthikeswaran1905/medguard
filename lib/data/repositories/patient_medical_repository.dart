import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase_client.dart';
import '../models/patient_medical_info.dart';

/// Reads/writes the small medical-info fields kept on the patient's own
/// `patients/{patientId}` document (see [PatientMedicalInfo]) — backs the
/// Emergency QR Health Card screen.
class PatientMedicalRepository {
  final _db = FirebaseService.db;

  Future<PatientMedicalInfo> fetch(String patientId) async {
    final doc = await _db.collection('patients').doc(patientId).get();
    return PatientMedicalInfo.fromDoc(doc);
  }

  Future<void> save(PatientMedicalInfo info) async {
    await _db
        .collection('patients')
        .doc(info.patientId)
        .set(info.toUpdateMap(), SetOptions(merge: true));
  }
}
