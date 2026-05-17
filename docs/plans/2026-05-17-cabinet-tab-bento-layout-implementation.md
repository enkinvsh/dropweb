# Cabinet Tab Bento Layout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refine the native Cabinet tab into the approved compact two-column FOCUS/Lumina bento layout.

**Architecture:** Keep the work inside `NativeCabinetHome` and its existing cabinet data flow. The screen remains a native Flutter surface backed by `cabinetHomeAdapter.snapshot`, with zencab auth, payment, support, and fallback routes still opened through `CabinetWebView`.

**Tech Stack:** Flutter, Dart, existing `Lumina` and `CommonCard` UI primitives, existing `CabinetHomeData`, existing `CabinetHomeAdapter`, existing `CabinetWebView` navigation.

---

## Scope and non-goals

This is visual-engineering work. Future delegation for this implementation must use design-mcp guidance before changing UI code, then apply the constraints below exactly.

Source of truth: `docs/plans/2026-05-17-cabinet-tab-bento-layout-design.md`.

Hard constraints:

1. Keep the Cabinet tab as a strict two-column bento grid.
2. Tariff is the only dominant card and spans `2×1`.
3. Balance and Devices are separate `1×1` cards.
4. Bottom four equal squares are `Рефералы`, `Продлить`, `Поддержка`, `Открыть кабинет`.
5. Use Lumina and `CommonCard` only. No new component library.
6. No gradients, no glow, no decorative or overlarge icon containers.
7. Keep spacing compact and mobile first, with max content width around `560`.
8. No new backend fields for the first pass. Devices may show fallback `—` or `Данные появятся позже`.
9. `subscriptionUrl` is token-bearing. It must stay excluded from SharedPreferences persistence.
10. No release, download, website, or APK distribution work.
11. Do not add dependencies.
12. Do not commit unless the orchestrator explicitly asks in a separate instruction.

## Current files to understand before editing

Read these files first during implementation:

1. `docs/plans/2026-05-17-cabinet-tab-bento-layout-design.md`
2. `lib/views/cabinet/native_cabinet_home.dart`
3. `lib/views/cabinet/cabinet_home_data.dart`
4. `lib/views/cabinet/cabinet_home_adapter.dart`
5. `test/views/cabinet/cabinet_home_adapter_persistence_test.dart`

## Implementation tasks

### Task 1: Confirm UI constraints with design-mcp

**Files:**

1. Read: `docs/plans/2026-05-17-cabinet-tab-bento-layout-design.md`
2. Read: `lib/views/cabinet/native_cabinet_home.dart`
3. Modify: none
4. Test: none

**Step 1: Load the visual guidance**

Use design-mcp for a compact mobile dashboard or bento card layout, dark mode, and existing Lumina/CommonCard style. Keep the output as guidance only, not as a new design direction.

Expected guidance to preserve:

1. Compact two-column bento rhythm.
2. Dominant tariff card.
3. Quiet square action cards.
4. No gradients or glow.
5. No large colored icon containers.

**Step 2: Re-read the approved design file**

Run no command for this step if you are already in an editor. Otherwise inspect:

```bash
sed -n '1,180p' docs/plans/2026-05-17-cabinet-tab-bento-layout-design.md
```

Expected: the design states tariff `2×1`, balance and devices `1×1`, then four equal square menu cards.

**Step 3: Re-read the target implementation file**

Run no command for this step if you are already in an editor. Otherwise inspect:

```bash
sed -n '1,430p' lib/views/cabinet/native_cabinet_home.dart
```

Expected: the current file contains `_TariffHeroCard`, `_TopUpCard`, `_ReferralCard`, `_openCabinet`, `_openTopUp`, and `_importSubscription`.

**Step 4: Checkpoint**

Do not edit yet. Confirm the next changes stay inside `lib/views/cabinet/native_cabinet_home.dart` unless Task 2 finds a small practical test boundary.

### Task 2: Add or adjust only practical narrow tests

**Files:**

1. Optional modify: `test/views/cabinet/cabinet_home_adapter_persistence_test.dart`
2. Optional create: no new broad widget test file unless a stable existing harness already exists
3. Modify: no Dart implementation files in this task

**Step 1: Decide whether a small test is practical**

Inspect existing cabinet tests:

```bash
sed -n '1,260p' test/views/cabinet/cabinet_home_adapter_persistence_test.dart
sed -n '1,220p' test/views/cabinet/cabinet_path_validators_test.dart
```

