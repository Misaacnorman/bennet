# Bennet Visual Aesthetic Refresh Plan

## Purpose

This document is written for an LLM implementation agent. The goal is to make Bennet substantially more beautiful, visually polished, and pleasant to use without changing product behavior, financial logic, persistence, routes, providers, or validation rules.

The app is currently functional but visually too monochromatic. Most surfaces use low-contrast green-tinted containers, cards feel empty, the sidebar does not provide enough brand presence, and repeated tables/lists do not have a strong visual system. The refresh should create a consistent premium finance-dashboard aesthetic across the whole app.

Do not treat this as a redesign of workflows. Treat it as a system-wide visual design upgrade.

## Non-Negotiables

- Do not break existing functionality.
- Do not change financial calculations.
- Do not change repository APIs unless absolutely necessary for visual state.
- Do not rename domain concepts.
- Do not introduce vertical-specific terminology. Keep the app general: clients, charges, payments, receipts, statements, accounts, balances.
- Do not remove existing screens, routes, providers, or tests.
- Do not add decorative UI that makes the app harder to scan.
- Do not use giant marketing-style hero sections. This is an operational finance app.
- Do not use purple-heavy, beige-heavy, brown-heavy, or monochrome green-only palettes.
- Do not use decorative blobs, gradient orbs, or bokeh backgrounds.
- Do not place cards inside cards.
- Keep UI responsive across mobile, tablet, desktop, and web.
- Run `flutter analyze` and `flutter test` before finishing if feasible.

## Current App Structure

Important shared files:

- `lib/presentation/theme/app_theme.dart`
- `lib/presentation/widgets/app_scaffold.dart`
- `lib/presentation/widgets/page_header.dart`
- `lib/presentation/widgets/metric_tile.dart`
- `lib/presentation/widgets/status_pill.dart`
- `lib/presentation/widgets/search_and_filters_bar.dart`
- `lib/presentation/widgets/empty_state.dart`
- `lib/presentation/widgets/auth_shell.dart`
- `lib/presentation/widgets/responsive_data_surface.dart`
- `lib/presentation/layout/responsive_content.dart`

Important screen groups:

- `lib/presentation/screens/overview_screen.dart`
- `lib/presentation/screens/clients/`
- `lib/presentation/screens/payments/`
- `lib/presentation/screens/charges/`
- `lib/presentation/screens/statements/`
- `lib/presentation/screens/transaction_list_screen.dart`
- `lib/presentation/screens/transaction_edit_screen.dart`
- `lib/presentation/screens/monthly_summary_screen.dart`
- `lib/presentation/screens/cash_book_screen.dart`
- `lib/presentation/screens/reconciliation_screen.dart`
- `lib/presentation/screens/balance_sheet_screen.dart`
- `lib/presentation/screens/tax_export_screen.dart`
- `lib/presentation/screens/settings_screen.dart`
- `lib/presentation/screens/login_screen.dart`
- `lib/presentation/screens/signup_screen.dart`

Existing app shell:

- `BennetScaffold` provides `Scaffold`, `AppBar`, responsive sidebar, content width cap, and optional FAB.
- `ResponsiveContent` caps page width using `ContentWidthMode`.
- `Breakpoints` are `compact = 600`, `medium = 840`, `expanded = 960`.
- Current `MaterialApp` uses:
  - `theme: bennetTheme(Brightness.light)`
  - `darkTheme: bennetTheme(Brightness.dark)`
  - `themeMode: ThemeMode.system`

## Visual Direction

Design Bennet as a polished small-business finance workspace:

- Calm, elegant, organized, and highly readable.
- Slightly warm page background, not cold gray and not pale green everywhere.
- Deep emerald brand color as the navigation and primary action anchor.
- Controlled secondary accents:
  - Amber/gold for open charges, due items, and attention.
  - Coral/red-orange for overdue, reversal, void, or destructive state.
  - Teal/blue-green for payments, credits, and positive movement.
  - Slate/blue-gray for neutral ledger/report surfaces.
