# Bennet Client Accounts Application Plan

## Purpose

Bennet should evolve from a simple ledger into a polished client-account operating system for small businesses that collect recurring or ad hoc payments from named clients. The product must stay domain-neutral in naming, UI copy, data model labels, tests, and documentation that ships with the app. It should feel like a beautiful, calm, trustworthy financial workspace: fast enough for daily use, clear enough for non-accountants, and structured enough to produce receipts, account statements, balance views, and exportable records without awkward manual work.

The core product idea is:

- A business keeps a book.
- The book has clients.
- Each client has an account timeline.
- The timeline contains charges, payments, credits, adjustments, notes, documents, and generated receipts.
- The app can show who owes money, who has credit, what was paid, what is overdue, what was issued, and what statement can be sent.
- Every client/payment action should remain tied to the general ledger so reports still work.

## Product Principles

1. Domain-neutral language only.
   Use "Client", "Account", "Charge", "Payment", "Receipt", "Statement", "Balance", "Schedule", "Reference", "Service", "Item", "Period", "Due date", "Outstanding", "Credit". Avoid vertical-specific words in code, UI, tests, routes, sample data, and generated documents.

2. The client account is the primary workflow.
   Ledger transactions still exist, but most daily work should happen from client screens: create client, issue charge, record payment, generate receipt, view statement, send/export.

3. Payments must be auditable.
   Every payment needs date, amount, method, account, optional reference, optional note, created timestamp, and a stable receipt number. Edits should preserve enough detail to explain what changed.

4. Receipts and statements are first-class documents.
   A receipt is not just a PDF button on a transaction. It is a generated document with a document number, issue date, business identity, client identity, payment allocation, totals, and regenerate/share support.

5. The UI must be beautiful and operational.
   The app should not look like a generic scaffold demo. It should have an intentional shell, strong information hierarchy, polished empty states, useful filters, tasteful color, and responsive desktop layouts.

6. Preserve accounting sanity.
   Client payments should create income-side ledger transactions unless marked as deposit/credit/other. Charges should be tracked separately from payments so statements can show amounts billed and amounts paid.

7. Keep implementation incremental.
   Build the client module without breaking existing ledger, cash book, tax export, and settings. Replace weak existing screens when the new client-account workflow makes them redundant.

## Current App Assessment

The current app already has useful foundations:

- Firebase Authentication.
- Firestore-backed repository.
- SQLite-backed repository for local mode.
- Ledger entities: books, categories, accounts, transactions.
- Cash book and monthly summary.
- Transaction receipt PDF generation.
- Tax export.
- Responsive content helper and navigation shell.

Current gaps:

- No client entity.
- Payments are plain transactions, not associated with a client.
- Receipts are transaction-centered, not client-centered.
- No statement document.
- No concept of charge, allocation, outstanding balance, credit, or due date.
- The UI reads like a utility ledger, not a polished client-accounts product.
- Existing balance sheet and reconciliation modules may not be the right first screen for this business workflow.
- Settings are too thin: business identity, document numbering, payment methods, statement preferences, and branding are missing.

Recommended product direction:

- Keep ledger and reports as the accounting backbone.
- Add client accounts as the main daily workflow.
- Reframe navigation around operational tasks.
- Improve the visual system before adding many screens.

## Target Navigation

Recommended primary navigation:

1. Overview
   A polished executive dashboard with receivables, collections, due items, recent payments, and quick actions.

2. Clients
   Client list, status, balance, last activity, quick payment, quick statement.

3. Payments
   Payment register across all clients, receipt status, methods, references, reversals.

4. Charges
   Create and track amounts to be collected. Includes recurring schedule support later.

5. Statements
   Statement builder/history across clients.

6. Ledger
   Existing transactions, cash book, monthly summary, and exports grouped under accounting.

7. Settings
   Business profile, document branding, numbering, payment methods, categories, data/export.

Possible route structure:

