/// The five MedGuard roles (Section 5 of the architecture report) and the
/// management/escalation chain between them:
///
///   Management:  admin -> doctor -> incharge -> caretaker -> patient
///   Escalation:  patient -> caretaker -> incharge -> (family + admin)
enum AppRole {
  admin,
  doctor,
  incharge,
  caretaker,
  patient;

  static AppRole fromString(String value) {
    return AppRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => AppRole.patient,
    );
  }

  String get label {
    switch (this) {
      case AppRole.admin:
        return 'Admin / Dean';
      case AppRole.doctor:
        return 'Doctor';
      case AppRole.incharge:
        return 'Incharge';
      case AppRole.caretaker:
        return 'Caretaker';
      case AppRole.patient:
        return 'Patient';
    }
  }
}

/// Medication event status values shared by patient_status, caretaker_status
/// and final_status columns (Section 24 / Section 45).
class EventStatus {
  EventStatus._();

  static const String pending = 'pending';
  static const String consumed = 'consumed';
  static const String notConsumed = 'not_consumed';
  static const String missed = 'missed';
}

/// Escalation levels stored on medication_events.escalation_level
/// (Section 24, extended in Section 40 with a final parallel step).
class EscalationLevel {
  EscalationLevel._();

  static const String patient = 'patient';
  static const String caretaker = 'caretaker';
  static const String incharge = 'incharge';
  static const String criticalUnresolved = 'critical_unresolved';
}
