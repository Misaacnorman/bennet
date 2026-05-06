# Bennet Full Product Utility Implementation Plan

## Purpose

This document is written for an LLM implementation agent. Its goal is to guide Bennet from a strong MVP foundation into a complete, reliable, beautiful, production-ready client-account and payment application.

Bennet should become a polished small-business financial workspace for tracking clients, charges, payments, receipts, statements, account balances, cash movement, and exportable records. The product must stay domain-neutral. Do not introduce vertical-specific language into routes, UI copy, code, tests, sample data, PDFs, comments, or documentation.

This plan covers:

- Functional completeness.
- Data integrity.
- Ledger/client-account integration.
- Receipt and statement document workflows.
- Settings and business profile.
- Reporting and exports.
- Desktop, tablet, and mobile UX.
- Visual quality and responsive appearance.
- Tests and release readiness.

## Current State Summary

The app already has a meaningful base:

- Flutter app with Riverpod and GoRouter.
- Firebase Auth.
- Cloud Firestore backend.
- SQLite/local backend behind `USE_SQLITE`.
- Ledger module:
  - books
  - accounts
  - categories
  - transactions
  - monthly summary
  - cash book
  - reconciliation
  - balance sheet
  - tax export
- Client-account module:
  - clients
  - charges
  - payments
  - payment allocations
  - adjustments
  - receipts
  - statements
  - overview metrics
- PDF generation:
  - transaction receipt
  - client payment receipt
  - statement
- Refreshed visual system:
  - richer theme
  - sidebar
  - surface widgets
  - improved cards/lists/tables

Important existing files:

- `lib/router.dart`
- `lib/application/providers.dart`
- `lib/application/client_account_providers.dart`
- `lib/domain/client_accounts.dart`
- `lib/domain/client_account_repository.dart`
- `lib/domain/entities.dart`
- `lib/domain/ledger_repository.dart`
- `lib/data/client_account_repository_impl.dart`
- `lib/data/firebase/firestore_client_account_repository.dart`
- `lib/data/ledger_repository_impl.dart`
- `lib/data/firebase/firestore_ledger_repository.dart`
- `lib/data/database/sqlite_db.dart`
- `lib/presentation/theme/app_theme.dart`
- `lib/presentation/theme/app_design_tokens.dart`
- `lib/presentation/widgets/app_scaffold.dart`
- `lib/presentation/widgets/bennet_surface.dart`
- `lib/presentation/screens/overview_screen.dart`
- `lib/presentation/screens/clients/`
- `lib/presentation/screens/payments/`
- `lib/presentation/screens/charges/`
- `lib/presentation/screens/statements/`
- `lib/services/receipt_pdf_service.dart`
- `lib/services/statement_pdf_service.dart`

## Non-Negotiables

- Do not break existing ledger workflows.
- Do not break existing client-account workflows.
- Do not use floating point for money.
- Store money as integer minor units.
- Do not physically delete posted financial records from normal UI. Reverse or void instead.
- Do not silently mutate historical receipts or statements.
- Do not commit secrets.
- Do not remove Firebase or SQLite support unless explicitly instructed.
- Do not change route names casually.
- Do not introduce vertical-specific vocabulary.
- Do not add excessive decorative UI that makes operational workflows slower.
- Keep desktop dense and scan-friendly.
- Keep tablet adaptive and uncluttered.
- Keep mobile thumb-friendly, readable, and overflow-free.
- Run `flutter analyze` and `flutter test` after implementation phases when feasible.

## Product Definition

Bennet is a domain-neutral client-account operating system.

A user should be able to:

1. Configure business profile and document preferences.
2. Create and manage clients.
3. Issue charges to clients.
4. Record payments from clients.
5. Allocate payments to open charges.
6. Leave overpayments as client credit.
7. Reverse payments safely.
8. Void charges safely.
9. Add client account adjustments.
10. Generate and share receipts.
11. Generate, save, view, regenerate, and share statements.
12. See who owes money, who has credit, who is overdue, and what was collected.
13. See payment-created ledger income in accounting reports.
14. Export tax/category reports.
15. Use the app comfortably on desktop, tablet, and mobile.

## Target Information Architecture

Primary navigation should support the daily workflow first, with accounting tools still available.

Recommended navigation order:

1. Overview
2. Clients
3. Payments
4. Charges
5. Statements
6. Transactions
7. Monthly summary
8. Cash book
9. Reconciliation
10. Balance sheet
11. Tax export
12. Settings

