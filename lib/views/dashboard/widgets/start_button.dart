import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dropweb/common/common.dart';
import 'package:dropweb/common/connect_trace.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/dashboard/widgets/vpn_disclosure_dialog.dart';
import 'package:dropweb/views/profiles/add_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

/// Включает или выключает VPN: общий путь старой кнопки [StartButton] и кнопки M3E-главной.
///
/// Выключение подтверждается тактильным откликом и звуком сразу, без ожидания: отклик
/// не должен задерживать смену статуса. При включении окно раскрытия VPN идёт ДО отклика
/// и звука: если пользователь его отменил, ничто не должно намекать, что подключение
/// вот-вот начнётся.
///
/// Возвращает `true`, только если запуск реально запрошен (окно раскрытия не отменено);
/// при выключении и при отмене окна — `false`.
Future<bool> toggleVpn(
  BuildContext context, {
  required bool currentlyRunning,
}) async {
  if (currentlyRunning) {
    unawaited(App().performHapticFeedback(DropwebHapticCue.confirm));
    unawaited(App().playUiSound(DropwebSoundCue.powerOff));
    unawaited(globalState.appController.updateStatus(false));
    return false;
  }

  final allowed = await _ensureVpnConsent(context);
  if (!allowed) return false;

  ConnectTrace.start();
  unawaited(App().performHapticFeedback(DropwebHapticCue.confirm));
  unawaited(App().playUiSound(DropwebSoundCue.powerOn));
  unawaited(_maybeRequestNotificationPermission());
  unawaited(globalState.appController.updateStatus(true));
  return true;
}

/// Разовый запрос POST_NOTIFICATIONS при ПЕРВОМ успешном подключении (Android 13+).
/// Без него уведомление foreground-сервиса VPN на свежей установке не видно. Не ждём
/// результата, чтобы не задерживать туннель; уровень SDK и текущую выдачу проверяет
/// нативная сторона.
Future<void> _maybeRequestNotificationPermission() async {
  if (!Platform.isAndroid) return;
  if (await notificationPermissionPrompt.isRequested()) return;
  await notificationPermissionPrompt.markRequested();
  await App().requestNotificationsPermission();
}