- `/` Overview
- `/clients` Client directory
- `/clients/new` New client
- `/clients/:id` Client profile
- `/clients/:id/edit` Edit client
- `/clients/:id/payment/new` Record payment for client
- `/clients/:id/charge/new` Create charge for client
- `/clients/:id/statement` Statement preview/generator
- `/payments` Payment register
- `/payments/new` Record payment
- `/payments/:id` Payment detail
- `/receipts/:id` Receipt detail/preview
- `/charges` Charge register
- `/statements` Statement history
- `/ledger/transactions`
- `/ledger/cashbook`
- `/ledger/monthly`
- `/ledger/tax-export`
- `/settings`

If the app needs a smaller first release, use:

- Overview
- Clients
- Payments
- Statements
- Ledger
- Settings

## Domain Model

### Client

Represents a person or organization with an account balance.

Fields:

- `id`: int/string stable identifier.
- `bookId`: book owner.
- `displayName`: required.
- `legalName`: optional.
- `clientCode`: short unique code, human-readable, e.g. `CL-0007`.
- `status`: active, paused, archived.
- `primaryPhone`: optional.
- `primaryEmail`: optional.
- `billingAddress`: optional structured address.
- `tags`: list of strings.
- `notes`: private note.
- `openingBalanceMinor`: optional initial account balance.
- `openingBalanceDate`: optional.
- `defaultCategoryId`: optional ledger category for payment transactions.
- `defaultAccountId`: optional payment account.
- `statementDelivery`: none, email, print, share.
- `createdAt`, `updatedAt`, `archivedAt`.

UI behavior:

- Client list should show name, code, balance, status, last payment date, and quick action buttons.
- Archived clients should be hidden by default.
- Client search should match name, code, phone, email, and tags.

### Client Charge

Represents an amount issued to a client. It increases the client balance.

Fields:

- `id`.
- `bookId`.
- `clientId`.
- `chargeNumber`: e.g. `CHG-2026-00013`.
- `description`: required.
- `periodStart`, `periodEnd`: optional.
- `issueDate`: required.
- `dueDate`: optional.
- `amountMinor`: required positive.
- `categoryId`: optional.
- `status`: draft, issued, partiallyPaid, paid, voided.
- `notes`: optional.
- `createdAt`, `updatedAt`, `voidedAt`.

Design notes:

- Keep charges separate from ledger transactions at first. A charge is an account receivable event; the payment is the cash movement.
- Later, if accrual accounting is needed, charges can optionally post ledger entries.
- For this business, the product can work cash-basis by default: payments create ledger income; charges drive statements and outstanding balances.

### Client Payment

Represents money received from a client. It reduces the client balance and creates a ledger transaction.

Fields:

- `id`.
- `bookId`.
- `clientId`.
- `paymentNumber`: e.g. `PAY-2026-00042`.
- `receiptNumber`: e.g. `RCT-2026-00042`.
- `ledgerTransactionId`: nullable until persisted.
- `receivedAt`.
- `amountMinor`: required positive.
- `method`: cash, bank, card, mobile, cheque, other.
- `accountId`: required ledger account.
- `categoryId`: required/derived income category.
- `reference`: optional.
- `memo`: optional.
- `status`: posted, reversed, draft.
- `allocatedMinor`: amount applied to charges.
- `unallocatedMinor`: credit remaining.
- `createdAt`, `updatedAt`, `reversedAt`.

Rules:

- Posted payment creates a ledger income transaction linked to client.
- Reversal should not delete history. Create a reversal record or mark reversed and create offset transaction depending on chosen accounting policy.
- Receipt number must remain stable once issued.

### Payment Allocation

Links payments to charges.

Fields:

- `id`.
- `bookId`.
- `clientId`.
- `paymentId`.
- `chargeId`.
- `amountMinor`.
- `createdAt`.

Rules:

- Allocate oldest open charges first by default.
- Allow manual allocation from payment detail.
- Unallocated payment amount becomes client credit.
- Client balance = opening balance + issued charges - posted payments + reversals/adjustments.

