// Раскладка эталонов доски (`test/ios27/ref/layout.json`) и сверка с ней рамок виджетов (G4).
//
// Файл снимает `tool/canon/shoot_board_ios.mjs`: для каждой сцены × тема × режим прозрачности ×
// провайдер он хранит рамки именованных элементов в CSS px относительно `[data-col="ios"] .app`.
// Корень приложения во Flutter лежит в (0, 0), поэтому `tester.getRect` сравнивается с ними напрямую.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Offset, Rect;

import 'package:flutter/rendering.dart' show RenderBox;
import 'package:flutter/widgets.dart' show Element;
import 'package:flutter_test/flutter_test.dart';

const String _layoutPath = 'test/ios27/ref/layout.json';

Map<String, dynamic>? _json;

Map<String, dynamic> _loadJson() {
  final cached = _json;
  if (cached != null) {
    return cached;
  }
  final file = File(_layoutPath);
  if (!file.existsSync()) {
    fail(
      'Нет $_layoutPath: эталоны раскладки снимает T1 (node tool/canon/shoot_board_ios.mjs).',
    );
  }
  return _json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Rect _rectOf(Object? raw) {
  final m = raw! as Map<String, dynamic>;
  return Rect.fromLTWH(
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['w'] as num).toDouble(),
    (m['h'] as num).toDouble(),
  );
}

/// Рамки имитаций системного UI доски: во Flutter их рисует система, golden закрашивает эти места.
class Ios27RefMask {
  const Ios27RefMask({required this.statusBar, required this.homeIndicator});

  /// Нарисованная строка состояния доски (`.sys-bar`): 411×40.
  final Rect statusBar;

  /// Индикатор «домой» (`.sys-gesture`): 108×4 у нижнего края.
  final Rect homeIndicator;
}

/// Одна запись `layout.json`: корень, именованные элементы и маски.
class Ios27RefLayout {
  const Ios27RefLayout._({
    required this.key,
    required this.root,
    required this.rects,
    required this.mask,
  });

  /// Читает запись `<сцена>-<тема>-<norm|rt>-p<N>`, например `home-off-light-norm-p0`.
  factory Ios27RefLayout.load(String key) {
    final all = _loadJson();
    final entry = all[key];
    if (entry == null) {
      final near = all.keys
          .where((k) => k.startsWith(key.split('-').first))
          .take(6)
          .join(', ');
      fail(
        'В layout.json нет записи "$key" (всего ${all.length}). Ключи — '
        '<сцена>-<light|dark>-<norm|rt>-p<0|5>. Рядом: $near',
      );
    }
    final e = entry as Map<String, dynamic>;
    final rootRaw = e['root'] as Map<String, dynamic>;
    final elements = e['elements'] as Map<String, dynamic>;
    final maskRaw = e['mask'] as Map<String, dynamic>;
    return Ios27RefLayout._(
      key: key,
      root: Rect.fromLTWH(
        0,
        0,
        (rootRaw['w'] as num).toDouble(),
        (rootRaw['h'] as num).toDouble(),
      ),
      rects: {
        for (final el in elements.entries)
          el.key: switch (el.value) {
            null => const <Rect>[],
            final List<dynamic> list => list.map(_rectOf).toList(),
            final other => [_rectOf(other)],
          },
      },
      mask: Ios27RefMask(
        statusBar: _rectOf(maskRaw['statusBar']),
        homeIndicator: _rectOf(maskRaw['homeIndicator']),
      ),
    );
  }

  /// Ключ записи.
  final String key;

  /// Корень `.app`: 411×914 в начале координат.
  final Rect root;

  /// Все рамки по имени. Пустой список значит «элемента нет в кадре»; элементы-списки
  /// (`card.stat`, `page.group`) дают несколько рамок в порядке документа.
  final Map<String, List<Rect>> rects;

  /// Рамки имитаций системного UI.
  final Ios27RefMask mask;

  /// Первая рамка элемента или `null`, если его в кадре нет.
  Rect? element(String name) {
    final list = rects[name];
    return list == null || list.isEmpty ? null : list.first;
  }

  /// Рамки элемента, которых может быть несколько.
  List<Rect> all(String name) => rects[name] ?? const <Rect>[];

  /// Первые рамки всех элементов (`null` у отсутствующих).
  Map<String, Rect?> get elements => {
        for (final name in rects.keys) name: element(name),
      };
}

/// Строка таблицы сверки: рамка на доске и во Flutter, разности и признак «в допуске».
class Ios27ParityRow {
  const Ios27ParityRow({
    required this.name,
    required this.ref,
    required this.app,
    required this.tol,
  });

  /// Имя элемента (у элементов-списков с индексом: `card.stat[1]`).
  final String name;

  /// Рамка на доске; `null`, если на доске элемента нет.
  final Rect? ref;

  /// Рамка во Flutter; `null`, если виджета нет.
  final Rect? app;

  /// Допуск, px.
  final double tol;

