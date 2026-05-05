# Bennet AI Agent Implementation Guide

## Mission

Build Bennet into a beautiful, domain-neutral client-account and payment application. The app is for a small business that tracks clients, charges, payments, receipts, statements, and ledger reports. Do not introduce vertical-specific vocabulary into code, UI, tests, sample data, routes, generated documents, or comments. Keep the product general.

## Non-Negotiables

- Never commit secrets. Firebase admin SDK JSON files must stay ignored.
- Do not delete user work or revert unrelated local changes.
- Keep money as integer minor units.
- Do not use floating point for financial calculations.
- Use domain-neutral language:
  - Client
  - Charge
  - Payment
  - Receipt
  - Statement
  - Account
  - Balance
  - Outstanding
  - Credit
  - Due
- Do not add vertical-specific labels anywhere in the app.
- Posted financial records should be reversed/voided, not silently deleted.
- Existing ledger, cash book, monthly summary, and tax export must keep working.
- All new UI must be responsive across mobile, tablet, and desktop.
- Run `flutter analyze` and `flutter test` before finishing any implementation turn when feasible.

## Current Architecture

The app is Flutter with Riverpod, GoRouter, Firebase Auth, Cloud Firestore, and a SQLite implementation.

Important files:

- `lib/domain/entities.dart`
- `lib/domain/ledger_repository.dart`
- `lib/data/firebase/firestore_ledger_repository.dart`
- `lib/data/ledger_repository_impl.dart`
- `lib/application/providers.dart`
- `lib/router.dart`
- `lib/presentation/widgets/app_scaffold.dart`
- `lib/presentation/layout/responsive_content.dart`
- `lib/services/receipt_pdf_service.dart`

Existing pattern:

- Domain entities are plain Dart classes.
- Repository interface lives in `domain`.
- Firestore implementation lives in `data/firebase`.
- SQLite/local implementation lives in `data`.
- Riverpod providers are in `application`.
- Screens are under `presentation/screens`.
- Shared UI belongs under `presentation/widgets` or `presentation/layout`.

## Preferred New Architecture

Add client-account functionality as a module rather than stuffing everything into the existing ledger files.

Recommended files:

```text
lib/domain/client_accounts.dart
lib/domain/client_account_repository.dart
lib/data/firebase/firestore_client_account_repository.dart
lib/data/client_account_repository_impl.dart
lib/application/client_account_providers.dart
lib/services/statement_pdf_service.dart
lib/presentation/widgets/amount_text.dart
lib/presentation/widgets/empty_state.dart
lib/presentation/widgets/metric_tile.dart
lib/presentation/widgets/page_header.dart
lib/presentation/widgets/status_pill.dart
lib/presentation/screens/overview_screen.dart
lib/presentation/screens/clients/client_list_screen.dart
lib/presentation/screens/clients/client_detail_screen.dart
lib/presentation/screens/clients/client_edit_screen.dart
lib/presentation/screens/payments/payment_list_screen.dart
lib/presentation/screens/payments/payment_edit_screen.dart
lib/presentation/screens/payments/payment_detail_screen.dart
lib/presentation/screens/charges/charge_list_screen.dart
lib/presentation/screens/charges/charge_edit_screen.dart
lib/presentation/screens/statements/statement_builder_screen.dart
lib/presentation/screens/statements/statement_history_screen.dart
```

If moving existing screens, do it carefully and update routes/imports in the same patch.

## Implementation Order

### Step 1: Domain

Create `client_accounts.dart` with:

- `Client`
- `ClientStatus`
- `ClientCharge`
- `ChargeStatus`
- `ClientPayment`
- `PaymentStatus`
- `PaymentMethod`
- `PaymentAllocation`
- `ClientAdjustment`
- `AdjustmentKind`
- `ReceiptDocument`
- `ClientStatement`
- `ClientLedgerLine`
- `ClientAccountSummary`
- Input classes:
  - `CreateClientInput`
  - `UpdateClientInput`
  - `CreateChargeInput`
  - `RecordPaymentInput`
  - `BuildStatementInput`

Use immutable classes with required fields. Use enum parsing extensions matching the existing style.

### Step 2: Repository Interface

Create `client_account_repository.dart`.

Minimum methods:

