import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/app_provider.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/language_switcher.dart';
import '../../profile/models/streamer_models.dart';
import '../../web/presentation/hidayah_web_header.dart';
import '../data/taysir_repository.dart';
import '../domain/taysir_models.dart';
import '../state/taysir_controller.dart';
import 'taysir_kit.dart';

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

/// A page of Hadayah Live's Lessons tab (ADR-014). The tab shell owns the
/// tab bar on phones and the website header on wide screens; this adds the
/// phone app bar, the loading and failure states, and a preacher's submit
/// button on the tab's home. [titleKey] is null on that home.
class TaysirTab extends StatefulWidget {
  const TaysirTab({super.key, required this.child, this.titleKey});
  final Widget child;
  final String? titleKey;
  @override
  State<TaysirTab> createState() => _TaysirTabState();
}

class _TaysirTabState extends State<TaysirTab> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<TaysirController>().ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final body = _TaysirGate(child: widget.child);
    if (context.wide) return Material(color: TC.page, child: body);
    final submit = context.select<TaysirController, bool>((c) => c.canSubmitOwn);
    return Scaffold(
      backgroundColor: TC.page,
      appBar: TaysirPhoneBar(title: widget.titleKey?.tr()),
      body: body,
      floatingActionButton: submit && widget.titleKey == null
          ? FloatingActionButton(
              onPressed: () => context.push('/taysir/submit'),
              backgroundColor: HidayahGold.g400,
              foregroundColor: TC.ink,
              tooltip: 'taysir.discover.submit'.tr(),
              child: const TIcon(TGlyph.plus, size: 24, color: TC.ink, stroke: 2.2),
            )
          : null,
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

/// Language, and the programme's own alerts while any are unread (a
/// cancelled lesson someone set a reminder for). Saved lessons, reminders
/// and the rest of a person's programme pages are in Settings.
class _Tools extends StatelessWidget {
  const _Tools();
  @override
  Widget build(BuildContext context) {
    final unread = context.select<TaysirController, int>((c) => c.mine.unread);
    final ar = context.ar;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      TIconButton(TGlyph.languages, tooltip: ar ? 'English' : 'العربية', onPressed: () => LanguageSwitcher.toggle(context)),
      if (unread > 0)
        TIconButton(TGlyph.bell, tooltip: 'taysir.nav.notifications'.tr(), badge: unread, onPressed: () => context.push('/taysir/me/notifications')),
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

/// A pushed Taysir page: back button and title on phones, Hadayah Live's
/// website header and footer on wide screens. [children] scroll.
class TaysirPage extends StatelessWidget {
  const TaysirPage({super.key, required this.title, required this.children, this.narrow = false, this.header});
  final String title;
  final List<Widget> children;
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
        if (context.wide) const HidayahWebFooter(),
      ]),
    );
    final gated = _TaysirGate(child: scroll);
    if (context.wide) {
      return Scaffold(
        backgroundColor: TC.page,
        body: SafeArea(
            child: Column(children: [
          const HidayahWebHeader(active: HidayahWebSection.lessons),
          Expanded(child: gated),
        ])),
      );
    }
    return Scaffold(backgroundColor: TC.page, appBar: TaysirPhoneBar(title: title), body: gated);
  }
}

/// A Lessons tab page's scrolling body, with the site footer on wide screens.
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
          if (context.wide) const HidayahWebFooter(),
        ]),
      ),
    );
  }
}
