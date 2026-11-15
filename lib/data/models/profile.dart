import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/roles.dart';

/// Mirrors a `profiles/{uid}` Firestore document: common identity, role,
/// orgId and timezone shared by every account type. The document id *is*
/// the Firebase Auth uid, so there's no separate `id` field stored — it's
/// attached from the document reference when read back.
class Profile {
  final String id;
  final String? orgId;
  final AppRole role;
  final String fullName;
  final String? phone;
  final String? email;
  final String timezone;
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.orgId,
    required this.role,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.timezone,
    required this.createdAt,
  });

  factory Profile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return Profile(
      id: doc.id,
      orgId: map['orgId'] as String?,
      role: AppRole.fromString(map['role'] as String? ?? 'patient'),
      fullName: map['fullName'] as String? ?? '',
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      timezone: map['timezone'] as String? ?? 'Asia/Kolkata',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'orgId': orgId,
        'role': role.name,
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'timezone': timezone,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
