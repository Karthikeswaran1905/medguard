import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors an `ai_insights/{id}` Firestore document (Section 44): a short,
/// pre-generated adherence summary for one patient, written nightly by the
/// `aiInsightsBatch` Cloud Function. Read-only from the Flutter app — see
/// `AnalyticsRepository.latestInsightsForPatients`.
class AiInsight {
  final String id;
  final String scopeType; // patient | caretaker | incharge | org
  final String scopeId;
  final String insightText;
  final DateTime generatedAt;

  AiInsight({
    required this.id,
    required this.scopeType,
    required this.scopeId,
    required this.insightText,
    required this.generatedAt,
  });

  factory AiInsight.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return AiInsight(
      id: doc.id,
      scopeType: map['scopeType'] as String? ?? 'patient',
      scopeId: map['scopeId'] as String? ?? '',
      insightText: map['insightText'] as String? ?? '',
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
