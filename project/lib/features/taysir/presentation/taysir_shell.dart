import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_identity.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/routing/sign_in_prompt.dart';
import '../../../core/widgets/app_logo.dart';
import '../../profile/models/streamer_models.dart';
import '../data/taysir_repository.dart';
import '../domain/taysir_models.dart';
import '../state/taysir_controller.dart';
import 'taysir_kit.dart';

/// Sections of the Taysir website header.
enum TaysirSection { discover, lessons, map, me, mine, console }

/// The live channel of a preacher who also streams on Hadayah Live.
StreamerModel? preacherChannel(BuildContext context, TaysirPreacher? p) {
  final id = p?.linkedProfileId;
  if (id == null) return null;
  final streamers = context.select<AppProvider, List<StreamerModel>>((a) => a.streamers);
  for (final s in streamers) {
    if (s.channelProfileId == id || s.streamerId == id) return s;
  }
  return null;
}

/// The four-tab Taysir shell: tabs on phones, a website header on wide
/// screens. Each tab keeps its own navigation stack.
class TaysirShell extends StatefulWidget {
  const TaysirShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  State<TaysirShell> createState() => _TaysirShellState();
}

class _TaysirShellState extends State<TaysirShell> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<TaysirController>().ensureLoaded());
  }

  void _go(int i) => widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final body = _TaysirGate(child: widget.shell);
    if (context.wide) {
      return Scaffold(
        backgroundColor: TC.page,
        body: SafeArea(
          child: Column(children: [
            TaysirWebHeader(
              active: TaysirSection.values[widget.shell.currentIndex],
              onBranch: _go,
            ),
            Expanded(child: body),
          ]),
        ),
      );
    }
    final c = context.watch<TaysirController>();
    final pending = c.canCoordinate ? c.pendingRequests.length : 0;
    final i = widget.shell.currentIndex;
    return Scaffold(
      backgroundColor: TC.page,
      appBar: const TaysirPhoneBar(),
      body: body,
      floatingActionButton: c.canSubmitOwn && (i == 0 || i == 3)
          ? FloatingActionButton(
              onPressed: () => context.push('/taysir/submit'),
              backgroundColor: HidayahGold.g400,
              foregroundColor: TC.ink,
              tooltip: 'taysir.discover.submit'.tr(),
              child: const TIcon(TGlyph.plus, size: 24, color: TC.ink, stroke: 2.2),
            )
          : null,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(color: TC.card, border: Border(top: BorderSide(color: TC.hair))),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Row(children: [
            for (final (n, glyph, key) in [
              (0, TGlyph.compass, 'taysir.nav.discover'),
              (1, TGlyph.book, 'taysir.nav.lessons'),
              (2, TGlyph.map, 'taysir.nav.map'),
              (3, TGlyph.user, 'taysir.nav.me'),
            ])
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == n,
                  child: InkWell(
                    onTap: () => _go(n),
                    borderRadius: BorderRadius.circular(16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Stack(clipBehavior: Clip.none, children: [
                        Container(
                          width: 56,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: i == n ? BoxDecoration(gradient: HidayahGradients.selected, borderRadius: BorderRadius.circular(15)) : null,
                          child: TIcon(glyph, size: 21, color: i == n ? HidayahGold.g200 : TC.muted),
                        ),
                        if (n == 3 && pending > 0)
                          PositionedDirectional(
                            top: -4,
                            end: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              constraints: const BoxConstraints(minWidth: 18),
                              height: 18,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: TC.live, borderRadius: BorderRadius.circular(9)),
                              child: Text('$pending', style: tBody(11, color: Colors.white, weight: FontWeight.w700, height: 1)),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 3),
                      Text(key.tr(), style: tBody(11.5, color: i == n ? TC.ink : TC.muted, weight: FontWeight.w700, height: 1.2)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Loading, the sample-data banner, and a branded failure state (ADR-005).
class _TaysirGate extends StatelessWidget {
  const _TaysirGate({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    if (!c.loaded && c.loading) {
      return const Center(child: CircularProgressIndicator(color: TC.gold));
    }
    if (!c.loaded && c.failure != null) {
      return TEmpty(
        icon: c.failure == TaysirFailure.unavailable ? TGlyph.refresh : TGlyph.alert,
        title: 'taysir.unavailable_title'.tr(),
        body: 'taysir.unavailable_body'.tr(),
        action: TButton('taysir.retry'.tr(), kind: TBtn.minted, icon: TGlyph.refresh, onPressed: c.refresh),
      );
    }
    if (!c.isDemo) return child;
    return Column(children: [
      Container(
        width: double.infinity,
        color: TC.warnBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text('taysir.sample_banner'.tr(), textAlign: TextAlign.center, style: tBody(12.5, color: TC.warnFg, weight: FontWeight.w600, height: 1.4)),
      ),
      Expanded(child: child),
    ]);
  }
}

class _Tools extends StatelessWidget {
  const _Tools();
  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final ar = context.ar;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      TIconButton(TGlyph.languages, tooltip: ar ? 'English' : 'العربية', onPressed: () => context.setLocale(Locale(ar ? 'en' : 'ar'))),
      TIconButton(TGlyph.bookmark, tooltip: 'taysir.nav.saved'.tr(), onPressed: () => context.push('/taysir/me/saved')),
      TIconButton(TGlyph.bell, tooltip: 'taysir.nav.notifications'.tr(), badge: c.mine.unread, onPressed: () => context.push('/taysir/me/notifications')),
    ]);
  }
}

class TaysirPhoneBar extends StatelessWidget implements PreferredSizeWidget {
  const TaysirPhoneBar({super.key, this.title});
  final String? title;
  @override
  Size get preferredSize => const Size.fromHeight(56);
  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: TC.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 6,
        shape: const Border(bottom: BorderSide(color: TC.hair)),
        leading: title == null
            ? null
            : TIconButton(TGlyph.arrow, tooltip: 'taysir.back'.tr(), color: TC.ink, onPressed: () => context.canPop() ? context.pop() : context.go('/taysir')),
        title: title != null
            ? Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tStrong(16))
            : InkWell(
                onTap: () => context.go('/taysir'),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 6),
                  const AppLogo(size: 30),
                  const SizedBox(width: 8),
                  Flexible(child: Text('taysir.app_name'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: tDisplay(17))),
                ]),
              ),
        actions: const [_Tools(), SizedBox(width: 4)],
      );
}

