// Тексты iOS-редизайна (R8): ru равен тексту доски, в ios27* нет слова «Android», плейсхолдеры и
// склонения работают во всех языках.
//
// Источник текстов — canon `dropweb/app.js` на df156ea1 (номера строк в таблице). Тот же набор
// строк с пояснениями лежит в `.omo/ios/l10n-map.md`. Переиспользованные ключи (m3e* и общие)
// проверяются тем же способом, что и новые `ios27*`: сцена показывает ключ, а не его копию.

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dropweb/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

/// Строка доски и способ получить её из приложения.
class _Row {
  const _Row(
    this.scene,
    this.line,
    this.key,
    this.board,
    this.render, {
    this.isNew = false,
    this.spaceSensitive = true,
  });

  final String scene;

  /// Номер строки `app.js` (или несколько).
  final String line;

  /// Имя ключа в `arb`: нужно только для сообщения об ошибке и для сверки с набором `ios27*`.
  final String key;

  /// Текст, как он нарисован на доске.
  final String board;

  final String Function(AppLocalizations l) render;

  /// Ключ добавлен этой волной (`ios27*`), а не взят готовым.
  final bool isNew;

  /// false: на доске обычный пробел, в приложении неразрывный (`m3eValueMs`, чтобы число не
  /// отрывалось от «мс»). Тогда NBSP перед сравнением приводится к пробелу.
  final bool spaceSensitive;
}

const _ru = Locale('ru');
const _en = Locale('en');
const _ja = Locale('ja');
const _zh = Locale('zh', 'CN');

const _arbFiles = {
  'en': 'arb/intl_en.arb',
  'ru': 'arb/intl_ru.arb',
  'ja': 'arb/intl_ja.arb',
  'zh_CN': 'arb/intl_zh_CN.arb',
};

Map<String, String> _readArb(String locale) {
  final raw = jsonDecode(File(_arbFiles[locale]!).readAsStringSync())
      as Map<String, dynamic>;
  return {for (final e in raw.entries) e.key: e.value as String};
}

/// Имена плейсхолдеров ICU-строки: `{name}` и `{count, plural, …{{count} …}}`.
Set<String> _placeholders(String message) => {
      for (final m in RegExp(r'\{(\w+)(?=[,}])').allMatches(message))
        m.group(1)!,
    }..removeAll(const {'plural'});

