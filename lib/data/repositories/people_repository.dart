import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/roles.dart';
import '../firebase_client.dart';
import '../models/profile.dart';
import '../models/relationship_models.dart';

/// Returned by [PeopleRepository.createStaffAccount] — the new account's
/// profile id, whether a password was set directly by whoever created the
/// account (rather than a random one), and, when it wasn't, whether
/// Firebase actually managed to email them a password-reset link (see
/// that method's doc comment for when it might not: the account itself is
/// created either way).
class StaffAccountResult {
  final String id;
  final bool passwordSetByCreator;
  final bool resetEmailSent;
  StaffAccountResult({
    required this.id,
    required this.passwordSetByCreator,
    required this.resetEmailSent,
  });
}

/// Everyone-management: Admin -> Doctor -> Incharge -> Caretaker -> Patient
/// (Section 11), plus the Doctor-Patient linking flow (Section 39) and
/// family/emergency contacts (Section 8, wired into escalation in
/// Section 40).
class PeopleRepository {
  final _db = FirebaseService.db;

  /// Firestore's `whereIn` accepts at most 30 values per query (10 in
  /// older SDKs) — chunking keeps every id-list lookup below here working
  /// regardless of how many patients a doctor/caretaker ends up with.
  static const _whereInChunkSize = 30;

