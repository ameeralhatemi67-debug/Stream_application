import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/lantern/lantern.dart';

/// A link that leads nowhere, in Lantern and Arch (ADR-026): the night band
/// with the arch, a short line, and the ways back: Discover first, then
/// Lessons and the map. The router's error page under Lantern.
class LanternNotFoundPage extends StatelessWidget implements LanternSkinWidget {
  const LanternNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: (context) {
        final t = context.lt;
        final wide = context.lanternWide;
        final band = LNightBand(
            latticeOpacity: .1,
            latticeStep: 40,
            child: SafeArea(
                top: !wide,
                child: Center(
                    child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                            horizontal: wide ? Lantern.webGutter : 20,
                            vertical: wide ? 72 : 40),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxWidth: Lantern.webContent),
                            child: const _Message())))));
        return Scaffold(
            key: const ValueKey('lantern-not-found'),
            backgroundColor: t.bg,
            body: wide
                ? Column(children: [
                    const SafeArea(bottom: false, child: LanternWebHeader()),
                    Expanded(child: band),
                  ])
                : band);
      }));
}

class _Message extends StatelessWidget {
  const _Message();

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final wide = context.lanternWide;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: wide ? 120 : 92,
              height: wide ? 86 : 66,
              child: LArchDraw(lineColor: t.line)),
          const SizedBox(height: 18),
          ExcludeSemantics(
              child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [LanternTokens.goldHi, LanternTokens.goldLo])
                      .createShader(rect),
                  child: Text('404',
                      textDirection: TextDirection.ltr,
                      style: Lantern.displayStyle(wide ? 120 : 84,
                          color: LanternTokens.white, height: 1)))),
          const SizedBox(height: 10),
          Semantics(
              header: true,
              child: Text('lantern.account.not_found_title'.tr(),
                  style: Lantern.displayStyle(wide ? 30 : 24,
                      color: LanternTokens.onNight,
                      height: context.lanternArabic ? 1.45 : 1.2))),
          const SizedBox(height: 8),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text('lantern.account.not_found_body'.tr(),
                  style: Lantern.textStyle(15, color: t.muted, height: 1.6))),
          const SizedBox(height: 22),
          Wrap(spacing: 10, runSpacing: 10, children: [
            LButton(
                key: const ValueKey('lantern-not-found-discover'),
                label: 'web.nav_discover'.tr(),
                icon: LGlyph.home,
                onPressed: () => context.go('/feed')),
            LButton(
                label: 'web.nav_lessons'.tr(),
                icon: LGlyph.book,
                kind: LButtonKind.dark,
                onPressed: () => context.go('/lessons')),
            LButton(
                label: 'web.nav_map'.tr(),
                icon: LGlyph.map,
                kind: LButtonKind.dark,
                onPressed: () => context.go('/map')),
          ]),
        ]);
  }
}