- Subtle depth through borders, shadows, tonal layering, and typography.
- Compact density appropriate for repeated daily use.
- Strong hierarchy: page, section, surface, row, status, action.

The app should feel more like a premium financial control room than a generic Flutter demo.

## Target Palette

Implement tokens in `app_theme.dart` first. Exact values can be adjusted after screenshot review, but start with this direction.

Light mode:

```dart
const brandEmerald = Color(0xFF0F6B57);
const brandEmeraldDeep = Color(0xFF073B32);
const mint = Color(0xFFBFEBDD);
const mintSoft = Color(0xFFEAF8F2);
const pageWarm = Color(0xFFF8FAF6);
const surface = Color(0xFFFFFFFF);
const surfaceWarm = Color(0xFFFBFCF8);
const line = Color(0xFFDCE5DE);
const slate = Color(0xFF34443F);
const textStrong = Color(0xFF17211D);
const amber = Color(0xFFE29A19);
const amberSoft = Color(0xFFFFF4D8);
const coral = Color(0xFFE4572E);
const coralSoft = Color(0xFFFFE7DF);
const teal = Color(0xFF159A88);
const tealSoft = Color(0xFFE1F6F1);
const blue = Color(0xFF2E77D0);
const blueSoft = Color(0xFFE6F0FF);
```

Dark mode:

```dart
const darkPage = Color(0xFF081311);
const darkSurface = Color(0xFF101C19);
const darkSurfaceRaised = Color(0xFF162622);
const darkLine = Color(0xFF29413A);
const darkText = Color(0xFFEAF3EE);
const darkMuted = Color(0xFFB3C7BF);
const darkEmerald = Color(0xFF72D7BD);
const darkAmber = Color(0xFFFFCA63);
const darkCoral = Color(0xFFFF8A68);
const darkBlue = Color(0xFF8DBBFF);
```

Avoid allowing `ColorScheme.fromSeed` to wash every surface into the same green family. It can still be used for Material compatibility, but override the important surfaces, outlines, and component themes explicitly.

## Theme Implementation Requirements

File: `lib/presentation/theme/app_theme.dart`

Refactor `bennetTheme(Brightness brightness)` into a token-driven implementation:

1. Define private design token classes or local constants:
   - colors
   - radii
   - shadows
   - spacing if useful
2. Build light and dark `ColorScheme`s explicitly.
3. Configure `ThemeData` with Material 3 enabled.
4. Add or improve these theme sections:
   - `scaffoldBackgroundColor`
   - `appBarTheme`
   - `cardTheme`
   - `navigationBarTheme`
   - `drawerTheme`
   - `filledButtonTheme`
   - `outlinedButtonTheme`
   - `textButtonTheme`
   - `floatingActionButtonTheme`
   - `inputDecorationTheme`
   - `chipTheme`
   - `dataTableTheme`
   - `listTileTheme`
   - `dividerTheme`
   - `snackBarTheme`
   - `tooltipTheme`
   - `progressIndicatorTheme`
5. Use `VisualDensity.standard`.
6. Keep typography readable and restrained. Do not scale type with viewport width.

Recommended typography treatment:

- Page titles: `headlineSmall`, weight 800, tight but not negative letter spacing.
- Section titles: `titleMedium`, weight 800.
- Values: `headlineSmall` or `titleLarge`, weight 800.
- Table headers: `labelLarge`, weight 800.
- Body: default Material text sizes are acceptable.

Recommended radius system:

- Small controls and pills: 8.
- Buttons: 10.
- Cards and surfaces: 14 or 16.
- Large auth card: 20.

Note: Existing developer guidance says cards should generally be 8px or less unless the design system requires otherwise. For this refresh, if increasing card radius, make it explicit in the design system and keep it consistent. Do not mix random radii.

Recommended elevation/depth:

- Avoid high Material elevation.
- Prefer subtle shadows plus borders:
  - cards: light shadow alpha and outline border
  - sidebar: no heavy shadow, use color contrast
  - popover/FAB: slightly stronger shadow

