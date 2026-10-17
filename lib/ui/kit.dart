import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// Building blocks of the design (docs/New_Design), shared by every screen.

/// A screen's big title, with an optional line above it ("Thursday, 15 October") and a trailing action.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader(
      {super.key, required this.title, this.overline, this.leading, this.trailing, this.back = false, this.size = 20});
  final String title;
  final String? overline;
  final Widget? leading, trailing;
  final bool back;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // A tab (no back arrow) gets the ☰ of the home screen's drawer.
    final leading = this.leading ?? (!back && Scaffold.maybeOf(context)?.hasDrawer == true ? const MenuButton() : null);
    // Large text: what sits beside the title goes under it instead of squeezing it.
    if (trailing != null && MediaQuery.textScalerOf(context).scale(10) > 13) {
      return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        ScreenHeader(title: title, overline: overline, leading: leading, back: back, size: size),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), child: trailing),
      ]);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64), // the design's app bar
      child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (back) ...[
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
        ],
        if (leading != null) ...[leading, const SizedBox(width: 12)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (overline != null) Text(overline!, style: AppText.caption.copyWith(color: c.muted)),
            Semantics(
              header: true,
              child: Text(title,
                  style: TextStyle(
                      fontSize: size, fontWeight: FontWeight.w800, letterSpacing: -0.015 * size, color: c.ink, height: 1.2)),
            ),
          ]),
        ),
        ?trailing,
      ]),
      ),
    );
  }
}

/// White card with the design's hairline border and 20 dp corners.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap,
      this.radius = Radii.card, this.border = true});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final double radius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius), side: border ? BorderSide(color: c.border) : BorderSide.none);
    return Material(
      color: color ?? c.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? Padding(padding: padding, child: child) : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Rows in one card, divided by hairlines ("Breakfast" items, settings groups, journal).
class PanelList extends StatelessWidget {
  const PanelList({super.key, required this.children, this.header});
  final List<Widget> children;
  final Widget? header;

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ?header,
          for (final (i, w) in children.indexed) ...[
            if (i > 0) Divider(indent: 16, endIndent: 16, color: context.colors.divider),
            w,
          ],
        ]),
      );
}

/// "FRUIT AND VEGETABLES", "LOOK AND LANGUAGE": small caps above a group.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(4, 20, 4, 8), this.color});
  final String text;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Semantics(
          header: true,
          child: Text(text.toUpperCase(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: color ?? context.colors.muted)),
        ),
      );
}

/// A heading with an optional action on the right ("Ingredients · + Add missing to shopping").
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(4, 16, 4, 8)});
  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(children: [
          Expanded(child: Semantics(header: true, child: Text(text, style: AppText.section.copyWith(color: context.colors.ink)))),
          if (trailing != null) Flexible(child: Align(alignment: AlignmentDirectional.centerEnd, child: trailing)),
        ]),
      );
}

/// The design's segmented control: a card-coloured track, the selected tab raised ("Day Week Month Year").
class PillTabs<T> extends StatelessWidget {
  const PillTabs({super.key, required this.values, required this.selected, required this.label, required this.onChanged,
      this.semanticsLabel});
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: semanticsLabel,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.tile),
            border: Border.all(color: c.border)),
        child: Row(children: [
          for (final v in values)
            Expanded(
              child: Semantics(
                selected: v == selected,
                button: true,
                child: Material(
                  color: v == selected ? c.surfaceHigh : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onChanged(v),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Text(label(v),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: v == selected ? FontWeight.w700 : FontWeight.w600,
                                  color: v == selected ? c.ink : c.muted)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// A row of pill choices, the selected one filled near-black ("Breakfast Lunch Dinner Snack").
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({super.key, required this.values, required this.selected, required this.label, required this.onChanged,
      this.scroll = false});
  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final v in values)
        Pill(label: label(v), selected: v == selected, onTap: () => onChanged(v)),
    ];
    return scroll
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [for (final ch in chips) Padding(padding: const EdgeInsets.only(right: 8), child: ch)]),
          )
        : Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

/// One pill: outlined white, or filled dark when selected.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.selected = false, this.onTap, this.icon, this.compact = false});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: Material(
        color: selected ? c.dark : c.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? c.dark : c.outline)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 40 : 48),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[Icon(icon, size: 18, color: selected ? c.background : c.ink), const SizedBox(width: 6)],
                Flexible(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: compact ? 14 : 15,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                          color: selected ? c.background : c.ink)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small coloured label: "−0.7 kg" (mint), "PRO" (gold), "BASIC" / "5" streak (warm), "7 DAYS FREE".
enum TagTone { mint, warm, gold, water, danger, neutral, dark }

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.tone = TagTone.mint, this.icon, this.big = false});
  final String text;
  final TagTone tone;
  final IconData? icon;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (tone) {
      TagTone.mint => (c.mint, c.onMint),
      TagTone.warm => (c.warm, c.onWarm),
      TagTone.gold => (c.gold, const Color(0xFF3A2A05)),
      TagTone.water => (c.waterBg, c.water),
      TagTone.danger => (c.dangerBg, c.danger),
      TagTone.neutral => (c.track, c.ink2),
      TagTone.dark => (c.primary, c.onPrimary),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 12 : 8, vertical: big ? 6 : 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: big ? 16 : 14, color: fg), const SizedBox(width: 4)],
        Flexible(
          child: Text(text,
              style: TextStyle(fontSize: big ? 15 : 13, fontWeight: FontWeight.w700, color: fg,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
      ]),
    );
  }
}

