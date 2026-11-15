import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors a `health_records/{id}` Firestore document (MedGuardian AI's
/// "Health Record Vault": prescriptions and selected health documents
/// stored via Firebase Storage + Firestore metadata).
class HealthRecord {
  final String id;
  final String patientId;
  final String title;
  final String type; // prescription | lab_report | scan | other
  final String storagePath;
  final String downloadUrl;
  final String uploadedByRole;
  final DateTime uploadedAt;

  HealthRecord({
    required this.id,
    required this.patientId,
    required this.title,
    required this.type,
    required this.storagePath,
    required this.downloadUrl,
    required this.uploadedByRole,
    required this.uploadedAt,
  });

  factory HealthRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return HealthRecord(
      id: doc.id,
      patientId: map['patientId'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled record',
      type: map['type'] as String? ?? 'other',
      storagePath: map['storagePath'] as String? ?? '',
      downloadUrl: map['downloadUrl'] as String? ?? '',
      uploadedByRole: map['uploadedByRole'] as String? ?? 'patient',
      uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Human labels for [HealthRecord.type], used by the upload dialog and the
/// list's leading icon alike so both stay in sync with the same source.
class HealthRecordType {
  HealthRecordType._();

  static const String prescription = 'prescription';
  static const String labReport = 'lab_report';
  static const String scan = 'scan';
  static const String other = 'other';

  static const List<String> all = [prescription, labReport, scan, other];

  static String label(String type) {
    switch (type) {
      case prescription:
        return 'Prescription';
      case labReport:
        return 'Lab report';
      case scan:
        return 'Scan / imaging';
      default:
        return 'Other document';
    }
  }
}
