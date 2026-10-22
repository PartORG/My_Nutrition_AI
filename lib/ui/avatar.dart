import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// Eva, the developer's miniature schnauzer: the assistant's face in the chat, the tab bar and on the unlock screen.
const evaAsset = 'assets/icons/icon_chat.png';

class EvaAvatar extends StatelessWidget {
  const EvaAvatar({super.key, this.size = 32, this.semanticLabel});
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => ClipOval(
        child: Image.asset(evaAsset,
            width: size, height: size, fit: BoxFit.cover, semanticLabel: semanticLabel, excludeFromSemantics: semanticLabel == null),
      );
}

/// Eva on a transparent background, so she sits on any colour (2026-10-22): her head (icon_chat.png without its
/// disc), and three poses the owner made, cut off their paper and scaled to 384 px.
const evaCutoutAsset = 'assets/icons/eva_cutout.png';
const evaWavingAsset = 'assets/icons/eva_waving.png'; // hello: the welcome screen
const evaSleepingAsset = 'assets/icons/eva_sleeping.png'; // nothing here yet
const evaEatingAsset = 'assets/icons/eva_eating.png'; // no food found, nothing to buy or cook

class EvaCutout extends StatelessWidget {
  const EvaCutout({super.key, this.size = 48, this.asset = evaCutoutAsset});
  final double size;
  final String asset;

  @override
  Widget build(BuildContext context) => Image.asset(asset, height: size, excludeFromSemantics: true);
}

/// Where a list has nothing yet: Eva (asleep, unless [asset] says otherwise) beside the line that says so.
class EvaNote extends StatelessWidget {
  const EvaNote(this.text, {super.key, this.asset = evaSleepingAsset});
  final String text;
  final String asset;

  @override
  Widget build(BuildContext context) => Row(children: [
        EvaCutout(size: 64, asset: asset),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(fontSize: 15, color: context.colors.muted, height: 1.35))),
      ]);
}

IconData avatarIcon(AvatarKind kind) => switch (kind) {
      AvatarKind.woman => Icons.face_3,
      AvatarKind.man => Icons.face_6,
      AvatarKind.neutral => Icons.face,
      AvatarKind.face2 => Icons.face_2,
      AvatarKind.face4 => Icons.face_4,
      AvatarKind.face5 => Icons.face_5,
      AvatarKind.pets => Icons.pets,
      AvatarKind.leaf => Icons.eco,
      AvatarKind.flower => Icons.local_florist,
      AvatarKind.spa => Icons.spa,
      AvatarKind.runner => Icons.directions_run,
      AvatarKind.yoga => Icons.self_improvement,
      AvatarKind.food => Icons.restaurant,
      AvatarKind.coffee => Icons.coffee,
      AvatarKind.heart => Icons.favorite,
      AvatarKind.star => Icons.star,
      AvatarKind.sun => Icons.wb_sunny,
    };

/// The person icons, named; the rest are offered as "Icon n".
const personAvatars = [AvatarKind.woman, AvatarKind.man, AvatarKind.neutral];

/// Background colours offered in Settings (ARGB), dark enough for a white icon.
const avatarColors = [
  0xFF2E7D32, 0xFF558B2F, 0xFF00796B, 0xFF00838F, 0xFF0277BD, 0xFF1565C0, 0xFF3949AB, 0xFF4527A0, 0xFF7B1FA2,
  0xFF6A1B9A, 0xFFC2185B, 0xFFAD1457, 0xFFC62828, 0xFFD84315, 0xFFEF6C00, 0xFF5D4037, 0xFF455A64, 0xFF212121,
];

String avatarKindName(AppLocalizations l, AvatarKind kind) => switch (kind) {
      AvatarKind.woman => l.avatarWoman,
      AvatarKind.man => l.avatarMan,
      AvatarKind.neutral => l.avatarNeutral,
      _ => l.avatarIconN(kind.index - personAvatars.length + 1),
    };

Avatar copyAvatar(Avatar a, {AvatarKind? kind, AvatarShape? shape, AvatarStyle? style, AvatarRing? ring}) => (
      kind: kind ?? a.kind,
      color: a.color,
      photo: a.photo,
      shape: shape ?? a.shape,
      style: style ?? a.style,
      ring: ring ?? a.ring,
    );

