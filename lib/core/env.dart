/// Environment configuration for MedGuard.
///
/// Values are injected at build/run time via `--dart-define`, never
/// hardcoded, so the same codebase can target dev / staging / prod
/// Supabase projects (see SETUP.md, and Section 51 of the architecture
/// report: "CI/CD and Deployment Architecture").
///
/// Example:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xyzcompany.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJI...
class Env {
  Env._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
