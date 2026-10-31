// Данные карточки главной: все строки уже отформатированы, виджет ничего не читает из провайдеров и l10n.
//
// Состав полей — карточка №4 «Компактная плашка» (canon/.omo/hig-cards/index.html, `stateModel`
// и render() варианта v4) вместо карточки `hc` основной доски (владелец, 30.10).

import 'package:flutter/foundation.dart';

/// Вид точки статуса: серая (`off`, `busy`), зелёная (`on`), красная (`bad`).
///
/// `busy` отличается от `off` только смыслом («идёт подключение»): точка статического размера,
/// без пульса и кольца, потому что карточка больше не двигается сама по себе (батарея).
enum Ios27DotKind { off, busy, on, bad }

/// Тон строки тарифа: обычный (`glass-label-2`), предупреждение (`orange-text`), ошибка (`red-text`).
enum Ios27CardTone { normal, warn, bad }

/// Содержимое карточки `hc` на любой из сцен главной.
///
/// Сборку из провайдеров и локализации делает экран; здесь только то, что нужно для рисования.
/// Поля про тексты доски указывают, откуда строка (`NORMAL` — набор фикстур `board_fixtures.dart`).
@immutable
class Ios27CardData {
  const Ios27CardData({
    required this.title,
    required this.dot,
    required this.planText,
    required this.countryLabel,
    required this.countryLoadingLabel,
    required this.semanticsLabel,
    this.statusText = '',
    this.since,
    this.planTone = Ios27CardTone.normal,
    this.meterPercent,
    this.countryText,
    this.countryFlag = '',
    this.countryPending = false,
    this.countryPlaceholder = '—',
    this.announce = '',
    this.refreshLabel,
  });

  /// Имя профиля (`v4-name`), как пришло из заголовка подписки.
  ///
  /// Ведущий эмодзи (D6) на карточке не выносится в аватар, это делает только список профилей.
  /// Поэтому строка идёт в виджет как есть.
  final String title;

  /// Вид точки слева от слова статуса в нижней строке.
  final Ios27DotKind dot;

  /// Слово статуса справа в нижней строке («Подключено», «Не подключено», «Нет сети», «Сервер не
  /// отвечает»). Не показывается, пока определяется страна ([countryPending]) или есть кнопка
  /// [refreshLabel]: на этом месте они. Читает его и VoiceOver в общей подписи карточки.
  final String statusText;

  /// Начало сеанса: не `null` — справа в шапке идёт таймер `m:ss`, раз в секунду, обычным текстом.
  final DateTime? since;

  /// Строка тарифа (`hc__line`): «Безлимит · бессрочно», «Осталось 2 дня», «Осталось 0,8 ГБ»,
  /// «Трафик закончился», «Подписка закончилась».
  final String planText;

  /// Тон [planText].
  final Ios27CardTone planTone;

  /// Заполнение шкалы квоты, 0..100; `null` — шкалы нет (безлимит или подписка закончилась).
  /// Цвет выводится из значения, как на доске: > 90 оранжевый, ≥ 100 красный.
  final double? meterPercent;

  /// Слово «Страна»: на карточке не рисуется (в №4 страну опознаёт флаг), нужно для общей подписи
  /// VoiceOver («Страна: Нидерланды»).
  final String countryLabel;

  /// Название страны выхода на языке приложения. Если страна неизвестна, а адрес есть, сюда
  /// кладётся замаскированный адрес («94.183.•••.•••»); полный адрес в карточку не попадает.
  /// `null` без [countryPending] — данных нет (нет сети), вместо них [countryPlaceholder].
  final String? countryText;

  /// Эмодзи флага страны перед названием; пусто — без плитки флага.
  final String countryFlag;

  /// Страна ещё определяется (подключение): вместо флага и названия крутится индикатор
  /// активности с подписью [countryLoadingLabel] (D9).
  final bool countryPending;

  /// Знак «данных нет» на месте названия: «—» только когда сети нет совсем.
  final String countryPlaceholder;

  /// Подпись рядом с индикатором, пока страна определяется: «Подключение…».
  final String countryLoadingLabel;

  /// Объявление провайдера. Рисуется не в карточке, а подвалом под ней (`Ios27CardFooter`):
  /// `https?://…` в нём подчёркнуто и нажимается. Пусто — подвала нет.
  final String announce;

  /// Подпись действия «Обновить» справа в нижней строке (подписка или трафик закончились);
  /// `null` — без действия.
  final String? refreshLabel;

  /// Подпись карточки для VoiceOver одной фразой: имя, тариф, страна, статус. Собирает адаптер,
  /// у которого есть локализация; «Обновить» читается отдельной кнопкой.
  final String semanticsLabel;

  /// Идёт ли сеанс: есть метка начала, значит и таймер.
  bool get live => since != null;

  /// Сети нет: страна не определена и не определяется.
  bool get offline => countryText == null && !countryPending;

  @override
  bool operator ==(Object other) =>
      other is Ios27CardData &&
      other.title == title &&
      other.dot == dot &&
      other.statusText == statusText &&
      other.since == since &&
      other.planText == planText &&
      other.planTone == planTone &&
      other.meterPercent == meterPercent &&
      other.countryLabel == countryLabel &&
      other.countryText == countryText &&
      other.countryFlag == countryFlag &&
      other.countryPending == countryPending &&
      other.countryPlaceholder == countryPlaceholder &&
      other.countryLoadingLabel == countryLoadingLabel &&
      other.announce == announce &&
      other.refreshLabel == refreshLabel &&
      other.semanticsLabel == semanticsLabel;

  @override
  int get hashCode => Object.hash(
        title,
        dot,
        statusText,
        since,
        planText,
        planTone,
        meterPercent,
        countryLabel,
        countryText,
        countryFlag,
        countryPending,
        countryPlaceholder,
        countryLoadingLabel,
        announce,
        refreshLabel,
        semanticsLabel,
      );
}