## Add Shared Visual Tokens

Create a new file if useful:

- `lib/presentation/theme/app_design_tokens.dart`

Suggested content:

- `abstract final class AppRadii`
- `abstract final class AppSpacing`
- `abstract final class AppShadows`
- `abstract final class AppSemanticColors`

Only create this file if it simplifies implementation. If the changes stay small, keep constants in `app_theme.dart`. Do not over-abstract.

## Add Shared Surface Components

Create a new shared widgets file:

- `lib/presentation/widgets/bennet_surface.dart`

This should centralize visual wrappers used by tables, list groups, forms, and sections.

Recommended widgets:

### `BennetSurface`

Purpose: a polished generic surface for content blocks.

Parameters:

- `Widget child`
- `EdgeInsetsGeometry padding`
- `Color? accent`
- `bool clip`
- `VoidCallback? onTap`
- `double? minHeight`

Visual:

- background uses `colorScheme.surface`
- border uses `outlineVariant` with alpha
- radius from design system
- subtle shadow
- optional top or left accent line when `accent` is provided

### `BennetSection`

Purpose: consistent section layout without nested cards.

Parameters:

- `String title`
- `String? subtitle`
- `List<Widget>? actions`
- `Widget child`

Visual:

- unframed heading
- framed child only if appropriate
- consistent spacing

### `BennetDataSurface`

Purpose: wrapper around `DataTable` or horizontally scrolling table.

Parameters:

- `Widget child`

Visual:

- clipped rounded border
- tinted table heading
- subtle row dividers
- no heavy card look

Implementation note:

- Existing screens currently wrap `DataTable` in `Card`. Replace those wrappers gradually with `BennetDataSurface`.

## App Shell Refresh

File: `lib/presentation/widgets/app_scaffold.dart`

### Sidebar

The sidebar should become the main brand element.

Current problem:

- It is pale, flat, and blends into the page.
- Selected state is a light mint rectangle with little depth.

Target:

- Expanded sidebar uses deep emerald or dark ink-green background in both light and dark modes.
- Add a subtle vertical gradient if easy:
  - top: brandEmeraldDeep
  - bottom: brandEmerald
- Brand header:
  - Add a small square/rounded monogram mark containing `B` or a wallet/account icon.
  - Text `Bennet` should be strong and high contrast.
  - Optional small subtitle: `Accounts` or no subtitle. Keep domain-neutral.
- Nav items:
  - Inactive icons/text use light mint/white alpha on dark sidebar.
  - Selected item uses a light pill background.
  - Selected text/icon use deep emerald.
  - Add a small selected indicator if the pill is not enough.
- Keep the collapse notch functional.
- The collapse notch should visually match the new shell, with clear hover/tap affordance.

Do not change:

- `BennetNav.destinations`
- route paths
- selected route logic
- sidebar collapse behavior

### AppBar

Current problem:

- AppBar duplicates the page title and contributes to the plain look.

Target:

- Keep AppBar for mobile/navigation consistency.
- Make desktop AppBar visually quiet:
  - transparent or page-background color
  - no heavy shadow
  - title smaller than page header
  - optional bottom border using `outlineVariant`
- Keep `actions` support.

### Main Body Background

Use a layered page background:

- Light mode: warm off-white.
- Dark mode: deep ink.
- Avoid page-wide gradients unless extremely subtle.

Implementation approach:

- Use `Scaffold.backgroundColor` from theme.
- If a subtle background accent is desired, add a `DecoratedBox` around `wrappedBody` in `BennetScaffold`.
- Do not add decorative blobs.

## Page Header Refresh

File: `lib/presentation/widgets/page_header.dart`

Current problem:

- Header is functional but plain.

Target:

- Stronger hierarchy without becoming a hero.
- Title should be weight 800.
- Subtitle should use muted color.
- Actions should align right on desktop and wrap cleanly on mobile.
- Add optional small accent rule or tinted eyebrow band only if it works across pages.

Implementation details:

- Preserve existing constructor API.
- Add better spacing:
  - desktop: title/actions row with `SizedBox(height: 20)` after header in screens where needed.
  - mobile: actions wrap below title.
- Do not require screen changes beyond existing use.

## MetricTile Refresh

File: `lib/presentation/widgets/metric_tile.dart`

Current problem:

- Cards are large, pale, and empty.
- Icon and value do not create enough visual hierarchy.

Target:

- Make KPI cards look like premium dashboard widgets.
- Keep current API:
  - `title`
  - `value`
  - `icon`
  - `accent`
- Add optional parameters only if useful, but do not require updating all call sites.

Visual:

- White/warm surface in light mode, raised dark surface in dark mode.
- Rounded border with subtle shadow.
- Icon appears inside a colored badge.
- A faint accent wash or top stripe uses `accent`.
- Value is large, strong, and aligned well.
- Title is clear and muted.
- Card should not look empty even when grid cells are large.

Recommended layout:

```text
[icon badge]  Title

$5,400,000.00

optional faint bottom accent / no text
```

Responsive:

- Maintain stable height.
- Text must not overflow on mobile.
- Use `FittedBox` or responsive constraints for long money values if needed.

## Overview Screen Refresh

File: `lib/presentation/screens/overview_screen.dart`

Current problem:

- The overview grid creates huge empty pale cards.
- Quick action chips feel disconnected.
- Activity sections below are basic cards/lists.

Target:

- Make overview the best-looking screen.
- Keep all metrics and navigation actions.
- Improve density and hierarchy.

Suggested changes:

1. Keep `PageHeader`.
2. Convert the quick actions from plain `ActionChip`s into a compact quick-action rail:
   - Use `Wrap`.
   - Use improved `ActionChip` theme or a small custom `QuickActionChip`.
   - Each action has an icon and label.
3. Use improved `MetricTile`.
4. Adjust grid:
   - On expanded desktop, use 3 columns.
   - On medium, use 2.
   - On mobile, use 1.
   - Use a lower `childAspectRatio` if needed so cards have balanced height.
5. Improve recent activity:
   - Add section headers with small actions.
   - Wrap recent payments and open charges in `BennetSurface`.
   - Use ListTiles with leading colored icon/avatar badges.
   - Keep `AmountText`.
6. Fix any mojibake separators like `Â·` if present. Use plain ASCII `-` or a proper middle dot only if the file already uses UTF-8 cleanly. Prefer ASCII: ` - `.

## StatusPill Refresh

File: `lib/presentation/widgets/status_pill.dart`

Current problem:

- Pills are simple translucent rectangles and do not feel designed.

Target:

- Compact, expressive, and consistent.

Keep constructor API:

- `label`
- `color`

Visual:

- background: `color.withValues(alpha: 0.12)` light, slightly stronger in dark
- border: same color alpha
- radius: 999 or 8
- optional leading dot:
  - 6px circle using `color`
  - then text
- text weight 700

Must handle:

- active
- paused
- archived
- posted
- void
- reversed
- open
- overdue

Do not require callers to pass status enums. Keep the generic color API.

## SearchAndFiltersBar Refresh

File: `lib/presentation/widgets/search_and_filters_bar.dart`

Current problem:

- Search field is default and visually flat.

Target:

- Search and filters should feel like a toolbar.

Visual:

- Use filled input style from theme.
- Prefix icon should use muted color.
- Search field background should be surface, not page background.
- Filter chips should align and have clear selected states.
- On desktop, keep one-row layout.
- On mobile, stack field and horizontal chips.

Do not change behavior:

- controller
- hintText
- onChanged
- filterChips

## EmptyState Refresh

File: `lib/presentation/widgets/empty_state.dart`

Current problem:

- Empty states are plain and gray.

Target:

- Empty states should feel intentional and reassuring.

Visual:

- Centered constrained content.
- Icon inside a soft colored badge.
- Optional subtle surface background if used in a blank area.
- Strong title.
- Muted subtitle.
- Action below with spacing.

