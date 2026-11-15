import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase_client.dart';
import '../models/prescription_scan.dart';

/// Prescription Scanner -> OCR Review flow (see [PrescriptionScan] for the
/// design note on why this saves a draft rather than a live prescription).
class PrescriptionScanRepository {
  final _db = FirebaseService.db;
  final _storage = FirebaseService.storage;

  /// Uploads the captured/picked image to
  /// `prescription_scans/{patientId}/{timestamp}.jpg` and creates the
  /// draft Firestore document. Returns the new scan's id so the caller can
  /// navigate straight to the OCR Review screen for it.
  ///
  /// OCR text extraction is not run here — that's the deferred "AI
  /// Prescription Understanding" step (Google ML Kit OCR + Gemini in the
  /// MedGuardian AI spec). The extracted* fields start blank and the
  /// patient fills them in by hand on the review screen, consistent with
  /// the spec's own "always provide confirmation/editing after OCR + AI
  /// extraction" design principle.
  Future<String> uploadScan({
    required String patientId,
    required File imageFile,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'prescription_scans/$patientId/$timestamp.jpg';
    final ref = _storage.ref(storagePath);
    await ref.putFile(imageFile);
    final url = await ref.getDownloadURL();

    final doc = await _db.collection('prescription_scans').add({
      'patientId': patientId,
      'imageStoragePath': storagePath,
      'imageUrl': url,
      'status': 'draft',
      'extractedName': '',
      'extractedDose': '',
      'extractedFrequency': '',
      'extractedDurationDays': 0,
      'extractedInstructions': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<PrescriptionScan> fetchScan(String id) async {
    final doc = await _db.collection('prescription_scans').doc(id).get();
    return PrescriptionScan.fromDoc(doc);
  }

  Future<List<PrescriptionScan>> fetchForPatient(String patientId) async {
    final snap = await _db
        .collection('prescription_scans')
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(PrescriptionScan.fromDoc).toList();
  }

  /// Patient reviews/edits the (currently manually entered) fields and
  /// confirms — marks the draft `reviewed` so it surfaces clearly to their
  /// Doctor as ready to act on.
  Future<void> confirmReview({
    required String scanId,
    required String name,
    required String dose,
    required String frequency,
    required int durationDays,
    required String instructions,
  }) async {
    await _db.collection('prescription_scans').doc(scanId).update({
      'extractedName': name,
      'extractedDose': dose,
      'extractedFrequency': frequency,
      'extractedDurationDays': durationDays,
      'extractedInstructions': instructions,
      'status': 'reviewed',
      'reviewedAt': Timestamp.now(),
    });
  }
}
