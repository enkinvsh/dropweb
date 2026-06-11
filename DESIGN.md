# DESIGN.md — dropweb design authority

> Read by design-cockpit (`design_start` / `design_brief_create` / `reference_search`) and the design-workflow skill on EVERY session, for EVERY agent. This file is the design authority. Obey it. Do not invent a new visual language, do not hardcode, do not inline styles, do not ship generic AI-SaaS slop.

## Vision
Dark-only, modular, token-driven. The product language is "Lumina": deep near-black surfaces (not pure black, faint blue tint), intentional glass, accent glow, and ambient orbs. Calm, dense, premium, quiet confidence. Every screen is composed from atomic widgets and design tokens. Nothing is styled ad-hoc.

## Non-negotiables (anti-slop)
- NO hardcoded `Color(0xFF...)` outside `lib/common/lumina.dart`.
- NO inline `TextStyle(...)` for ad-hoc size/color. Use `Theme.of(context).textTheme.*` + text atoms.
- NO new visual system, NO light/system mode, NO purple/neon/gamer defaults, NO random glassmorphism. Glass is intentional but tokenized only.
- NO rebuilding buttons / cards / inputs / sheets from raw `Container`/`Material`. Compose existing atoms.
- NO fake data, placeholder Acme/John Doe, or default three-card SaaS rows.
- NO color-only state. Cover default / pressed / disabled / loading / empty / error.

## Tokens (single source of truth)
- `lib/common/lumina.dart` (`Lumina`): surfaces `void_`/`surface1..5`; glass `glass()`/`glassCircle()`/`glassBlur`/`heavyBlur`; glow `glowPrimary`/`glowSecondary`/`glowAccent` + `glowShadow()`; shadows; radii `radiusMd 16`/`radiusLg 24`/`radiusXl 32`/`radiusXxl 48`; motion `luminaCurve` + `luminaDuration 400ms`. Blur sigma capped 4/8 for mid-range Android (Skia, no Impeller); GPU cost ~quadratic in sigma. Do not raise it.
- `lib/common/color.dart`: opacity `.opacity80..opacity0` (NOT `withOpacity`), `lighten/darken`, `blendDarken/blendLighten(context)`, scheme-variant filters, `ColorScheme.toPureBlack`.
- `lib/common/theme.dart` (`CommonTheme`): cached derived colors.
- Semantic color = `context.colorScheme.*` (Material 3). Accents/orbs/presets via `themeSettingProvider` (Emerald/Frost/Amethyst/Magma/Amber/Crimson/Stealth).
- Typography: `FontFamily` enum, Onest (UI) / JetBrainsMono (mono) / Twemoji (emoji). Never literal family strings.
- Spacing & radius on the 8-scale already in use (16 / 24 / 64).

## Atoms (compose, do not reinvent)
`package:dropweb/widgets/widgets.dart`: card, chip, container, input, sheet, side_sheet, dialog, popup, scaffold, list, grid, super_grid, tab, icon, text, palette, color_scheme_box, notification, null_status, effect, mesh_background, donut_chart, line_chart, and more.

## Workflow for any UI task
1. Route non-trivial UI to the `visual-engineering` category with the `design-workflow` skill.
2. design-cockpit: `design_start` then `design_brief_create`. The brief must cite these tokens/atoms, not taste.
3. Build by composing atoms + tokens only.
4. Visual QA on device with flutter-dev `flutter_screenshot` (this is a Flutter app, NOT browser capture). Verify every state. Fix or report mismatches.

Authority order: this file > existing screens/tokens > taste. Legacy design-mcp is fallback context, never authority.