/// A big number with its label under it ("231 days logged", "−0.16 kg per week"); optional colour dot.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.dot, this.onTap, this.labelFirst = false});
  final String value;
  final String label;
  final Color? dot;
  final VoidCallback? onTap;

  /// Me's targets show the label above the value.
  final bool labelFirst;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Shrinks rather than breaking a word ("Maintai/n") in a narrow tile.
    final valueText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.ink, letterSpacing: -0.3,
              fontFeatures: const [FontFeature.tabularFigures()])),
    );
    final labelText = Row(mainAxisSize: MainAxisSize.min, children: [
      if (dot != null) ...[
        Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
      ],
      Flexible(child: Text(label, style: AppText.caption.copyWith(fontSize: 13, color: c.muted))),
    ]);
    return Panel(
      radius: Radii.tile,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: labelFirst ? [labelText, const SizedBox(height: 4), valueText] : [valueText, const SizedBox(height: 2), labelText],
      ),
    );
  }
}

/// The design's icon in a rounded square, on a tint of its colour (drawer, settings, Me's links).
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.color, this.size = 36});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: tint(context, color, alpha: Theme.of(context).brightness == Brightness.dark ? .18 : .12),
              borderRadius: BorderRadius.circular(size * .3)),
          child: Icon(icon, size: size * .52, color: color),
        ),
      );
}

/// A meal's [IconTile] in its colour; [icon] replaces the meal's own (a recipe's book).
class MealIcon extends StatelessWidget {
  const MealIcon({super.key, required this.type, this.icon, this.size = 44});
  final String type;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) =>
      IconTile(icon: icon ?? mealIcons[type] ?? Icons.cookie_outlined, color: context.mealColor(type), size: size);
}

/// ☰: opens the home screen's side drawer.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) => RoundIconButton(
        icon: Icons.menu,
        tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
        onPressed: () => Scaffold.of(context).openDrawer(),
      );
}

/// 48 dp round button on the card colour: lock, settings, back on a photo.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.size = 44,
      this.background, this.foreground, this.shape = const CircleBorder()});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final Color? background, foreground;

  /// A rounded square instead of the circle (the + on a meal).
  final ShapeBorder shape;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background ?? c.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: math.max(size, 48),
            child: Semantics(button: true, label: tooltip, child: Icon(icon, size: 22, color: foreground ?? c.ink)),
          ),
        ),
      ),
    );
  }
}

/// The dashed "+ Add" box: an empty meal, "+ Add item", "+ Add" allergy.
class DashedAdd extends StatelessWidget {
  const DashedAdd({super.key, required this.child, required this.onTap, this.radius = Radii.card});
  final Widget child;
  final VoidCallback onTap;
  final double radius;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashedBorder(context.colors.outline, radius),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: child),
            ),
          ),
        ),
      );
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color, this.radius);
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 5, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}

/// A rounded progress bar ("1,510 of 2,200 kcal", fasting).
class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, this.color, this.track, this.height = 8, this.label});
  final double value;
  final Color? color, track;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: height,
          color: color ?? context.colors.primary,
          backgroundColor: track ?? context.colors.track,
          semanticsLabel: label,
        ),
      );
}

/// A two-button footer pinned to the bottom ("Log a serving · Start cooking", "Plan again · Shopping list").
class BottomActions extends StatelessWidget {
  const BottomActions({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: context.colors.surface, border: Border(top: BorderSide(color: context.colors.border))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              for (final (i, w) in children.indexed) ...[if (i > 0) const SizedBox(width: 10), w],
            ]),
          ),
        ),
      );
}

/// Recipe photo stand-in: nutri.db has no pictures, so a tint of a nutrient colour (from the title) and a food icon.
class RecipeArt extends StatelessWidget {
  const RecipeArt({super.key, required this.title, this.height = 120, this.radius = 0});
  final String title;
  final double height;
  final double radius;

  static const _hues = ['protein_g', 'kcal', 'fat_g', 'carbs_g', 'sodium_mg', 'fiber_g'];
  static const _icons = [Icons.ramen_dining, Icons.rice_bowl, Icons.lunch_dining, Icons.bakery_dining, Icons.set_meal,
      Icons.soup_kitchen, Icons.egg_alt, Icons.local_pizza];

  @override
  Widget build(BuildContext context) {
    final h = title.codeUnits.fold(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    final hue = context.nutrientColor(_hues[h % _hues.length]);
    return Container(
      height: height,
      decoration: BoxDecoration(color: tint(context, hue, alpha: .22), borderRadius: BorderRadius.circular(radius)),
      alignment: Alignment.center,
      child: ExcludeSemantics(
        child: Icon(_icons[h % _icons.length], size: height * .38, color: hue.withValues(alpha: .55)),
      ),
    );
  }
}