```dart
abstract class ClientAccountRepository {
  Future<List<Client>> listClients({ClientStatus? status, String? query});
  Future<Client?> getClient(int id);
  Future<int> createClient(CreateClientInput input);
  Future<void> updateClient(UpdateClientInput input);
  Future<void> archiveClient(int id);

  Future<ClientAccountSummary> clientSummary(int clientId);
  Future<List<ClientLedgerLine>> clientLedger(
    int clientId, {
    DateTime? from,
    DateTime? to,
  });

  Future<int> createCharge(CreateChargeInput input);
  Future<void> voidCharge(int chargeId, String reason);

  Future<int> recordPayment(RecordPaymentInput input);
  Future<void> reversePayment(int paymentId, String reason);

  Future<ReceiptDocument> receiptForPayment(int paymentId);
  Future<StatementPreview> buildStatementPreview(BuildStatementInput input);
  Future<int> saveStatement(BuildStatementInput input);
}
```

Adjust names/types as implementation clarifies, but keep the model domain-neutral.

### Step 3: Persistence

Firestore:

- Store under `users/{uid}/books/{bookId}/...`.
- Add collections:
  - `clients`
  - `clientCharges`
  - `clientPayments`
  - `paymentAllocations`
  - `clientAdjustments`
  - `receipts`
  - `statements`
- Extend counters in `_meta/ids` or add `documentCounters/main`.
- Use transactions/batches for payment posting.
- Keep timestamps consistent: Firestore `Timestamp` in Firestore, milliseconds in SQLite.

SQLite:

- Bump `dbVersion`.
- Add `onUpgrade`.
- Create client-account tables.
- Add indexes for list screens.

### Step 4: Providers

Create `client_account_providers.dart`.

Providers:

- `clientAccountRepositoryProvider`
- `clientsProvider`
- `clientProvider`
- `clientSummaryProvider`
- `clientLedgerProvider`
- `clientPaymentsProvider`
- `clientChargesProvider`
- `statementPreviewProvider`
- `overviewProvider`

Invalidate after writes:

- affected client provider.
- client list.
- client summary.
- client ledger.
- payment/charge lists.
- receipt/statement providers.
- existing ledger providers if payment created a transaction.

### Step 5: UI Components

Build reusable components before screens:

- `AmountText`: right-aligned, optional status color, tabular-feeling style.
- `StatusPill`: compact colored label.
- `MetricTile`: title, value, optional delta/icon.
- `EmptyState`: icon, title, action.
- `PageHeader`: title, subtitle/meta, actions, responsive wrapping.
- `SearchAndFiltersBar`: search plus chips.
- `ResponsiveDataSurface`: switches table/cards by width.

Rules:

- Icon-only buttons need tooltips.
- Buttons must not span the full desktop width unless inside a narrow form.
- Tables on desktop, cards/lists on mobile.
- Keep cards radius 8px unless theme says otherwise.
- Avoid nested cards.

### Step 6: Screens

Recommended first UI sequence:

1. `OverviewScreen`
2. `ClientListScreen`
3. `ClientEditScreen`
4. `ClientDetailScreen`
5. `PaymentEditScreen`
6. Receipt PDF support
7. Statement builder

Screen acceptance:

- Overview shows business-critical metrics and quick actions.
- Client list supports search/filter and create.
- Client detail shows balance, timeline, charges, payments, receipts, statements.
- Payment form validates amount/client/account/category/method/date.
- Receipt can be generated after payment.
- Statement can preview and generate PDF.

### Step 7: PDF Services

Improve `receipt_pdf_service.dart` for client payments.

Create `statement_pdf_service.dart`.

PDF rules:

- Snapshot business/client fields into document models.
- Avoid relying on live settings for old documents.
- Use simple robust tables.
- Keep long names wrapping safely.
- Include receipt/statement number, issue date, client, payment/line details, totals, footer.

### Step 8: Navigation

Update routes:

- `/` Overview
- `/clients`
- `/clients/new`
- `/clients/:id`
- `/clients/:id/edit`
- `/clients/:id/payment/new`
- `/clients/:id/charge/new`
- `/payments`
- `/payments/new`
- `/payments/:id`
- `/charges`
- `/statements`
- Ledger routes either preserve old paths or move carefully with redirects.

