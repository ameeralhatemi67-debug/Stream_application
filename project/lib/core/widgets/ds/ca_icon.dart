import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_theme.dart';
import 'ca_focus_ring.dart';
import '../language_switcher.dart';

/// Exported Identity Lab glyphs; decorative SVGs inherit the control's label.
enum CaGlyph {
  translate,
  bell,
  search,
  sliders,
  bookmark,
  user,
  gear,
  menu,
  back,
  close,
  check,
  verified,
  plus,
  edit,
  trash,
  refresh,
  download,
  share,
  copy,
  external,
  link,
  key,
  lock,
  shield,
  eye,
  eyeoff,
  mic,
  micoff,
  video,
  videooff,
  flip,
  volume,
  play,
  pause,
  fullscreen,
  heart,
  send,
  chat,
  users,
  cal,
  clock,
  pin,
  map,
  compass,
  list,
  info,
  alert,
  bars,
  wifi,
  dots,
  arrow,
  logout,
  globe,
  scale,
  home
}

class CaIcon extends StatelessWidget {
  const CaIcon(this.glyph,
      {super.key,
      this.color = Canopy.brandGreen,
      this.size = CanopySize.icon,
      this.label});
  final CaGlyph glyph;
  final Color color;
  final double size;
  final String? label;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/canopy/icons/${glyph.name}.svg',
        width: size,
        height: size,
        matchTextDirection:
            const [CaGlyph.back, CaGlyph.arrow, CaGlyph.send].contains(glyph),
        colorFilter: glyph == CaGlyph.verified
            ? null
            : ColorFilter.mode(color, BlendMode.srcIn),
        semanticsLabel: label,
        excludeFromSemantics: label == null,
      );
}

class CaIconButton extends StatelessWidget {
  const CaIconButton(
      {super.key,
      required this.icon,
      required this.label,
      this.onPressed,
      this.glass = false,
      this.selected = false});
  final CaGlyph icon;
  final String label;
  final VoidCallback? onPressed;
  final bool glass, selected;
  @override
  Widget build(BuildContext context) {
    final color = glass ? Canopy.paper : Canopy.brandGreen;
    return Semantics(
        button: true,
        enabled: onPressed != null,
        label: label,
        child: Tooltip(
            message: label,
            excludeFromSemantics: true,
            child: CaFocusRing(
                onDark: glass,
                child: SizedBox.square(
                  dimension: CanopySize.target,
                  child: Material(
                    color: glass
                        ? Canopy.paper.withValues(alpha: CanopySize.glassAlpha)
                        : selected
                            ? Canopy.mint
                            : Canopy.paper,
                    shape: CircleBorder(
                        side: BorderSide(
                            color: glass
                                ? Canopy.paper.withValues(
                                    alpha: CanopySize.glassBorderAlpha)
                                : Canopy.hairline)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                        onTap: onPressed,
                        customBorder: const CircleBorder(),
                        child: Center(
                            child: CaIcon(icon,
                                color: onPressed == null
                                    ? (glass ? Canopy.mist : Canopy.haze)
                                    : color))),
                  ),
                ))));
  }
}

/// Reuses locale/push synchronization in LanguageSwitcher.
class CaLanguageChip extends StatelessWidget {
  const CaLanguageChip(
      {super.key, this.glass = false, this.compact = false, this.bare = false});
  final bool glass, compact;

  /// Glyph only, without the glass circle behind it.
  final bool bare;
  @override
  Widget build(BuildContext context) => compact
      ? Center(
          child: SizedBox.square(
              dimension: CanopySize.target,
              child: LanguageSwitcher(
                  canopy: true,
                  overlay: glass,
                  bare: bare,
                  showLabel: false,
                  padding: const EdgeInsets.all(AppTheme.spaceSm))))
      : LanguageSwitcher(
          canopy: true,
          overlay: glass,
          bare: bare,
          showLabel: MediaQuery.sizeOf(context).width >= 360 &&
              MediaQuery.textScalerOf(context).scale(1) < 1.3,
        );
}