  Future<List<T>> _fetchByIdsChunked<T>(
    String collection,
    List<String> ids,
    T Function(DocumentSnapshot<Map<String, dynamic>>) fromDoc,
  ) async {
    if (ids.isEmpty) return [];
    final results = <T>[];
    for (var i = 0; i < ids.length; i += _whereInChunkSize) {
      final chunk = ids.sublist(i, i + _whereInChunkSize > ids.length ? ids.length : i + _whereInChunkSize);
      final snap = await _db
          .collection(collection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(snap.docs.map(fromDoc));
    }
    return results;
  }

  // ---- Staff creation (privileged; Section 39/48) ------------------------

  static const _tempPasswordChars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%';

  /// A one-time password for the new Auth account — nobody needs to know
  /// it, since sign-in happens through the password-reset email instead.
  String _randomTempPassword() {
    final rand = Random.secure();
    return List.generate(
      20,
      (_) => _tempPasswordChars[rand.nextInt(_tempPasswordChars.length)],
    ).join();
  }

  /// Admin adds a Doctor, Doctor adds an Incharge, Incharge adds a
  /// Caretaker (Section 39, 48). MedGuard runs on Firebase's free Spark
  /// plan, which can't deploy Cloud Functions at all (that needs Blaze) —
  /// so unlike the original `createStaffUser` design (still in
  /// `functions/src/createStaffUser.ts` for anyone who does upgrade to
  /// Blaze), this can't go through the Admin SDK server-side. It's done
  /// entirely with client SDKs instead:
  ///
  ///  1. A short-lived *secondary* [FirebaseApp] creates the new person's
  ///     Auth account. Using a second app (rather than the default one) is
  ///     what keeps this from signing the caller themselves out — creating
  ///     a user on `FirebaseAuth.instance` would switch its `currentUser`
  ///     to the account just created.
  ///  2. The caller's own (default-app) session then writes
  ///     `profiles/{uid}`, the `{role}s/{uid}` placeholder, and an
  ///     `audit_logs` entry — allowed by `canCreateStaffRole()` in
  ///     firestore.rules, the client-write equivalent of the old Cloud
  ///     Function's server-side role check.
  ///  3. If [password] wasn't given, `sendPasswordResetEmail` asks Firebase
  ///     Auth to email the new person a reset link directly, using its own
  ///     built-in template (Authentication -> Templates in the console) —
  ///     nobody has to relay a link by hand the way the old Cloud
  ///     Function's returned link would have needed.
  ///     [StaffAccountResult.resetEmailSent] is false only if that last
  ///     step itself throws; the account and profile are already created
  ///     by then either way, so this doesn't roll anything back — the
  ///     person can still get in via "Forgot password?" on the sign-in
  ///     screen. When [password] *was* given, this step is skipped
  ///     entirely — whoever set it is expected to pass it on to the new
  ///     person themselves, and [StaffAccountResult.passwordSetByCreator]
  ///     is true so the caller's UI can say so instead of talking about a
  ///     reset email that was never sent.
  ///
  /// One gap this used to have: steps 2 and 3 run under the *caller's*
  /// permissions, checked by firestore.rules — but step 1 (creating the
  /// Auth user) happens first and isn't gated by those rules at all. If
  /// step 2's Firestore writes then failed for any reason (a dropped
  /// connection, a rules mismatch, the app being killed mid-write), the
  /// Auth account from step 1 was left behind with no profile document
  /// anywhere — invisible to the rest of the app, but still permanently
  /// "taken" from Firebase Auth's point of view, so any retry with that
  /// same email failed forever with `email-already-in-use`. That's now
  /// handled: if the Firestore writes in step 2 throw, this reaches back
  /// into a fresh secondary app, signs in as the just-created user (using
  /// the temp password from step 1, which is still in scope), and deletes
  /// the orphaned Auth account before rethrowing — so the email becomes
  /// retryable again instead of stuck. That cleanup is itself best-effort
  /// (if it fails too, the original error still propagates; the caller
  /// just may need to try again or contact an admin who can delete the
  /// leftover Auth user from the Firebase Console).
  Future<StaffAccountResult> createStaffAccount({
    required String email,
    required String fullName,
    required String phone,
    required AppRole role, // doctor | incharge | caretaker
    String? orgId,
    // When given, the new account signs in with this password from the
    // start instead of a random one + a reset-email link — e.g. Admin
    // typing a password directly on the Add Doctor screen.
    String? password,
  }) async {
    final passwordSetByCreator = password != null && password.isNotEmpty;
    final String tempPassword = passwordSetByCreator ? password! : _randomTempPassword();
    final secondaryApp = await Firebase.initializeApp(
      name: 'staffCreate-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    late final String newUserId;
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );
      newUserId = cred.user!.uid;
      await cred.user!.updateDisplayName(fullName);
      await secondaryAuth.signOut();
    } finally {
      await secondaryApp.delete();
    }

    try {
      final now = FieldValue.serverTimestamp();
      await _db.collection('profiles').doc(newUserId).set({
        'orgId': orgId,
        'role': role.name,
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'timezone': 'Asia/Kolkata',
        'createdAt': now,
      });
      await _db.collection('${role.name}s').doc(newUserId).set({});
      await _db.collection('audit_logs').add({
        'actorId': FirebaseService.auth.currentUser!.uid,
        'action': 'staff_account_created',
        'details': {'newUserId': newUserId, 'role': role.name},
        'createdAt': now,
      });
    } catch (e) {
      await _deleteOrphanedAuthUser(email: email, password: tempPassword);
      rethrow;
    }

    var resetEmailSent = false;
    if (!passwordSetByCreator) {
      resetEmailSent = true;
      try {
        await FirebaseService.auth.sendPasswordResetEmail(email: email);
      } catch (_) {
        resetEmailSent = false;
      }
    }

    return StaffAccountResult(
      id: newUserId,
      passwordSetByCreator: passwordSetByCreator,
      resetEmailSent: resetEmailSent,
    );
  }

