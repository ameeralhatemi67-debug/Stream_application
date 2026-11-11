import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'lantern_base.dart';
import 'lantern_controls.dart';
import 'lantern_surfaces.dart';

/// A panel that slides in from the end side over the page (the website
/// layout's notifications). On a phone it is a Lantern sheet instead.
///
/// [body] scrolls; [header] sits under the title and stays put.
Future<T?> showLanternDrawer<T>(BuildContext context,
    {required String title,
    required WidgetBuilder body,
    WidgetBuilder? header,
    double width = 420}) {
  if (!context.lanternWide) {
    return showLanternSheet<T>(context,
        title: title,
        body: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (header != null) header(context),
                  body(context),
                ]));
  }
  final forced = context.lt.night ? true : null;
  return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: context.lt.scrim,
      transitionDuration: Lantern.calm(context) ? Lantern.none : Lantern.enter,
      transitionBuilder: (context, animation, _, child) {
        if (Lantern.calm(context)) return child;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final curved = CurvedAnimation(parent: animation, curve: Lantern.ease);
        return FadeTransition(
            opacity: curved,
            child: SlideTransition(
                position: Tween<Offset>(
                        begin: Offset(rtl ? -.12 : .12, 0), end: Offset.zero)
                    .animate(curved),
                child: child));
      },
      pageBuilder: (dialogContext, _, __) => LanternSurface(
          night: forced,
          child: Builder(builder: (context) {
            final t = context.lt;
            return Align(
                alignment: AlignmentDirectional.centerEnd,
                child: SafeArea(
                    child: SizedBox(
                        width: width,
                        height: double.infinity,
                        child: Material(
                            color: t.raised,
                            elevation: 0,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    border: BorderDirectional(
                                        start: BorderSide(color: t.line)),
                                    boxShadow: t.shadowHi),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                          padding: const EdgeInsetsDirectional
                                              .fromSTEB(18, 14, 10, 8),
                                          child: Row(children: [
                                            Expanded(
                                                child: Semantics(
                                                    header: true,
                                                    child: Text(title,
                                                        style: Lantern.displayStyle(
                                                            18,
                                                            color: t.fg,
                                                            height: context
                                                                    .lanternArabic
                                                                ? 1.45
                                                                : 1.25)))),
                                            LIconButton(
                                                icon: LGlyph.close,
                                                label: MaterialLocalizations
                                                        .of(context)
                                                    .closeButtonLabel,
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .maybePop()),
                                          ])),
                                      if (header != null)
                                        Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                18, 0, 18, 10),
                                            child: header(context)),
                                      Container(height: 1, color: t.line),
                                      Expanded(
                                          child: SingleChildScrollView(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      18, 14, 18, 24),
                                              child: body(context))),
                                    ]))))));
          })));
}

/// The card of a Lantern dialog without its route: 28 px corners on the
/// raised ground, the display title, the body and the actions at the end.
/// For dialogs whose route an older screen opens and whose state it keeps.
class LDialogCard extends StatelessWidget implements LanternSkinWidget {
  const LDialogCard(
      {super.key,
      required this.title,
      required this.body,
      this.actions = const [],
      this.onClose,
      this.maxWidth = 480});

  final String title;
  final Widget body;
  final List<Widget> actions;

  /// Shows the close button when set.
  final VoidCallback? onClose;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Dialog(
        backgroundColor: t.raised,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Lantern.radiusDialog),
            side: BorderSide(color: t.line)),
        child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: onClose == null ? 8 : 0),
                                child: Semantics(
                                    header: true,
                                    child: Text(title,
                                        style: Lantern.displayStyle(19,
                                            color: t.fg,
                                            height: context.lanternArabic
                                                ? 1.45
                                                : 1.25))))),
                        if (onClose != null)
                          LIconButton(
                              icon: LGlyph.close,
                              label: MaterialLocalizations.of(context)
                                  .closeButtonLabel,
                              onPressed: onClose),
                      ]),
                      const SizedBox(height: 8),
                      Flexible(child: SingleChildScrollView(child: body)),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 10,
                            runSpacing: 10,
                            children: actions),
                      ],
                    ]))));
  }
}