Do not make it cartoonish. Keep it business-grade.

## Auth Screens Refresh

Files:

- `lib/presentation/widgets/auth_shell.dart`
- `lib/presentation/screens/login_screen.dart`
- `lib/presentation/screens/signup_screen.dart`

Current problem:

- Auth shell is centered and functional but visually generic.

Target:

- Make login/signup feel branded and polished.

Suggested changes:

- Use page background from refreshed theme.
- Add a compact brand mark above `Bennet`.
- Auth card uses warm/raised surface, border, and shadow.
- Inputs use filled style.
- Buttons use refreshed theme.
- Keep centered narrow form.
- Do not add a marketing hero.
- Do not add images unless explicitly requested later.

## Data Tables and List Screens

Files likely needing table/list wrapper updates:

- `lib/presentation/screens/clients/client_list_screen.dart`
- `lib/presentation/screens/payments/payment_list_screen.dart`
- `lib/presentation/screens/charges/charge_list_screen.dart`
- `lib/presentation/screens/statements/statement_builder_screen.dart`
- `lib/presentation/screens/transaction_list_screen.dart`
- `lib/presentation/screens/cash_book_screen.dart`
- `lib/presentation/screens/reconciliation_screen.dart`
- `lib/presentation/screens/balance_sheet_screen.dart`

Current problem:

- DataTables are wrapped in plain cards.
- Mobile cards are repetitive and flat.
- Row hierarchy is weak.

Target:

- Tables and mobile cards should share a refined visual language.

Implementation strategy:

1. Add `BennetDataSurface`.
2. Replace plain `Card(child: SingleChildScrollView(child: DataTable(...)))` wrappers with `BennetDataSurface`.
3. Use `DataTableThemeData` for global improvements:
   - heading row color
   - heading text style
   - data row color on hover/selected where available
   - divider thickness
   - horizontal margin
   - column spacing
4. Mobile cards:
   - Use `BennetSurface` where practical.
   - Add leading icon/status badges when already semantically clear.
   - Keep ListTile tap behavior.
   - Avoid adding information that requires new data queries.

Do not change:

- filtering logic
- sorting logic
- navigation on row tap
- data source/provider usage

## Form Screens

Files likely involved:

- `lib/presentation/screens/clients/client_edit_screen.dart`
- `lib/presentation/screens/payments/payment_edit_screen.dart`
- `lib/presentation/screens/charges/charge_edit_screen.dart`
- `lib/presentation/screens/transaction_edit_screen.dart`
- `lib/presentation/screens/settings_screen.dart`
- `lib/presentation/screens/statements/statement_builder_screen.dart`

Current problem:

- Forms are plain and utilitarian.

Target:

- Forms should look calmer and more premium while retaining speed.

Suggested changes:

- Use refreshed `InputDecorationTheme`.
- Group related fields with `BennetSurface` only when grouping helps.
- Use section labels for complex forms.
- Keep desktop max widths from `ContentWidthMode.form` and `ContentWidthMode.narrow`.
- Primary save/post/create action should be visually clear.
- Destructive/reversal actions should use coral/error styling.

Do not:

- Change validation logic.
- Change save logic.
- Change field names or model mapping.

## Semantic Color Guidance

Use these meanings consistently:

- Primary emerald: main create/save actions, active nav, brand.
- Teal/blue-green: payments, credits, successful posted movement.
- Amber/gold: charges, due amounts, pending attention.
- Coral/red-orange: overdue, destructive, voided, reversed, failed.
- Slate: neutral reports, archived, secondary metadata.

Examples:

- `Total balance`: emerald or blue-green.
- `Open charges`: amber.
- `Overdue items`: coral.
- `Payments (30 days)`: teal.
- `Active clients`: blue or emerald.
- Client active: emerald.
- Client paused: amber.
- Client archived: slate.
- Payment posted: teal.
- Payment reversed/voided: coral.
- Charge open: amber.
- Charge paid: teal.
- Charge void: slate/coral depending current semantics.

