// Basic sanity tests for MedGuard.
//
// The default `flutter create` counter test is replaced here rather than
// adapted, because MedGuardApp's widget tree (AuthGate -> AuthRepository)
// touches Supabase.instance.client as soon as it builds, which requires a
// real Supabase.initialize() call. Standing up a Supabase test double is
// worth doing once real integration/widget tests are added (see
// SETUP.md's "next iteration" list), but is out of scope for a starter
// smoke test — so these check the parts of the app that don't depend on a
// live backend: role parsing and theme construction.

import 'package:flutter_test/flutter_test.dart';
import 'package:medguard/core/roles.dart';
import 'package:medguard/core/theme.dart';

void main() {
  test('AppRole.fromString parses known roles', () {
    expect(AppRole.fromString('admin'), AppRole.admin);
    expect(AppRole.fromString('doctor'), AppRole.doctor);
    expect(AppRole.fromString('incharge'), AppRole.incharge);
    expect(AppRole.fromString('caretaker'), AppRole.caretaker);
    expect(AppRole.fromString('patient'), AppRole.patient);
  });

  test('AppRole.fromString falls back to patient for an unknown value', () {
    // A stale or unexpected role value should never crash routing
    // (Section 26) — it should fail safe to the least-privileged role.
    expect(AppRole.fromString('unknown_role'), AppRole.patient);
  });

  test('AppRole.label is a human-readable, non-empty string per role', () {
    for (final role in AppRole.values) {
      expect(role.label, isNotEmpty);
    }
  });

  test('AppTheme.light() builds a valid Material 3 theme', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, isNotNull);
  });

  test('statusColor maps every known event status to a color', () {
    for (final status in ['pending', 'consumed', 'not_consumed', 'missed', 'critical_unresolved']) {
      expect(statusColor(status), isNotNull);
    }
  });
}