Future grouping option:

- Keep current direct nav items for now.
- Later, group accounting tools under a `Ledger` or `Accounting` section if the shell supports nav groups.

Do not group routes until the app has a clear UI pattern for grouped navigation.

## Route Completeness

Current route set is close, but full utility needs additional routes.

Keep existing:

```text
/
/clients
/clients/new
/clients/:id
/clients/:id/edit
/clients/:id/payment/new
/clients/:id/charge/new
/clients/:id/statement
/payments
/payments/new
/payments/:id
/charges
/charges/new
/statements
/transactions
/transactions/new
/transactions/:id
/monthly
/cashbook
/reconciliation
/balance-sheet
/reports
/settings
```

Add when implementing document workflows:

```text
/statements/:id
/receipts/:paymentId
```

Optional later:

```text
/clients/:id/adjustment/new
/settings/business
/settings/documents
/settings/numbering
/settings/payment-methods
/settings/categories
/settings/data
```

If adding new routes:

- Update `lib/router.dart`.
- Update navigation only when the route deserves primary navigation.
- Add deep-link-safe parsing with graceful handling of invalid ids.
- Never allow a bad path id to crash the whole app with `int.parse` if the route can be reached externally. Prefer `int.tryParse` and a not-found screen.

## Critical Data Integrity Fixes

These are the highest priority. Do them before feature expansion.

### 1. Reversed Payment Allocations Must Not Reduce Open Charges

Current risk:

- Client balance excludes reversed payments.
- Open charge calculations may still include allocations from reversed payments.
- This can make a reversed payment restore balance but leave charge open amounts wrong.

Required behavior:

- Only allocations from posted payments should reduce charge open amount.
- Reversed payments should not contribute to allocation totals.
- Receipt snapshots should still show original allocations, marked reversed.

Implementation:

SQLite:

- Update allocation aggregation methods to join `payment_allocations` to `client_payments`.
- Filter `client_payments.status = 'posted'`.
- Apply this everywhere open charge amount or outstanding amount is calculated:
  - `_allocationsByCharge`
  - `listClientSummaries`
  - `listChargesWithOpenAmount`
  - `overviewMetrics`

Firestore:

- Firestore cannot do arbitrary joins.
- Options:
  1. Fetch allocations and posted payments, then filter allocations in memory by posted `paymentId`.
  2. Denormalize `paymentStatus` onto allocation docs and update on reversal.
  3. Store allocation docs under payment docs and load through payment state.

Recommended for current code:

- Fetch posted payments for selected clients.
- Build a `Set<int> postedPaymentIds`.
- Sum only allocations where `paymentId` is in that set.
- Do this in summary/open charge code paths.

Tests:

- Add SQLite test:
  - create charge 100
  - record payment 100 allocated to charge
  - open amount is 0
  - reverse payment
  - balance is 100
  - open amount is 100
- Add pure or repository-level test for partial reversal equivalent.

### 2. Repository-Level Allocation Validation

Current risk:

- UI validates allocations, but repository methods must enforce data integrity.
- Firestore has no foreign keys.
- SQLite can still store mismatched `client_id` in `payment_allocations`.

Required behavior:

When `recordPayment` receives allocation inputs:

- Every referenced charge must exist.
- Every referenced charge must belong to the payment client.
- Voided charges cannot receive allocations.
- Allocation amount per line must be positive.
- Combined allocation per charge must not exceed current open amount.
- Total allocations must not exceed payment amount.

Implementation:

- Add shared private validation helper in both repositories.
- Given `clientId`, `paymentAmountMinor`, and `allocations`, load relevant charges and posted allocation totals.
- Collapse duplicate allocation lines by `chargeId` before validation.
- Return normalized allocation list or map.
- Insert normalized allocations to avoid duplicate charge rows if desired.

Tests:

- Reject allocation to another client’s charge.
- Reject allocation to missing charge.
- Reject allocation to voided charge.
- Reject allocation above open amount.
- Allow partial allocation.
- Allow overpayment with unallocated credit.

### 3. Firestore Client Code Uniqueness

Current risk:

- SQLite enforces `UNIQUE(book_id, client_code)`.
- Firestore does not.

Required behavior:

- `clientCode` must be unique per book.
- Checks must be transaction-safe enough for normal use.

Recommended implementation:

- Add reservation docs:

```text
users/{uid}/books/{bookId}/clientCodeIndex/{normalizedCode}
```

