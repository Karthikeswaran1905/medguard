import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/roles.dart';

/// Mirrors a `prescriptions/{id}` Firestore document (Section 45): a
/// Doctor-created record that medicines hang off. Only the prescribing
/// doctor may create/update one (enforced by Firestore Security Rules,
/// replacing Section 46's RLS), grounded in a doctor_patient_link
/// (Section 39).
class Prescription {
  final String id;
  final String patientId;
  final String doctorId;
  final String status; // active | discontinued
  final DateTime createdAt;

  Prescription({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.status,
    required this.createdAt,
  });

  factory Prescription.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return Prescription(
      id: doc.id,
      patientId: map['patientId'] as String? ?? '',
      doctorId: map['doctorId'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Mirrors a `medicines/{id}` Firestore document (Section 9 / Section 45):
/// name, dose, frequency, duration and instructions set by the Doctor.
/// Patients and Caretakers may read but never write these fields
/// (Section 6.2, Section 7).
class Medicine {
  final String id;
  final String prescriptionId;
  final String name;
  final String dose;
  final int frequencyPerDay;
  final String? instructions;
  final int durationDays;
  final DateTime startDate;

  Medicine({
    required this.id,
    required this.prescriptionId,
    required this.name,
    required this.dose,
    required this.frequencyPerDay,
    required this.instructions,
    required this.durationDays,
    required this.startDate,
  });

  factory Medicine.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return Medicine(
      id: doc.id,
      prescriptionId: map['prescriptionId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      dose: map['dose'] as String? ?? '',
      frequencyPerDay: map['frequencyPerDay'] as int? ?? 1,
      instructions: map['instructions'] as String?,
      durationDays: map['durationDays'] as int? ?? 30,
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'prescriptionId': prescriptionId,
        'name': name,
        'dose': dose,
        'frequencyPerDay': frequencyPerDay,
        'instructions': instructions,
        'durationDays': durationDays,
        'startDate': Timestamp.fromDate(startDate),
      };
}

/// Mirrors a `medication_schedules/{id}` Firestore document (Section 13,
/// Section 45): one row per daily dose time. Stored as local wall-clock
/// time — the patient's `profiles.timezone` gives it meaning (Section 41).
class MedicationSchedule {
  final String id;
  final String medicineId;
  final String patientId;
  final String timeOfDay; // "HH:mm:ss" local time

  MedicationSchedule({
    required this.id,
    required this.medicineId,
    required this.patientId,
    required this.timeOfDay,
  });

  factory MedicationSchedule.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return MedicationSchedule(
      id: doc.id,
      medicineId: map['medicineId'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      timeOfDay: map['timeOfDay'] as String? ?? '08:00:00',
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'medicineId': medicineId,
        'patientId': patientId,
        'timeOfDay': timeOfDay,
      };
}

/// Mirrors a `medication_events/{id}` Firestore document (Section 24,
/// extended in Section 42/45 with server_received_at / sync_status / ack
/// fields). This is the single document the whole escalation chain
/// (Section 15, 40) revolves around.
///
/// Unlike the Postgres version, `medicineName`/`medicineDose` are
/// denormalized directly onto this document at creation time (rather than
/// joined via `medicines!inner` at read time) — Firestore has no
/// server-side joins, so the value each screen actually needs is copied
/// onto the event once instead of being re-fetched per read.
class MedicationEvent {
  final String id;
  final String patientId;
  final String medicineId;
  final String? scheduleId;
  final DateTime scheduledAt;
  final String patientStatus;
  final DateTime? patientConfirmedAt;
  final DateTime? serverReceivedAt;
  final String caretakerStatus;
  final DateTime? caretakerConfirmedAt;
  final String finalStatus;
  final String escalationLevel;
  final DateTime? ackAt;
  final DateTime createdAt;

  final String? medicineName;
  final String? medicineDose;

  MedicationEvent({
    required this.id,
    required this.patientId,
    required this.medicineId,
    required this.scheduleId,
    required this.scheduledAt,
    required this.patientStatus,
    required this.patientConfirmedAt,
    required this.serverReceivedAt,
    required this.caretakerStatus,
    required this.caretakerConfirmedAt,
    required this.finalStatus,
    required this.escalationLevel,
    required this.ackAt,
    required this.createdAt,
    this.medicineName,
    this.medicineDose,
  });

  bool get isResolved =>
      finalStatus == EventStatus.consumed || finalStatus == EventStatus.notConsumed;

  factory MedicationEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return MedicationEvent(
      id: doc.id,
      patientId: map['patientId'] as String? ?? '',
      medicineId: map['medicineId'] as String? ?? '',
      scheduleId: map['scheduleId'] as String?,
      scheduledAt: (map['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      patientStatus: map['patientStatus'] as String? ?? EventStatus.pending,
      patientConfirmedAt: (map['patientConfirmedAt'] as Timestamp?)?.toDate(),
      serverReceivedAt: (map['serverReceivedAt'] as Timestamp?)?.toDate(),
      caretakerStatus: map['caretakerStatus'] as String? ?? EventStatus.pending,
      caretakerConfirmedAt: (map['caretakerConfirmedAt'] as Timestamp?)?.toDate(),
      finalStatus: map['finalStatus'] as String? ?? EventStatus.pending,
      escalationLevel: map['escalationLevel'] as String? ?? EscalationLevel.patient,
      ackAt: (map['ackAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      medicineName: map['medicineName'] as String?,
      medicineDose: map['medicineDose'] as String?,
    );
  }
}
