/// Local SQLite ledger + client accounts (no Firestore data layer).
///
/// Enable with:
/// `flutter run --dart-define=USE_SQLITE=true`
const bool kUseSqliteBackend = bool.fromEnvironment(
  'USE_SQLITE',
  defaultValue: false,
);
