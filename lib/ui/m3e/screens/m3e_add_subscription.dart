import 'dart:async';

import 'package:dropweb/common/clipboard_subscription.dart';
import 'package:dropweb/common/common.dart' show system;
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/views/profiles/add_profile.dart';
import 'package:dropweb/views/profiles/receive_profile_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../symbols.g.dart';
import '../theme/m3e_text.dart';
import '../theme/m3e_theme_scope.dart';
import '../theme/tokens.g.dart';
import '../widgets/m3e_button.dart';
import '../widgets/m3e_list.dart';
import '../widgets/m3e_sheet.dart';
import '../widgets/m3e_symbol.dart';

/// Ключи элементов: имена как в `test/m3e/ref/layout.json` (`field`, `field.input`, ...).
const Key kM3eAddFieldKey = ValueKey<String>('m3e.field');
const Key kM3eAddFieldInputKey = ValueKey<String>('m3e.field.input');
const Key kM3eAddFieldLabelKey = ValueKey<String>('m3e.field.label');
const Key kM3eAddFieldPasteKey = ValueKey<String>('m3e.field.paste');
const Key kM3eAddFieldSupKey = ValueKey<String>('m3e.field.sup');
const Key kM3eAddQrKey = ValueKey<String>('m3e.add.qr');
const Key kM3eAddPhoneKey = ValueKey<String>('m3e.add.phone');
const Key kM3eAddSubmitKey = ValueKey<String>('m3e.add.submit');

/// Импорт подписки по ссылке. Провайдером, чтобы тесты подменяли сеть и контроллер.
final m3eAddImportProvider =
    Provider<Future<void> Function(String url)>((ref) => addProfileFromUrl);

/// Сканер QR. Сам открывает камеру и по результату вызывает импорт (на рабочем столе
/// путь другой), поэтому возвращает только завершение.
final m3eAddScanProvider =
    Provider<Future<void> Function(BuildContext context)>(
  (ref) => scanProfileQrCode,
);

/// Телевизор ли это: на Android TV нет камеры и удобного ввода, поэтому ссылку
/// принимают с телефона (как `AddProfileView` старого листа). Провайдером, чтобы
/// тесты не ходили в платформенный канал.
final m3eAddIsTvProvider = FutureProvider<bool>((ref) => system.isAndroidTV);

/// Диалог приёма ссылки с телефона: возвращает ссылку или `null`.
final m3eAddReceiveProvider =
    Provider<Future<String?> Function(BuildContext context)>(
  (ref) => (context) => showDialog<String>(
        context: context,
        builder: (_) => const ReceiveProfileDialog(),
      ),
);

/// Ссылка подписки из введённого текста или `null`. Правило контроллера
/// (`addProfileFormURL`): http и https с хостом, плюс обёртки `clash://` и `dropweb://`,
/// которые уже понимает строка буфера обмена старого листа.
String? m3eAddParseUrl(String text) => extractSubscriptionUrl(text);

/// Тело шага «Добавить подписку» для [M3eSheetStack] (`addView()` доски).
///
/// После успешной проверки сначала закрывается лист ([onDone] или `Navigator.pop`), потом
/// запускается импорт: контроллер ведёт главный экран через глобальный навигатор,
/// а не через контекст листа (порядок прежнего `AddProfileView`).
class M3eAddSubscriptionView extends ConsumerStatefulWidget {
  const M3eAddSubscriptionView({super.key, this.initialValue, this.onDone});

  /// Предзаполнение поля, например текст из буфера, не похожий на ссылку.
  final String? initialValue;

  /// Закрыть лист после отправки. По умолчанию закрывается маршрут листа.
  final VoidCallback? onDone;

  @override
  ConsumerState<M3eAddSubscriptionView> createState() =>
      _M3eAddSubscriptionViewState();
}