Expected: existing persistence tests already cover snapshot restore behavior, and path validator tests cover safe cabinet paths.

**Step 2: Add only the security persistence assertion if missing**

If the persistence test does not already assert that raw prefs omit `subscriptionUrl`, add or keep a narrow assertion like this inside the existing persistence round-trip test:

```dart
expect(restored.subscriptionUrl, isNull);
expect(rawPrefsString, isNot(contains('subscriptionUrl')));
expect(rawPrefsString, isNot(contains('token.example')));
```

Use the actual local variable names from the existing test. Do not invent broad UI snapshot tests.

Expected: the test proves `subscriptionUrl` is not persisted.

**Step 3: Run the targeted test only if the test was changed**

```bash
flutter test test/views/cabinet/cabinet_home_adapter_persistence_test.dart
```

Expected: all tests in `cabinet_home_adapter_persistence_test.dart` pass.

**Step 4: Skip broad widget testing if no stable harness exists**

If adding a Cabinet widget test requires pump scaffolding, navigation fakes, custom globals, or brittle layout assertions, do not add it. This plan favors targeted analyzer, existing adapter tests, and real Android smoke for the visual layout.

### Task 3: Add navigation helpers for the four actions

**Files:**

1. Modify: `lib/views/cabinet/native_cabinet_home.dart`
2. Test: existing navigation and cabinet path tests only

**Step 1: Add small private helpers beside existing helpers**

In `NativeCabinetHome`, keep `_openCabinet`, `_openTopUp`, and `_importSubscription`. Add narrow helpers for renew/payment and support.

Target shape:

```dart
Future<void> _openRenew(BuildContext context) async {
  await BaseNavigator.push(
    context,
    const CabinetWebView(initialPath: '/payment'),
  );
}

Future<void> _openSupport(BuildContext context) async {
  await BaseNavigator.push(
    context,
    const CabinetWebView(initialPath: '/support'),
  );
}
```

If existing route validators or navigation tests indicate a different renew path, use the existing validated zencab payment or renew path. Do not add native payment code.

Expected: renew/payment and support still delegate to `CabinetWebView`.

**Step 2: Keep referral copy local to the referral card or a new action card callback**

Preserve current behavior:

```dart
await Clipboard.setData(ClipboardData(text: value));
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Реферальная ссылка скопирована')),
);
```

Expected: tapping `Рефералы` copies the link when present and does nothing or shows disabled fallback when absent.

**Step 3: Do not run a full build here**

Verification for these helpers is included in Task 8.

### Task 4: Replace the vertical body with a two-column bento grid

**Files:**

1. Modify: `lib/views/cabinet/native_cabinet_home.dart`
2. Test: analyzer in Task 8

**Step 1: Keep the outer scroll and max-width container**

Preserve this structure:

```dart
SingleChildScrollView(
  padding: const EdgeInsets.all(16).copyWith(bottom: 24),
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ...
    ),
  ),
)
```

Increase bottom padding only if needed to protect the last row from bottom navigation and gesture area.

Expected: content stays centered and mobile first.

**Step 2: Compute a reusable square size with `LayoutBuilder`**

Inside the constrained content, wrap the grid area with `LayoutBuilder` and compute:

```dart
const gap = 12.0;
final squareSize = (constraints.maxWidth - gap) / 2;
```

Expected: every `1×1` card uses `squareSize`, and the tariff card uses full width with a compact `2×1` height derived from the same rhythm.

**Step 3: Build the bento order exactly**

Use this order:

1. Header text `Кабинет`.
2. Tariff card full width.
3. Row with Balance left and Devices right.
4. Row with Referrals left and Renew right.
5. Row with Support left and Open Cabinet right.

Expected: strict two-column bento, no fallback list layout for narrow phones unless the two-column grid becomes unusable in real smoke.

**Step 4: Use compact gaps**

Use `12` for grid gaps unless local Lumina spacing constants already provide the same compact rhythm. Avoid `20+` gaps between square cards.

Expected: layout feels bento and compact, not a vertical feed.

### Task 5: Refactor the tariff card into the `2×1` dominant card

**Files:**

1. Modify: `lib/views/cabinet/native_cabinet_home.dart`
2. Test: analyzer in Task 8

**Step 1: Keep `_TariffHeroCard` or rename it only if helpful**

Either keep `_TariffHeroCard` or rename it to `_TariffBentoCard`. Do not move it to a new file in this pass.

