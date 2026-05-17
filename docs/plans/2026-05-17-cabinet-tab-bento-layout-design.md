# Cabinet Tab Bento Layout Design

**Goal:** refine the native Cabinet tab into a compact FOCUS/Lumina bento grid without changing app architecture, backend contracts, or zencab routes.

## Current problem

`NativeCabinetHome` is already native Flutter and uses Lumina/CommonCard primitives, but the hierarchy is still the previous vertical version: a large tariff hero, then a wide balance/top-up card and a referral card. This no longer matches the requested Cabinet tab shape:

> первая карточка 2к1 содержит в себе инфо о тарифе слева внизу карточка 1к1 баланс справа 1к1 устройства и четыре нижних квадрата это рефералы и меню

The current balance/referral row also competes with the tariff card instead of reading as a clear bento layout with one dominant tariff card and quiet lower actions.

## Design goals

- Keep `NativeCabinetHome` as the only target screen for this refinement.
- Preserve the three-tab Cabinet / Main / Settings app model.
- Keep zencab auth, payment, support, and fallback pages delegated to `CabinetWebView` routes.
- Use existing Lumina/CommonCard language: compact spacing, glass surfaces, subtle borders, no gradients, no glow, no decorative icon containers.
- Make tariff the only dominant element. Lower menu squares are intentionally equal.
- Treat navigation as quiet infrastructure. Content stays primary.
- Avoid backend expansion in the first pass.

## Selected layout

Recommended approach: strict two-column bento grid, mobile first, max width around `560`.

1. Row 1, `2×1`: tariff card spans both columns.
   - Left-heavy composition.
   - Tariff name and subtle status near the top.
   - Expiry/status label as subdued copy, dot, or small pill.
   - Tariff cost and primary connect/import action inside the same card.
2. Row 2: two `1×1` square cards.
   - Left: `Баланс`.
   - Right: `Устройства`.
3. Rows 3 and 4: four equal square menu cards.
   - `Рефералы`
   - `Продлить`
   - `Поддержка`
   - `Открыть кабинет`

Use a consistent square unit derived from available two-column width. Preserve bottom navigation safe area with extra bottom padding so the last row is not hidden behind the tab bar or gesture area.

## Alternatives considered

### Approach A, strict two-column bento grid, selected

Matches the latest user wording exactly: tariff is `2×1`, balance and devices are separate `1×1`, then four lower squares for referrals and menu. It gives one clear dominant card while keeping all secondary actions quiet and predictable.

### Approach B, keep balance inside tariff and only add menu below, rejected

This follows an older hierarchy note, but it conflicts with the latest request for `Баланс` as its own lower-left `1×1` card. It would also leave the Cabinet tab feeling closer to the current vertical layout than a bento grid.

### Approach C, list-style menu below tariff, rejected

A list is efficient, but it loses the requested square bento feel and makes the lower navigation feel like settings chrome rather than a native FOCUS cabinet surface.

## Component responsibilities

- `NativeCabinetHome`
  - Owns the screen layout only.
  - Listens to `cabinetHomeAdapter.snapshot`.
  - Centers content in a max-width container around `560`.
  - Builds the bento grid and preserves bottom nav safe area.
- Tariff card
  - Shows tariff name, status/expiry text, tariff cost, and primary import/open action.
  - Remains visually dominant with `2×1` span.
  - Uses subtle status treatment, not a rainbow badge.
- Balance card
  - Shows current balance from existing data.
  - Primary action opens zencab top-up or renew/payment route through `CabinetWebView`.
- Devices card
  - First pass may show `—` or fallback copy because current native model has no devices field.
  - If a structured devices payload appears later, render it here without changing the first-pass backend contract.
- Menu card component
  - Reusable square action surface for the four lower cards.
  - Uses plain icon plus text, without colored icon boxes, gradients, or glow.

## Data mapping

Existing `CabinetHomeData` is enough for the first pass:

- `tariffName` -> tariff card title, fallback `Войдите в кабинет Dropweb`.
- `statusLabel` -> subtle tariff status/expiry copy, fallback `Данные появятся после входа`.
- `tariffCostLabel` -> tariff card cost, fallback `—`.
- `balanceLabel` / `balanceAmountKopeks` -> balance card value, fallback `Баланс —` or `—`.
- `referralLink` -> `Рефералы` card copy/share behavior.
- `subscriptionUrl` -> import action only when present in live bridge data.
- `importState` -> primary tariff CTA label and small connection copy.

No new backend fields are required for the first pass. Devices should render from available structured payload if one is added later. Until then, the devices card shows `—` or short fallback copy like `Данные появятся позже`.

Security constraint: `subscriptionUrl` is token-bearing. It must not be persisted in SharedPreferences or treated as harmless stored metadata. On restored snapshots, absence of `subscriptionUrl` should keep the action on the safe `CabinetWebView` fallback path.

## Action behavior

- Tariff primary action
  - If a live `subscriptionUrl` exists, import it into Dropweb through the existing native profile path.
  - If no live `subscriptionUrl` exists, open `CabinetWebView(initialPath: '/login')` or the existing cabinet fallback.
- `Баланс`
  - Opens existing top-up route through `CabinetWebView`, for example `/balance/top-up`.
- `Устройства`
  - First pass: no backend or device-management scope. Show fallback state and, if actionable, open the cabinet fallback route.
- `Рефералы`
  - Copies or opens the existing `referralLink` when present. Disabled or fallback copy when absent.
- `Продлить`
  - Opens existing zencab payment/renew flow through `CabinetWebView`. No native payment implementation.
- `Поддержка`
  - Opens existing zencab support route through `CabinetWebView`.
- `Открыть кабинет`
  - Opens the existing cabinet WebView route.

## Error and empty states

- Empty snapshot
  - Tariff: `Войдите в кабинет Dropweb`, cost `—`, status `Данные появятся после входа`.
  - Balance: `—` or `Баланс —`.
  - Devices: `—` or `Данные появятся позже`.
  - Referral action disabled or shows `Ссылка —`.
- Restored snapshot without `subscriptionUrl`
  - Continue showing display-only tariff, balance, and referral data.
  - Primary import action falls back to opening the cabinet WebView until zencab republishes a live URL.
- Bridge validation failure
  - Do not fabricate values. Render the same empty copy.
- Action failure
  - Keep current safe fallback pattern: show a short snackbar when import succeeds, otherwise open `CabinetWebView`.

## Verification plan

Documentation-only task now:

- Confirm this design file exists at `docs/plans/2026-05-17-cabinet-tab-bento-layout-design.md`.
- Confirm no Dart code, release/download/site files, dependencies, or git commits were changed.

Future implementation verification:

- Run Flutter analyzer on changed Dart files.
- Smoke the Cabinet tab at narrow mobile width and around max-width `560`.
- Verify two-column square grid, tariff `2×1` span, bottom nav safe area, and four lower cards.
- Verify `subscriptionUrl` remains excluded from SharedPreferences snapshots.
- Verify CabinetWebView still owns auth, payment, support, and fallback routes.
