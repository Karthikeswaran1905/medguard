import 'package:firebase_auth/firebase_auth.dart';

import '../../core/roles.dart';
import '../firebase_client.dart';
import '../models/profile.dart';

/// Owns the current user's own auth session and profile.
///
/// Creating *other* people's accounts (Admin -> Doctor, Doctor -> Incharge,
/// Incharge -> Caretaker) is a privileged operation and lives in
/// [PeopleRepository], backed by the `createStaffUser` Cloud Function
/// (Section 39/48) rather than a client-side Auth call.
class AuthRepository {
  final _auth = FirebaseService.auth;
  final _db = FirebaseService.db;

  Stream<User?> get onAuthStateChange => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Patient self-registration (Section 12). If [inviteCode] is provided,
  /// the new patient is linked to a Doctor via the `linkPatient` Cloud
  /// Function immediately after signup (Section 39). Without a code the
  /// patient is created "unlinked" and appears in a Doctor/Admin pending
  /// queue for manual review.
  Future<void> signUpPatient({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? inviteCode,
    String timezone = 'Asia/Kolkata',
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user;
    if (user == null) {
      throw Exception('Sign up failed: no user returned.');
    }

    final profile = Profile(
      id: user.id,
      orgId: null,
      role: AppRole.patient,
      fullName: fullName,
      phone: phone,
      email: email,
      timezone: timezone,
      createdAt: DateTime.now(),
    );
    await _db.collection('profiles').doc(user.id).set(profile.toInsertMap());
    await _db.collection('patients').doc(user.id).set({});

    if (inviteCode != null && inviteCode.trim().isNotEmpty) {
      await FirebaseService.functions.httpsCallable('linkPatient').call({
        'code': inviteCode.trim(),
        'patientId': user.id,
      });
    }
  }

  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// "Forgot password?" on [SignInScreen] — same Firebase Auth mechanism
  /// `PeopleRepository.createStaffAccount` uses when it provisions a new
  /// staff account, just triggered by the user themselves this time.
  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Loads the signed-in user's own document from `profiles`, which carries
  /// the role that [AuthGate] uses to route to the right dashboard.
  Future<Profile?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final doc = await _db.collection('profiles').doc(user.uid).get();
    if (!doc.exists) return null;
    return Profile.fromDoc(doc);
  }
}

/// [User.id] reads more naturally than [User.uid] at the call sites above
/// while staying exactly what firebase_auth returns.
extension on User {
  String get id => uid;
}
