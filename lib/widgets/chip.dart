import 'package:dropweb/common/color.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:flutter/material.dart';

class CommonChip extends StatelessWidget {

  const CommonChip({
    super.key,
    required this.label,
    this.onPressed,
    this.avatar,
    this.type = ChipType.action,
    this.radius,
    this.isSelected = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final ChipType type;
  final Widget? avatar;

  /// Whether this chip is the chosen one in its row.
  ///
  /// Drawn as an accent border and nothing else. The chip had no selected
  /// state at all, so the one row that needed one marked its choice with a
  /// tick glued into the avatar slot — which put a glyph on this screen that
  /// appears nowhere else in the app, and said "chosen" a third way on a
  /// screen where the tab bar above already says it by filling a pill.
  /// A border is the smallest thing that reads as chosen, and it leaves the
  /// chip the same size selected or not, so a row does not reflow as you tap
  /// along it.
  final bool isSelected;

  BorderSide _side(BuildContext context) => isSelected
      ? BorderSide(color: Theme.of(context).colorScheme.primary)
      : BorderSide(color: Theme.of(context).dividerColor.opacity15);

  /// Corner radius, when the caller wants the house one.
  ///
  /// Null leaves Material's own chip shape alone, which is what every existing
  /// caller has always drawn and what the delete chips in the profile lists
  /// still expect. It is exposed rather than hard-set here because changing
  /// the default would restyle every chip in the app at once, which is a
  /// bigger change than any one screen is entitled to make.
  ///
  /// New callers should pass `Lumina.radiusLg` — 26 is the house corner, and a
  /// chip left on Material's 8 sits visibly wrong next to the tab bar and the
  /// cards it shares a screen with.
  final double? radius;

  OutlinedBorder? get _shape => radius == null
      ? null
      : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius!));

  @override
  Widget build(BuildContext context) {
    if (type == ChipType.delete) {
      return Chip(
        avatar: avatar,
        shape: _shape,
        labelPadding: const EdgeInsets.symmetric(
          vertical: 0,
          horizontal: 4,
        ),
        clipBehavior: Clip.antiAlias,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onDeleted: onPressed ?? () {},
        side: _side(context),
        labelStyle: Theme.of(context).textTheme.bodyMedium,
        label: Text(label),
      );
    }
    return ActionChip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: avatar,
      shape: _shape,
      clipBehavior: Clip.antiAlias,
      labelPadding: const EdgeInsets.symmetric(
        vertical: 0,
        horizontal: 4,
      ),
      onPressed: onPressed ?? () {},
      side: _side(context),
      labelStyle: Theme.of(context).textTheme.bodyMedium,
      label: Text(label),
    );
  }
}
