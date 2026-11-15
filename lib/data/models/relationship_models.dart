import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors a `patient_invites/{code}` Firestore document (Section 39): a
/// one-time code a Doctor issues so a self-registering Patient can be
/// linked to them in an auditable way. The document id *is* the code
/// (upper-cased) so lookups are a direct `.doc(code).get()` instead of a
/// query, and the code is naturally unique.
class PatientInvite {
  final String id;
  final String code;
  final String doctorId;
  final String? orgId;
  final DateTime expiresAt;
  final DateTime? usedAt;

  PatientInvite({
    required this.id,
    required this.code,
    required this.doctorId,
    required this.orgId,
    required this.expiresAt,
    required this.usedAt,
  });

  factory PatientInvite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return PatientInvite(
      id: doc.id,
      code: doc.id,
      doctorId: map['doctorId'] as String? ?? '',
      orgId: map['orgId'] as String?,
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      usedAt: (map['usedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Mirrors a `doctor_patient_links/{doctorId_patientId}` Firestore document
/// (Section 39): the authorized Doctor - Patient relationship created once
/// an invite code is redeemed.
class DoctorPatientLink {
  final String id;
  final String doctorId;
  final String patientId;
  final String status; // active | unlinked | revoked
  final DateTime linkedAt;

  DoctorPatientLink({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.status,
    required this.linkedAt,
  });

  factory DoctorPatientLink.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return DoctorPatientLink(
      id: doc.id,
      doctorId: map['doctorId'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      linkedAt: (map['linkedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Mirrors an `assignments/{patientId}` Firestore document (Section 45):
/// Incharge -> Caretaker -> Patient allocation (Section 11). The document
/// id *is* the patient id, matching the Postgres `unique (patient_id)`
/// constraint — a patient has exactly one assignment row.
class Assignment {
  final String id;
  final String inchargeId;
  final String? caretakerId;
  final String patientId;
  final DateTime createdAt;

  Assignment({
    required this.id,
    required this.inchargeId,
    required this.caretakerId,
    required this.patientId,
    required this.createdAt,
  });

  factory Assignment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return Assignment(
      id: doc.id,
      inchargeId: map['inchargeId'] as String? ?? '',
      caretakerId: map['caretakerId'] as String?,
      patientId: map['patientId'] as String? ?? doc.id,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Mirrors a `family_contacts/{id}` Firestore document (Section 6, 8, wired
/// into escalation in Section 40): the contacts notified when an event
/// escalates past the Incharge with no response.
class FamilyContact {
  final String id;
  final String patientId;
  final String name;
  final String relationship;
  final String phone;
  final bool isEmergency;

  FamilyContact({
    required this.id,
    required this.patientId,
    required this.name,
    required this.relationship,
    required this.phone,
    required this.isEmergency,
  });

  factory FamilyContact.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return FamilyContact(
      id: doc.id,
      patientId: map['patientId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      relationship: map['relationship'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      isEmergency: map['isEmergency'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'patientId': patientId,
        'name': name,
        'relationship': relationship,
        'phone': phone,
        'isEmergency': isEmergency,
      };
}
