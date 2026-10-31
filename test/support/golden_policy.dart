// Политика сравнения golden: пиксели сверяются только на macOS.
//
// Эталоны (`test/m3e/goldens`, `test/ios27/goldens`) нарисованы на macOS. Skia на Linux иначе
// сглаживает текст и края, поэтому на ubuntu-раннере CI почти каждый кадр расходится с PNG
// на доли процента (первый прогон 1.0.0: 337 падений при зелёном локальном прогоне). Правка
// порога не лечит: расхождение зависит от шрифта и размера кадра, а не от ошибки раскладки.
// Перерисовать эталоны под Linux тоже нельзя: тогда они разойдутся с macOS, где их держит
// разработчик.
//
// Поэтому вне macOS pixel-сравнение отключено, а всё остальное остаётся: файл эталона обязан
// существовать, быть PNG и совпадать по размеру с кадром (ошибка раскладки или поверхности
// меняет размер), а `--update-goldens` отказывает, чтобы Linux не затёр эталоны macOS.
// Остальные expect-ы тестов (поиск виджетов, семантика, размеры) выполняются на любом хосте.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Подключает политику golden к текущему тестовому файлу.
///
/// Вызывается из `testExecutable` в `test/flutter_test_config.dart`: к этому моменту
/// `flutter test` уже поставил `LocalFileComparator` на каталог тестового файла. На macOS
/// компаратор остаётся штатным (настоящее сравнение пикселей, `--update-goldens` работает).
/// [onMacOS] нужен тестам политики, чтобы проверить не-macOS ветку на любом хосте.
void installGoldenPolicy({bool? onMacOS}) {
  if (onMacOS ?? Platform.isMacOS) return;
  final current = goldenFileComparator;
  // Незнакомый компаратор не трогаем: строгое сравнение лучше молчаливого пропуска.
  if (current is! LocalFileComparator) return;
  goldenFileComparator = SizeOnlyGoldenComparator(current.basedir);
}

/// Компаратор вне macOS: проверяет эталон и размер кадра, пиксели не сравнивает.
class SizeOnlyGoldenComparator extends GoldenFileComparator {
  SizeOnlyGoldenComparator(this.basedir, {void Function(String)? notice})
      : _notice = notice ?? _printNoticeOnce;

  /// Каталог тестового файла: ключи эталонов (`goldens/x.png`) считаются от него.
  final Uri basedir;

  final void Function(String) _notice;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    _notice(_noticeText);
    final file = File.fromUri(basedir.resolveUri(golden));
    if (!file.existsSync()) {
      throw TestFailure('эталон не найден: ${file.path}');
    }
    final expected = _pngSize(await file.readAsBytes(), what: file.path);
    final actual = _pngSize(imageBytes, what: 'кадр теста');
    if (expected != actual) {
      throw TestFailure(
        'размер кадра ${actual.$1}×${actual.$2} не совпадает с эталоном '
        '${expected.$1}×${expected.$2}: $golden',
      );
    }
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    throw TestFailure(
      'эталон $golden не обновлён: golden перерисовываются только на macOS '
      '(на ${Platform.operatingSystem} pixel-сравнение отключено, '
      'запись затёрла бы эталоны Mac)',
    );
  }
}

final _noticeText = 'golden: на ${Platform.operatingSystem} проверяются наличие '
    'эталона и размер кадра, пиксели сверяются только на macOS';

/// Метка «уведомление уже было в этом прогоне». Каждый тестовый файл идёт в своём
/// изоляте, статическая переменная это не склеит, поэтому метка лежит в temp.
/// Устаревшая метка (прошлый прогон) заменяется, чтобы уведомление не пропадало навсегда.
const _noticeMarkerTtl = Duration(minutes: 15);
bool _noticePrinted = false;

void _printNoticeOnce(String text) {
  if (_noticePrinted) return;
  _noticePrinted = true;
  final marker = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'dropweb_golden_policy_notice',
  );
  try {
    if (marker.existsSync() &&
        DateTime.now().difference(marker.lastModifiedSync()) >
            _noticeMarkerTtl) {
      marker.deleteSync();
    }
    // exclusive: атомарно, из параллельных изолятов успевает один.
    marker.createSync(exclusive: true);
  } on FileSystemException {
    return;
  }
  // ignore: avoid_print
  print(text);
}

/// Ширина и высота PNG из заголовка IHDR (байты 16–24). Полный разбор не нужен: пиксели
/// не сравниваются, а битый файл эталона виден по сигнатуре.
(int, int) _pngSize(Uint8List bytes, {required String what}) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 24) {
    throw TestFailure('$what: слишком короткий для PNG (${bytes.length} байт)');
  }
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) {
      throw TestFailure('$what: нет сигнатуры PNG');
    }
  }
  final header = ByteData.sublistView(bytes, 16, 24);
  return (header.getUint32(0), header.getUint32(4));
}