Where normalized code is:

- trim
- uppercase or lowercase consistently
- restricted to safe document id characters, or encoded

On create:

- In a Firestore transaction:
  - check index doc does not exist
  - allocate client id
  - create client doc
  - create index doc `{ clientId }`

On update client code:

- In a Firestore transaction:
  - check new code index absent or owned by same client
  - update client
  - delete old index doc
  - create new index doc

SQLite:

- Keep existing unique constraint.
- Catch database unique failures and surface a friendly app-level error.

UI:

- Client form should show friendly message: `Client code already exists.`

Tests:

- SQLite duplicate create.
- Firestore duplicate create if Firestore tests/emulator are available.
- At minimum, isolate normalization helper and test it.

### 4. Decide Stored vs Derived Charge Status

Current issue:

- `ChargeStatus.paid` exists.
- Charges are created as open and can be voided.
- Paid status is not consistently set.
- Open amount is computed dynamically from allocations.

Recommended approach:

- Treat paid/open as derived from open amount, not stored, for first production release.
- Keep stored status only for voided/non-voided:
  - If status is `voided`, excluded.
  - Else charge is effectively:
    - open if open amount > 0
    - paid if open amount == 0

Implementation options:

Option A: minimal:

- Keep enum as-is.
- Stop relying on stored `ChargeStatus.paid`.
- Fix UI to derive display status from open amount where open amount is available.
- Remove or disable global Paid filter until list has open amount.

Option B: stronger:

- Add repository method for charge register rows:

```dart
Future<List<ChargeRegisterRow>> listChargeRegister();
```

Where row contains:

- charge
- client
- openMinor
- derivedStatus: open, paid, overdue, voided

Recommended:

- Implement `ChargeRegisterRow` or a record type provider first.
- Let Charges screen use rows with open amount.

Required immediate bug fix:

- In `charge_list_screen.dart`, fix Paid filter assignment:

```dart
setState(() => _statusFilter = ChargeStatus.paid)
```

But this is not enough unless paid statuses exist or are derived.

Tests:

- Fully allocated charge appears paid.
- Reversed payment makes charge open again.
- Voided charge appears voided and not paid/open.

## Ledger Integration Completion

### Current Integration

Client payment creates an income ledger transaction and stores `ledgerTransactionId` on the payment.

### Missing Integration

Ledger transaction does not store:

- `clientId`
- `sourceType`
- `sourceId`
- `sourceNumber`

This limits traceability from transaction/cash book back to the client payment and receipt.

### Target Behavior

When a client payment is posted:

- Ledger transaction is created.
- Ledger transaction is linked to source:
  - `sourceType = clientPayment`
  - `sourceId = paymentId`
  - `clientId = payment.clientId`
  - `sourceNumber = receiptNumber` or payment number

When a payment is reversed:

- Create an offset ledger transaction.
- Link it to source:
  - `sourceType = clientPaymentReversal`
  - `sourceId = paymentId`
  - `clientId = payment.clientId`

Ledger/cash book screens should show:

- counterparty/client
- source badge
- link to payment detail when source exists

### Schema Changes

SQLite:

- Bump `dbVersion`.
- Add nullable columns to `transactions`:

```sql
client_id INTEGER REFERENCES clients(id),
source_type TEXT,
source_id INTEGER,
source_number TEXT
```

Firestore:

- Add same fields to transaction documents.

Domain:

- Extend `LedgerTransaction` with nullable fields.
- Extend `LedgerRepository.insertTransaction` and `updateTransaction`.
- Keep backward compatibility by making new args optional.

Tests:

- Payment-created transaction has source fields.
- Reversal transaction has source fields.
- Transaction list still works with old rows missing source fields.

## Client Management Completion

### Existing

- Create client.
- Edit client.
- Archive status exists.
- Client list hides archived by default.

### Missing/Incomplete

- No explicit archive/unarchive action in client detail.
- No client code auto-generation.
- No duplicate-code friendly validation.
- No email format validation.
- No default account/category controls in UI.
- No last activity/last payment in list.
- No quick payment from list row.

### Target Client List

Desktop table columns:

- Client
- Code
- Balance
- Outstanding
- Last activity
- Status
- Actions

Actions:

- Record payment
- Add charge
- Statement
- More menu

Tablet:

- Table can remain if width allows.
- Otherwise use two-column cards.

Mobile:

