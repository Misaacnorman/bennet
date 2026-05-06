# Bennet

Bennet is a Flutter app for lightweight bookkeeping plus **client-account** workflows: balances, charges, payments (with allocations and receipts), statements, ledger sync, PDF output, and CSV exports.

The product copy is intentionally **domain-neutral** (charges, receipts, balances, ledger) so it stays readable across different businesses.

## Features

- **Dual backend**: Firebase (Auth + Cloud Firestore) for signed-in sync, or a fully local **SQLite** book for offline/demo use.
- **Money**: amounts are stored in **minor units** (integer cents or equivalent)—no floating‑point balances in persistence.
- **Payments**: allocations against open balances, receipts, reversal path (no destructive delete of posted money from normal flows).
- **Statements**: persisted **snapshot** (lines JSON, client/code labels, business name) so PDFs remain stable after directory edits.
- **Ledger linkage**: postings from client payments can carry **traceability fields** (`client_payment` / reversal) surfaced in transactions.
- **Exports**: CSV for clients, charge register, payments, statement index via **Settings → Export CSV**.
- **Settings**: business name, document footer line (PDFs), default payment method (new payment forms).

## Getting started

1. Install [Flutter](https://docs.flutter.dev/get-started/install) for your platform.
2. From the repo root:

   ```bash
   flutter pub get
   ```

3. Run the analyzer and tests locally:

   ```bash
   flutter analyze
   flutter test
   ```

## Running with SQLite only (local book)

SQLite mode skips Firebase authentication and persists under the app documents directory.

```bash
flutter run --dart-define=USE_SQLITE=true
```

This uses `LedgerRepositoryImpl` plus `ClientAccountRepositoryImpl`; the client database opens at **`bennet.db`** (see [`lib/data/database/sqlite_db.dart`](lib/data/database/sqlite_db.dart)).

## Running with Firebase (Firestore)

1. Create a Firebase project and add Android / iOS / Web apps as usual.
2. Place `firebase_options.dart` (from `flutterfire configure`) where your app expects it.
3. Deploy **Firestore indexes** after you change composite queries (`firebase/firestore.indexes.json` if present).
4. Run **without** the SQLite define so `kUseSqliteBackend` stays false:

   ```bash
   flutter run
   ```

Firestore paths follow `users/{uid}/books/{bookId}/…` (see Firebase repository classes under [`lib/data/firebase/`](lib/data/firebase/)).

### Security notes

- Production **Firestore rules** are your responsibility—tighten incrementally alongside your data model (see plan under “Firestore Completion”).
- This README does **not** grant access to secrets; rotate API keys and use environment-specific Firebase projects.

## Schema migrations (SQLite)

`dbVersion` lives in [`lib/data/database/sqlite_db.dart`](lib/data/database/sqlite_db.dart).

- **v6** adds **ledger traceability** columns on `transactions` and **statement snapshot** columns on `client_statements`. Upgrades from earlier installs apply idempotent `ALTER TABLE` additions.

Fresh installs use the consolidated `CREATE TABLE` definitions in the same module.

## Main routes

| Path | Purpose |
|------|---------|
| `/clients`, `/clients/:id` | Client directory and detail |
| `/payments`, `/payments/:id` | Posted payments |
| `/receipts/:paymentId` | Receipt preview and PDF share |
| `/charges/:id` | Charge detail |
| `/statements`, `/statements/:id` | Statement history and saved snapshots |
| `/transactions/:id`, `/cashbook` | Ledger browsing |
| `/reports` | Category roll‑ups (“tax export” style summaries) |

Numeric IDs are validated with `int.tryParse`; bad links render a lightweight error scaffold instead of throwing.

## Tests

- **`test/client_account_repository_impl_test.dart`** – repository rules, allocations, register rows, SQLite integrity.
- **`test/sqlite_schema_test.dart`** – expected tables/columns through current `dbVersion`.
- **`test/statement_snapshot_codec_test.dart`** – JSON stability for saved statement lines.
- **`test/pdf_documents_smoke_test.dart`** – basic PDF builders.

Continuous integration locally: `flutter test` plus `flutter analyze` (the latter may emit style “info” lints depending on analyzer options).

## Deployment

- **Web**: `flutter build web` — host the `build/web` bundle on HTTPS; configure CSP if you integrate third‑party fonts for PDF previews.
- **Desktop / mobile**: use `flutter build <target>` per platform guide.

Document limitations honestly in release notes:

- Offline SQLite is single-device unless you ship your own sync.
- Firebase mode requires connectivity for first-time bootstrap and authenticated reads/writes unless you cache explicitly.

## License

Follow the licensing terms declared in [`LICENSE`](LICENSE) for this repo (if absent, retain whatever your organization requires).
