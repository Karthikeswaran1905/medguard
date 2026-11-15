import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:meta/meta.dart';

/// Thin accessor around the Firebase services used throughout the app —
/// the Firestore-backed equivalent of the old `SupabaseService`.
///
/// Every data access in MedGuard goes through this client so that Firestore
/// Security Rules (`firestore.rules`, replacing the Postgres RLS policies in
/// the original architecture report's Section 46) are the only enforcement
/// point — the Flutter app never assumes a permission the database itself
/// doesn't also check.
class FirebaseService {
  FirebaseService._();

  // Test-only seam (see [debugOverride]): every repository reads Firestore
  // and FirebaseAuth exclusively through the getters below, so pointing
  // these at a FakeFirebaseFirestore / MockFirebaseAuth in a test's setUp
  // is enough to make PeopleRepository, MedicationRepository and
  // AnalyticsRepository testable without a live Firebase project — no
  // production code path touches these fields. Left null, both getters
  // fall through to the real Firebase singletons exactly as before.
  static FirebaseAuth? _authOverride;
  static FirebaseFirestore? _dbOverride;

  static FirebaseAuth get auth => _authOverride ?? FirebaseAuth.instance;

  static FirebaseFirestore get db => _dbOverride ?? FirebaseFirestore.instance;

  static FirebaseFunctions get functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static FirebaseStorage get storage => FirebaseStorage.instance;

  static User? get currentUser => auth.currentUser;

  /// Test-only. Call from a test's `setUp` with a `FakeFirebaseFirestore`
  /// and/or `MockFirebaseAuth` (see test/flows/critical_flows_test.dart)
  /// so the repositories under test read/write an in-memory double
  /// instead of a real Firebase project; call again with no arguments in
  /// `tearDown` to restore the real singletons. Never call this from app
  /// code.
  @visibleForTesting
  static void debugOverride({FirebaseAuth? auth, FirebaseFirestore? db}) {
    _authOverride = auth;
    _dbOverride = db;
  }
}