- Card list.
- Each card shows:
  - client name
  - code
  - status pill
  - balance
  - outstanding/open charges
  - compact action row or overflow menu

Filters:

- Active
- Outstanding
- Credit
- Paused
- Archived

Search:

- name
- code
- email
- phone
- notes

### Client Detail

Desktop:

- Header with client name, code, status, balance.
- Primary actions:
  - Record payment
  - Add charge
  - Statement
  - Edit
- Summary metrics:
  - balance
  - outstanding charges
  - open charge count
  - overdue count
  - credit/unallocated amount if applicable
- Tabs:
  - Timeline
  - Charges
  - Payments
  - Statements
  - Adjustments/Notes

Tablet:

- Same content, single-column with sticky-ish action area if practical.

Mobile:

- Header compact.
- Primary action FAB or bottom action bar.
- Tabs scrollable.
- Avoid multi-FAB stacks that obscure content.

### Client Code Generation

Add optional code generation:

- If user leaves code blank, generate next code.
- Default format: `CL-0001`.
- Store next client code counter.
- Let settings customize prefix later.

Implementation:

- Keep manual code entry supported.
- Add repository method or internal create logic.
- Do not break existing required-code tests unless intentionally updated.

## Charge Workflow Completion

### Existing

- Create charge for selected client.
- List charges.
- Void charge from client detail.

### Missing

- Charge detail route/screen.
- Derived open/paid/overdue status.
- Charge number.
- Edit draft/open charge policy.
- Register should show open amount, not only original amount.
- Global charge creation is two-step and acceptable, but can be improved.

### Target Charge Model

For full utility, add:

- `chargeNumber`
- optional `periodStart`
- optional `periodEnd`
- `createdAt`
- `updatedAt`
- `voidedAt`

Do this carefully with migrations and backward compatibility.

### Target Charge Register

Desktop table:

- Issued date
- Due date
- Charge number
- Client
- Description
- Original amount
- Open amount
- Derived status
- Actions

Mobile cards:

- Description and client
- Due date
- amount/open amount
- status pill
- tap to detail

Filters:

- Open
- Paid
- Overdue
- Voided
- Date range

### Charge Detail

Route:

```text
/charges/:id
```

Content:

- charge metadata
- original amount
- open amount
- allocations/payment list
- void action if open/non-voided
- client link

## Payment Workflow Completion

### Existing

- Global and client-specific record payment.
- Manual allocation.
- Fill oldest first.
- Payment register.
- Payment detail.
- Reverse payment.
- Share receipt PDF.

### Missing/Incomplete

- Payment number separate from receipt number.
- Payment detail does not show allocations.
- Payment detail does not show linked ledger transaction.
- Payment detail does not show unallocated amount.
- No receipt preview/detail route.
- No success state after posting besides navigating to payment detail.
- No search by amount/date range.
- No payment method display formatting.

### Target Payment Form

Desktop:

- Use two-column form if width allows:
  - left: client, amount, date, method, account/category
  - right: allocation panel
- Allocation panel should show:
  - total payment
  - allocated
  - unallocated credit
  - open charges oldest-first
  - fill oldest first button
  - clear allocations button
- Submit button fixed at bottom of form area or clearly at end.

Tablet:

- Form sections stacked but allocation panel remains prominent.

Mobile:

- Single column.
- Allocation panel collapsible if many charges.
- Button full width at bottom of content.
- Avoid fields narrower than usable touch width.

### Payment Detail

Add sections:

- Payment summary:
  - amount
  - status
  - date
  - method
  - reference
  - notes
- Client:
  - name
  - code
  - link
- Receipt:
  - receipt number
  - share/download/regenerate
- Allocations:
  - charge number/id
  - description
  - amount applied
- Ledger:
  - linked transaction id
  - account
  - category
  - cash book link if applicable
- Reversal:
  - reversal reason
  - reversal date if added
  - offset transaction id if added

### Receipt Detail

Route:

```text
/receipts/:paymentId
```

Features:

- Show receipt metadata.
- Show whether payment was reversed.
- Share PDF.
- Download/save PDF where platform supports.
- Link to payment and client.

Receipt document snapshot must include:

- business snapshot
- client snapshot
- payment amount
- method
- reference
- allocation snapshot
- generated/issued timestamp
- payment reversed flag

Future:

- Persist generated PDF path/storage path.

## Statement Workflow Completion

### Existing

- Statement preview by date range.
- Save and share PDF.
- Statement history list.

### Missing

