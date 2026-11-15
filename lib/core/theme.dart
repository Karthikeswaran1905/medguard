import 'package:flutter/material.dart';

/// MedGuard app theme. A calm, clinical palette: teal as the primary
/// (trust, health), amber for pending/attention states, red reserved for
/// escalation/critical states so it stays meaningful (Section 27, 40).
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF0F766E); // teal-700
  static const Color pending = Color(0xFFB45309); // amber-700
  static const Color critical = Color(0xFFB91C1C); // red-700
  static const Color success = Color(0xFF15803D); // green-700

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F9F9),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

/// Status -> color mapping used across every dashboard so a "pending" chip
/// looks the same for a Patient, a Caretaker and an Incharge.
Color statusColor(String status) {
  switch (status) {
    case 'consumed':
      return AppTheme.success;
    case 'not_consumed':
    case 'missed':
      return AppTheme.critical;
    case 'critical_unresolved':
      return AppTheme.critical;
    default:
      return AppTheme.pending;
  }
}
