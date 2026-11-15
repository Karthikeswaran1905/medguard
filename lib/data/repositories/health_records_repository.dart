import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/roles.dart';
import '../firebase_client.dart';
import '../models/health_record.dart';

/// Health Record Vault (MedGuardian AI SUPPORT feature): prescriptions and
/// selected health documents, stored as Firebase Storage objects with
/// Firestore metadata rows for listing/filtering.
class HealthRecordsRepository {
  final _db = FirebaseService.db;
  final _storage = FirebaseService.storage;

  Future<void> upload({
    required String patientId,
    required File file,
    required String title,
    required String type,
    required AppRole uploaderRole,
  }) async {
    final ext = file.path.contains('.') ? file.path.split('.').last : 'dat';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'health_records/$patientId/$timestamp.$ext';
    final ref = _storage.ref(storagePath);
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await _db.collection('health_records').add({
      'patientId': patientId,
      'title': title,
      'type': type,
      'storagePath': storagePath,
      'downloadUrl': url,
      'uploadedByRole': uploaderRole.name,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<HealthRecord>> fetchForPatient(String patientId) async {
    final snap = await _db
        .collection('health_records')
        .where('patientId', isEqualTo: patientId)
        .orderBy('uploadedAt', descending: true)
        .get();
    return snap.docs.map(HealthRecord.fromDoc).toList();
  }

  Future<void> delete(HealthRecord record) async {
    await _db.collection('health_records').doc(record.id).delete();
    // Best-effort: an already-missing Storage object (e.g. deleted
    // manually from the console) shouldn't block removing the metadata row.
    try {
      await _storage.ref(record.storagePath).delete();
    } catch (_) {}
  }
}