/// The Taysir website header.
class TaysirWebHeader extends StatelessWidget {
  const TaysirWebHeader({super.key, this.active, this.onBranch});
  final TaysirSection? active;
  final ValueChanged<int>? onBranch;

  void _go(BuildContext context, TaysirSection s) {
    final i = s.index;
    if (i <= 3 && onBranch != null) return onBranch!(i);
    context.go(switch (s) {
      TaysirSection.discover => '/taysir',
      TaysirSection.lessons => '/taysir/lessons',
      TaysirSection.map => '/taysir/map',
      TaysirSection.me => '/taysir/me',
      TaysirSection.mine => '/taysir/me/lessons',
      TaysirSection.console => '/taysir/console',
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final pending = c.canCoordinate ? c.pendingRequests.length : 0;
    Widget link(TaysirSection s, String label, {Widget? trailing}) {
      final on = s == active;
      return InkWell(
        onTap: () => _go(context, s),
        child: SizedBox(
          height: 72,
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                widthFactor: 1,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(label, style: tBody(14.5, color: on ? TC.ink : TC.ink2, weight: on ? FontWeight.w700 : FontWeight.w600, height: 1.2)),
                  if (trailing != null) ...[const SizedBox(width: 7), trailing],
                ]),
              ),
            ),
            if (on)
              const Positioned(
                  left: 6, right: 6, bottom: 0, child: SizedBox(height: 3, child: DecoratedBox(decoration: BoxDecoration(gradient: HidayahGradients.gilded)))),
          ]),
        ),
      );
    }

    return Material(
      color: TC.card,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TC.hair))),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(children: [
          InkWell(
            onTap: () => context.go('/taysir'),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const AppLogo(size: 40),
              const SizedBox(width: 10),
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.4,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('taysir.app_name'.tr(), style: tDisplay(19)),
                  Text('taysir.brand_sub'.tr(), style: tBody(11, color: TC.muted, height: 1.3)),
                ]),
              ),
            ]),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                link(TaysirSection.discover, 'taysir.nav.discover'.tr()),
                link(TaysirSection.lessons, 'taysir.nav.lessons'.tr()),
                link(TaysirSection.map, 'taysir.nav.map'.tr()),
                if (c.canSubmitOwn) link(TaysirSection.mine, 'taysir.nav.my_lessons'.tr()),
                if (c.canCoordinate)
                  link(TaysirSection.console, 'taysir.nav.console'.tr(),
                      trailing: pending == 0
                          ? null
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                              decoration: BoxDecoration(gradient: HidayahGradients.minted, borderRadius: BorderRadius.circular(999)),
                              child: Text('$pending', style: tBody(11.5, color: TC.ink, weight: FontWeight.w700, height: 1.3)),
                            )),
              ]),
            ),
          ),
          const _Tools(),
          TIconButton(TGlyph.gear, tooltip: 'taysir.nav.settings'.tr(), onPressed: () => context.push('/settings')),
          const SizedBox(width: 6),
          if (!c.signedIn)
            TButton('taysir.sign_in'.tr(), kind: TBtn.minted, small: true, onPressed: () => openSignIn(context))
          else
            TButton('taysir.nav.me'.tr(), small: true, icon: TGlyph.user, onPressed: () => _go(context, TaysirSection.me)),
          const SizedBox(width: 4),
        ]),
      ),
    );
  }
}

