import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the small set of fields MedGuard stores directly on the
/// existing `patients/{patientId}` document (created empty at sign-up by
/// `AuthRepository.signUpPatient`) for the Emergency QR Health Card and
/// the Drug Interaction Checker's "known allergies" cross-check.
///
/// This deliberately reuses `patients/{patientId}` rather than adding a
/// new collection — Firestore Security Rules already let the patient
/// read/write their own document there and let every
/// caretaker/incharge/doctor/admin who can view the patient read it too
/// (`canViewPatient`), so no rules changes are needed for this data.
class PatientMedicalInfo {
  final String patientId;
  final String bloodType;
  final String allergies;
  final String conditions;
  final DateTime? updatedAt;

  PatientMedicalInfo({
    required this.patientId,
    required this.bloodType,
    required this.allergies,
    required this.conditions,
    required this.updatedAt,
  });

  bool get isEmpty =>
      bloodType.isEmpty && allergies.isEmpty && conditions.isEmpty;

  factory PatientMedicalInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return PatientMedicalInfo(
      patientId: doc.id,
      bloodType: map['bloodType'] as String? ?? '',
      allergies: map['allergies'] as String? ?? '',
      conditions: map['conditions'] as String? ?? '',
      updatedAt: (map['medicalInfoUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toUpdateMap() => {
        'bloodType': bloodType,
        'allergies': allergies,
        'conditions': conditions,
        'medicalInfoUpdatedAt': FieldValue.serverTimestamp(),
      };
}