class _M3eAddSubscriptionViewState
    extends ConsumerState<M3eAddSubscriptionView> {
  late final TextEditingController _controller;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '')
      ..addListener(_onText);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onText)
      ..dispose();
    super.dispose();
  }

  void _onText() => setState(() {});

  void _close() {
    final onDone = widget.onDone;
    if (onDone != null) {
      onDone();
    } else {
      // pop, а не maybePop: стек листа перехватывает «Назад» и снял бы только шаг,
      // а после отправки должен уйти весь лист.
      Navigator.of(context).pop();
    }
  }

  void _submit() {
    final url = m3eAddParseUrl(_controller.text);
    if (url == null) {
      setState(() => _error = true);
      return;
    }
    final import = ref.read(m3eAddImportProvider);
    _close();
    unawaited(import(url));
  }

  /// Кнопка вставки в поле: подставляет ссылку из буфера, ошибка снимается.
  /// Чтение буфера идёт только по касанию пользователя.
  Future<void> _paste() async {
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      // Доступ к буферу может быть закрыт системой: поле остаётся как было.
    }
    if (!mounted || text == null || text.trim().isEmpty) return;
    final value = m3eAddParseUrl(text) ?? text.trim();
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() => _error = false);
  }

  Future<void> _scan() => ref.read(m3eAddScanProvider)(context);

  /// «Получить с телефона» (Android TV): после принятой ссылки лист закрывается
  /// и идёт обычный импорт, как после ручного ввода.
  Future<void> _receiveFromPhone() async {
    final receive = ref.read(m3eAddReceiveProvider);
    final url = await receive(context);
    if (url == null || url.isEmpty || !mounted) return;
    final import = ref.read(m3eAddImportProvider);
    _close();
    unawaited(import(url));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isTv = ref.watch(m3eAddIsTvProvider).valueOrNull ?? false;

    // Отступа под клавиатуру здесь нет: его целиком отдаёт маршрут листа
    // (`showM3eSheet`: max(viewPadding, viewInsets)). Раньше вид добавлял свою
    // долю поверх, отступ считался дважды, и на телефоне владельца (клавиатура
    // ≈ 350 dp, шрифт приложения ×1.4) область прокрутки схлопывалась до
    // десятков dp: полоса «BOTTOM OVERFLOWED», под заголовком пусто.
    return M3eListSurfaceScope(
      surface: M3eListSurface.sheet,
      child: M3eSheetScaffold(
        title: l10n.addSubscription,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LinkField(
              controller: _controller,
              error: _error,
              onPaste: _paste,
              onSubmitted: _submit,
            ),
            M3eList(
              children: [
                M3eListItem(
                  key: kM3eAddQrKey,
                  label: l10n.m3eEmptyScanQr,
                  lead: M3eListLead.icon(M3eSymbol.qrCodeScanner),
                  onTap: () => unawaited(_scan()),
                ),
                if (isTv)
                  M3eListItem(
                    key: kM3eAddPhoneKey,
                    label: l10n.addFromPhoneTitle,
                    sup: l10n.addFromPhoneSubtitle,
                    // Значка телевизора в таблице символов нет: «загрузка»
                    // читается как «получить».
                    lead: M3eListLead.icon(M3eSymbol.download),
                    onTap: () => unawaited(_receiveFromPhone()),
                  ),
              ],
            ),
          ],
        ),
        footer: M3eButton(
          key: kM3eAddSubmitKey,
          label: l10n.add,
          variant: M3eButtonVariant.filled,
          size: M3eButtonSize.m,
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
        ),
      ),
    );
  }
}

/// Самостоятельный лист «Добавить подписку» (для пустого экрана). Вызывать с контекста
/// внутри `M3eThemeScope`, как и [showM3eSheet].
Future<void> showM3eAddSubscription(
  BuildContext context, {
  String? initialValue,
}) =>
    showM3eSheet<void>(
      context,
      // Стек оставлен: лист живёт как шаг «Подписки» и принимает «Назад». Входа по
      // почте здесь нет ни в одной сборке (решение владельца 2026-10-29).
      builder: (context) => M3eSheetStack(
        root: (_) => M3eAddSubscriptionView(initialValue: initialValue),
      ),
    );