// Строки доски. `ios27*` — новые ключи, остальное — готовые (m3e* и общие).
final _rows = <_Row>[
  _Row('home', '532', 'm3eA11yCard', 'Подключение и подписка',
      (l) => l.m3eA11yCard),
  _Row('home', '537', 'm3eStatIp', 'IP-адрес', (l) => l.m3eStatIp),
  _Row('home', '538', 'm3eStatTraffic', 'Трафик', (l) => l.m3eStatTraffic),
  // Решение владельца 30.10: на карточке одна метрика «Страна» вместо «IP-адрес | Трафик».
  _Row('home', '537', 'ios27StatCountry', 'Страна', (l) => l.ios27StatCountry,
      isNew: true),
  _Row('home', '481', 'm3eStatusConnecting', 'Подключение…',
      (l) => l.m3eStatusConnecting),
  _Row(
      'home', '482', 'm3eStatusOffline', 'Нет сети', (l) => l.m3eStatusOffline),
  _Row('home', '483', 'm3eStatusConnected', 'Подключено',
      (l) => l.m3eStatusConnected),
  _Row('home', '484', 'm3eStatusError', 'Сервер не отвечает',
      (l) => l.m3eStatusError),
  _Row('home', '485', 'm3eStatusDisconnected', 'Не подключено',
      (l) => l.m3eStatusDisconnected),
  _Row('home', '518', 'loadingEllipsis', 'Загрузка…', (l) => l.loadingEllipsis),
  _Row(
      'home', '478', 'm3eValueGb', '0,23\u00a0ГБ', (l) => l.m3eValueGb('0,23')),
  _Row('home', '524', 'm3ePlanTrafficOf', '0,23 из 50 ГБ',
      (l) => l.m3ePlanTrafficOf('0,23', '50')),
  _Row(
      'home', '524', 'm3ePlanUnlimited', 'Безлимит', (l) => l.m3ePlanUnlimited),
  _Row('home', '524', 'm3ePlanUntil', 'до 13 января 2027',
      (l) => l.m3ePlanUntil('13 января 2027')),
  _Row('home', '524', 'm3ePlanForever', 'бессрочно', (l) => l.m3ePlanForever),
  _Row('home', '524', 'm3ePlanLine', '0,23 из 50 ГБ · бессрочно',
      (l) => l.m3ePlanLine('0,23 из 50 ГБ', 'бессрочно')),
  _Row('home', '528', 'm3ePlanExpired', 'Подписка закончилась',
      (l) => l.m3ePlanExpired),
  _Row('home', '529', 'm3ePlanTrafficOut', 'Трафик закончился',
      (l) => l.m3ePlanTrafficOut),
  _Row('home', '530', 'm3ePlanDaysLeft', 'Осталось 2 дня',
      (l) => l.m3ePlanDaysLeft(2)),
  _Row('home', '531', 'm3ePlanTrafficLeft', 'Осталось 0,8 ГБ',
      (l) => l.m3ePlanTrafficLeft('0,8')),
  _Row('home', '528, 529', 'm3eRefresh', 'Обновить', (l) => l.m3eRefresh),
  _Row('home', '551', 'm3eA11yDisconnect', 'Отключить VPN',
      (l) => l.m3eA11yDisconnect),
  _Row('home', '551', 'm3eA11yCancel', 'Отменить подключение',
      (l) => l.m3eA11yCancel),
  _Row('home', '551', 'm3eA11yRetry', 'Повторить подключение',
      (l) => l.m3eA11yRetry),
  _Row('home', '551', 'm3eA11yConnect', 'Подключить VPN',
      (l) => l.m3eA11yConnect),
  _Row('home', '554', 'ios27A11yJoy', 'Подключение и страна',
      (l) => l.ios27A11yJoy,
      isNew: true),
  _Row('home', '556', 'm3eSubTitle', 'Подписка', (l) => l.m3eSubTitle),
  _Row('home', '559', 'ios27A11yRoute', 'Маршрут: Авто. Открыть список',
      (l) => l.ios27A11yRoute('Авто'),
      isNew: true),
  _Row('home', '559', 'ios27A11yRoute', 'Маршрут: Нидерланды. Открыть список',
      (l) => l.ios27A11yRoute('Нидерланды'),
      isNew: true),
  _Row('home', '446', 'settings', 'Настройки', (l) => l.settings),
  _Row('empty', '450', 'm3eEmptyTitle', 'Добавьте подписку',
      (l) => l.m3eEmptyTitle),
  _Row('empty', '451', 'm3eEmptyPaste', 'Вставить ссылку',
      (l) => l.m3eEmptyPaste),
  _Row('empty', '452', 'm3eEmptyScanQr', 'Сканировать QR-код',
      (l) => l.m3eEmptyScanQr),
  _Row('disclosure', '801', 'ios27DisclosureTitle', 'Перед подключением',
      (l) => l.ios27DisclosureTitle,
      isNew: true),
  _Row(
      'disclosure',
      '801',
      'ios27DisclosureBody',
      // Решение владельца 30.10: идентификатор устройства отключить нельзя (без него не
      // работает подписка), поэтому оговорки «если это не отключено в настройках»,
      // которая есть на доске (app.js:801), в приложении нет. Остальной текст побайтово
      // равен доске.
      'dropweb создаёт VPN-туннель через конфигурацию VPN, iPhone попросит разрешить её добавить. Трафик идёт через серверы вашей подписки. dropweb не видит и не записывает, что вы делаете в сети. Провайдер подписки получает ваш IP-адрес и идентификатор устройства.',
      (l) => l.ios27DisclosureBody,
      isNew: true),
  _Row('disclosure', '803', 'ios27DisclosurePolicy',
      'Политика конфиденциальности', (l) => l.ios27DisclosurePolicy,
      isNew: true),
  _Row('disclosure', '799', 'cancel', 'Отмена', (l) => l.cancel),
  _Row('disclosure', '802', 'vpnDisclosureContinue', 'Продолжить',
      (l) => l.vpnDisclosureContinue),
  _Row('delete-alert', '804', 'm3eDeleteTitle', 'Удалить «DROPWEB»?',
      (l) => l.m3eDeleteTitle('DROPWEB')),
  _Row('delete-alert', '804', 'm3eDeleteBody',
      'Оплаченная подписка у провайдера останется.', (l) => l.m3eDeleteBody),
  _Row('delete-alert', '799', 'cancel', 'Отмена', (l) => l.cancel),
  _Row('delete-alert', '805', 'delete', 'Удалить', (l) => l.delete),
  _Row('toasts', '199', 'm3eToastSupport', 'Открываем справочную',
      (l) => l.m3eToastSupport),
  _Row('toasts', '200', 'm3eToastRefreshed', 'Подписка обновлена',
      (l) => l.m3eToastRefreshed),
  _Row('toasts', '201', 'ios27ToastQr', 'Здесь откроется камера для QR-кода',
      (l) => l.ios27ToastQr,
      isNew: true),
  _Row('toasts', '202', 'ios27ToastLink', 'Откроется в браузере',
      (l) => l.ios27ToastLink,
      isNew: true),
  _Row('toasts', '203', 'm3eToastRefreshFail', 'Нет связи с сервером',
      (l) => l.m3eToastRefreshFail),
  _Row('route', '655', 'm3eRouteTitle', 'Маршрут', (l) => l.m3eRouteTitle),
  _Row('route', '684', 'm3eRouteAuto', 'Авто', (l) => l.m3eRouteAuto),
  _Row('route', '688', 'm3eRouteAllTraffic', 'Весь трафик через VPN',
      (l) => l.m3eRouteAllTraffic),
  _Row('route', '690', 'm3eServersTitle', 'Серверы и группы',
      (l) => l.m3eServersTitle),
  _Row('route', '297', 'm3eValueMs', '41 мс', (l) => l.m3eValueMs('41'),
      spaceSensitive: false),
  _Row('route', '297', 'm3eMsNoAnswer', 'нет ответа', (l) => l.m3eMsNoAnswer),
  _Row('route', '671', 'm3eA11yBack', 'Назад', (l) => l.m3eA11yBack),
  _Row('route', '713', 'close', 'Закрыть', (l) => l.close),
  _Row('servers', '655', 'm3eServersTitle', 'Серверы и группы',
      (l) => l.m3eServersTitle),
  _Row('servers', '696', 'm3eValueMs', '156 мс', (l) => l.m3eValueMs('156'),
      spaceSensitive: false),
  _Row('servers', '297, 696', 'm3eMsNoAnswer', 'нет ответа',
      (l) => l.m3eMsNoAnswer),
  _Row('group', '704', 'm3eValueMs', '88 мс', (l) => l.m3eValueMs('88'),
      spaceSensitive: false),
  _Row('group', '297, 704', 'm3eMsNoAnswer', 'нет ответа',
      (l) => l.m3eMsNoAnswer),
  _Row('sub', '668', 'm3eSubTitle', 'Подписка', (l) => l.m3eSubTitle),
  _Row('sub', '572', 'm3eRefresh', 'Обновить', (l) => l.m3eRefresh),
  _Row('sub', '251', 'ios27UpdatedMinutesAgo', '1 минуту назад',
      (l) => l.ios27UpdatedMinutesAgo(1),
      isNew: true),
  _Row('sub', '251', 'ios27UpdatedMinutesAgo', '4 минуты назад',
      (l) => l.ios27UpdatedMinutesAgo(4),
      isNew: true),
  _Row('sub', '251', 'ios27UpdatedMinutesAgo', '5 минут назад',
      (l) => l.ios27UpdatedMinutesAgo(5),
      isNew: true),
  _Row('sub', '1231', 'ios27UpdatedJustNow', 'только что',
      (l) => l.ios27UpdatedJustNow,
      isNew: true),
  _Row('sub', '—', 'ios27UpdatedHoursAgo', '2 часа назад',
      (l) => l.ios27UpdatedHoursAgo(2),
      isNew: true),
  _Row('sub', '—', 'ios27UpdatedDaysAgo', '3 дня назад',
      (l) => l.ios27UpdatedDaysAgo(3),
      isNew: true),
  _Row('sub', '572', 'm3eSubSupport', 'Справочная', (l) => l.m3eSubSupport),
  _Row('sub', '575', 'addSubscription', 'Добавить подписку',
      (l) => l.addSubscription),
  _Row('sub', '577', 'm3eSubDelete', 'Удалить подписку', (l) => l.m3eSubDelete),
  _Row('sub', '671', 'm3eA11yBack', 'Назад', (l) => l.m3eA11yBack),
  _Row('sub', '713', 'close', 'Закрыть', (l) => l.close),
  _Row('add', '668, 722', 'addSubscription', 'Добавить подписку',
      (l) => l.addSubscription),
  _Row('add', '659, 660', 'm3eAddFieldLabel', 'Ссылка на подписку',
      (l) => l.m3eAddFieldLabel),
  _Row('add', '660', 'paste', 'Вставить', (l) => l.paste),
  _Row('add', '658', 'm3eAddFieldError', 'Ссылка должна начинаться с https://',
      (l) => l.m3eAddFieldError),
  _Row('add', '663', 'm3eEmptyScanQr', 'Сканировать QR-код',
      (l) => l.m3eEmptyScanQr),
  _Row('add', '665', 'add', 'Добавить', (l) => l.add),
  _Row('add', '671', 'm3eA11yBack', 'Назад', (l) => l.m3eA11yBack),
  _Row('add', '713', 'close', 'Закрыть', (l) => l.close),
  _Row('settings', '601', 'settings', 'Настройки', (l) => l.settings),
  _Row('settings', '602', 'language', 'Язык', (l) => l.language),
  _Row('settings', '602', 'm3eAppearanceTitle', 'Оформление',
      (l) => l.m3eAppearanceTitle),
  _Row('settings', '604', 'm3eAboutTitle', 'О программе',
      (l) => l.m3eAboutTitle),
  _Row('settings', '581', 'ios27AppearanceOwn', 'Свои',
      (l) => l.ios27AppearanceOwn,
      isNew: true),
  _Row('settings', '581', 'ios27AppearanceProvider', 'Провайдер',
      (l) => l.ios27AppearanceProvider,
      isNew: true),
  _Row('settings', '598', 'm3eA11yBack', 'Назад', (l) => l.m3eA11yBack),
  _Row('language', '606', 'language', 'Язык', (l) => l.language),
  _Row('language', '197, 586', 'm3eLangSystem', 'Как в системе',
      (l) => l.m3eLangSystem),
  _Row('appearance', '620', 'm3eAppearanceTitle', 'Оформление',
      (l) => l.m3eAppearanceTitle),
  _Row('appearance', '621', 'ios27GlassTitle', 'Стекло',
      (l) => l.ios27GlassTitle,
      isNew: true),
  _Row('appearance', '623', 'ios27GlassTitle', 'Стекло',
      (l) => l.ios27GlassTitle,
      isNew: true),
  _Row('appearance', '624', 'ios27GlassCapClear', 'Прозрачное',
      (l) => l.ios27GlassCapClear,
      isNew: true),
  _Row('appearance', '624', 'ios27GlassTinted', 'Тонированное',
      (l) => l.ios27GlassTinted,
      isNew: true),
  _Row('appearance', '425', 'ios27GlassClearer', 'Прозрачнее',
      (l) => l.ios27GlassClearer,
      isNew: true),
  _Row('appearance', '425', 'ios27GlassStandard', 'Стандартное',
      (l) => l.ios27GlassStandard,
      isNew: true),
  _Row('appearance', '425', 'ios27GlassDenser', 'Плотнее',
      (l) => l.ios27GlassDenser,
      isNew: true),
  _Row('appearance', '425', 'ios27GlassTinted', 'Тонированное',
      (l) => l.ios27GlassTinted,
      isNew: true),
  _Row('appearance', '626', 'ios27AppearanceColors', 'Цвета',
      (l) => l.ios27AppearanceColors,
      isNew: true),
  // Строки «Темы» на доске нет: ключ заведён для страницы «Оформление» (W4a).
  _Row('appearance', '—', 'ios27AppearanceThemes', 'Темы',
      (l) => l.ios27AppearanceThemes,
      isNew: true),
  _Row('appearance', '627', 'ios27AppearanceProvider', 'Провайдер',
      (l) => l.ios27AppearanceProvider,
      isNew: true),
  _Row('appearance', '627', 'ios27AppearanceOwn', 'Свои',
      (l) => l.ios27AppearanceOwn,
      isNew: true),
  _Row('appearance', '128', 'ios27ColorSlotAccent', 'Кнопки',
      (l) => l.ios27ColorSlotAccent,
      isNew: true),
  _Row('appearance', '128', 'ios27ColorSlotOrb1', 'Фон сверху',
      (l) => l.ios27ColorSlotOrb1,
      isNew: true),
  _Row('appearance', '128', 'ios27ColorSlotOrb2', 'Фон снизу',
      (l) => l.ios27ColorSlotOrb2,
      isNew: true),
  _Row('colors', '744', 'ios27ColorSheetLabel', 'Цвет: Кнопки',
      (l) => l.ios27ColorSheetLabel('Кнопки'),
      isNew: true),
  _Row('colors', '744', 'ios27ColorSheetLabel', 'Цвет: Фон сверху',
      (l) => l.ios27ColorSheetLabel('Фон сверху'),
      isNew: true),
  _Row('colors', '744', 'ios27ColorSheetLabel', 'Цвет: Фон снизу',
      (l) => l.ios27ColorSheetLabel('Фон снизу'),
      isNew: true),
  _Row('colors', '104', 'ios27PresetBlue', 'Синий', (l) => l.ios27PresetBlue,
      isNew: true),
  _Row('colors', '105', 'ios27PresetPurple', 'Фиолетовый',
      (l) => l.ios27PresetPurple,
      isNew: true),
  _Row('colors', '106', 'ios27PresetPink', 'Розовый', (l) => l.ios27PresetPink,
      isNew: true),
  _Row('colors', '107', 'ios27PresetRed', 'Красный', (l) => l.ios27PresetRed,
      isNew: true),
  _Row('colors', '108', 'ios27PresetOrange', 'Оранжевый',
      (l) => l.ios27PresetOrange,
      isNew: true),
  _Row('colors', '109', 'ios27PresetYellow', 'Жёлтый',
      (l) => l.ios27PresetYellow,
      isNew: true),
  _Row(
      'colors', '110', 'ios27PresetGreen', 'Зелёный', (l) => l.ios27PresetGreen,
      isNew: true),
  _Row('colors', '111', 'ios27PresetGraphite', 'Графитовый',
      (l) => l.ios27PresetGraphite,
      isNew: true),
  _Row('colors', '713', 'close', 'Закрыть', (l) => l.close),
  _Row('about', '592', 'm3eAboutTitle', 'О программе', (l) => l.m3eAboutTitle),
  _Row('about', '631', 'm3eAboutVersion', 'Версия 0.10.3, ядро 1.19.31',
      (l) => l.m3eAboutVersion('0.10.3', '1.19.31')),
  _Row('about', '635', 'm3eAboutSite', 'Сайт проекта', (l) => l.m3eAboutSite),
  _Row('about', '635', 'm3eAboutPrivacy', 'Политика конфиденциальности',
      (l) => l.m3eAboutPrivacy),
];

