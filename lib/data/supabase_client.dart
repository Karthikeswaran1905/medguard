// Deprecated — left over from the original Supabase implementation,
// superseded by `lib/data/firebase_client.dart` when this project migrated
// to Firebase. Nothing imports this file anymore.
//
// It's emptied out (rather than left with its old `supabase_flutter`
// import) because `supabase_flutter` was removed from `pubspec.yaml`
// during the migration, which made the old content fail to compile —
// `flutter analyze`/`flutter build` would error on this file even though
// nothing in the app actually uses it.
//
// Safe to delete outright, along with `lib/core/env.dart` (only this file
// imported it) — see SETUP.md's "Files to remove".