### Client Adjustment

Represents corrections that are neither charges nor payments.

Fields:

- `id`.
- `bookId`.
- `clientId`.
- `adjustmentNumber`.
- `kind`: increase, decrease.
- `amountMinor`.
- `reason`.
- `effectiveAt`.
- `createdAt`.

Examples:

- Write-off.
- Correction.
- Transfer.
- Opening balance change.

### Receipt

Receipts can be generated from payments.

Fields:

- `id`.
- `bookId`.
- `clientId`.
- `paymentId`.
- `receiptNumber`.
- `issuedAt`.
- `businessSnapshot`: business name, contact, logo URL, address at issue time.
- `clientSnapshot`: name, code, contact at issue time.
- `amountMinor`.
- `method`.
- `reference`.
- `pdfStoragePath`: optional if stored.
- `lastGeneratedAt`.

Rules:

- The receipt should preserve snapshots so old receipts do not change if names/settings change later.
- The app can regenerate on demand from stored receipt data.

### Statement

Statements are generated for a client over a date range.

Fields:

- `id`.
- `bookId`.
- `clientId`.
- `statementNumber`.
- `fromDate`, `toDate`.
- `issuedAt`.
- `openingBalanceMinor`.
- `totalChargesMinor`.
- `totalPaymentsMinor`.
- `totalAdjustmentsMinor`.
- `closingBalanceMinor`.
- `pdfStoragePath`: optional.
- `deliveryStatus`: draft, generated, shared.
- `createdAt`.

Statement line model:

- `date`.
- `type`: opening, charge, payment, adjustment.
- `documentNumber`.
- `description`.
- `debitMinor`.
- `creditMinor`.
- `balanceMinor`.

### Business Profile

Settings should expand beyond a single business name.

Fields:

- `businessName`.
- `displayName`.
- `phone`.
- `email`.
- `address`.
- `taxIdLabel`, `taxIdValue`.
- `logoStoragePath`.
- `accentColor`.
- `receiptFooter`.
- `statementFooter`.
- `defaultCurrency`.
- `dateFormat`.
- `receiptNumberPrefix`.
- `statementNumberPrefix`.
- `clientNumberPrefix`.
- `paymentNumberPrefix`.
- `chargeNumberPrefix`.

## Firestore Structure

Current structure: `users/{uid}/books/{bookId}/...`

Recommended new collections:

- `users/{uid}/books/{bookId}/clients/{clientId}`
- `users/{uid}/books/{bookId}/clientCharges/{chargeId}`
- `users/{uid}/books/{bookId}/clientPayments/{paymentId}`
- `users/{uid}/books/{bookId}/paymentAllocations/{allocationId}`
- `users/{uid}/books/{bookId}/clientAdjustments/{adjustmentId}`
- `users/{uid}/books/{bookId}/receipts/{receiptId}`
- `users/{uid}/books/{bookId}/statements/{statementId}`
- `users/{uid}/books/{bookId}/documentCounters/main`
- `users/{uid}/settings/app`

Counters:

- Store counters in `_meta/ids` or `documentCounters/main`.
- Current `_meta/ids` should be extended conservatively.
- Counter fields:
  - `nextClientId`
  - `nextClientCode`
  - `nextChargeId`
  - `nextChargeNumber`
  - `nextPaymentId`
  - `nextPaymentNumber`
  - `nextReceiptId`
  - `nextReceiptNumber`
  - `nextStatementId`
  - `nextStatementNumber`
  - `nextAdjustmentId`

Indexes:

- Clients by `status`, `displayNameLower`.
- Payments by `clientId`, `receivedAt`.
- Payments by `receivedAt`.
- Charges by `clientId`, `status`, `dueDate`.
- Charges by `dueDate`, `status`.
- Allocations by `paymentId`.
- Allocations by `chargeId`.
- Statements by `clientId`, `issuedAt`.

Security:

- All book data remains scoped under authenticated user.
- Validate authenticated UID matches path.
- Later support team/multi-user by introducing membership documents; do not overbuild in first release.

## SQLite Structure

Add tables:

```sql
CREATE TABLE clients (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  legal_name TEXT,
  client_code TEXT NOT NULL,
  status TEXT NOT NULL,
  primary_phone TEXT,
  primary_email TEXT,
  billing_address TEXT,
  tags_json TEXT NOT NULL DEFAULT '[]',
  notes TEXT,
  opening_balance_minor INTEGER NOT NULL DEFAULT 0,
  opening_balance_date INTEGER,
  default_category_id INTEGER REFERENCES categories(id),
  default_account_id INTEGER REFERENCES accounts(id),
  statement_delivery TEXT NOT NULL DEFAULT 'none',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  archived_at INTEGER,
  UNIQUE(book_id, client_code)
);
```

```sql
CREATE TABLE client_charges (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  charge_number TEXT NOT NULL,
  description TEXT NOT NULL,
  period_start INTEGER,
  period_end INTEGER,
  issue_date INTEGER NOT NULL,
  due_date INTEGER,
  amount_minor INTEGER NOT NULL,
  category_id INTEGER REFERENCES categories(id),
  status TEXT NOT NULL,
  notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  voided_at INTEGER,
  UNIQUE(book_id, charge_number)
);
```

```sql
CREATE TABLE client_payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  payment_number TEXT NOT NULL,
  receipt_number TEXT NOT NULL,
  ledger_transaction_id INTEGER REFERENCES transactions(id),
  received_at INTEGER NOT NULL,
  amount_minor INTEGER NOT NULL,
  method TEXT NOT NULL,
  account_id INTEGER NOT NULL REFERENCES accounts(id),
  category_id INTEGER NOT NULL REFERENCES categories(id),
  reference TEXT,
  memo TEXT,
  status TEXT NOT NULL,
  allocated_minor INTEGER NOT NULL DEFAULT 0,
  unallocated_minor INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  reversed_at INTEGER,
  UNIQUE(book_id, payment_number),
  UNIQUE(book_id, receipt_number)
);
```

```sql
CREATE TABLE payment_allocations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  payment_id INTEGER NOT NULL REFERENCES client_payments(id) ON DELETE CASCADE,
  charge_id INTEGER NOT NULL REFERENCES client_charges(id) ON DELETE CASCADE,
  amount_minor INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
```

```sql
CREATE TABLE client_adjustments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  adjustment_number TEXT NOT NULL,
  kind TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  reason TEXT NOT NULL,
  effective_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  UNIQUE(book_id, adjustment_number)
);
```

```sql
CREATE TABLE client_statements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  statement_number TEXT NOT NULL,
  from_date INTEGER NOT NULL,
  to_date INTEGER NOT NULL,
  issued_at INTEGER NOT NULL,
  opening_balance_minor INTEGER NOT NULL,
  total_charges_minor INTEGER NOT NULL,
  total_payments_minor INTEGER NOT NULL,
  total_adjustments_minor INTEGER NOT NULL,
  closing_balance_minor INTEGER NOT NULL,
  delivery_status TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  UNIQUE(book_id, statement_number)
);
```

Migration:

- Current SQLite `dbVersion` is 1.
- Move to version 2.
- Use `onUpgrade` to create new tables.
- Keep old transaction tables untouched.

## Repository API Expansion

Create a separate abstraction or extend `LedgerRepository`.

Preferred: split responsibilities.

- `LedgerRepository`: accounting backbone.
- `ClientAccountRepository`: client module.
- `DocumentRepository` or services for PDF generation.

Provider additions:

- `clientAccountRepositoryProvider`.
- `clientsProvider`.
- `clientProvider(clientId)`.
- `clientLedgerProvider(clientId)`.
- `clientBalanceProvider(clientId)`.
- `clientPaymentsProvider({clientId?, from?, to?})`.
- `clientChargesProvider({clientId?, status?, dueBefore?})`.
- `clientStatementPreviewProvider({clientId, from, to})`.
- `dashboardReceivablesProvider`.

