import 'package:flutter/material.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/widget/slant_chip.dart';

enum StickerChipStyle { small, large, mono }

/// Stand-in for black on the chips in dark theme.
const Color _kDarkInk = Color(0xFF2A2A2A);

/// Offset-shadow color in dark theme: a lighter grey so it stands out
/// against the background.
const Color _kDarkShadow = Color(0xFF4A4A4A);

/// Slanted "sticker" chip used by the category filters. Unselected: white
/// with a black outline and black offset shadow. Selected: red with a black
/// shadow for [StickerChipStyle.large], black with a red shadow otherwise.
class StickerChip extends StatelessWidget {
  const StickerChip({
    super.key,
    required this.label,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final StickerChipStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool large = style == StickerChipStyle.large;
    final bool mono = style == StickerChipStyle.mono;
    final double height = large ? 48 : 32;
    final double shadow = large ? 4 : 3;

    // Softened to dark grey in dark theme so the black fill and shadows
    // don't disappear into the near-black background.
    final bool dark = ThemeService.instance.isDark;
    final Color fill = !selected
        ? Colors.white
        : large
            ? SlantChip.accent
            : (dark ? _kDarkInk : Colors.black);
    final Color shadowColor = selected && !large
        ? SlantChip.accent
        : (dark ? _kDarkShadow : Colors.black);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        // Room for the slant and the offset shadow so neither gets clipped.
        padding: EdgeInsets.only(left: large ? 6 : 4, right: large ? 10 : 8),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.skewX(-0.2),
          child: Container(
            height: height,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: large ? 20 : 14),
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(
                color: selected ? fill : Colors.black,
                width: large ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(color: shadowColor, offset: Offset(shadow, shadow)),
              ],
            ),
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontFamily: mono ? AppFonts.number : AppFonts.heading,
                fontSize: large ? 30 : (mono ? 12 : 18),
                fontWeight: FontWeight.w700,
                letterSpacing: mono ? 1.2 : 0.4,
                height: 1,
                color: selected ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontally scrollable row of [StickerChip]s, centred when it fits.
class StickerChipRow extends StatelessWidget {
  const StickerChipRow({
    super.key,
    required this.height,
    required this.children,
  });

  final double height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth - 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// The small "FIT & FABRIC" caption that leads the fit chip row.
class StickerChipCaption extends StatelessWidget {
  const StickerChipCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    // Listen to the theme directly: callers build this as a const widget,
    // which Flutter skips on parent rebuilds, so it would keep a stale color.
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: AppFonts.number,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
