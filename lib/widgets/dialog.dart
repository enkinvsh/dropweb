import 'dart:io';
import 'dart:math';

import 'package:dropweb/providers/app.dart';
import 'package:dropweb/ui/m3e/widgets/m3e_dialog_skin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommonDialog extends ConsumerWidget {
  const CommonDialog({
    super.key,
    required this.title,
    this.titleBuilder,
    this.actions,
    this.child,
    this.padding,
    this.overrideScroll = false,
    this.backgroundColor,
    this.useM3e,
  });
  final String title;

  /// Optional locale-reactive title resolver; falls back to [title]. Lets a
  /// dialog re-localize its title in place when the app language changes.
  final String Function(BuildContext context)? titleBuilder;
  final Widget? child;
  final List<Widget>? actions;
  final EdgeInsets? padding;
  final bool overrideScroll;
  final Color? backgroundColor;

  /// Рисовать диалог в рамке M3E. `null` — по [defaultUseM3e] (на Android включено).
  /// Параметр и флаг нужны, чтобы тест на macOS мог включить новый путь, а `lib/ui/m3e`
  /// при этом не читал `Platform`.
  final bool? useM3e;

  /// Значение по умолчанию для всех диалогов; `showCommonDialog` берёт отсюда же
  /// затемнение без блюра.
  static bool defaultUseM3e = Platform.isAndroid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = titleBuilder?.call(context) ?? this.title;
    // Цвет фона (`backgroundColor`) при перекраске игнорируется: это цвет Lumina,
    // на светлой M3E-теме он дал бы тёмную плашку.
    if (useM3e ?? defaultUseM3e) {
      return M3eDialogSkin(
        title: title,
        actions: actions,
        padding: padding,
        overrideScroll: overrideScroll,
        child: child,
      );
    }
    final size = ref.watch(viewSizeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      title: title.isEmpty ? null : Text(title),
      actions: actions,
      contentPadding: padding,
      backgroundColor:
          backgroundColor ?? colorScheme.surface.withValues(alpha: 0.92),
      content: Container(
        constraints: BoxConstraints(
          maxHeight: min(
            size.height - 40,
            500,
          ),
          maxWidth: 300,
        ),
        width: size.width - 40,
        child: !overrideScroll
            ? SingleChildScrollView(
                child: child,
              )
            : child,
      ),
    );
  }
}

class CommonModal extends ConsumerWidget {
  const CommonModal({
    super.key,
    this.child,
  });
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(viewSizeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: size.width * 0.85,
        height: size.height * 0.85,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