Repository methods:

- `Future<List<Client>> listClients({ClientStatus? status, String? query})`
- `Future<Client?> getClient(int id)`
- `Future<int> createClient(CreateClientInput input)`
- `Future<void> updateClient(UpdateClientInput input)`
- `Future<void> archiveClient(int id)`
- `Future<ClientAccountSummary> clientSummary(int clientId)`
- `Future<List<ClientLedgerLine>> clientLedger(int clientId, {DateTime? from, DateTime? to})`
- `Future<int> createCharge(CreateChargeInput input)`
- `Future<void> voidCharge(int chargeId)`
- `Future<int> recordPayment(RecordPaymentInput input)`
- `Future<void> reversePayment(int paymentId, String reason)`
- `Future<List<PaymentAllocation>> allocatePayment(int paymentId, AllocationMode mode)`
- `Future<ReceiptDocument> receiptForPayment(int paymentId)`
- `Future<StatementPreview> buildStatementPreview(...)`
- `Future<int> saveStatement(...)`
- `Future<ClientDashboard> clientDashboard(int bookId)`

Inputs should be immutable classes in `domain/entities.dart` or a new `domain/client_accounts.dart`.

## Ledger Integration

Recording a client payment should:

1. Validate client exists and is active.
2. Validate amount > 0.
3. Resolve default account/category if not provided.
4. Allocate payment to open charges oldest-first.
5. Insert client payment.
6. Insert allocation records.
7. Insert ledger transaction:
   - type: income
   - amount: payment amount
   - occurredAt: receivedAt
   - accountId: selected account
   - categoryId: selected category
   - counterparty: client display name
   - paymentMethod: method
   - notes: reference/memo
   - clientId link once transaction schema supports it, or store in payment only.
8. Store `ledgerTransactionId` on the payment.
9. Generate or reserve receipt number.
10. Invalidate client, payments, transactions, monthly summary, cash book, dashboard.

If transaction schema is extended:

- Add optional `clientId`, `sourceType`, `sourceId`.
- This makes cross-module tracing possible.

## Screens And UX

### Overview

Goal: make the first screen immediately useful and beautiful.

Desktop layout:

- Top header: business name, period selector, primary action "Record payment".
- KPI row:
  - Total outstanding
  - Collected this month
  - Due soon
  - Clients with credit
- Two-column grid:
  - Left: "Needs attention" list.
  - Right: "Recent payments" list with receipt buttons.
- Bottom:
  - "Collection trend" compact chart if chart package is added.
  - "Quick actions" strip.

Mobile layout:

- KPI carousel or stacked cards.
- Recent actions first.
- FAB for record payment.

Visual:

- Calm off-white/dark adaptive background.
- One strong accent.
- Status colors sparingly.
- Cards with 8px radius.
- No huge empty whitespace.

### Clients

Client directory:

- Search field pinned at top.
- Filter chips: Active, Outstanding, Credit, Archived.
- Desktop table columns:
  - Client
  - Code
  - Balance
  - Last payment
  - Status
  - Actions
- Mobile cards:
  - Name/code
  - balance/status
  - last activity
  - quick payment icon.
- Empty state:
  - concise message
  - create client button.

Client profile:

- Header:
  - display name
  - code
  - balance pill
  - actions: record payment, add charge, statement, edit.
- Summary cards:
  - outstanding
  - last payment
  - unallocated credit
  - open charges.
- Tabs:
  - Timeline
  - Charges
  - Payments
  - Receipts
  - Statements
  - Notes
- Timeline:
  - grouped by month.
  - running balance.
  - document number links.

### Record Payment

Entry points:

- Global Payments > New.
- Client profile > Record payment.
- Quick action from client row.

Form:

- Client selector with search.
- Amount.
- Received date.
- Method.
- Account.
- Reference.
- Memo.
- Allocation panel:
  - Auto-apply to oldest open charges.
  - Manual allocation option.
  - Shows unallocated credit if overpaid.
- Submit button:
  - "Record payment"
  - Secondary "Record and issue receipt".

Success state:

- Receipt preview side panel/dialog.
- Actions: share PDF, download PDF, view client, record another.

### Charges

Charge register:

- Filters: Open, Paid, Overdue, Voided.
- Desktop table.
- Mobile list.
- Add charge dialog or full page.

Create charge:

- Client.
- Description.
- Amount.
- Issue date.
- Due date.
- Optional period.
- Optional category.

Future recurring charges:

- Schedule templates.
- Generate upcoming charges.
- Pause/resume schedule.

### Payments

Payment register:

- Search by client, receipt number, reference.
- Filters by date, method, status.
- Table columns:
  - Date
  - Receipt
  - Client
  - Method
  - Reference
  - Amount
  - Status
  - Actions

Payment detail:

- Payment summary.
- Allocations.
- Linked ledger transaction.
- Receipt preview.
- Reverse action, not delete.

### Receipts

Receipt PDF design:

- Header with business identity.
- Receipt number, issue date.
- Client block.
- Payment block.
- Allocation table:
  - charge number
  - description
  - amount applied
- Total received.
- Balance after payment.
- Footer.

Receipt screen:

- Preview metadata.
- Regenerate.
- Share/download.

### Statements

Statement builder:

- Client.
- Date range.
- Include paid lines toggle.
- Include notes toggle.
- Preview before generate.

Statement PDF:

- Business header.
- Client block.
- Statement number and date range.
- Opening balance.
- Line table with running balance.
- Totals.
- Closing balance.
- Payment instructions/footer.

Statement history:

- Client.
- Date range.
- Generated date.
- Closing balance.
- Shared status.

### Settings

Sections:

- Business profile.
- Document branding.
- Numbering.
- Payment methods.
- Categories.
- Data and security.

Business profile:

- Name.
- Contact.
- Address.
- Logo.
- Accent color.

Numbering:

- Prefixes.
- Next number preview.
- Reset/adjust carefully with confirmation.

Payment methods:

- Default list editable.
- Active/inactive.

## UI Redesign Direction

The app should move away from plain Material defaults and toward a refined financial console.

Style:

- Use Material 3 components, but customize color, spacing, typography, and surfaces.
- Use a neutral base with green/teal accent, but do not let the whole app become a single green palette.
- Use status colors:
  - Outstanding: amber
  - Paid/settled: green
  - Overdue/attention: red
  - Credit: blue
  - Draft: gray

Layout:

- Desktop:
  - Navigation rail.
  - Centered content width.
  - Tables for dense records.
  - Split panes for profile/detail screens.
  - Side panels/dialogs for quick entry.
- Tablet:
  - Rail or drawer depending width.
  - Two-column cards where useful.
- Mobile:
  - Drawer.
  - Cards/lists.
  - Sticky/FAB primary action.

Components to create:

- `BennetPageHeader`
- `MetricTile`
- `StatusPill`
- `AmountText`
- `EmptyState`
- `SearchAndFiltersBar`
- `ResponsiveDataSurface`
- `ClientAvatar`
- `DocumentActionBar`
- `TimelineList`
- `InlineReceiptPreview`
- `SideSheet` for desktop quick forms

Spacing:

- 16px page padding mobile.
- 24px page padding desktop.
- 8px cards radius.
- 12px field gaps.
- 16px section gaps.
- 24px major gaps.

Typography:

- Page title: 24-28.
- Section title: 16-18.
- Table/list body: 14.
- Amounts: tabular figures if available, medium/bold.

No visible instructional paragraphs unless they help a real workflow. Empty states may explain briefly.

## Code Organization

Recommended structure:

```text
lib/
  domain/
    entities.dart
    client_accounts.dart
    ledger_repository.dart
    client_account_repository.dart
  data/
    firebase/
      firestore_ledger_repository.dart
      firestore_client_account_repository.dart
    database/
      sqlite_db.dart
      sqlite_init.dart
    ledger_repository_impl.dart
    client_account_repository_impl.dart
  application/
    providers.dart
    client_account_providers.dart
  presentation/
    layout/
      responsive_content.dart
    theme/
      app_theme.dart
    widgets/
      app_scaffold.dart
      amount_text.dart
      empty_state.dart
      metric_tile.dart
      status_pill.dart
      page_header.dart
    screens/
      overview_screen.dart
      clients/
        client_list_screen.dart
        client_detail_screen.dart
        client_edit_screen.dart
      payments/
        payment_list_screen.dart
        payment_edit_screen.dart
        payment_detail_screen.dart
      charges/
        charge_list_screen.dart
        charge_edit_screen.dart
      statements/
        statement_builder_screen.dart
        statement_history_screen.dart
      ledger/
        transaction_list_screen.dart
        cash_book_screen.dart
        monthly_summary_screen.dart
        tax_export_screen.dart
  services/
    receipt_pdf_service.dart
    statement_pdf_service.dart
```

Refactor rule:

- If a screen exceeds roughly 350 lines, split widgets.
- Do not mix Firestore parsing, business rules, and UI in the same file.
- Keep calculations testable in pure Dart.

## What To Keep, Improve, Or Replace

Keep:

- Authentication.
- Firestore/SQLite repository pattern.
- Money parsing/formatting helpers.
- Monthly summary logic.
- Cash book, but make it one accounting sub-screen.
- Tax export.

Improve:

- App shell visual design.
- Settings.
- Receipt PDF service.
- Provider organization.
- Firestore indexes.
- Test coverage.

Replace or demote:

- Current Dashboard should become Overview.
- Balance Sheet can move under Ledger or be simplified until it is truly useful.
- Reconciliation can stay under Ledger, but should not be primary navigation for this business workflow.
- Transaction entry should become a lower-level accounting tool; client payment entry should be the primary path.

## Implementation Phases

### Phase 0: Safety and Foundation

- Ensure Firebase admin keys are ignored and not committed.
- Add docs and agent instructions.
- Confirm current tests pass.
- Create `client_accounts.dart` domain file.
- Add money/date helper tests.
- Add repository interfaces without UI.

Exit criteria:

- App still builds.
- Existing ledger workflows unchanged.

### Phase 1: Data Model And Repository

- Add client entities.
- Add Firestore collections and serializers.
- Add SQLite tables and migrations.
- Add providers.
- Implement:
  - create/list/update/archive client.
  - create charge.
  - record payment.
  - client balance.
  - client ledger lines.
  - receipt model.

Exit criteria:

- Unit tests for balance math.
- Repository tests where possible.
- Existing transaction list includes client-created payments as income.

### Phase 2: New UI Shell

- Redesign theme.
- Add shared components.
- Update navigation.
- Build Overview.
- Build Client List.
- Build Client Detail.

Exit criteria:

- Desktop and mobile layouts verified.
- Empty states polished.
- No domain-specific forbidden language.

### Phase 3: Payment Workflow

- Build global record payment.
- Build client-specific record payment.
- Auto-allocation.
- Payment register.
- Payment detail.
- Receipt generation from client payment.

Exit criteria:

- A user can create a client, create charge, record payment, and generate receipt.
- Payment appears in ledger/cash book/monthly summary.

### Phase 4: Statements

- Statement preview.
- Statement PDF generation.
- Save statement history.
- Share/download.

Exit criteria:

- A user can generate a statement for any date range.
- Opening/running/closing balances match client ledger math.

### Phase 5: Polish And Advanced Features

- Better search and filters.
- Dashboard charts.
- Import/export clients.
- Recurring charge templates.
- Bulk statement generation.
- Payment reminders if later desired.
- Document logo/branding.

