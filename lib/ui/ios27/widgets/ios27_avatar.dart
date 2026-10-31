// Ведущий значок строки списка: серая плитка со значком, эмодзи или логотипом и флаг в скруглённом квадрате
// (доска `.row__icon`, `.row__logo`, `.row__emoji`, `.flag`, app.css:213-232).

import 'package:dropweb/ui/ios27/icons.g.dart';
import 'package:dropweb/ui/ios27/theme/accent.dart';
import 'package:dropweb/ui/ios27/theme/ios27_theme_scope.dart';
import 'package:dropweb/ui/ios27/theme/tokens.g.dart'
    show Ios27Palette, Ios27Text, Ios27TextRole;
import 'package:dropweb/ui/m3e/m3e_emoji.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Сторона плитки и флага (`.row__icon`, `.row__logo`, `.flag{--fs:32px}`).
const double kIos27AvatarSize = 32;

/// Скругление плитки значка и логотипа (`border-radius:9px`).
const double kIos27AvatarRadius = 9;

/// Поля SVG-логотипа внутри плитки: как у Android-аватара (`M3eListLead.avatar`, малый размер),
/// чтобы один и тот же файл провайдера выглядел одинаково на обеих платформах.
const EdgeInsets kIos27AvatarSvgPadding =
    EdgeInsets.symmetric(horizontal: 4, vertical: 6);

enum _AvatarKind { icon, emoji, logo, logoImage, flag }

/// Запас декодирования растрового логотипа над размером плитки.
///
/// Декод ровно в 32 dp × dpr превращает пиксельный логотип в рваную картинку (кодек уменьшает
/// без сглаживания: у «db» появляются полосы и швы), а отрисовка с `FilterQuality.medium` из
/// увеличенной картинки сглаживает мипами. Четырёхкратный запас даёт вид, неотличимый от
/// полноразмерного (макс. разница пикселя 29/255), при этом текстура в 16 раз меньше.
const int kIos27AvatarLogoSupersample = 4;

/// Растровый логотип, декодируемый в размер плитки с запасом: [kIos27AvatarSize] dp ×
/// [devicePixelRatio] × [kIos27AvatarLogoSupersample], с округлением вверх.
///
/// Логотип провайдера приходит как 1024×1024 PNG; без этого он целиком декодировался бы для
/// плитки 32 dp (≈4 МБ текстуры с mip-цепочкой) прямо в момент раскрытия листа «Подписка» и
/// давал лаг (отчёт `.omo/ios/g6/lag/report.md`, причина 2). `ResizeImagePolicy.fit` сохраняет
/// пропорции в рамке, а `BoxFit.cover` заполняет плитку так же, как полноразмерная картинка;
/// для неквадратного логотипа короткая сторона получается меньше рамки, что на 32 dp не видно.
@visibleForTesting
ImageProvider ios27AvatarLogoImage(
  ImageProvider source,
  double devicePixelRatio,
) {
  final px = (kIos27AvatarSize * devicePixelRatio * kIos27AvatarLogoSupersample)
      .ceil();
  return ResizeImage(
    source,
    width: px,
    height: px,
    policy: ResizeImagePolicy.fit,
  );
}

/// Проверенный логотип провайдера для [Ios27Avatar.logoImage]: растр или текст SVG.
@immutable
class Ios27AvatarLogo {
  const Ios27AvatarLogo.raster(ImageProvider this.image) : svg = null;
  const Ios27AvatarLogo.svg(String this.svg) : image = null;

  final ImageProvider? image;
  final String? svg;
}

/// Ведущий значок строки: 32×32.
///
/// Решение владельца 26.10: значки строк ВСЕГДА серые: плитка `--fill-3`, знак `--label`, в
/// любой теме и при любом провайдере ([Ios27RowIconColors]); чужие цвета логотипов отброшены.
/// Размер не зависит от системного шрифта: плитка и флаг остаются 32×32 (на доске у них
/// фиксированная сторона), эмодзи внутри масштабируется как обычный текст, но не вылезает из плитки.
///
/// * [Ios27Avatar.icon] — глиф [Ios27IconName] 18 px (`Ios27IconSpecs.row`).
/// * [Ios27Avatar.emoji] — эмодзи 18 px Twemoji в серой плитке (ведущий эмодзи группы без флага).
/// * [Ios27Avatar.flag] — флаг (пара региональных индикаторов) в квадрате с радиусом `.22 × 32`
///   и тонкой кромкой, чтобы белые флаги не сливались с карточкой.
/// * [Ios27Avatar.logo] — инициалы провайдера (700 12 px), когда логотипа нет или он не загрузился.
/// * [Ios27Avatar.logoImage] — сам логотип провайдера из заголовка `dropweb-logo`, в цвете и как
///   есть (решение владельца 30.10: «значок провайдера должен подтягиваться из лого в
///   заголовке»; доска рисует вырезанный знак `cutMark`, владелец его не узнавал). Растр
///   заполняет плитку (`cover`), SVG вписывается с полями (`contain`), как на Android.
/// * [Ios27Avatar.fromName] — по имени: ведущий эмодзи → флаг (если это флаг) или эмодзи в плитке
///   (решение D6), иначе значок `fallback`.
class Ios27Avatar extends StatelessWidget {
  const Ios27Avatar.icon(Ios27IconName this.icon, {super.key})
      : text = null,
        logo = null,
        _kind = _AvatarKind.icon;

  const Ios27Avatar.emoji(String this.text, {super.key})
      : icon = null,
        logo = null,
        _kind = _AvatarKind.emoji;