Expected: the card still receives `CabinetHomeData? data`, `onPrimaryPressed`, and `onFallbackPressed`.

**Step 2: Remove balance summary from the tariff card**

Delete `_HeroSummaryRow` and `_SummaryLine` if they become unused. Balance now lives in its own `1×1` card.

Expected: tariff card shows tariff title, status, cost, and primary connect/import action only.

**Step 3: Keep CTA behavior unchanged**

Preserve the existing logic:

```dart
if (data?.subscriptionUrl == null) return 'Открыть кабинет';
return switch (data?.importState) {
  CabinetImportState.imported => 'Импортировать снова',
  CabinetImportState.ready => 'Подключить в Dropweb',
  _ => 'Открыть кабинет',
};
```

Expected: live `subscriptionUrl` imports into Dropweb, restored data without `subscriptionUrl` opens cabinet.

**Step 4: Keep visual treatment quiet**

Use `CommonCard`, `Lumina.radiusLg`, compact `Padding`, subdued status text or `_StatusPill`, and no gradient or glow.

Expected: tariff is dominant by span and typography, not by effects.

### Task 6: Create the Balance and Devices `1×1` cards

**Files:**

1. Modify: `lib/views/cabinet/native_cabinet_home.dart`
2. Test: analyzer in Task 8

**Step 1: Replace `_TopUpCard` with a square balance card**

Implement a card with this responsibility:

```dart
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balanceLabel, required this.onPressed});

  final String? balanceLabel;
  final VoidCallback onPressed;
}
```

Expected content:

1. Small plain wallet icon.
2. Title `Баланс`.
3. Value `balanceLabel ?? '—'`.
4. Quiet action hint such as `Пополнить`.

Expected behavior: tapping opens `_openTopUp(context)`.

**Step 2: Add a square devices card without backend expansion**

Implement a card with this responsibility:

```dart
class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.onPressed});

  final VoidCallback onPressed;
}
```

Expected content:

1. Small plain devices icon.
2. Title `Устройства`.
3. Value `—` or `Данные появятся позже`.
4. Optional hint `Открыть кабинет`.

Expected behavior: tapping opens `_openCabinet(context)` if actionable.

**Step 3: Do not add fields to `CabinetHomeData`**

Leave `lib/views/cabinet/cabinet_home_data.dart` unchanged unless analyzer reveals an existing import cleanup need caused by your edits.

Expected: no backend contract change.

### Task 7: Create the lower square menu action component

**Files:**

1. Modify: `lib/views/cabinet/native_cabinet_home.dart`
2. Test: analyzer in Task 8

**Step 1: Replace `_ReferralCard` with a reusable lower action card or adapt it into one**

Create a reusable private widget:

```dart
class _BentoActionCard extends StatelessWidget {
  const _BentoActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;
}
```

Expected: it uses `CommonCard`, compact padding, a plain `Icon`, title, and one short subtitle. No icon background box.

**Step 2: Wire `Рефералы`**

For `data?.referralLink`, pass:

1. Title: `Рефералы`.
2. Subtitle when link exists: `Скопировать ссылку` or the shortened link if it fits cleanly.
3. Subtitle when link is absent: `Ссылка —`.
4. `onPressed`: copy the referral link when present, otherwise `null`.

Expected: copy snackbar still says `Реферальная ссылка скопирована`.

**Step 3: Wire `Продлить`**

Pass:

1. Title: `Продлить`.
2. Subtitle: `Оплата тарифа`.
3. `onPressed`: `_openRenew(context)`.

Expected: opens existing zencab payment or renew flow through `CabinetWebView`.

**Step 4: Wire `Поддержка`**

Pass:

1. Title: `Поддержка`.
2. Subtitle: `Помощь в кабинете`.
3. `onPressed`: `_openSupport(context)`.

Expected: opens existing support route through `CabinetWebView`.

**Step 5: Wire `Открыть кабинет`**

Pass:

1. Title: `Открыть кабинет`.
2. Subtitle: `Веб-кабинет`.
3. `onPressed`: `_openCabinet(context)`.

Expected: opens `CabinetWebView(initialPath: '/login')` or the existing cabinet fallback.

### Task 8: Run targeted verification

**Files:**

1. Analyze: `lib/views/cabinet/native_cabinet_home.dart`
2. Analyze: `lib/views/cabinet/cabinet_home_data.dart`
3. Analyze: `lib/views/cabinet/cabinet_home_adapter.dart`
4. Analyze: `test/views/cabinet/cabinet_home_adapter_persistence_test.dart`
5. Test: existing navigation and cabinet tests