- Statement detail screen.
- Regenerate/share from saved statement.
- Statement line snapshot.
- Business/client snapshot.
- Statement totals fields.
- Delivery status.
- Statement filters/search.

### Target Statement Model

Add or plan fields:

- `businessNameSnapshot`
- `clientDisplayNameSnapshot`
- `clientCodeSnapshot`
- `totalChargesMinor`
- `totalPaymentsMinor`
- `totalAdjustmentsMinor`
- `linesJson` or separate statement lines collection/table
- `deliveryStatus`
- `sharedAt`
- `pdfStoragePath` optional

For first completion pass:

- Store enough snapshot data to regenerate the same statement later.
- If storing every line is too large, store `linesJson` in SQLite and Firestore initially.

### Statement Detail Route

Route:

```text
/statements/:id
```

Content:

- statement number
- client snapshot
- period
- issued date
- opening/closing balance
- totals
- line table/card list
- share/download PDF
- link to client

Statement history:

- Row tap goes to `/statements/:id`, not just client detail.
- Add filters:
  - client
  - date range
  - statement number

### Statement Builder UX

Desktop:

- Date range controls in a compact toolbar.
- Preview table in `BennetDataSurface`.
- Summary totals above table.
- Save/share action in header.

Tablet:

- Date controls in two columns.
- Preview table or cards depending width.

Mobile:

- Date controls stacked.
- Preview cards.
- Save/share button visible without crowding app bar.

## Settings Completion

Current settings are too thin. Expand in phases.

### Settings Structure

Use sections:

1. Business profile
2. Document appearance
3. Numbering
4. Payment defaults
5. Categories and accounts
6. Data and exports
7. Security/session

### Business Profile

Fields:

- business name
- display name
- phone
- email
- address
- tax id label
- tax id value
- default currency display

Storage:

- Use settings repository keys initially.
- Consider typed settings model:

```dart
class BusinessProfileSettings { ... }
class DocumentSettings { ... }
class NumberingSettings { ... }
```

PDFs:

- Receipts/statements should use business profile snapshots.

### Document Appearance

Fields:

- accent color
- receipt footer
- statement footer
- optional logo later

Do not implement logo upload unless storage story is clear.

### Numbering

Fields:

- client prefix
- charge prefix
- payment prefix
- receipt prefix
- statement prefix
- next number preview

Rules:

- Changing prefix affects future documents only.
- Never reuse existing numbers.
- Require confirmation for changing next number below current max.

### Payment Defaults

Fields:

- default deposit account
- default income category
- preferred payment method

Use these in Payment form:

- client default overrides global default
- global default overrides first account/category

### Data and Exports

Add:

- export clients CSV
- export payments CSV
- export charges CSV
- export statements CSV metadata
- backup/export local SQLite later if needed

## Reporting and Overview Completion

### Overview Target

Overview should answer:

- How much is owed?
- How much was collected recently?
- What is overdue?
- Which clients need attention?
- What happened recently?
- What should I do next?

### Metrics

Add/derive:

- total balance
- outstanding open charges
- overdue open amount
- overdue item count
- posted payments last 30 days
- posted payments this month
- active clients
- clients with credit
- clients with overdue charges

### Needs Attention

Add section:

- overdue charges
- clients with high outstanding balance
- recent reversed payments
- unallocated credits needing review

### Recent Activity

Show:

- recent payments
- recent charges
- recent statements

Desktop:

- KPI grid top.
- Two-column content:
  - needs attention
  - recent activity

Tablet:

- KPI grid 2 columns.
- Sections stacked.

Mobile:

- KPI cards stacked or horizontally scrollable.
- Primary action near top.
- Recent/attention sections stacked.

## Search, Filtering, and Sorting

Implement consistent list behaviors:

### Clients

Search:

- name
- code
- email
- phone
- notes

Filters:

- active
- paused
- archived
- outstanding
- credit

Sorting:

- name
- balance
- last activity

### Payments

Search:

- client
- receipt/payment number
- reference
- method
- notes

Filters:

- posted
- reversed
- date range
- method

Sorting:

- newest
- oldest
- amount high/low

### Charges

Search:

- client
- charge number
- description

Filters:

- open
- paid
- overdue
- voided
- due date range

Sorting:

- due date
- issue date
- amount
- client

### Statements

Search:

- client
- statement number

Filters:

- date range
- client

Sorting:

- issued date
- period
- closing balance

## Responsive Appearance Requirements

This section is mandatory for every implementation phase.

