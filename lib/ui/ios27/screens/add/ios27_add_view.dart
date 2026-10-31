// Форма «Добавить подписку» iOS-редизайна: поле ссылки, «Вставить», QR, подвал «Добавить» (доска addForm/addSubmit, app.js:657-665).
//
// Одна форма на два входа: самостоятельный лист с пустого экрана (`showIos27AddSheet`) и второй
// уровень листа «Подписка» (`pushIos27AddStep`). Данные и действия берутся из M3E-провайдеров без
// правок: импорт, разбор ссылки и сканер QR общие с Android.

import 'dart:async';

import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/theme/ios27_text.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart' show Ios27Text;
import 'package:dropweb/ui/ios27/widgets/ios27_avatar.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_button.dart';
import 'package:dropweb/ui/ios27/widgets/ios27_list.dart';
import 'package:dropweb/ui/m3e/screens/m3e_add_subscription.dart'
    show m3eAddImportProvider, m3eAddParseUrl, m3eAddScanProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключи частей: имена как в `test/ios27/ref/layout.json`.
const Key kIos27AddFieldKey = ValueKey<String>('sheet.field');
const Key kIos27AddFieldInputKey = ValueKey<String>('sheet.fieldInput');
const Key kIos27AddFieldPasteKey = ValueKey<String>('sheet.fieldPaste');
const Key kIos27AddFieldErrorKey = ValueKey<String>('sheet.fieldError');
const Key kIos27AddSubmitButtonKey = ValueKey<String>('sheet.addBtn');
const Key kIos27AddFootKey = ValueKey<String>('sheet.foot');
const Key kIos27AddSubmitKey = ValueKey<String>('sheet.submit');
const Key kIos27AddQrRowKey = ValueKey<String>('ios27.add.qr');

/// Отступ подвала снизу (`.sheet__foot{padding:12px 16px 34px}`, app.css:365).
const double kIos27AddFootBottom = 34;

/// Отступ подвала снизу над клавиатурой: лист уже стоит над ней, индикатора «домой» под
/// кнопкой нет, и 34 dp только отняли бы место у поля.
const double kIos27AddFootBottomKeyboard = 12;

/// Содержимое формы: прокручиваемая часть и подвал с «Добавить».
///
/// Кнопка «Добавить» всегда прижата к низу листа и не прокручивается. На доске у шага листа она
/// лежит в самом экране (`.sheet__submit`), но у короткой формы геометрия та же (низ листа,
/// отступ 34), а у длинной (клавиатура, крупный шрифт) кнопка в прокрутке уехала бы за край.
///
/// Клавиатуру считает лист: он поднимается над ней и отдаёт содержимому `viewInsets` без низа,
/// поэтому здесь отступа под клавиатуру нет (урок 26: дважды считать нельзя).
class Ios27AddView extends ConsumerStatefulWidget {
  const Ios27AddView({
    super.key,
    this.initialUrl,
    this.step = false,
    this.onDone,
  });

  /// Предзаполнение поля, например ссылка из буфера обмена.
  final String? initialUrl;

  /// Форма как второй уровень листа «Подписка»: подвал ключится как `sheet.submit`.
  final bool step;

  /// Закрыть лист после отправки. По умолчанию закрывается корневой маршрут листа.
  final VoidCallback? onDone;

  @override
  ConsumerState<Ios27AddView> createState() => _Ios27AddViewState();
}

class _Ios27AddViewState extends ConsumerState<Ios27AddView>
    with WidgetsBindingObserver {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl ?? '')
      ..addListener(_onText);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..removeListener(_onText)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Клавиатура появилась или ушла: от неё зависит только отступ подвала.
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  late String _lastText = widget.initialUrl ?? '';

  void _onText() {
    // Слушатель вызывается и при движении курсора: перерисовка только при смене текста.
    final text = _controller.text;
    if (text == _lastText) return;
    _lastText = text;
    // Ошибка относилась к прежнему вводу: правка снимает её.
    setState(() => _error = false);
  }

  void _close() {
    final onDone = widget.onDone;
    if (onDone != null) {
      onDone();
    } else {
      // Корневой pop: после отправки уходит весь лист, а не один шаг стека.
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _submit() {
    final url = m3eAddParseUrl(_controller.text);
    if (url == null) {
      setState(() => _error = true);
      _focus.requestFocus();
      return;
    }
    final import = ref.read(m3eAddImportProvider);
    // Сначала закрывается лист, потом идёт импорт: контроллер ведёт главный экран через
    // глобальный навигатор, а не через контекст листа (порядок прежнего `AddProfileView`).
    _close();
    unawaited(import(url));
  }

  /// Подставляет ссылку из буфера; ошибка снимается. Буфер читается только по касанию.
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

  /// Высота клавиатуры в dp. Лист убирает `viewInsets` у содержимого, поэтому читаем окно.
  double _keyboard() {
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Ios27Colors.of(context);
    final palette = colors.palette;

    final field = Container(
      key: kIos27AddFieldKey,
      padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      child: Row(
        children: [
          Expanded(
            child: ConstrainedBox(
              key: kIos27AddFieldInputKey,
              constraints: const BoxConstraints(minHeight: kIos27RowMinHeight),
              child: Center(
                child: Semantics(
                  label: l10n.m3eAddFieldLabel,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    maxLines: 1,
                    style: ios27Text(context, Ios27Text.body),
                    cursorColor: colors.accentColor,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration.collapsed(
                      hintText: 'https://',
                      hintStyle: ios27Text(
                        context,
                        Ios27Text.body,
                        color: palette.label3,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Ios27Button(
            key: kIos27AddFieldPasteKey,
            label: l10n.paste,
            size: Ios27ButtonSize.small,
            onPressed: () => unawaited(_paste()),
          ),
        ],
      ),
    );

    final error = _error
        ? Padding(
            key: kIos27AddFieldErrorKey,
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
            child: Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Ios27Icon(
                      Ios27IconName.alert,
                      size: 16,
                      color: palette.redText,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.m3eAddFieldError,
                      style: ios27Text(
                        context,
                        Ios27Text.footnote,
                        color: palette.redText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : null;

    final scroll = SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Ios27GroupHead(l10n.m3eAddFieldLabel),
          Ios27List(children: [field]),
          if (error != null) error,
          const Ios27Gap(),
          Ios27List(
            children: [
              Ios27ListRow(
                key: kIos27AddQrRowKey,
                title: l10n.m3eEmptyScanQr,
                leading: const Ios27Avatar.icon(Ios27IconName.qr),
                onTap: () => unawaited(_scan()),
              ),
            ],
          ),
        ],
      ),
    );

    final bottom =
        _keyboard() > 0 ? kIos27AddFootBottomKeyboard : kIos27AddFootBottom;
    final enabled = _controller.text.trim().isNotEmpty;
    final submit = Padding(
      key: widget.step ? kIos27AddSubmitKey : null,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Ios27Button(
        key: kIos27AddSubmitButtonKey,
        label: l10n.add,
        style: Ios27ButtonStyle.prominent,
        block: true,
        onPressed: enabled ? _submit : null,
      ),
    );
    final foot = Column(
      key: widget.step ? null : kIos27AddFootKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [submit, SizedBox(height: bottom)],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [scroll, foot],
          );
        }
        // Подвал прижат к низу листа: тело занимает всё, что лист отдал.
        return SizedBox(
          height: constraints.maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: scroll), foot],
          ),
        );
      },
    );
  }
}
