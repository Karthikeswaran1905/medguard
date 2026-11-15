import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors an `organizations/{orgId}` Firestore document: the multi-tenant
/// boundary every role-bearing profile is scoped to (Section 38).
class Organization {
  final String id;
  final String name;
  final String type; // school | college | hostel | clinic | hospital
  final String? address;
  final DateTime createdAt;

  Organization({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.createdAt,
  });

  factory Organization.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return Organization(
      id: doc.id,
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? 'clinic',
      address: map['address'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