### Desktop: 1200px and Wider

Goals:

- Dense but elegant.
- Use tables for registers.
- Use side-by-side layouts where they improve scanning.
- Avoid huge empty cards.
- Keep content width capped appropriately.

Layout rules:

- Overview can use `ContentWidthMode.wide`.
- List/register screens should use `ContentWidthMode.wide`.
- Form screens should use `ContentWidthMode.form`.
- Settings should use `ContentWidthMode.standard` with section cards, or `narrow` for single forms.
- Client detail can use `wide` and split header/metrics/tabs.

Visual rules:

- Sidebar expanded by default.
- Sidebar selected item obvious.
- App bar quiet.
- Table headers tinted.
- Row hover states visible.
- Numeric columns right-aligned.
- Actions compact, usually icon buttons with tooltips.

### Tablet: 600px to 1199px

Goals:

- Preserve productivity without crowding.
- Use 2-column cards where helpful.
- Use tables only if they remain readable.

Layout rules:

- Sidebar may collapse depending breakpoint.
- Use drawer/compact sidebar if width is tight.
- KPI grids usually 2 columns.
- Forms can stay one column or two columns depending width.
- Register screens switch to card/list if tables become cramped.

Visual rules:

- No text overlap.
- Buttons wrap cleanly.
- Horizontal filters scroll if needed.
- FAB should not cover important trailing content.

### Mobile: Below 600px

Goals:

- Thumb-friendly.
- No horizontal overflow except intentional table scroll.
- Primary action obvious.
- Lists scan quickly.

Layout rules:

- Sidebar collapsed/drawer.
- Use card/list views instead of tables.
- Page padding 16.
- Buttons can be full width in forms.
- Use one primary action per screen.
- Avoid multi-FAB stacks where possible.
- Tabs should be scrollable or reduced to labels that fit.

Visual rules:

- Minimum touch target near 40x40.
- Long names ellipsize.
- Money values scale down or wrap safely.
- Status pills should not force overflow.
- Trailing widgets in `ListTile` must not exceed available width.

### Cross-Platform PDF/Share UX

- `share_plus` works differently by platform.
- On web, sharing/downloading may need alternate behavior.
- If a platform cannot share, show a clear message or provide file save/download where supported.

## Visual Design Requirements

Keep the refreshed aesthetic and extend it consistently.

### Overall Style

- Premium finance workspace.
- Warm neutral background.
- Deep emerald brand anchor.
- Amber for charges/due/attention.
- Teal for payments/credits/positive movement.
- Coral for overdue/reversal/destructive states.
- Slate/blue-gray for neutral accounting/reporting.

### Components

Use shared components before local styling:

- `BennetSurface`
- `BennetDataSurface`
- `BennetSection`
- `MetricTile`
- `StatusPill`
- `SearchAndFiltersBar`
- `EmptyState`
- `PageHeader`
- `AmountText`

Add new components as needed:

- `ClientAvatar`
- `DocumentNumberChip`
- `MoneySummaryBar`
- `RegisterToolbar`
- `InlineActionMenu`
- `ResponsiveActionBar`
- `TimelineEventTile`

### Do Not Do

- Do not make a landing page.
- Do not use decorative blobs or abstract background ornaments.
- Do not make oversized hero sections.
- Do not use cards inside cards.
- Do not make the UI one-note green.
- Do not use tiny low-contrast text.
- Do not let app bar and page header compete visually.

## Firestore Completion

### Structure

Current structure is under:

```text
users/{uid}/books/{bookId}/...
```

Keep this structure.

Add/confirm collections:

```text
clients
clientCodeIndex
clientCharges
clientPayments
paymentAllocations
clientAdjustments
receipts
statements
_meta/clientAccounts
```

### Indexes

Update `firebase/firestore.indexes.json` as queries become stricter.

Likely needed:

- `clientCharges`: `clientId ASC`, `status ASC`
- `clientCharges`: `clientId ASC`, `dueDate ASC`
- `clientCharges`: `status ASC`, `dueDate ASC`
- `clientPayments`: `clientId ASC`, `status ASC`
- `clientPayments`: `clientId ASC`, `receivedAt DESC`
- `clientPayments`: `status ASC`, `receivedAt DESC`
- `paymentAllocations`: `paymentId ASC`
- `paymentAllocations`: `chargeId ASC`
- `paymentAllocations`: `clientId ASC`
- `statements`: `clientId ASC`, `issuedAt DESC`