  const Ios27Avatar.flag(String this.text, {super.key})
      : icon = null,
        logo = null,
        _kind = _AvatarKind.flag;

  const Ios27Avatar.logo({String? initials, super.key})
      : icon = null,
        text = initials,
        logo = null,
        _kind = _AvatarKind.logo;

  const Ios27Avatar.logoImage(Ios27AvatarLogo this.logo, {super.key})
      : icon = null,
        text = null,
        _kind = _AvatarKind.logoImage;

  /// Выбирает вид по ведущему эмодзи [name] (`extractLeadEmoji`); без эмодзи — [fallback].
  factory Ios27Avatar.fromName(
    String name, {
    Ios27IconName fallback = Ios27IconName.layers,
    Key? key,
  }) {
    final lead = extractLeadEmoji(name);
    if (lead == null) {
      return Ios27Avatar.icon(fallback, key: key);
    }
    return isFlagEmoji(lead)
        ? Ios27Avatar.flag(lead, key: key)
        : Ios27Avatar.emoji(lead, key: key);
  }

  final Ios27IconName? icon;
  final String? text;

  /// Имя элемента `layout.json` для этого вида: `rowIcon`, `rowFlag` или `rowLogo`.
  String get layoutName => switch (_kind) {
        _AvatarKind.icon || _AvatarKind.emoji => 'rowIcon',
        _AvatarKind.flag => 'rowFlag',
        _AvatarKind.logo || _AvatarKind.logoImage => 'rowLogo',
      };

  /// Логотип для [Ios27Avatar.logoImage]; в остальных видах `null`.
  final Ios27AvatarLogo? logo;
  final _AvatarKind _kind;

  /// Эмодзи — флаг страны: ровно пара региональных индикаторов U+1F1E6..U+1F1FF.
  static bool isFlagEmoji(String emoji) {
    final runes = emoji.runes.toList();
    return runes.length == 2 &&
        runes.every((r) => r >= 0x1F1E6 && r <= 0x1F1FF);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Ios27Colors.of(context);
    final palette = colors.palette;
    switch (_kind) {
      case _AvatarKind.flag:
        return _flag(context, colors.dark);
      case _AvatarKind.icon:
        return _tile(
          palette,
          Ios27Icon.spec(
            icon!,
            Ios27IconSpecs.row,
            color: Ios27RowIconColors.glyph(palette),
          ),
        );
      case _AvatarKind.emoji:
        return _tile(
          palette,
          _fit(
            Text(
              text!,
              maxLines: 1,
              softWrap: false,
              style: Ios27Text.style(_emojiRole),
            ),
          ),
        );
      case _AvatarKind.logo:
        return _tile(
          palette,
          _fit(
            Text(
              text ?? '',
              maxLines: 1,
              softWrap: false,
              style: Ios27Text.style(
                _initialsRole,
                color: Ios27RowIconColors.glyph(palette),
              ),
            ),
          ),
        );
      case _AvatarKind.logoImage:
        return _tile(palette, _logoBody(context, logo!));
    }
  }

  static const _emojiRole =
      Ios27TextRole(size: 18, lineHeight: 18, weight: 400, tracking: 0);
  static const _initialsRole =
      Ios27TextRole(size: 12, lineHeight: 12, weight: 700, tracking: 0);

  // Знак внутри плитки не вылезает за неё при любом масштабе текста.
  Widget _fit(Widget child) => FittedBox(fit: BoxFit.scaleDown, child: child);

  // Плитка `--fill-3` остаётся подложкой для прозрачных логотипов; непрозрачные (чёрный фон
  // `logo.png`) закрывают её целиком. Обрезка по форме плитки нужна растру: `cover` вылезает
  // за квадрат. Рамка 32×32 не меняется, как у остальных видов.
  Widget _logoBody(BuildContext context, Ios27AvatarLogo logo) => ClipRRect(
        borderRadius: BorderRadius.circular(kIos27AvatarRadius),
        child: SizedBox.expand(
          child: logo.svg != null
              ? Padding(
                  padding: kIos27AvatarSvgPadding,
                  child: SvgPicture.string(logo.svg!, fit: BoxFit.contain),
                )
              : Image(
                  image: ios27AvatarLogoImage(
                    logo.image!,
                    MediaQuery.devicePixelRatioOf(context),
                  ),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                  // Адрес уже проверен `m3eSubLogoProvider`; если кэш всё же потерял
                  // картинку, плитка остаётся пустой, а не красной.
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
        ),
      );

  Widget _tile(Ios27Palette palette, Widget child) => SizedBox.square(
        dimension: kIos27AvatarSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Ios27RowIconColors.tile(palette),
            borderRadius: BorderRadius.circular(kIos27AvatarRadius),
          ),
          child: Center(child: child),
        ),
      );

  /// `.flag`: глиф 1,2 × 32 по центру, обрезан квадратом с радиусом `.22 × 32`; кромка
  /// `inset 0 0 0 .5px` светлая `#0000001F` / тёмная `#FFFFFF24`.
  Widget _flag(BuildContext context, bool dark) {
    const radius = kIos27AvatarSize * 0.22;
    return SizedBox.square(
      dimension: kIos27AvatarSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Text(
                text!,
                maxLines: 1,
                softWrap: false,
                textScaler: TextScaler.noScaling,
                style: Ios27Text.style(
                  const Ios27TextRole(
                    size: kIos27AvatarSize * 1.2,
                    lineHeight: kIos27AvatarSize * 1.2,
                    weight: 400,
                    tracking: 0,
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: dark
                        ? const Color(0x24FFFFFF)
                        : const Color(0x1F000000),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
