import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medguard/core/roles.dart';
import 'package:medguard/data/models/profile.dart';

void main() {
  group('Profile.fromDoc', () {
    test('parses every field from a well-formed profiles document', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('profiles').doc('u1').set({
        'orgId': 'org-1',
        'role': 'doctor',
        'fullName': 'Dana Doctor',
        'phone': '555-0100',
        'email': 'dana@example.com',
        'timezone': 'Asia/Kolkata',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      final doc = await db.collection('profiles').doc('u1').get();

      final profile = Profile.fromDoc(doc);

      expect(profile.id, 'u1');
      expect(profile.role, AppRole.doctor);
      expect(profile.fullName, 'Dana Doctor');
      expect(profile.orgId, 'org-1');
      expect(profile.email, 'dana@example.com');
      expect(profile.timezone, 'Asia/Kolkata');
    });

    test('falls back to patient for a missing/unknown role rather than throwing', () async {
      // A stale or corrupted role value should never crash AuthGate's
      // routing switch (lib/features/auth/auth_gate.dart) — it should fail
      // safe to the least-privileged role (Section 26).
      final db = FakeFirebaseFirestore();
      await db.collection('profiles').doc('u2').set({'fullName': 'No Role'});
      final doc = await db.collection('profiles').doc('u2').get();

      expect(Profile.fromDoc(doc).role, AppRole.patient);
    });
  });

  group('Profile.toInsertMap', () {
    test('round-trips role/name/contact fields for writing back to Firestore', () {
      final profile = Profile(
        id: 'u1',
        orgId: 'org-1',
        role: AppRole.caretaker,
        fullName: 'Cara Caretaker',
        phone: '555-0100',
        email: 'cara@example.com',
        timezone: 'Asia/Kolkata',
        createdAt: DateTime(2026, 1, 1),
      );

      final map = profile.toInsertMap();

      expect(map['role'], 'caretaker');
      expect(map['fullName'], 'Cara Caretaker');
      expect(map['orgId'], 'org-1');
      expect(map['email'], 'cara@example.com');
    });
  });
}