/// The outline of [shape] at [size] (the picture and its outline share it).
ShapeBorder avatarBorder(AvatarShape shape, double size, {BorderSide side = BorderSide.none}) => switch (shape) {
      AvatarShape.circle => CircleBorder(side: side),
      AvatarShape.rounded => RoundedRectangleBorder(borderRadius: BorderRadius.circular(size * .28), side: side),
      AvatarShape.hexagon => StarBorder.polygon(sides: 6, pointRounding: .3, side: side),
      AvatarShape.flower => StarBorder(points: 8, innerRadiusRatio: .84, pointRounding: .6, valleyRounding: .4, side: side),
    };

/// Options drawn as the picture would look with each, the chosen one ringed: a row with captions, or a grid of
/// small ones without ([captions] false; the caption is still read out).
class AvatarChoices<T> extends StatelessWidget {
  const AvatarChoices({super.key, required this.values, required this.selected, required this.preview,
      required this.label, required this.onSelected, this.captions = true});
  final List<T> values;
  final T selected;
  final Avatar Function(T value) preview;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;
  final bool captions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget choice(T v) => Semantics(
          button: true,
          selected: v == selected,
          label: label(v),
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelected(v),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: captions ? 8 : 2, horizontal: captions ? 0 : 2),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: v == selected ? c.primary : Colors.transparent, width: 3)),
                  child: UserAvatar(radius: captions ? 26 : 20, avatar: preview(v)),
                ),
                if (captions) ...[
                  const SizedBox(height: 6),
                  Text(label(v),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: v == selected ? FontWeight.w700 : FontWeight.w500)),
                ],
              ]),
            ),
          ),
        );
    return captions
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final v in values) Expanded(child: choice(v))])
        : Wrap(spacing: 4, runSpacing: 4, children: [for (final v in values) choice(v)]);
  }
}

/// The user's picture: their photo, else the icon they chose on its colour; in their shape, with their outline.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, this.radius = 20, this.avatar, this.frame});
  final double radius;

  /// Shown instead of the saved one (a preview while choosing).
  final Avatar? avatar;

  /// A 4 px border of this colour around it, in the same shape (the unlock screen's white on green).
  final Color? frame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Avatar a = avatar ?? ref.watch(avatarProvider);
    final bg = a.color == null ? context.colors.primary : Color(a.color!);
    final size = radius * 2;
    final ring = switch (a.ring) { AvatarRing.none => 0.0, AvatarRing.thin => size * .04, AvatarRing.thick => size * .08 };
    final inner = ring == 0 ? size : size - 4 * ring; // the outline, then a gap as wide
    final soft = a.style == AvatarStyle.soft;
    final hsl = HSLColor.fromColor(bg);
    Widget picture = Container(
      width: inner,
      height: inner,
      decoration: ShapeDecoration(
        shape: avatarBorder(a.shape, inner),
        color: switch (a.style) {
          AvatarStyle.solid => bg,
          AvatarStyle.soft => Color.alphaBlend(bg.withValues(alpha: .18), Colors.white),
          AvatarStyle.gradient => null,
        },
        gradient: a.style == AvatarStyle.gradient
            ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [bg, hsl.withHue((hsl.hue + 40) % 360).toColor()])
            : null,
        image: a.photo == null ? null : DecorationImage(image: FileImage(a.photo!), fit: BoxFit.cover, onError: (_, _) {}),
      ),
      child: a.photo != null
          ? null
          : Icon(avatarIcon(a.kind), size: inner * .65,
              color: soft ? bg : ThemeData.estimateBrightnessForColor(bg) == Brightness.dark ? Colors.white : Colors.black87),
    );
    if (ring > 0) {
      picture = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: ShapeDecoration(shape: avatarBorder(a.shape, size, side: BorderSide(color: bg, width: ring))),
        child: picture,
      );
    }
    if (frame != null) {
      picture = Container(
        padding: const EdgeInsets.all(4),
        decoration: ShapeDecoration(color: frame, shape: avatarBorder(a.shape, size + 8)),
        child: picture,
      );
    }
    return ExcludeSemantics(child: picture);
  }
}
