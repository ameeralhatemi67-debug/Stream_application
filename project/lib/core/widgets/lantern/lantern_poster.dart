import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'lantern.dart';

/// An invitation picture: a lesson or a broadcast drawn as a poster in the
/// Lantern identity (night ground, the lattice, the gold arch, the star and
/// the Hedayah logo), ready to send to a group chat.
///
/// Mosque lessons are announced with pictures that people forward. This
/// makes that picture from what the app already knows, on the device:
/// nothing is uploaded and no service is called.

/// One line of the poster with its icon: the day, the time, the place.
typedef LanternPosterFact = ({LGlyph icon, String text});

class LanternPosterData {
  const LanternPosterData(
      {required this.eyebrow,
      required this.title,
      required this.facts,
      required this.link,
      this.person});

  /// The kind of event in words: "Mosque lesson", "Live broadcast".
  final String eyebrow;
  final String title;

  /// The preacher or the channel.
  final String? person;
  final List<LanternPosterFact> facts;

  /// Shown small at the foot and sent with the picture as text.
  final String link;
}

/// The poster itself, 360 by 450 logical pixels (4:5). It is captured at
/// three times that, 1080 by 1350, the size chat apps show without cutting.
class LanternPoster extends StatelessWidget implements LanternSkinWidget {
  const LanternPoster(this.data, {super.key});

  final LanternPosterData data;

  static const Size size = Size(360, 450);
  static const double pixelRatio = 3;

  @override
  Widget build(BuildContext context) {
    final arabic = context.lanternArabic;
    final muted = LanternTokens.dark.muted;
    return MediaQuery.withNoTextScaling(
        // The picture has one size, whatever the phone's text size.
        child: SizedBox.fromSize(
            size: size,
            child: ColoredBox(
                color: LanternTokens.nightGround,
                child: Stack(children: [
                  const LLattice(opacity: .09),
                  Positioned.fill(
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 64),
                          child: DecoratedBox(
                              decoration: const ShapeDecoration(
                                  color: Color(0x33000000),
                                  shape: LArchBorder(
                                      bottom: 16,
                                      side: BorderSide(
                                          color: LanternTokens.gold,
                                          width: 1.6))),
                              child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(26, 54, 26, 18),
                                  child: Column(children: [
                                    const LStar(size: 16),
                                    const SizedBox(height: 10),
                                    Text(data.eyebrow,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: Lantern.textStyle(11.5,
                                            color: LanternTokens.goldHi,
                                            weight: FontWeight.w700,
                                            height: 1.3)),
                                    const SizedBox(height: 8),
                                    Text(data.title,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: Lantern.displayStyle(
                                            data.title.length > 48 ? 18 : 21,
                                            color: LanternTokens.white,
                                            height: arabic ? 1.5 : 1.25)),
                                    if (data.person != null &&
                                        data.person!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(data.person!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: Lantern.textStyle(13.5,
                                              color: LanternTokens.goldHi,
                                              weight: FontWeight.w600,
                                              height: 1.4)),
                                    ],
                                    const SizedBox(height: 12),
                                    Container(
                                        width: 44,
                                        height: 1.5,
                                        color: LanternTokens.gold),
                                    const SizedBox(height: 12),
                                    for (final fact in data.facts)
                                      if (fact.text.isNotEmpty)
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 7),
                                            child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 2),
                                                      child: LIcon(fact.icon,
                                                          size: 14,
                                                          color: LanternTokens
                                                              .goldHi)),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                      child: Text(fact.text,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: Lantern
                                                              .textStyle(12.5,
                                                                  color:
                                                                      LanternTokens
                                                                          .white,
                                                                  height:
                                                                      1.4))),
                                                ])),
                                  ]))))),
                  PositionedDirectional(
                      start: 22,
                      end: 22,
                      bottom: 18,
                      child: Row(children: [
                        const LLogo(height: 26, onDark: true),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(data.link,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.ltr,
                                textAlign: arabic
                                    ? TextAlign.left
                                    : TextAlign.right,
                                style: Lantern.textStyle(9.5,
                                    color: muted, height: 1.35))),
                      ])),
                ]))));
  }
}

/// The poster under [boundary] as a PNG, 1080 by 1350.
Future<Uint8List> lanternPosterPng(GlobalKey boundary) async {
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage(pixelRatio: LanternPoster.pixelRatio);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// How the picture leaves the app; tests replace it.
typedef LanternPosterShare = Future<void> Function(
    Uint8List png, String fileName, String text);

Future<void> _systemShare(Uint8List png, String fileName, String text) =>
    Share.shareXFiles(
        [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
        text: text);

/// Shows the poster and one button that sends it with the system share
/// sheet. [fileName] has no extension.
Future<void> showLanternPoster(BuildContext context, LanternPosterData data,
        {String fileName = 'hedayah-invitation',
        LanternPosterShare share = _systemShare}) =>
    showLanternSheet<void>(context,
        title: 'lantern.poster.title'.tr(),
        body: (context) =>
            _PosterPreview(data: data, fileName: fileName, share: share));

class _PosterPreview extends StatefulWidget {
  const _PosterPreview(
      {required this.data, required this.fileName, required this.share});

  final LanternPosterData data;
  final String fileName;
  final LanternPosterShare share;

  @override
  State<_PosterPreview> createState() => _PosterPreviewState();
}

class _PosterPreviewState extends State<_PosterPreview> {
  final _boundary = GlobalKey();
  bool _busy = false;

  Future<void> _send() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await lanternPosterPng(_boundary);
      await widget.share(png, '${widget.fileName}.png', widget.data.link);
    } catch (_) {
      if (mounted) {
        lanternToast(context, 'lantern.poster.failed'.tr(), warn: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Column(
        key: const ValueKey('lantern-poster-preview'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Semantics(
                      image: true,
                      label:
                          '${widget.data.eyebrow}, ${widget.data.title}${widget.data.person == null ? '' : ', ${widget.data.person}'}',
                      child: ExcludeSemantics(
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: FittedBox(
                                  child: RepaintBoundary(
                                      key: _boundary,
                                      child: LanternPoster(widget.data)))))))),
          const SizedBox(height: 14),
          LButton(
              key: const ValueKey('lantern-poster-share'),
              label: 'lantern.poster.share'.tr(),
              icon: LGlyph.share,
              expand: true,
              loading: _busy,
              onPressed: _busy ? null : _send),
          const SizedBox(height: 10),
          Text('lantern.poster.note'.tr(),
              textAlign: TextAlign.center,
              style: Lantern.textStyle(12.5, color: t.muted, height: 1.45)),
        ]);
  }
}
