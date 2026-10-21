import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_theme.dart';
import 'canopy_lattice_background.dart';
import '../safe_image_provider.dart';
import 'ca_cards.dart';
import 'ca_button.dart';
import 'canopy_content_motion.dart';
import 'ca_icon.dart';

/// One live feature, with intrinsic text height above the class minimum.
class CaHeroCard extends StatefulWidget {
  const CaHeroCard(
      {super.key,
      required this.title,
      required this.presenter,
      required this.action,
      required this.height,
      this.imageUrl,
      this.onTap,
      this.audio = false,
      this.showAction = true,
      this.viewerLabel,
      this.viewerCount,
      this.viewerSuffix});
  final String title, presenter, action;
  final String? imageUrl, viewerLabel;

  /// When [viewerSuffix] is set the viewer pill shows a rolling count of
  /// [viewerCount] ('\u2014' while unknown) instead of the plain [viewerLabel].
  final int? viewerCount;
  final String? viewerSuffix;
  final double height;
  final bool audio, showAction;
  final VoidCallback? onTap;
  @override
  State<CaHeroCard> createState() => _CaHeroCardState();
}

class _CaHeroCardState extends State<CaHeroCard> {
  final _pointer = ValueNotifier<Offset?>(null);
  @override
  void dispose() {
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
      onHover: kIsWeb &&
              MediaQuery.sizeOf(context).width >= CanopyWindow.expanded &&
              !CanopyMotion.reduced(context)
          ? (event) {
              if (CanopyTexturePolicy.instance.value) {
                _pointer.value = event.localPosition;
              }
            }
          : null,
      onExit: (_) => _pointer.value = null,
      child: CaCard(
          variant: CaCardVariant.feature,
          padding: EdgeInsets.zero,
          child: LayoutBuilder(builder: (context, constraints) {
            final image = resolveImageProviderOrNull(widget.imageUrl);
            return Stack(children: [
              Positioned.fill(
                  child: CanopyLatticeBackground(
                      texture: false,
                      child: image == null
                          ? const SizedBox()
                          : Image(
                              image: downscaledImage(image,
                                  width: (constraints.maxWidth *
                                          MediaQuery.devicePixelRatioOf(
                                              context))
                                      .round()),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox()))),
              const Positioned.fill(
                  child: DecoratedBox(
                      decoration:
                          BoxDecoration(gradient: AppGradients.mediaScrim))),
              Positioned.fill(
                  child: IgnorePointer(
                      child: CanopyLatticeBackground(
                          gradient: false,
                          pointer: _pointer,
                          child: const SizedBox.expand()))),
              Positioned.fill(
                  child: ColoredBox(
                      color: image == null
                          ? CanopyGradients.entryTextScrim
                          : CanopyGradients.heroTextScrim)),
              ConstrainedBox(
                  constraints: BoxConstraints(minHeight: widget.height),
                  child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceLg),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                                spacing: AppTheme.spaceSm,
                                runSpacing: AppTheme.spaceSm,
                                children: [
                                  CaStatusChip(
                                      kind: widget.audio
                                          ? CaStatusKind.audio
                                          : CaStatusKind.live),
                                  if (widget.viewerLabel != null || widget.viewerSuffix != null)
                                    DecoratedBox(
                                        decoration: BoxDecoration(
                                            color: Canopy.forestDeep,
                                            borderRadius: BorderRadius.circular(
                                                CanopyRadius.pill)),
                                        child: Padding(
                                            padding: const EdgeInsetsDirectional.symmetric(
                                                horizontal: AppTheme.spaceSm,
                                                vertical: AppTheme.spaceXs),
                                            child: widget.viewerSuffix != null
                                                ? CaRollingCount(
                                                    value: widget.viewerCount,
                                                    suffix:
                                                        widget.viewerSuffix!,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                            color:
                                                                Canopy.paper))
                                                : Text(widget.viewerLabel!,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(color: Canopy.paper)))),
                                ]),
                            const SizedBox(height: AppTheme.spaceXl),
                            Text(widget.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(color: Canopy.paper)),
                            const SizedBox(height: AppTheme.spaceSm),
                            Text(widget.presenter,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Canopy.paper)),
                            const SizedBox(height: AppTheme.spaceMd),
                            if (widget.showAction)
                              CaButton(
                                  label: widget.action,
                                  icon:
                                      widget.audio ? CaGlyph.mic : CaGlyph.play,
                                  onPressed: widget.onTap),
                          ]))),
            ]);
          })));
}

/// Transparent edge mask keeps horizontally scrolling categories discoverable.
class CaChipRow extends StatelessWidget {
  const CaChipRow({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => CanopyGradients.edgeFade.createShader(bounds),
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppTheme.spaceSm),
          child: Row(children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: AppTheme.spaceSm),
              children[i],
            ]
          ])));
}