void main() {
  group('ru: каждая строка iOS-колонки равна тексту доски', () {
    late AppLocalizations l;

    setUp(() async {
      l = await AppLocalizations.load(_ru);
    });

    for (final row in _rows) {
      test('${row.scene} · ${row.key} (app.js:${row.line})', () {
        var actual = row.render(l);
        if (!row.spaceSensitive) {
          actual = actual.replaceAll('\u00a0', ' ');
        }
        expect(actual, row.board);
      });
    }
  });

  group('набор ключей ios27*', () {
    final arb = {for (final loc in _arbFiles.keys) loc: _readArb(loc)};
    final ios = {
      for (final loc in _arbFiles.keys)
        loc: {
          for (final e in arb[loc]!.entries)
            if (e.key.startsWith('ios27')) e.key: e.value,
        },
    };

    test(
        'таблица доски покрывает все ключи ios27* и ничего лишнего не называет',
        () {
      final inTable = {
        for (final r in _rows)
          if (r.isNew) r.key,
      };
      expect(inTable, ios['ru']!.keys.toSet());
      // Помеченный новым ключ обязан носить префикс, а готовый — не носить.
      for (final r in _rows) {
        expect(r.key.startsWith('ios27'), r.isNew, reason: r.key);
      }
    });

    test('во всех четырёх языках один и тот же набор ключей', () {
      final ru = ios['ru']!.keys.toSet();
      for (final loc in _arbFiles.keys) {
        expect(ios[loc]!.keys.toSet(), ru, reason: loc);
      }
    });

    test('плейсхолдеры совпадают во всех языках', () {
      for (final key in ios['ru']!.keys) {
        final ru = _placeholders(ios['ru']![key]!);
        for (final loc in _arbFiles.keys) {
          expect(_placeholders(ios[loc]![key]!), ru, reason: '$loc · $key');
        }
      }
    });

    test('в ios27* нет слова Android ни в одном языке (App Store 2.3.10)', () {
      for (final loc in _arbFiles.keys) {
        for (final e in ios[loc]!.entries) {
          expect(e.value.toLowerCase().contains('android'), isFalse,
              reason: '$loc · ${e.key}');
        }
      }
    });

    // Переведённые на ja и zh_CN ключи (решение владельца 30.10): раскрытие VPN перед
    // подключением (юридический текст, App Store 5.4) и название раздела «Темы». Все
    // остальные ios27* в ja и zh_CN пока английские.
    const translated = {
      'ios27DisclosureTitle',
      'ios27DisclosureBody',
      'ios27DisclosurePolicy',
      'ios27AppearanceThemes',
      'ios27StatCountry',
    };

    test('en, ja и zh_CN: английский текст, без кириллицы и иероглифов', () {
      for (final loc in ['en', 'ja', 'zh_CN']) {
        for (final e in ios[loc]!.entries) {
          if (loc != 'en' && translated.contains(e.key)) continue;
          expect(
              RegExp(r'[А-Яа-яЁё\u3040-\u30ff\u4e00-\u9fff]').hasMatch(e.value),
              isFalse,
              reason: '$loc · ${e.key}');
        }
      }
      for (final key in ios['en']!.keys) {
        if (translated.contains(key)) continue;
        expect(ios['ja']![key], ios['en']![key], reason: 'ja · $key');
        expect(ios['zh_CN']![key], ios['en']![key], reason: 'zh_CN · $key');
      }
    });

    test('раскрытие VPN и «Темы» переведены на ja и zh_CN, не английский', () {
      for (final loc in ['ja', 'zh_CN']) {
        for (final key in translated) {
          final value = ios[loc]![key]!;
          expect(value, isNot(ios['en']![key]), reason: '$loc · $key');
          expect(
              RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]').hasMatch(value), isTrue,
              reason: '$loc · $key');
        }
      }
      expect(ios['ja']!['ios27DisclosurePolicy'], 'プライバシーポリシー');
      expect(ios['zh_CN']!['ios27DisclosurePolicy'], '隐私政策');
      expect(ios['ja']!['ios27AppearanceThemes'], 'テーマ');
      expect(ios['zh_CN']!['ios27AppearanceThemes'], '主题');
    });

    test(
        'раскрытие VPN не обещает отключить идентификатор устройства (hwid '
        'обязателен для подписки)', () {
      // Оговорки «если не отключено в настройках» на каждом языке: ни одной.
      const promises = {
        'ru': ['отключено', 'отключить', 'выключ', 'в настройках'],
        'en': ['unless', 'disabled', 'turn off', 'in settings', 'opt out'],
        'ja': ['設定で', '無効', 'オフ'],
        'zh_CN': ['设置中', '关闭', '禁用'],
      };
      for (final loc in promises.keys) {
        final body = ios[loc]!['ios27DisclosureBody']!;
        for (final phrase in promises[loc]!) {
          expect(body.toLowerCase().contains(phrase), isFalse,
              reason: '$loc · «$phrase» в ios27DisclosureBody');
        }
      }
    });

    test('в тексте раскрытия на каждом языке названы IP-адрес и идентификатор',
        () {
      const needles = {
        'ru': ['IP-адрес', 'идентификатор устройства'],
        'en': ['IP address', 'device ID'],
        'ja': ['IPアドレス', 'デバイス識別子'],
        'zh_CN': ['IP 地址', '设备标识符'],
      };
      for (final loc in needles.keys) {
        final body = ios[loc]!['ios27DisclosureBody']!;
        for (final n in needles[loc]!) {
          expect(body, contains(n), reason: loc);
        }
        // Бренд и платформа остаются латиницей, слова Android нет (App Store 2.3.10).
        expect(body, contains('dropweb'), reason: loc);
        expect(body, contains('iPhone'), reason: loc);
        expect(body, contains('VPN'), reason: loc);
      }
    });

    test('старые тексты раскрытия не тронуты (Android и старый интерфейс)', () {
      final ru = arb['ru']!;
      expect(ru.containsKey('vpnDisclosureBodyIos'), isTrue);
      expect(ru.containsKey('vpnDisclosureBody'), isTrue);
      expect(ru.containsKey('m3eDisclosureTitle'), isTrue);
      expect(ru['m3eDisclosureBody'], contains('Android'));
      expect(ru['ios27DisclosureBody'], isNot(ru['m3eDisclosureBody']));
    });
  });

  group('ru: склонения', () {
    late AppLocalizations l;

    setUp(() async {
      l = await AppLocalizations.load(_ru);
    });

    test('минуты: 0, 1, 2, 5, 11, 21, 22', () {
      expect({
        for (final n in [0, 1, 2, 5, 11, 21, 22]) n: l.ios27UpdatedMinutesAgo(n)
      }, {
        0: '0 минут назад',
        1: '1 минуту назад',
        2: '2 минуты назад',
        5: '5 минут назад',
        11: '11 минут назад',
        21: '21 минуту назад',
        22: '22 минуты назад',
      });
    });

    test('часы: 1, 2, 5, 11, 21', () {
      expect({
        for (final n in [1, 2, 5, 11, 21]) n: l.ios27UpdatedHoursAgo(n)
      }, {
        1: '1 час назад',
        2: '2 часа назад',
        5: '5 часов назад',
        11: '11 часов назад',
        21: '21 час назад',
      });
    });

    test('дни: 1, 2, 5, 11, 21', () {
      expect({
        for (final n in [1, 2, 5, 11, 21]) n: l.ios27UpdatedDaysAgo(n)
      }, {
        1: '1 день назад',
        2: '2 дня назад',
        5: '5 дней назад',
        11: '11 дней назад',
        21: '21 день назад',
      });
    });

    test('имя подставляется в подпись маршрута и листа цвета', () {
      expect(l.ios27A11yRoute('Нидерланды'),
          'Маршрут: Нидерланды. Открыть список');
      expect(l.ios27ColorSheetLabel('Фон сверху'), 'Цвет: Фон сверху');
    });
  });

  group('en, ja, zh_CN: плейсхолдеры и склонения', () {
    for (final locale in [_en, _ja, _zh]) {
      test(
          '${locale.toLanguageTag()}: 1 в единственном числе, 2 и 5 во множественном',
          () async {
        final l = await AppLocalizations.load(locale);
        expect(l.ios27UpdatedMinutesAgo(1), '1 minute ago');
        expect(l.ios27UpdatedMinutesAgo(2), '2 minutes ago');
        expect(l.ios27UpdatedMinutesAgo(5), '5 minutes ago');
        expect(l.ios27UpdatedHoursAgo(1), '1 hour ago');
        expect(l.ios27UpdatedHoursAgo(5), '5 hours ago');
        expect(l.ios27UpdatedDaysAgo(1), '1 day ago');
        expect(l.ios27UpdatedDaysAgo(5), '5 days ago');
      });

      test('${locale.toLanguageTag()}: имя и слот подставляются', () async {
        final l = await AppLocalizations.load(locale);
        expect(l.ios27A11yRoute('Auto'), 'Route: Auto. Open list');
        expect(l.ios27ColorSheetLabel('Buttons'), 'Color: Buttons');
      });
    }
  });
}
