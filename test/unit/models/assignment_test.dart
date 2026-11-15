import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medguard/data/models/relationship_models.dart';

/// The Doctor -> Incharge -> Caretaker -> Patient allocation chain
/// (Section 11) lives in one `assignments/{patientId}` document per
/// patient rather than ids scattered across every user document. These
/// cover that document's shape at each stage of being filled in; the
/// allocation *writes* themselves (PeopleRepository.allocateIncharge /
/// allocateCaretaker) are exercised in test/flows/critical_flows_test.dart.
void main() {
  group('Assignment.fromDoc', () {
    test('parses inchargeId/caretakerId/patientId once fully allocated', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('assignments').doc('patient-1').set({
        'inchargeId': 'incharge-1',
        'caretakerId': 'caretaker-1',
        'patientId': 'patient-1',
        'createdAt': Timestamp.now(),
      });
      final doc = await db.collection('assignments').doc('patient-1').get();

      final assignment = Assignment.fromDoc(doc);

      expect(assignment.id, 'patient-1');
      expect(assignment.inchargeId, 'incharge-1');
      expect(assignment.caretakerId, 'caretaker-1');
      expect(assignment.patientId, 'patient-1');
    });

    test('caretakerId is null before an Incharge has allocated one', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('assignments').doc('patient-2').set({
        'inchargeId': 'incharge-1',
        'patientId': 'patient-2',
        'createdAt': Timestamp.now(),
      });
      final doc = await db.collection('assignments').doc('patient-2').get();

      expect(Assignment.fromDoc(doc).caretakerId, isNull);
    });

    test('falls back to the document id for patientId (doc id == patient id by design)', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('assignments').doc('patient-3').set({
        'inchargeId': 'incharge-1',
        'createdAt': Timestamp.now(),
      });
      final doc = await db.collection('assignments').doc('patient-3').get();

      expect(Assignment.fromDoc(doc).patientId, 'patient-3');
    });
  });
}
