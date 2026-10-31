// Политика golden вне macOS (test/support/golden_policy.dart): тесты гоняют не-macOS ветку на
// любом хосте, потому что на Mac реальный путь Linux иначе не виден до красного CI.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_policy.dart';

/// Кадр [w]×[h], залитый [color]: пиксели разные, размер задаётся.
Future<ui.Image> _image(int w, int h, Color color) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = color,
  );
  return recorder.endRecording().toImage(w, h);
}

Future<Uint8List> _png(int w, int h, Color color) async {
  final data = await (await _image(w, h, color))
      .toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late Uri basedir;
  late GoldenFileComparator saved;
  late List<String> notices;
  late SizeOnlyGoldenComparator comparator;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('golden_policy_test');
    basedir = Uri.directory(dir.path);
    saved = goldenFileComparator;
    notices = [];
    comparator = SizeOnlyGoldenComparator(basedir, notice: notices.add);
  });

  tearDown(() {
    goldenFileComparator = saved;
    dir.deleteSync(recursive: true);
  });

  Future<void> writeGolden(String name, Uint8List bytes) async {
    final file = File.fromUri(basedir.resolve('goldens/$name'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  test('тот же размер, другие пиксели: проходит (пиксели не сравниваются)',
      () async {
    await writeGolden('a.png', await _png(8, 6, const Color(0xFFFF0000)));
    final frame = await _png(8, 6, const Color(0xFF0000FF));

    expect(await comparator.compare(frame, Uri.parse('goldens/a.png')), isTrue);
    expect(notices.single, contains('macOS'));
  });

  test('другой размер кадра: падает с обоими размерами', () async {
    await writeGolden('a.png', await _png(8, 6, const Color(0xFFFF0000)));
    final frame = await _png(8, 7, const Color(0xFFFF0000));

    await expectLater(
      comparator.compare(frame, Uri.parse('goldens/a.png')),
      throwsA(
        isA<TestFailure>().having(
          (e) => e.message,
          'message',
          allOf(contains('8×7'), contains('8×6')),
        ),
      ),
    );
  });

  test('эталона нет: падает, а не молча проходит', () async {
    final frame = await _png(8, 6, const Color(0xFFFF0000));

    await expectLater(
      comparator.compare(frame, Uri.parse('goldens/missing.png')),
      throwsA(isA<TestFailure>()),
    );
  });

  test('эталон не PNG: падает', () async {
    await writeGolden('a.png', Uint8List.fromList(List.filled(64, 7)));
    final frame = await _png(8, 6, const Color(0xFFFF0000));

    await expectLater(
      comparator.compare(frame, Uri.parse('goldens/a.png')),
      throwsA(isA<TestFailure>()),
    );
  });

  test('--update-goldens вне macOS отказывает и не пишет файл', () async {
    final frame = await _png(8, 6, const Color(0xFFFF0000));

    await expectLater(
      comparator.update(Uri.parse('goldens/new.png'), frame),
      throwsA(isA<TestFailure>()),
    );
    expect(File.fromUri(basedir.resolve('goldens/new.png')).existsSync(),
        isFalse);
  });

  test('через matchesGoldenFile: размер ловится, пиксели нет', () async {
    goldenFileComparator = comparator;
    await writeGolden('a.png', await _png(8, 6, const Color(0xFFFF0000)));

    await expectLater(
      await _image(8, 6, const Color(0xFF00FF00)),
      matchesGoldenFile('goldens/a.png'),
    );
    await expectLater(
      expectLater(
        await _image(9, 6, const Color(0xFFFF0000)),
        matchesGoldenFile('goldens/a.png'),
      ),
      throwsA(isA<TestFailure>()),
    );
  });

  group('installGoldenPolicy', () {
    test('не macOS: ставит компаратор без сравнения пикселей на тот же каталог',
        () {
      final local = LocalFileComparator(Uri.file('${dir.path}/x_test.dart'));
      goldenFileComparator = local;

      installGoldenPolicy(onMacOS: false);

      final installed = goldenFileComparator;
      expect(installed, isA<SizeOnlyGoldenComparator>());
      expect((installed as SizeOnlyGoldenComparator).basedir, local.basedir);
    });

    test('macOS: штатный компаратор остаётся тем же объектом', () {
      final local = LocalFileComparator(Uri.file('${dir.path}/x_test.dart'));
      goldenFileComparator = local;

      installGoldenPolicy(onMacOS: true);

      expect(identical(goldenFileComparator, local), isTrue);
    });
  });
}