/// The Taysir website footer.
class TaysirWebFooter extends StatelessWidget {
  const TaysirWebFooter({super.key});
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    Widget col(String title, List<(String, String)> links) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: tStrong(14, color: TC.onNightGold)),
          const SizedBox(height: 10),
          for (final (label, path) in links)
            InkWell(
              onTap: () => context.go(path),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(label, style: tBody(14, color: TC.onNight2))),
            ),
        ]);
    return TNight(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Wrap(spacing: 48, runSpacing: 24, children: [
            SizedBox(
              width: 360,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const AppLogo(size: 40),
                const SizedBox(height: 10),
                Text('taysir.app_name'.tr(), style: tDisplay(22, color: TC.onNight)),
                const SizedBox(height: 8),
                Text(AppIdentity.name(lang), style: tBody(14, color: TC.onNight2)),
              ]),
            ),
            col('taysir.programme'.tr(), [
              ('taysir.nav.discover'.tr(), '/taysir'),
              ('taysir.nav.lessons'.tr(), '/taysir/lessons'),
              ('taysir.nav.map'.tr(), '/taysir/map'),
            ]),
            col('taysir.perm.title'.tr(), [
              ('taysir.perm.title'.tr(), '/taysir/permissions'),
              ('taysir.nav.console'.tr(), '/taysir/console'),
              ('taysir.switch_back'.tr(), '/settings'),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// A pushed Taysir page: back button and title on phones, the website
/// header on wide screens. [children] scroll.
class TaysirPage extends StatelessWidget {
  const TaysirPage({super.key, required this.title, required this.children, this.active, this.narrow = false, this.header});
  final String title;
  final List<Widget> children;
  final TaysirSection? active;
  final bool narrow;

  /// Full-bleed content above the page column (detail heroes).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final c = context.read<TaysirController>();
    unawaited(c.ensureLoaded());
    final scroll = SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (header != null) header!,
        TPage(narrow: narrow, children: children),
        if (context.wide) const TaysirWebFooter(),
      ]),
    );
    final gated = _TaysirGate(child: scroll);
    if (context.wide) {
      return Scaffold(
        backgroundColor: TC.page,
        body: SafeArea(child: Column(children: [TaysirWebHeader(active: active), Expanded(child: gated)])),
      );
    }
    return Scaffold(backgroundColor: TC.page, appBar: TaysirPhoneBar(title: title), body: gated);
  }
}

/// A root tab's scrolling body, with the footer on wide screens.
class TaysirTabBody extends StatelessWidget {
  const TaysirTabBody({super.key, required this.children, this.header, this.narrow = false});
  final List<Widget> children;
  final Widget? header;
  final bool narrow;
  @override
  Widget build(BuildContext context) {
    final c = context.read<TaysirController>();
    return RefreshIndicator(
      color: TC.gold,
      onRefresh: c.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (header != null) header!,
          TPage(narrow: narrow, children: children),
          if (context.wide) const TaysirWebFooter(),
        ]),
      ),
    );
  }
}