## Implementation Phases

### Phase 1: Theme Foundation

Files:

- `lib/presentation/theme/app_theme.dart`
- optional `lib/presentation/theme/app_design_tokens.dart`

Tasks:

1. Define richer light and dark palettes.
2. Override Material component themes.
3. Improve inputs, chips, buttons, cards, tables, snackbars, tooltips.
4. Run `flutter analyze`.
5. Launch app and inspect overview in light and dark mode if feasible.

Acceptance:

- App no longer looks monochrome.
- Existing screens compile.
- Button, input, card, table, chip styles improve globally.

### Phase 2: Shell and Navigation

Files:

- `lib/presentation/widgets/app_scaffold.dart`

Tasks:

1. Refresh sidebar background.
2. Add brand mark/header.
3. Improve selected nav item styling.
4. Improve collapse notch.
5. Tune AppBar.
6. Verify desktop and narrow layouts.

Acceptance:

- Sidebar feels branded and premium.
- Collapse still works.
- Navigation still works.
- Mobile/compact behavior remains intact.

### Phase 3: Shared Widgets

Files:

- `lib/presentation/widgets/metric_tile.dart`
- `lib/presentation/widgets/status_pill.dart`
- `lib/presentation/widgets/search_and_filters_bar.dart`
- `lib/presentation/widgets/empty_state.dart`
- `lib/presentation/widgets/page_header.dart`
- `lib/presentation/widgets/auth_shell.dart`
- new `lib/presentation/widgets/bennet_surface.dart`

Tasks:

1. Add `BennetSurface`, `BennetSection`, `BennetDataSurface`.
2. Refresh `MetricTile`.
3. Refresh `StatusPill`.
4. Refresh `SearchAndFiltersBar`.
5. Refresh `EmptyState`.
6. Refresh `PageHeader`.
7. Refresh `AuthShell.card`.
8. Run `flutter analyze`.

Acceptance:

- Existing constructor APIs still work.
- No call sites are broken.
- Shared widgets establish a consistent design system.

### Phase 4: Overview Polish

Files:

- `lib/presentation/screens/overview_screen.dart`

Tasks:

1. Improve quick actions.
2. Tune KPI grid spacing/aspect ratio.
3. Apply refreshed metric tile colors intentionally.
4. Wrap recent payments/open charges with refined surfaces.
5. Add leading badges to activity rows if simple.
6. Fix any bad separator text.

Acceptance:

- Overview becomes the visual benchmark for the app.
- All existing actions still navigate correctly.
- Loading/error/data states still work.

### Phase 5: Lists and Tables

Files:

- Client, payment, charge, statement, transaction, cash book, reconciliation, balance sheet list/table screens.

Tasks:

1. Replace plain table cards with `BennetDataSurface`.
2. Replace repetitive mobile cards with `BennetSurface` where practical.
3. Keep all row taps and trailing actions.
4. Ensure horizontal table scroll still works.
5. Avoid touching business logic.

Acceptance:

- Tables feel consistent and polished.
- Mobile cards look intentional.
- No list filtering/search behavior changes.

### Phase 6: Forms and Detail Screens

Files:

- Client detail/edit.
- Payment detail/edit.
- Charge edit.
- Transaction edit.
- Statement builder/history.
- Settings.

Tasks:

1. Apply shared surfaces to detail sections.
2. Let global input theme improve forms first.
3. Add section grouping only where helpful.
4. Keep narrow/form content widths.
5. Style destructive/reversal actions consistently.

Acceptance:

- Forms are clearer and more pleasant.
- Validation and saving behavior unchanged.
- Detail screens have better hierarchy.

### Phase 7: Verification and Screenshot Review

Tasks:

1. Run:

```powershell
flutter analyze
flutter test
```

If local Flutter requires the known Windows path from existing docs, use:

```powershell
cmd.exe /c D:\Work\SoftwaresLab\MarketPlace\flutter\bin\flutter.bat analyze
cmd.exe /c D:\Work\SoftwaresLab\MarketPlace\flutter\bin\flutter.bat test
```