  double get dx => _diff((r, a) => a.left - r.left);
  double get dy => _diff((r, a) => a.top - r.top);
  double get dw => _diff((r, a) => a.width - r.width);
  double get dh => _diff((r, a) => a.height - r.height);

  double _diff(double Function(Rect ref, Rect app) f) {
    final r = ref;
    final a = app;
    return r == null || a == null ? double.nan : f(r, a);
  }

  /// Наибольшее по модулю из четырёх отклонений; `NaN`, если рамки нет с одной из сторон.
  double get worst {
    final values = [dx, dy, dw, dh];
    if (values.any((v) => v.isNaN)) {
      return double.nan;
    }
    return values.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
  }

  /// В допуске. Нет с обеих сторон — тоже норма; нет только с одной — расхождение.
  bool get ok {
    if (ref == null && app == null) {
      return true;
    }
    final w = worst;
    return !w.isNaN && w <= tol;
  }

  static String _fmt(Rect? r) => r == null
      ? '—'
      : '${r.left.toStringAsFixed(1)}, ${r.top.toStringAsFixed(1)}, '
          '${r.width.toStringAsFixed(1)}×${r.height.toStringAsFixed(1)}';

  static String _d(double v) => v.isNaN ? '—' : v.toStringAsFixed(1);

  /// Строка markdown-таблицы.
  String toMarkdown() =>
      '| $name | ${_fmt(ref)} | ${_fmt(app)} | ${_d(dx)} | ${_d(dy)} | ${_d(dw)} | ${_d(dh)} | '
      '${ok ? 'да' : 'НЕТ'} |';
}

/// Сверяет рамки виджетов с эталоном [refKey] и возвращает строки таблицы.
///
/// [elements] — имя элемента из `layout.json` и искатель его виджета. Если искатель находит
/// несколько виджетов, они сравниваются по порядку с рамками-списком эталона; лишние и недостающие
/// дают строки вне допуска. Элемент без виджета и без рамки на доске — норма.
///
/// Только при заданной переменной окружения `IOS27_PARITY_TABLE` (абсолютный путь) строки
/// дописываются в этот файл markdown-таблицей; без неё тест ничего не пишет на диск.
List<Ios27ParityRow> ios27Parity(
  WidgetTester tester,
  String refKey,
  Map<String, Finder> elements, {
  double tol = 4,
}) {
  final layout = Ios27RefLayout.load(refKey);
  final rows = <Ios27ParityRow>[];
  for (final entry in elements.entries) {
    final refs = layout.all(entry.key);
    final apps = entry.value.evaluate().map(_rectOfElement).toList();
    final count = refs.length > apps.length ? refs.length : apps.length;
    if (count == 0) {
      rows.add(Ios27ParityRow(name: entry.key, ref: null, app: null, tol: tol));
      continue;
    }
    for (var i = 0; i < count; i++) {
      rows.add(
        Ios27ParityRow(
          name: count == 1 ? entry.key : '${entry.key}[$i]',
          ref: i < refs.length ? refs[i] : null,
          app: i < apps.length ? apps[i] : null,
          tol: tol,
        ),
      );
    }
  }
  _appendTable(refKey, rows);
  return rows;
}

// Рамка виджета в координатах окна: `tester.getRect` принимает ровно один виджет, а искателю
// элемента-списка нужны все.
Rect _rectOfElement(Element element) {
  final box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

void _appendTable(String refKey, List<Ios27ParityRow> rows) {
  final path = Platform.environment['IOS27_PARITY_TABLE'];
  if (path == null || path.isEmpty) {
    return;
  }
  ios27AppendParityTable(path, refKey, rows);
}

/// Markdown-таблица [rows] под заголовком [refKey].
String ios27ParityMarkdown(String refKey, List<Ios27ParityRow> rows) {
  final buf = StringBuffer()
    ..writeln('### $refKey')
    ..writeln()
    ..writeln(
        '| элемент | доска x, y, w×h | Flutter x, y, w×h | dx | dy | dw | dh | в допуске |')
    ..writeln('|---|---|---|---|---|---|---|---|');
  for (final r in rows) {
    buf.writeln(r.toMarkdown());
  }
  buf.writeln();
  return buf.toString();
}

/// Дописывает таблицу в файл по пути [path]. Отдельной функцией, чтобы ветку записи можно было
/// проверить без переменной окружения (в процессе теста её не выставить).
void ios27AppendParityTable(
    String path, String refKey, List<Ios27ParityRow> rows) {
  File(path).writeAsStringSync(ios27ParityMarkdown(refKey, rows),
      mode: FileMode.append);
}

/// Падает с таблицей отклонений, если хоть одна строка вне допуска.
void expectIos27Parity(List<Ios27ParityRow> rows) {
  final bad = rows.where((r) => !r.ok).toList();
  expect(
    bad,
    isEmpty,
    reason: 'вне допуска ${bad.length} из ${rows.length}:\n'
        '${bad.map((r) => r.toMarkdown()).join('\n')}',
  );
}