Update `BennetNav.destinations` to prioritize:

- Overview
- Clients
- Payments
- Charges
- Statements
- Ledger
- Settings

If grouping Ledger is too large for one patch, keep existing ledger destinations but place new client workflow first.

## UI Design Requirements

The current UI is functional but too plain. Make it feel like a crafted financial product.

Visual direction:

- Calm, modern, business-grade.
- Neutral surfaces.
- Deep green primary.
- Blue for credit/info.
- Amber for due/attention.
- Red only for serious negative state.
- Compact, readable, not oversized.
- Desktop content is centered/capped.
- Mobile is full-width and thumb-friendly.

Theme work:

- Improve `app_theme.dart`.
- Add card/list/table styles.
- Add input styles.
- Keep Material 3.
- Do not use decorative blobs or oversized marketing hero sections.

Spacing:

- Mobile page padding 16.
- Desktop page padding 24.
- Field gap 12 or 16.
- Section gap 24.
- Card radius 8.

Responsive:

- Use `ResponsiveContent`.
- Use `ContentWidthMode.narrow` for small settings/forms.
- Use `ContentWidthMode.form` for edit forms.
- Use `ContentWidthMode.standard` for dashboards and normal lists.
- Use `ContentWidthMode.wide` for tables/split panes.

## Data Math Rules

Client balance:

```text
opening balance
+ issued charges
+ increasing adjustments
- posted payments
- decreasing adjustments
+ reversed payments if reversal policy adds balance back
= current balance
```

Charge open amount:

```text
charge amount - allocations from posted payments
```

Payment unallocated amount:

```text
payment amount - sum allocations
```

Statement opening:

```text
client balance immediately before fromDate
```

Statement closing:

```text
opening + charges in range - payments in range +/- adjustments in range
```

## Validation Rules

Client:

- Name required.
- Code unique per book.
- Email format if present.
- Status cannot be invalid.

Charge:

- Client required.
- Amount > 0.
- Issue date required.
- Due date can be null but cannot be before issue date if present.
- Voided charge is excluded from active balance.

Payment:

- Client required.
- Amount > 0.
- Date required.
- Method required.
- Account required.
- Category required.
- Reference optional.
- Posted payment gets payment and receipt numbers.

Statement:

- Client required.
- Date range required.
- End date cannot be before start date.

## Testing Checklist

Always add or update tests for:

- Balance math.
- Allocation math.
- Statement line running balance.
- Number generation.
- Repository serializers/parsers.
- Payment creates ledger transaction.
- Reversal behavior.
- Widget validation for critical forms.

Run:

```bash
cmd.exe /c D:\\Work\\SoftwaresLab\\MarketPlace\\flutter\\bin\\flutter.bat analyze
cmd.exe /c D:\\Work\\SoftwaresLab\\MarketPlace\\flutter\\bin\\flutter.bat test
```

The Linux `flutter` shell script may fail in this workspace because of line endings. Prefer the Windows `.bat` command from WSL as shown above.

## Firestore Index Notes

Likely indexes:

- `clients`: `status ASC`, `displayNameLower ASC`
- `clientPayments`: `clientId ASC`, `receivedAt DESC`
- `clientPayments`: `receivedAt DESC`
- `clientCharges`: `clientId ASC`, `status ASC`, `dueDate ASC`
- `clientCharges`: `status ASC`, `dueDate ASC`
- `paymentAllocations`: `paymentId ASC`
- `paymentAllocations`: `chargeId ASC`
- `statements`: `clientId ASC`, `issuedAt DESC`

Update `firebase/firestore.indexes.json` when Firestore asks for indexes.

## Review Checklist

Before finalizing a client-account implementation patch:

- Search for forbidden vertical-specific vocabulary.
- Confirm no secrets were added.
- Confirm route names are domain-neutral.
- Confirm UI copy is domain-neutral.
- Confirm desktop layout is not stretched edge-to-edge.
- Confirm mobile layout has no overflow.
- Confirm existing ledger screens still work.
- Confirm Firestore and SQLite implementations are aligned.
- Confirm invalidations update all relevant screens.
- Confirm analyze/test pass.

## Current Product Plan

The dense product and technical blueprint is in:

```text
docs/client-accounts-application-plan.md
```

Read that file before implementing the client account module.