2. Start the app on web if feasible:

```powershell
flutter run -d chrome --web-port 8083
```

or use the existing script:

```powershell
.\scripts\dev-web.ps1
```

3. Inspect:
   - Overview
   - Clients list
   - Client detail
   - Payment list
   - Charge list
   - Statement builder
   - Transaction list
   - Settings
   - Login
4. Check both light and dark mode if possible.
5. Check mobile-width behavior using browser dev tools or a narrow window.

Acceptance:

- No text overflow.
- No incoherent overlap.
- No broken navigation.
- Tables remain horizontally scrollable where needed.
- FABs do not cover critical content.
- Contrast is readable in light and dark.

## Suggested Code Patterns

### Color extension helpers

If repeated alpha code becomes noisy, add small helper methods only if they stay local and obvious. Do not introduce a large theming framework.

### Surface wrapper pattern

Use this shape for shared surfaces:

```dart
class BennetSurface extends StatelessWidget {
  const BennetSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.24 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
```

Adapt as needed. Keep code formatted and concise.

### Avoid duplicated visual logic

If three screens need the same wrapper, make it shared. If only one screen needs a special layout, keep it local.

## Screen-Specific Notes

### `overview_screen.dart`

- Highest priority visual screen.
- Use intentional accent colors for metrics.
- Improve activity list presentation.
- Keep all actions and providers unchanged.

### `client_list_screen.dart`

- Preserve search/filter logic.
- Improve table/card surfaces.
- Active/paused/archived pills should be clearer.

### `client_detail_screen.dart`

- Likely has many sections. Improve with consistent section headers and surfaces.
- Keep payments, charges, statements, and ledger sections easy to scan.

### `payment_list_screen.dart`

- Payments should visually read as positive cash movement.
- Posted status should use teal.
- Reversed/void status should use coral/slate.

### `charge_list_screen.dart`

- Charges should use amber as the primary semantic accent.
- Overdue should use coral.
- Paid/closed should use teal.

### `statement_builder_screen.dart`

- Statement preview should feel like a document/workbench.
- Do not alter PDF generation logic.

### `transaction_list_screen.dart`, `cash_book_screen.dart`, `monthly_summary_screen.dart`

- These are ledger/reporting screens.
- Use slate/blue-gray neutral accents.
- Keep dense table readability.

### `settings_screen.dart`

- Keep narrow layout.
- Wrap settings fields in a simple polished surface.
- Sign out button should not visually compete with save.

### `login_screen.dart` and `signup_screen.dart`

- Refresh through `AuthShell`.
- Keep forms narrow and centered.
- Do not build a landing page.

## Accessibility and Usability Requirements

- Maintain sufficient contrast for all text.
- Selected nav item must be obvious without relying only on color.
- Status pills must remain readable in light and dark.
- Focus states should be visible.
- Hover states should be visible on desktop/web.
- Touch targets should remain at least approximately 40x40.
- Long money values should not overflow cards.
- Long client names should ellipsize where needed.
- Tables should not shrink columns until text overlaps.

## What Not To Do

- Do not rewrite the app into a new layout framework.
- Do not add animations everywhere.
- Do not add charts unless requested later.
- Do not add external UI packages for this refresh unless there is a strong reason.
- Do not change Riverpod providers for visual-only work.
- Do not add real-time data polling.
- Do not add images or illustrations unless the user asks.
- Do not create a landing page.
- Do not make the UI playful or cartoonish.
- Do not make the palette one-note green again.

## Final Implementation Checklist

Before reporting completion:

- `flutter analyze` passes or blockers are documented.
- `flutter test` passes or blockers are documented.
- Overview visually improved.
- Sidebar visually improved.
- Shared widgets updated.
- At least the main list/table surfaces use the new system.
- Auth screen still works.
- Light mode is polished.
- Dark mode is polished.
- Mobile width has no obvious overflow.
- Desktop width has no huge dead surfaces.
- No product/domain behavior changed.

