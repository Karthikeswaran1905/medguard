import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors a `prescription_scans/{id}` Firestore document — the
/// MedGuardian AI "Prescription Scanner -> OCR -> AI extraction ->
/// Confirmation" flow, adapted to MedGuard's existing prescribing model.
///
/// Design note: the original MedGuardian AI flow has the patient save a
/// medication schedule directly after confirming the OCR/AI result. In
/// MedGuard, only a linked Doctor may create `medicines`/
/// `medication_schedules` documents (Firestore Security Rules, mirroring
/// Section 46's RLS) — a patient's own confirmation can't bypass that
/// without weakening the exact safety property the escalation chain
/// depends on. So a scan is saved here as the patient's own draft; it
/// becomes visible to their linked Doctor (`canViewPatient`), who uses it
/// as a reference when actually prescribing via the existing "Add
/// medicine" flow. `status` tracks that handoff.
///
/// OCR text extraction and the Gemini "understand the prescription" step
/// are stubbed for now (`extractedName` etc. start empty and the patient
/// fills them in by hand on the OCR Review screen) — wiring in real
/// OCR/Gemini calls is the deferred "API" work.
class PrescriptionScan {
  final String id;
  final String patientId;
  final String imageStoragePath;
  final String imageUrl;
  final String status; // draft | reviewed
  final String extractedName;
  final String extractedDose;
  final String extractedFrequency;
  final int extractedDurationDays;
  final String extractedInstructions;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  PrescriptionScan({
    required this.id,
    required this.patientId,
    required this.imageStoragePath,
    required this.imageUrl,
    required this.status,
    required this.extractedName,
    required this.extractedDose,
    required this.extractedFrequency,
    required this.extractedDurationDays,
    required this.extractedInstructions,
    required this.createdAt,
    required this.reviewedAt,
  });

  factory PrescriptionScan.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return PrescriptionScan(
      id: doc.id,
      patientId: map['patientId'] as String? ?? '',
      imageStoragePath: map['imageStoragePath'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      status: map['status'] as String? ?? 'draft',
      extractedName: map['extractedName'] as String? ?? '',
      extractedDose: map['extractedDose'] as String? ?? '',
      extractedFrequency: map['extractedFrequency'] as String? ?? '',
      extractedDurationDays: map['extractedDurationDays'] as int? ?? 0,
      extractedInstructions: map['extractedInstructions'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }
}