/// true, если раскрытие уже принято раньше или принято сейчас в диалоге И флаг удалось
/// сохранить. Вернуть true без сохранённого флага нельзя: кнопка сыграла бы отклик
/// включения, а `AppController.updateStatus` молча отказал бы в старте. Если запись
/// не удалась, считаем попытку отменённой, и диалог спросит снова.
Future<bool> _ensureVpnConsent(BuildContext context) async {
  // Где раскрытие нужно (только магазинные сборки), решает vpnConsent.isAccepted():
  // это общий источник истины с проверкой в updateStatus(true). Сборку здесь не
  // проверять: обход одного диалога оставит контроллер отказывать в старте.
  if (await vpnConsent.isAccepted()) return true;
  if (!context.mounted) return false;
  final accepted = await showVpnDisclosureDialog(context);
  if (accepted != true) return false;
  return vpnConsent.markAccepted();
}

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key, this.iconSize = 48.0});

  final double iconSize;

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton>
    with SingleTickerProviderStateMixin {
  /// Power-glyph drop shadow (lab `icon shadow` dials): a blurred dark copy
  /// of the glyph painted underneath, since HugeIcon (SVG) has no shadows.
  static const double _iconShadowBlur = 5.9;
  static const double _iconShadowAlpha = 0.81;

  /// Fresnel rim painted ONTO the power glyph (ported from
  /// tool/glyph_rim_lab.html `rim внутри`): a conic SweepGradient
  /// (white top / accent sides / dim bottom) masked to the glyph strokes,
  /// so the icon catches the same glass edge-light as the lens rim.
  /// Applied only while connected — the idle glyph stays the plain dimmed icon.
  static const double _glyphRimConnected = 0.75;
  static const double _glyphRimIdle = 0.0;

  /// Vertical shift of the rim conic origin on the glyph (lab `rim внутри ↑`,
  /// in ×r). Applied by translating the shader rect: dy = -1.25*iconSize*lift
  /// (since r == iconSize / 0.8). Keeps the white-top fresnel orientation.
  static const double _glyphRimLift = -0.5;

  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Future<void> handleSwitchStart() => toggleVpn(
        context,
        currentlyRunning: ref.read(runTimeProvider) != null,
      );

  void _handleTapDown() {
    // Press-down only fires the gestureStart haptic — the audible cue was
    // removed (user feedback: the per-press tick felt redundant on top of
    // the powerOn/powerOff cue). Animation still runs so the visual press
    // affordance is preserved.
    if (ref.read(startButtonSelectorStateProvider).hasProfile) {
      App().performHapticFeedback(DropwebHapticCue.gestureStart);
    }
    _pressController.forward();
  }

  void _handleAddProfile() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: AddProfileView(context: context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startButtonSelectorStateProvider);
    // Watch boolean running state only — was watching raw int timestamp,
    // which forced a rebuild on every runTimeProvider tick (every second
    // while connected) even though the icon depends only on null/not-null.
    final isStart = ref.watch(runTimeProvider.select((state) => state != null));

    // Connecting affordance: while handleStart is waiting on the native TUN
    // readiness ack (or while core init is still pending), reuse the existing
    // dimmed/disabled look and swallow taps. The glyph is NEVER hidden — the
    // old `if (!state.isInit) return SizedBox.shrink()` bricked the UI when the
    // boot auto-start stalled/threw before init() set isInit=true.
    // No new colors/animations — just the opacity60 extension + null onTap.
    return ValueListenableBuilder<bool>(
      valueListenable: globalState.isConnecting,
      builder: (context, isConnecting, _) =>
          _buildButton(context, state, isStart, isConnecting),
    );
  }

  /// Conic Fresnel (white top / accent sides / dim bottom) masked to the
  /// power glyph — Flutter port of glyph_rim_lab.html `glyphFresnel`.
  Widget _rimGlyph(
    List<List<dynamic>> icon,
    double strokeWidth,
    Color accent,
    double amount,
  ) {
    return Opacity(
      opacity: amount.clamp(0.0, 1.0),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => SweepGradient(
          transform: const GradientRotation(-math.pi / 2),
          colors: [
            Lumina.lensHighlight,
            accent.withValues(alpha: 0.5),
            Lumina.lensHighlight.withValues(alpha: 0.12),
            accent.withValues(alpha: 0.5),
            Lumina.lensHighlight,
          ],
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(
          // lift: shift the conic origin like the lab (center = cy - r*lift,
          // r == iconSize / 0.8) — keeps the white-top fresnel orientation
          rect.translate(0, -1.25 * widget.iconSize * _glyphRimLift),
        ),
        child: HugeIcon(
          icon: icon,
          size: widget.iconSize,
          strokeWidth: strokeWidth,
          color: Lumina.lensHighlight,
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    StartButtonSelectorState state,
    bool isStart,
    bool isConnecting,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasProfile = state.hasProfile;
    final isInactive = hasProfile && !isStart;
    // Core not yet initialised → keep the glyph visible but in the same
    // dimmed/disabled "pending" affordance already used while connecting.
    // Hiding it (the old SizedBox.shrink on !isInit) bricked the UI when the
    // boot auto-start stalled/threw before init() set isInit=true.
    final isPending = isConnecting || !state.isInit;
    final baseIconColor = isInactive
        ? Color.lerp(Lumina.lensBody, colorScheme.primary, 0.28)!
        : colorScheme.primary;
    // While pending (connecting or core init not done), dim the icon with the
    // existing opacity extension so it reads as a pending/disabled affordance.
    final iconColor = isPending ? baseIconColor.opacity60 : baseIconColor;

    const motionDuration = Duration(milliseconds: 180);
    const motionCurve = Curves.easeOutCubic;

    // `dw_connect`: стабильный resource-id для uiautomator и adb-QA.
    // `container: true` — собственный узел семантики размером с кнопку.
    // Без него PageView сливал кнопку с текстом подсказки пустого экрана в
    // один узел на полэкрана; Robo (Test Lab, pre-launch report Play) жмёт в
    // центр узла, попадал в текст, и кнопка «+» для него не работала.
    // Своя подпись нужна, потому что узел больше не берёт текст подсказки:
    // без неё TalkBack читал бы просто «Кнопка».
    return Semantics(
      container: true,
      button: true,
      identifier: 'dw_connect',
      label: !hasProfile
          ? appLocalizations.dashboardEmptyTitle
          : isStart
              ? appLocalizations.stop
              : appLocalizations.start,
      child: AnimatedBuilder(
        animation: _pressController,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Ignore press feedback + taps while connecting (or while core init is
          // pending) so a second tap can't race the in-flight start transition.
          onTapDown: isPending ? null : (_) => _handleTapDown(),
          onTapUp: isPending ? null : (_) => _pressController.reverse(),
          onTapCancel: isPending ? null : () => _pressController.reverse(),
          onTap: isPending
              ? null
              : (hasProfile ? handleSwitchStart : _handleAddProfile),
          child: SizedBox.expand(
            child: Center(
              child: RepaintBoundary(
                child: AnimatedScale(
                  scale: isInactive ? 0.94 : 1.0,
                  duration: motionDuration,
                  curve: motionCurve,
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: iconColor),
                    duration: motionDuration,
                    curve: motionCurve,
                    builder: (_, color, __) => AnimatedBuilder(
                      animation: _pressController,
                      builder: (_, __) {
                        final iconData = !hasProfile
                            ? HugeIcons.strokeRoundedAddCircleHalfDot
                            : HugeIcons.strokeRoundedPower;
                        final strokeWidth =
                            _pressController.value > 0 ? 3.0 : 1.7;
                        final accent = Theme.of(context).colorScheme.primary;
                        final connected = isStart;
                        final rimAmount =
                            connected ? _glyphRimConnected : _glyphRimIdle;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outline/glow: the same glyph, dark + blurred,
                            // painted UNDER the main icon. Mirrors the tuner's
                            // drawGlyphPaths(..., rgba(#000,0.72), blur 5.5) pass
                            // since HugeIcon (SVG) doesn't accept shadows.
                            ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: _iconShadowBlur,
                                sigmaY: _iconShadowBlur,
                              ),
                              child: HugeIcon(
                                icon: iconData,
                                size: widget.iconSize,
                                strokeWidth: strokeWidth,
                                color: Lumina.lensShadow
                                    .withValues(alpha: _iconShadowAlpha),
                              ),
                            ),
                            // body
                            HugeIcon(
                              icon: iconData,
                              size: widget.iconSize,
                              strokeWidth: strokeWidth,
                              color: color ?? iconColor,
                            ),
                            // rim внутри: conic Fresnel painted over the glyph.
                            if (rimAmount > 0)
                              _rimGlyph(
                                iconData,
                                strokeWidth,
                                accent,
                                rimAmount,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
