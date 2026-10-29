// Логотип провайдера для аватаров листа «Подписка». Решение владельца 2026-10-29: в листе
// логотип есть всегда, когда провайдер прислал `dropweb-logo`, а на кнопке подписок
// главной его нет (там стопка). Переключателя «Лого из подписки» в M3E нет, его значение
// сюда не попадает.
//
// Логотип проверяется до отрисовки: у общего аватара (`M3eListLead.avatar`) нет запасного
// вида на случай битой картинки, поэтому битый файл или недоступная сеть должны отсеяться
// здесь и дать инициалы, а не ошибку в кадре.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

/// Текст SVG-логотипа провайдера по адресу из `dropweb-logo`: аватару листа «Подписка»
/// нужен сам файл (`SvgPicture.string`), а не картинка по адресу, чтобы заранее проверить,
/// что он разбирается. Ошибка сети, код не 200 или таймаут — `null`, аватар покажет
/// инициалы.
final m3eLogoSvgProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, url) async {
  try {
    final res = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 10),
        );
    if (res.statusCode != 200) return null;
    return res.body;
  } on Object {
    return null;
  }
});

/// Проверенный логотип: либо текст SVG, либо растровая картинка.
@immutable
class M3eSubLogo {
  const M3eSubLogo.svg(String this.svg) : image = null;
  const M3eSubLogo.raster(ImageProvider this.image) : svg = null;

  final String? svg;
  final ImageProvider? image;
}

/// Сколько ждём растровый логотип, прежде чем показать инициалы.
const Duration kM3eSubLogoTimeout = Duration(seconds: 10);

/// Логотип по адресу из `dropweb-logo`; `null` — показать инициалы (сеть недоступна,
/// файл не картинка, SVG не разбирается).
final m3eSubLogoProvider =
    FutureProvider.autoDispose.family<M3eSubLogo?, String>((ref, url) async {
  try {
    if (url.toLowerCase().endsWith('.svg')) {
      final svg = await ref.watch(m3eLogoSvgProvider(url).future);
      if (svg == null || svg.trim().isEmpty) return null;
      // Тот же загрузчик, что у SvgPicture.string: если он не разобрал файл, аватару
      // этот текст отдавать нельзя.
      await SvgStringLoader(svg).loadBytes(null);
      return M3eSubLogo.svg(svg);
    }
    final image = CachedNetworkImageProvider(url);
    return await _resolves(image) ? M3eSubLogo.raster(image) : null;
  } on Object {
    return null;
  }
});

/// Загружается ли картинка. Результат остаётся в кэше изображений, поэтому аватар
/// потом рисуется без повторной загрузки.
Future<bool> _resolves(ImageProvider image) {
  final done = Completer<bool>();
  final stream = image.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, __) {
      if (!done.isCompleted) done.complete(true);
    },
    onError: (_, __) {
      if (!done.isCompleted) done.complete(false);
    },
  );
  stream.addListener(listener);
  return done.future
      .timeout(kM3eSubLogoTimeout, onTimeout: () => false)
      .whenComplete(() => stream.removeListener(listener));
}