**Step 1: Run the targeted tests**

```bash
flutter test test/common/navigation_test.dart test/views/cabinet/cabinet_home_adapter_persistence_test.dart test/views/cabinet/cabinet_path_validators_test.dart
```

Expected: all selected tests pass.

**Step 2: Run the targeted analyzer**

```bash
flutter analyze lib/views/cabinet/native_cabinet_home.dart lib/views/cabinet/cabinet_home_data.dart lib/views/cabinet/cabinet_home_adapter.dart test/views/cabinet/cabinet_home_adapter_persistence_test.dart
```

Expected: analyzer reports no issues for these files.

**Step 3: Verify `subscriptionUrl` persistence remains safe**

Confirm `test/views/cabinet/cabinet_home_adapter_persistence_test.dart` still proves all of the following:

1. Restored `CabinetHomeData.subscriptionUrl` is `null`.
2. Raw SharedPreferences JSON does not include the `subscriptionUrl` key.
3. Raw SharedPreferences JSON does not include the token-bearing URL value or host path.

Expected: no token-bearing subscription URL is persisted.

**Step 4: Inspect the changed Dart diff**

```bash
git diff -- lib/views/cabinet/native_cabinet_home.dart lib/views/cabinet/cabinet_home_data.dart lib/views/cabinet/cabinet_home_adapter.dart test/views/cabinet/cabinet_home_adapter_persistence_test.dart
```

Expected:

1. UI changes are limited to the Cabinet bento layout.
2. No release, download, or website files changed.
3. No dependency files changed.
4. No backend fields added for devices.

### Task 9: Optional real Android smoke verification

**Files:**

1. Modify: none unless a smoke failure identifies a specific UI bug
2. Test: real Android device or emulator

This is final optional verification. Do not run it after every small task.

**Step 1: Build and install the Android debug app**

Use the project-standard Android debug command if one exists in local notes or scripts. If there is no project wrapper, use:

```bash
flutter build apk --debug
flutter install
```

Expected: debug APK builds and installs on the connected Android target.

**Step 2: Smoke the Cabinet tab**

On Android, open the app and switch to the Cabinet tab.

Expected visual result:

1. Header `Кабинет` appears.
2. Tariff card spans both columns and is visually dominant.
3. Balance and Devices are equal square cards below the tariff.
4. Four bottom menu cards are equal squares: `Рефералы`, `Продлить`, `Поддержка`, `Открыть кабинет`.
5. Last row is not hidden by bottom navigation or gesture area.
6. No gradients, no glow, no large icon containers.

**Step 3: Smoke actions**

Tap each action once:

1. Tariff CTA imports only when a live `subscriptionUrl` exists, otherwise opens cabinet fallback.
2. `Баланс` opens top-up.
3. `Устройства` shows fallback and may open cabinet fallback.
4. `Рефералы` copies the link when present.
5. `Продлить` opens payment or renew flow.
6. `Поддержка` opens support.
7. `Открыть кабинет` opens the cabinet WebView.

Expected: no crashes, no native payment implementation, all route ownership stays with `CabinetWebView`.

## Final completion checklist

Before reporting completion, verify:

1. `flutter test test/common/navigation_test.dart test/views/cabinet/cabinet_home_adapter_persistence_test.dart test/views/cabinet/cabinet_path_validators_test.dart` passed.
2. `flutter analyze lib/views/cabinet/native_cabinet_home.dart lib/views/cabinet/cabinet_home_data.dart lib/views/cabinet/cabinet_home_adapter.dart test/views/cabinet/cabinet_home_adapter_persistence_test.dart` passed.
3. `subscriptionUrl` remains excluded from SharedPreferences persistence.
4. Devices card uses fallback only and no backend fields were added.
5. No release, download, or site files changed.
6. No dependencies were added.
7. No commit was created unless separately requested by the orchestrator.

## Known implementation risks

1. Payment or renew path may already have a validated route name. Check `cabinet_path_validators_test.dart` and existing navigation tests before choosing `/payment`.
2. Flutter square layout can overflow if text is too long. Use `maxLines`, `overflow: TextOverflow.ellipsis`, compact text styles, and real Android smoke.
3. Restored cabinet snapshots intentionally do not contain `subscriptionUrl`, so the tariff CTA must keep falling back to the cabinet WebView until zencab republishes a live URL.