  /// Best-effort cleanup for [createStaffAccount]: signs into a throwaway
  /// secondary app as the Auth user that step 1 just created, and deletes
  /// it, so a subsequent Firestore-write failure doesn't leave the email
  /// permanently stuck on `email-already-in-use`. Never throws — if this
  /// itself fails (e.g. no network), the caller's original error is what
  /// the user sees, and the orphaned account is left for an admin to
  /// remove from the Firebase Console's Authentication tab.
  Future<void> _deleteOrphanedAuthUser({
    required String email,
    required String password,
  }) async {
    FirebaseApp? cleanupApp;
    try {
      cleanupApp = await Firebase.initializeApp(
        name: 'staffCleanup-${DateTime.now().microsecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final cleanupAuth = FirebaseAuth.instanceFor(app: cleanupApp);
      final cred = await cleanupAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user!.delete();
    } catch (_) {
      // Best-effort — see doc comment. The original error is what matters.
    } finally {
      if (cleanupApp != null) await cleanupApp.delete();
    }
  }

  Future<List<Profile>> fetchByRole(AppRole role, {String? orgId}) async {
    Query<Map<String, dynamic>> query =
        _db.collection('profiles').where('role', isEqualTo: role.name);
    if (orgId != null) query = query.where('orgId', isEqualTo: orgId);
    final snap = await query.orderBy('fullName').get();
    return snap.docs.map(Profile.fromDoc).toList();
  }

  /// A single profile by id — e.g. the Medication Details screen resolving
  /// a prescription's `doctorId` to a "Prescribed by" name.
  Future<Profile?> fetchProfile(String id) async {
    final doc = await _db.collection('profiles').doc(id).get();
    if (!doc.exists) return null;
    return Profile.fromDoc(doc);
  }

  // ---- Doctor <-> Patient linking (Section 39) ---------------------------

  /// The invite document id *is* the code (see [PatientInvite]), so
  /// `linkPatient` (Cloud Function) can validate it with a direct get
  /// instead of a query.
  Future<String> generateInviteCode({
    required String doctorId,
    String? orgId,
    Duration validFor = const Duration(days: 7),
  }) async {
    final code = _randomCode();
    await _db.collection('patient_invites').doc(code).set({
      'doctorId': doctorId,
      'orgId': orgId,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(validFor)),
      'usedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    return List.generate(6, (i) => chars[(rand ~/ (i + 1)) % chars.length]).join();
  }

  Future<List<Profile>> fetchPatientsForDoctor(String doctorId) async {
    final links = await _db
        .collection('doctor_patient_links')
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'active')
        .get();
    final patientIds = links.docs.map((d) => d.data()['patientId'] as String).toList();
    return _fetchByIdsChunked('profiles', patientIds, Profile.fromDoc);
  }

  /// Doctor allocates an Incharge to a patient (Section 11 step 4): creates
  /// (or reuses) the `assignments/{patientId}` document that the Incharge
  /// later fills in with a Caretaker.
  Future<void> allocateIncharge({
    required String inchargeId,
    required String patientId,
  }) async {
    await _db.collection('assignments').doc(patientId).set({
      'inchargeId': inchargeId,
      'patientId': patientId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---- Incharge <-> Caretaker / Patient (Section 11 steps 5-6) -----------

  Future<List<Assignment>> fetchAssignmentsForIncharge(String inchargeId) async {
    final snap = await _db
        .collection('assignments')
        .where('inchargeId', isEqualTo: inchargeId)
        .get();
    return snap.docs.map(Assignment.fromDoc).toList();
  }

  Future<void> allocateCaretaker({
    required String assignmentId,
    required String caretakerId,
  }) async {
    await _db
        .collection('assignments')
        .doc(assignmentId)
        .update({'caretakerId': caretakerId});
  }

  Future<List<Profile>> fetchPatientsForCaretaker(String caretakerId) async {
    final links = await _db
        .collection('assignments')
        .where('caretakerId', isEqualTo: caretakerId)
        .get();
    final patientIds = links.docs.map((d) => d.data()['patientId'] as String).toList();
    return _fetchByIdsChunked('profiles', patientIds, Profile.fromDoc);
  }

  // ---- Family / emergency contacts (Section 8, 40) -----------------------

  Future<List<FamilyContact>> fetchFamilyContacts(String patientId) async {
    final snap = await _db
        .collection('family_contacts')
        .where('patientId', isEqualTo: patientId)
        .get();
    return snap.docs.map(FamilyContact.fromDoc).toList();
  }

  Future<void> addFamilyContact(FamilyContact contact) async {
    await _db.collection('family_contacts').add(contact.toInsertMap());
  }
}