### Rules

Current rules allow read/write under user id. That is acceptable for single-user MVP but broad.

Future tightening:

- Validate required fields.
- Validate amount fields are integers.
- Validate status enum values.
- Validate user owns path.

Do not overbuild rules before data model stabilizes, but do not ignore them before production.

## SQLite Completion

### Migration Discipline

Every schema change must:

- Bump `dbVersion`.
- Add idempotent migration function.
- Update `onUpgrade`.
- Update fresh schema creator.
- Update `sqlite_schema_test.dart`.
- Preserve old data.

### Needed Schema Evolutions

Likely version 6:

- transaction source link columns
- charge number
- payment number
- statement snapshot fields
- statement lines JSON or table
- business settings fields if stored relationally

Prefer adding nullable columns first, then UI support.

## Testing Plan

### Unit Tests

Add tests for:

- reversed payment restores open charge amount
- allocation cannot target another client charge
- allocation cannot exceed charge open amount
- allocation cannot target voided charge
- duplicate client code rejection
- generated client codes
- statement opening/closing across date boundaries
- statement snapshot stability
- receipt snapshot stability
- charge derived status
- ledger source link fields

### Repository Tests

SQLite:

- Cover all core workflows end-to-end.
- Use in-memory database.
- Verify ledger integration.
- Verify migrations where practical.

Firestore:

- If emulator is available, add integration tests.
- If not, isolate Firestore serialization helpers and transaction logic where possible.

### Widget Tests

Add tests for:

- client form validation
- payment form validation
- allocation panel behavior
- charge filters
- payment filters
- statement builder date validation
- sidebar responsive behavior
- mobile layout smoke for key screens

### Golden/Screenshot Tests

If the project accepts golden tests later:

- Overview desktop light
- Overview mobile light
- Client detail desktop
- Payment form mobile
- Statement builder tablet
- Dark mode overview

Do not block core functionality on golden tests initially.

### Manual QA Checklist

Run through:

1. Create client.
2. Duplicate code attempt.
3. Add charge.
4. Record partial payment allocated to charge.
5. Confirm charge open amount.
6. Record overpayment.
7. Confirm credit/unallocated amount.
8. Generate receipt.
9. Reverse payment.
10. Confirm balance and charge open amount recover correctly.
11. Generate statement.
12. Save statement.
13. Open statement history.
14. Regenerate/share statement.
15. Confirm payment appears in transactions, cash book, monthly summary, tax export.
16. Test mobile width.
17. Test tablet width.
18. Test desktop width.
19. Test dark mode.

## Implementation Phases

### Phase 1: Integrity Fixes

Files:

- `lib/data/client_account_repository_impl.dart`
- `lib/data/firebase/firestore_client_account_repository.dart`
- `lib/core/payment_allocation_math.dart`
- `test/client_account_repository_impl_test.dart`

Tasks:

1. Filter allocation totals to posted payments only.
2. Add repository-level allocation validation.
3. Normalize duplicate allocation lines.
4. Add tests for reversal/open amount.
5. Add tests for invalid allocations.
6. Fix paid filter assignment bug.

Exit criteria:

- `flutter analyze` passes.
- `flutter test` passes.
- Reversing an allocated payment makes the charge open again.

### Phase 2: Charge Register and Derived Status

Files:

- `lib/domain/client_accounts.dart`
- `lib/domain/client_account_repository.dart`
- repository implementations
- `lib/application/client_account_providers.dart`
- `lib/presentation/screens/charges/charge_list_screen.dart`
- optional `lib/presentation/screens/charges/charge_detail_screen.dart`

Tasks:

1. Add charge register row model/record.
2. Include client display and open amount.
3. Derive status from status + open amount + due date.
4. Update charge list filters.
5. Add charge detail route if scoped.
6. Add tests.

Exit criteria:

- Open/Paid/Overdue/Voided filters work correctly.
- Paid charges appear without needing stored paid status.

### Phase 3: Client Workflow Completion

Files:

- client repository methods
- `client_list_screen.dart`
- `client_detail_screen.dart`
- `client_edit_screen.dart`

Tasks:

1. Add friendly duplicate-code handling.
2. Add Firestore uniqueness.
3. Add archive/unarchive UI.
4. Add default account/category fields.
5. Add last activity/last payment summary.
6. Add quick actions in list rows/cards.
7. Improve mobile client detail action layout.

Exit criteria:

- Client management feels complete.
- Archived clients are manageable.
- Client list is useful for daily operations.

### Phase 4: Payment and Receipt Completion

Files:

- payment screens
- receipt service
- repositories
- router

Tasks:

1. Add payment detail allocation section.
2. Add ledger link section.
3. Add unallocated credit display.
4. Add receipt detail route.
5. Add receipt regenerate/share from route.
6. Improve payment form defaults.
7. Add payment method display labels.
8. Add tests.

Exit criteria:

- Payment detail is audit-ready.
- Receipt is first-class.
- Ledger linkage is visible.

### Phase 5: Statement Completion

Files:

- statement screens
- statement service
- repositories
- router

Tasks:

1. Add statement snapshot fields.
2. Add statement detail route.
3. Add regenerate/share from history/detail.
4. Add statement history search/filter.
5. Add statement totals.
6. Add tests for snapshot stability.

Exit criteria:

- Saved statements can be opened and reshared.
- Historical statements do not unexpectedly change after client/business edits.

### Phase 6: Ledger Traceability

Files:

- `entities.dart`
- `ledger_repository.dart`
- SQLite ledger repo
- Firestore ledger repo
- transaction/cashbook screens
- migrations/tests

Tasks:

1. Add source link fields to transactions.
2. Populate on client payment and reversal.
3. Show source badges in transaction/cash book screens.
4. Link source badge to payment detail.
5. Ensure manual transactions still work.

Exit criteria:

- Payment-created ledger entries are traceable back to payment/client.

### Phase 7: Settings and Business Profile

Files:

- settings screen
- providers
- repositories/settings handling
- PDF services

Tasks:

1. Add business profile section.
2. Add document footer settings.
3. Add payment defaults.
4. Add numbering settings.
5. Use settings in receipts/statements.
6. Add tests for settings serialization if typed.

Exit criteria:

- PDFs can carry complete business identity.
- Payment form uses defaults.
- Settings feel like a real product area.

### Phase 8: Responsive UX and Visual QA

Files:

- shared widgets
- app shell
- all primary screens

Tasks:

1. Inspect overview, clients, payments, charges, statements, settings on desktop/tablet/mobile.
2. Fix text overflow.
3. Fix action wrapping.
4. Fix FAB overlap.
5. Tune tables/cards.
6. Inspect dark mode.
7. Add widget tests for key responsive behavior.

Exit criteria:

- App is polished at:
  - 390px mobile
  - 768px tablet
  - 1366px desktop
  - 1920px desktop
- Light and dark modes are readable and visually balanced.

### Phase 9: Export and Operational Readiness

Files:

- tax export
- new export services if needed
- README
- docs

Tasks:

1. Add client/payment/charge CSV exports.
2. Confirm tax export includes payment-created ledger transactions.
3. Improve README.
4. Document Firebase setup.
5. Document SQLite local mode.
6. Document test commands.
7. Document deployment.

Exit criteria:

- A new developer or operator can run and deploy the app from docs.

## README Completion Requirements

Replace default Flutter README with:

- Product summary.
- Feature list.
- Prerequisites.
- Setup.
- Firebase setup.
- SQLite local mode.
- Running app.
- Running tests.
- Deployment.
- Data model overview.
- Known limitations.

## Definition of Done for Full Product Utility

Functional:

- Create, edit, archive, unarchive clients.
- Create, void, and inspect charges.
- Record, allocate, inspect, reverse payments.
- Generate, view, regenerate, and share receipts.
- Generate, save, view, regenerate, and share statements.
- Ledger transactions link back to client payments.
- Reports include payment-created ledger activity.
- Settings support business profile and document defaults.

Data:

- No invalid cross-client allocations.
- Reversed payments do not reduce open charge amounts.
- Duplicate client codes prevented in SQLite and Firestore.
- Statement/receipt snapshots are stable.
- SQLite migrations preserve existing data.
- Firestore structure and indexes match queries.

Appearance:

- Desktop is dense, elegant, and table-friendly.
- Tablet adapts without cramped controls.
- Mobile is thumb-friendly and overflow-free.
- Light mode is polished.
- Dark mode is polished.
- Shared visual system is consistent.

Testing:

- `flutter analyze` passes.
- `flutter test` passes.
- Core workflows have repository tests.
- Critical forms have widget tests.
- Manual QA checklist completed.

Documentation:

- README is useful.
- Firebase setup documented.
- Local SQLite mode documented.
- Product limitations documented.