/// Поле с обводкой (`.dr-field` доски, learn/08): высота 56, угол 4, обводка outline 1 dp,
/// в фокусе primary 2 dp, ярлык «всплыл» в разрыв рамки (подсказка `https://` видна всегда).
/// Текст ошибки занимает место под полем.
class _LinkField extends StatefulWidget {
  const _LinkField({
    required this.controller,
    required this.error,
    required this.onPaste,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool error;
  final VoidCallback onPaste;
  final VoidCallback onSubmitted;

  @override
  State<_LinkField> createState() => _LinkFieldState();
}

class _LinkFieldState extends State<_LinkField> {
  final FocusNode _focus = FocusNode();
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = M3eColors.of(context).scheme;
    final focused = _focus.hasFocus;
    final error = widget.error;

    final Color border;
    if (error) {
      border = scheme.error;
    } else if (focused) {
      border = scheme.primary;
    } else if (_hover) {
      border = scheme.onSurface;
    } else {
      border = scheme.outline;
    }
    // Фокус и ошибка в CSS добавляют внутреннее кольцо 1 dp к рамке 1 dp: итого 2.
    final width = (focused || error) ? 2.0 : 1.0;
    final Color labelColor;
    if (error) {
      labelColor = scheme.error;
    } else if (focused) {
      labelColor = scheme.primary;
    } else {
      labelColor = scheme.onSurfaceVariant;
    }

    final textStyle = m3eTextStyle(M3eType.bodyLarge, color: scheme.onSurface);

    return Padding(
      // `.dr-form { margin-bottom: 16px }`
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ярлык вылезает на 8 dp над рамкой: оставляем ему место без сдвига поля.
          Stack(
            clipBehavior: Clip.none,
            children: [
              MouseRegion(
                onEnter: (_) => setState(() => _hover = true),
                onExit: (_) => setState(() => _hover = false),
                child: SizedBox(
                  key: kM3eAddFieldKey,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: border, width: width),
                      borderRadius: BorderRadius.circular(M3eShape.extraSmall),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 52),
                      child: Center(
                        child: Semantics(
                          label: l10n.m3eAddFieldLabel,
                          child: TextField(
                            key: kM3eAddFieldInputKey,
                            controller: widget.controller,
                            focusNode: _focus,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.done,
                            autocorrect: false,
                            enableSuggestions: false,
                            textCapitalization: TextCapitalization.none,
                            maxLines: 1,
                            style: textStyle,
                            cursorColor: scheme.primary,
                            onSubmitted: (_) => widget.onSubmitted(),
                            decoration: InputDecoration.collapsed(
                              hintText: 'https://',
                              hintStyle: m3eTextStyle(
                                M3eType.bodyLarge,
                                color: scheme.onSurfaceVariant,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: -8,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Container(
                      key: kM3eAddFieldLabelKey,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      // Фон ярлыка равен фону листа: он «вырезает» рамку.
                      color: scheme.surfaceContainerLow,
                      child: Text(
                        l10n.m3eAddFieldLabel,
                        maxLines: 1,
                        style: m3eTextStyle(
                          M3eType.bodySmall,
                          color: labelColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 8,
                child: _PasteButton(
                  key: kM3eAddFieldPasteKey,
                  color: scheme.onSurfaceVariant,
                  label: l10n.paste,
                  onPressed: widget.onPaste,
                ),
              ),
            ],
          ),
          if (error)
            Padding(
              key: kM3eAddFieldSupKey,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.m3eAddFieldError,
                  style: m3eTextStyle(M3eType.bodySmall, color: scheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Кнопка-значок 40 без заливки (`iconBtn`), как «Назад» листа: значок onSurfaceVariant.
class _PasteButton extends StatelessWidget {
  const _PasteButton({
    super.key,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  final Color color;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 40,
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              overlayColor: m3eStateLayer(color),
              child: Center(
                child: M3eSymbolIcon(M3eSymbol.contentPaste, color: color),
              ),
            ),
          ),
        ),
      );
}
