import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/hidden_content_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../../core/widgets/ds/ca_rows.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';

enum _ContentAction { share, hide, show }

/// Wraps a video or playlist on a channel page. A long press (or a right click)
/// opens a menu to share it and, for the channel owner, to hide it from or show
/// it to viewers. The owner sees a hidden item blurred with a "hidden" icon;
/// viewers never get the item at all (the provider leaves it out), so this
/// widget draws nothing for a viewer if one slips through.
class ChannelContentItem extends StatelessWidget {
  const ChannelContentItem({
    super.key,
    required this.streamerId,
    required this.kind,
    required this.itemId,
    required this.title,
    required this.shareText,
    required this.child,
  });

  final String streamerId;
  final HiddenContentKind kind;
  final String itemId;
  final String title;

  /// What the share sheet sends: the item's title and its YouTube link.
  final String shareText;
  final Widget child;

  Future<void> _openMenu(BuildContext context,
      {required bool canManage, required bool hidden}) async {
    HapticFeedback.mediumImpact();
    final action = await showCaSheet<_ContentAction>(context,
        title: title,
        body: Builder(
            builder: (sheetContext) => Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.spaceLg),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CaSettingsRow(
                      icon: CaGlyph.share,
                      title: (kind == HiddenContentKind.video
                              ? 'content_actions.share_video'
                              : 'content_actions.share_playlist')
                          .tr(),
                      onTap: () =>
                          Navigator.pop(sheetContext, _ContentAction.share)),
                  if (canManage)
                    CaSettingsRow(
                        divider: true,
                        icon: hidden ? CaGlyph.eye : CaGlyph.eyeoff,
                        title: (hidden
                                ? 'content_actions.show'
                                : 'content_actions.hide')
                            .tr(),
                        subtitle: (hidden
                                ? 'content_actions.show_hint'
                                : 'content_actions.hide_hint')
                            .tr(),
                        onTap: () => Navigator.pop(sheetContext,
                            hidden ? _ContentAction.show : _ContentAction.hide)),
                ]))));
    if (action == null || !context.mounted) return;
    switch (action) {
      case _ContentAction.share:
        await _share(context);
      case _ContentAction.hide:
      case _ContentAction.show:
        await _setHidden(context, action == _ContentAction.hide);
    }
  }

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Share.share(shareText, subject: title);
    } catch (_) {
      // Browsers without a share sheet: copy the link instead.
      await Clipboard.setData(ClipboardData(text: shareText));
      messenger?.showSnackBar(
          SnackBar(content: Text('content_actions.link_copied'.tr())));
    }
  }

  Future<void> _setHidden(BuildContext context, bool hide) async {
    final provider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await provider.setContentHidden(streamerId, kind, itemId, hide);
      messenger?.showSnackBar(SnackBar(
          content: Text((hide
                  ? 'content_actions.hidden_done'
                  : 'content_actions.shown_done')
              .tr())));
    } catch (_) {
      messenger?.showSnackBar(
          SnackBar(content: Text('content_actions.save_failed'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (hidden, canManage) = context.select<AppProvider, (bool, bool)>((p) => (
          p.isContentHidden(streamerId, kind, itemId),
          p.canManageChannelContent(streamerId),
        ));
    if (hidden && !canManage) return const SizedBox.shrink();
    void open() => _openMenu(context, canManage: canManage, hidden: hidden);
    return GestureDetector(
      onLongPress: open,
      onSecondaryTapUp: (TapUpDetails _) => open(),
      child: hidden ? _HiddenFrame(child: child) : child,
    );
  }
}

/// The owner's view of a hidden item: blurred, with a "not visible" icon.
class _HiddenFrame extends StatelessWidget {
  const _HiddenFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CanopyRadius.card);
    return Semantics(
      label: 'content_actions.hidden_badge'.tr(),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(children: [
          ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: child),
          Positioned.fill(
              child: IgnorePointer(
                  child: LayoutBuilder(builder: (context, constraints) {
            final roomy = constraints.maxHeight >= 110;
            return ColoredBox(
                color: Canopy.forestDeep
                    .withValues(alpha: .5),
                child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CaIcon(CaGlyph.eyeoff,
                      size: 28, color: Canopy.paper),
                  if (roomy) ...[
                    const SizedBox(height: AppTheme.spaceXs),
                    Text('content_actions.hidden_badge'.tr(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Canopy.paper)),
                  ],
                ])));
          }))),
        ]),
      ),
    );
  }
}