## Testing Strategy

Pure unit tests:

- Client balance.
- Payment allocation.
- Statement line running balance.
- Receipt numbering.
- Reversal behavior.
- Date-range filtering.

Widget tests:

- Client list empty and populated.
- Record payment validation.
- Client profile tabs.
- Statement preview totals.

Integration/manual checks:

- Create client.
- Add charge.
- Record payment less than charge.
- Record payment equal to charge.
- Record payment greater than charge.
- Generate receipt.
- Generate statement.
- Confirm ledger transaction appears.
- Confirm exports do not break.

Responsive checks:

- 390px mobile.
- 768px tablet.
- 1366px desktop.
- 1920px desktop.

Accessibility:

- All icon-only buttons need tooltips.
- Amounts must not rely on color alone.
- Text contrast must pass on light/dark themes.
- Tables must remain scrollable, not overflow.

## Document Numbering

Use human-readable numbers:

- Clients: `CL-0001`
- Charges: `CHG-2026-0001`
- Payments: `PAY-2026-0001`
- Receipts: `RCT-2026-0001`
- Statements: `STM-2026-0001`

Rules:

- Numbers are assigned at creation/posting.
- Receipt number is assigned when payment is posted.
- Statement number is assigned when statement is generated/saved.
- Never reuse numbers after deletion/reversal.
- Allow prefix customization in settings later, but keep stable defaults.

## Data Integrity Rules

- Amounts are stored as integer minor units.
- No floating point for money.
- Posted records are not physically deleted from normal UI.
- Void/reverse instead of delete for financial records.
- Client archive allowed only if no active workflow is pending, or archive leaves records visible in history.
- Payment cannot allocate more than open charge balance.
- Payment cannot be posted without client, account, category, date, method, and amount.
- Statement generation uses immutable snapshots where practical.

## UI Copy Direction

Use:

- Client
- Account
- Balance
- Outstanding
- Credit
- Charge
- Payment
- Receipt
- Statement
- Due
- Paid
- Open
- Archived
- Record payment
- Add charge
- Generate statement
- Issue receipt

Avoid:

- Vertical-specific labels.
- Accounting jargon on primary client screens.
- Long explanatory text.
- Huge full-width buttons on desktop.

## Recommended Beautiful UI Concept

Name the visual direction internally: "Quiet Ledger".

Light theme:

- Background: warm neutral near white.
- Surface: white or slight tint.
- Primary: deep green.
- Accent: muted blue for credit/links.
- Warning: amber.
- Error: restrained red.
- Borders: low-contrast gray.

Dark theme:

- Background: near black green/neutral.
- Surface: elevated dark neutral.
- Primary: mint/green.
- Text: high contrast but not stark.

Screen composition:

- Keep page headers compact.
- Use cards only for repeated items, metrics, and framed forms.
- Avoid nested cards.
- Use tables on desktop.
- Use cards/lists on mobile.
- Use side sheets for quick entry on desktop, full pages/dialogs on mobile.

## Risks

- Scope creep: client accounts plus statements plus UI redesign is a large feature. Use phases.
- Existing repository is broad; adding too much to `LedgerRepository` will make it unwieldy. Prefer module repository.
- Firestore indexes may fail at runtime if not added.
- Receipt/statement PDFs need careful layout to avoid overflow.
- Domain-neutral wording must be enforced in reviews.
- Reversal/edit policy must be decided before heavy real-world use.

## Definition Of Done For First Real Release

- User can create clients.
- User can create charges.
- User can record client payments.
- Payment creates ledger transaction.
- User can issue receipt PDF.
- User can generate client statement PDF.
- Overview shows meaningful client/account metrics.
- Client profile shows balance and timeline.
- Existing cash book/monthly/tax export still work.
- Responsive UI looks polished on mobile, tablet, desktop.
- No forbidden vertical-specific wording in UI/code/tests.
- `flutter analyze` passes.
- `flutter test` passes.

