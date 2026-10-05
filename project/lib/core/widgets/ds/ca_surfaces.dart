import '../../layout/window_class.dart';
import 'package:flutter/material.dart';
import 'canopy_lattice_background.dart';
import '../../theme/app_theme.dart';
import 'ca_icon.dart';

enum CaSheetJob { standard, confirmation, studio }

enum CaSheetPresentation { sheet, dialog, drawer }

CaSheetPresentation caSheetPresentation(double width, CaSheetJob job) =>
    job == CaSheetJob.confirmation
        ? CaSheetPresentation.dialog
        : job == CaSheetJob.studio &&
                windowClassFor(width).index >= WindowClass.expanded.index
            ? CaSheetPresentation.drawer
            : windowClassFor(width) != WindowClass.compact
                ? CaSheetPresentation.dialog
                : CaSheetPresentation.sheet;

class CaSheet extends StatelessWidget {
  const CaSheet(
      {super.key,
      required this.title,
      required this.body,
      this.actions = const [],
      this.headerStatus,
      this.onClose,
      this.scrollBody = true,
      this.handle = true,
      this.bareChrome = false});
  final String title;
  final Widget? headerStatus;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final bool handle;
  final bool scrollBody;

  /// Icon-only header controls: the language glyph (no label) and the close
  /// button are drawn without a circle or pill behind them.
  final bool bareChrome;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(CanopyRadius.sheetTop),
      child: Material(
          color: Canopy.paper,
          child: LayoutBuilder(builder: (context, bounds) {
            final header = ColoredBox(
                color: Canopy.dawn,
                child: CanopyLatticeBackground(
                    gradient: false,
                    textureColor: Canopy.brandGreen,
                    textureOpacity: CanopyTexture.headerLatticeOpacity,
                    child: Stack(children: [
                      Padding(
                          padding: const EdgeInsets.all(AppTheme.spaceLg),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            if (handle) ...[
                              Container(
                                  width: CanopySize.handleWidth,
                                  height: CanopySize.handleHeight,
                                  decoration: BoxDecoration(
                                      color: Canopy.hairlineStrong,
                                      borderRadius: BorderRadius.circular(
                                          CanopyRadius.pill))),
                              const SizedBox(height: AppTheme.spaceMd)
                            ],
                            Row(children: [
                              Expanded(
                                  child: Text(title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge)),
                              const SizedBox(width: AppTheme.spaceSm),
                              CaLanguageChip(
                                  compact: bareChrome, bare: bareChrome),
                              if (onClose != null)
                                CaIconButton(
                                    bare: bareChrome,
                                    icon: CaGlyph.close,
                                    label: MaterialLocalizations.of(context)
                                        .closeButtonTooltip,
                                    onPressed: onClose),
                            ]),
                            if (headerStatus != null) ...[
                              const SizedBox(height: AppTheme.spaceSm),
                              Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: headerStatus!),
                            ],
                          ])),
                    ])));
            if (bounds.maxHeight >= CanopySize.shortSurfaceHeight ||
                !scrollBody) {
              return Column(mainAxisSize: MainAxisSize.min, children: [
                header,
                Flexible(
                    child: scrollBody
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(AppTheme.spaceLg),
                            child: body)
                        : Padding(
                            padding: const EdgeInsets.all(AppTheme.spaceLg),
                            child: body)),
                if (actions.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceLg),
                      child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Wrap(
                              spacing: AppTheme.spaceSm,
                              runSpacing: AppTheme.spaceSm,
                              children: actions))),
              ]);
            }
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                  flex: 2,
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    header,
                    Padding(
                        padding: const EdgeInsets.all(AppTheme.spaceLg),
                        child: body)
                  ]))),
              if (actions.isNotEmpty)
                Flexible(
                    child: SingleChildScrollView(
                        child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Padding(
                                padding: const EdgeInsets.all(AppTheme.spaceSm),
                                child: Wrap(
                                    spacing: AppTheme.spaceSm,
                                    runSpacing: AppTheme.spaceSm,
                                    children: actions)))))
            ]);
          })));
}

class CaDialog extends StatelessWidget {
  const CaDialog(
      {super.key,
      required this.title,
      required this.body,
      this.titleWidget,
      this.actions = const [],
      this.onClose});
  final String title;
  final Widget? titleWidget;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) => Dialog(
      backgroundColor: Canopy.transparent,
      elevation: 0,
      surfaceTintColor: Canopy.transparent,
      clipBehavior: Clip.none,
      insetAnimationDuration: CanopyMotion.reduced(context)
          ? CanopyMotion.none
          : CanopyMotion.dialog,
      insetAnimationCurve: CanopyMotion.easeOut,
      insetPadding: const EdgeInsets.all(AppTheme.screenPadding),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CanopyRadius.dialog)),
      constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width >= CanopyWindow.expanded
              ? CanopySize.sheetMax
              : CanopySize.dialogCompactMax),
      child: DecoratedBox(
          decoration: BoxDecoration(
              color: Canopy.paper,
              borderRadius: BorderRadius.circular(CanopyRadius.dialog),
              boxShadow: CanopyShadow.floating),
          child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceXl),
              child: LayoutBuilder(builder: (context, bounds) {
                final header = CanopyLatticeBackground(
                    gradient: false,
                    textureColor: Canopy.brandGreen,
                    textureOpacity: CanopyTexture.headerLatticeOpacity,
                    child: Row(children: [
                      Expanded(
                          child: titleWidget ??
                              Text(title,
                                  style:
                                      Theme.of(context).textTheme.titleLarge)),
                      if (onClose != null)
                        CaIconButton(
                            icon: CaGlyph.close,
                            label: MaterialLocalizations.of(context)
                                .closeButtonTooltip,
                            onPressed: onClose)
                    ]));
                if (bounds.maxHeight >= CanopySize.shortSurfaceHeight &&
                    MediaQuery.textScalerOf(context).scale(1) <=
                        CanopySize.dialogReflowTextScale) {
                  return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        header,
                        const SizedBox(height: AppTheme.spaceLg),
                        Flexible(child: SingleChildScrollView(child: body)),
                        if (actions.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.spaceXl),
                          Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Wrap(
                                  spacing: AppTheme.spaceSm,
                                  runSpacing: AppTheme.spaceSm,
                                  children: actions))
                        ],
                      ]);
                }
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                      flex: 2,
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            header,
                            const SizedBox(height: AppTheme.spaceLg),
                            body
                          ]))),
                  if (actions.isNotEmpty)
                    Flexible(
                        child: SingleChildScrollView(
                            child: Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: Wrap(
                                    spacing: AppTheme.spaceSm,
                                    runSpacing: AppTheme.spaceSm,
                                    children: actions))))
                ]);
              }))));
}

Future<T?> showCaSheet<T>(BuildContext context,
    {required String title,
    required Widget body,
    List<Widget> actions = const [],
    CaSheetJob job = CaSheetJob.standard,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
    bool framed = true,
    Color? barrierColor,
    BoxConstraints? constraints,
    bool fullWidthOnPhone = false,
    bool flushOnPhone = false,
    Color edgeColor = Canopy.paper}) {
  final presentation =
      caSheetPresentation(MediaQuery.sizeOf(context).width, job);
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
      _CaSurfaceRoute<T>(
          title: title,
          body: body,
          actions: actions,
          job: job,
          presentation: presentation,
          framed: framed,
          surfaceConstraints: constraints,
          scrimColor: barrierColor,
          fullWidthOnPhone: fullWidthOnPhone,
          flushOnPhone: flushOnPhone,
          edgeColor: edgeColor,
          themes: InheritedTheme.capture(
              from: context,
              to: Navigator.of(context, rootNavigator: useRootNavigator)
                  .context),
          reduced: CanopyMotion.reduced(context),
          barrierDismissible: barrierDismissible,
          barrierLabel:
              MaterialLocalizations.of(context).modalBarrierDismissLabel));
}

class _CaSurfaceRoute<T> extends PopupRoute<T> {
  _CaSurfaceRoute(
      {required this.title,
      required this.body,
      required this.actions,
      required this.job,
      required this.presentation,
      required this.themes,
      required this.reduced,
      required this.framed,
      this.surfaceConstraints,
      this.scrimColor,
      this.fullWidthOnPhone = false,
      this.flushOnPhone = false,
      this.edgeColor = Canopy.paper,
      required this.barrierDismissible,
      required this.barrierLabel})
      : super(
            traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
            requestFocus: true);
  final String title;
  final Widget body;
  final List<Widget> actions;
  final CaSheetJob job;
  final CaSheetPresentation presentation;
  final CapturedThemes themes;
  final bool reduced, framed;
  final BoxConstraints? surfaceConstraints;
  final Color? scrimColor;

  /// On a phone-width bottom sheet, the surface (painted in [edgeColor]) runs
  /// edge to edge and down behind the system navigation bar. The content keeps
  /// the inset width it would have had, so controls do not stretch.
  final bool fullWidthOnPhone;

  /// With [fullWidthOnPhone], also drops the side inset: the body spans the
  /// whole width and supplies its own padding (a [CaSheet] header band does).
  final bool flushOnPhone;
  final Color edgeColor;
  @override
  final bool barrierDismissible;
  @override
  final String barrierLabel;
  @override
  Color get barrierColor => scrimColor ?? Canopy.modalBarrier;
  @override
  Duration get transitionDuration => reduced
      ? CanopyMotion.none
      : presentation == CaSheetPresentation.dialog
          ? CanopyMotion.dialog
          : CanopyMotion.sheetIn;
  @override
  Duration get reverseTransitionDuration =>
      reduced ? CanopyMotion.none : CanopyMotion.sheetOut;
  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    void close() => Navigator.of(context).pop();
    // Unframed bodies read insets from where they are placed (inside the
    // SafeArea/padding below), not from the route: reading the route's own
    // MediaQuery added the status bar and navigation bar heights again.
    Widget surface({bool handle = true, bool edge = false}) => framed
        ? CaSheet(
            title: title,
            body: body,
            actions: actions,
            onClose: close,
            handle: handle)
        : Builder(
            builder: (placed) => MediaQuery.removeViewInsets(
                context: placed,
                removeBottom: true,
                child: edge
                    ? Material(color: edgeColor, child: body)
                    : ClipRRect(
                        borderRadius:
                            BorderRadius.circular(CanopyRadius.sheetTop),
                        child: Material(color: Canopy.paper, child: body))));
    Widget child;
    if (fullWidthOnPhone &&
        job != CaSheetJob.confirmation &&
        presentation == CaSheetPresentation.sheet) {
      final media = MediaQuery.of(context);
      final insets = media.padding;
      child = AnimatedPadding(
          duration: reduced ? CanopyMotion.none : CanopyMotion.sheetIn,
          curve: CanopyMotion.drawer,
          padding: EdgeInsets.only(
              top: insets.top + AppTheme.spaceMd,
              bottom: context.isPhoneLandscape ? 0 : media.viewInsets.bottom),
          child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: media.size.height * CanopySize.sheetHeightFraction),
                  child: BottomSheet(
                      animationController: controller,
                      backgroundColor: Canopy.transparent,
                      elevation: 0,
                      onClosing: close,
                      builder: (_) => ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(CanopyRadius.sheetTop)),
                          child: ColoredBox(
                              color: edgeColor,
                              child: Padding(
                                  padding: EdgeInsetsDirectional.only(
                                      start: flushOnPhone
                                          ? 0
                                          : AppTheme.screenPadding,
                                      end: flushOnPhone
                                          ? 0
                                          : AppTheme.screenPadding),
                                  // The body keeps the bottom inset, so its own
                                  // SafeArea clears the navigation bar while
                                  // this surface paints behind it.
                                  child: Center(
                                      heightFactor: 1,
                                      child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                              maxWidth: surfaceConstraints
                                                      ?.maxWidth ??
                                                  (job == CaSheetJob.studio
                                                      ? CanopySize.studioMax
                                                      : CanopySize.sheetMax)),
                                          // The sheet sits below the status
                                          // bar; only the bottom inset stays.
                                          child: MediaQuery.removePadding(
                                              context: context,
                                              removeTop: true,
                                              child:
                                                  surface(edge: true)))))))))));
    } else if (job == CaSheetJob.confirmation) {
      child = framed
          ? CaDialog(title: title, body: body, actions: actions, onClose: close)
          : body;
    } else {
      final size = MediaQuery.sizeOf(context);
      final drawer = presentation == CaSheetPresentation.drawer;
      child = AnimatedPadding(
          duration: reduced ? CanopyMotion.none : CanopyMotion.sheetIn,
          curve: CanopyMotion.drawer,
          padding: EdgeInsetsDirectional.fromSTEB(
              drawer ? AppTheme.spaceMd : AppTheme.screenPadding,
              AppTheme.spaceMd,
              drawer ? AppTheme.spaceMd : AppTheme.screenPadding,
              context.isPhoneLandscape
                  ? 0
                  : MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
              child: Align(
                  alignment: drawer
                      ? AlignmentDirectional.centerEnd
                      : presentation == CaSheetPresentation.sheet
                          ? Alignment.bottomCenter
                          : Alignment.center,
                  child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: surfaceConstraints?.maxWidth ??
                              (drawer
                                  ? CanopySize.drawerMax
                                  : job == CaSheetJob.studio
                                      ? CanopySize.studioMax
                                      : CanopySize.sheetMax),
                          maxHeight:
                              size.height * CanopySize.sheetHeightFraction),
                      child: presentation == CaSheetPresentation.sheet
                          ? BottomSheet(
                              animationController: controller,
                              backgroundColor: Canopy.transparent,
                              elevation: 0,
                              onClosing: close,
                              builder: (_) => surface())
                          : surface(handle: false)))));
    }
    return themes.wrap(MediaQuery(
        data: MediaQuery.of(context).copyWith(
            disableAnimations:
                reduced || MediaQuery.disableAnimationsOf(context)),
        child: Semantics(
            scopesRoute: true, explicitChildNodes: true, child: child)));
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (reduced) {
      return child;
    }
    final curve = CurvedAnimation(
        parent: animation,
        curve: CanopyMotion.drawer,
        reverseCurve: CanopyMotion.drawer);
    if (presentation == CaSheetPresentation.dialog) {
      return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
              scale: Tween(begin: CanopyMotion.pressScale, end: 1.0)
                  .animate(curve),
              child: child));
    }
    final direction =
        Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return SlideTransition(
        position: Tween<Offset>(
                begin: presentation == CaSheetPresentation.drawer
                    ? Offset(direction, 0)
                    : const Offset(0, 1),
                end: Offset.zero)
            .animate(curve),
        child: child);
  }
}

/// Shared confirmation transport: preserves the caller's result and callbacks.
/// Exposed for callers that must await reverse-animation completion before
/// disposing an editor controller.
PopupRoute<T> createCaDialogRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) =>
    _CaSurfaceRoute<T>(
      title: '',
      body: Builder(builder: builder),
      actions: const [],
      job: CaSheetJob.confirmation,
      presentation: CaSheetPresentation.dialog,
      framed: false,
      reduced: CanopyMotion.reduced(context),
      themes: InheritedTheme.capture(
          from: context,
          to: Navigator.of(context, rootNavigator: useRootNavigator).context),
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    );

Future<T?> showCaDialog<T>(
        {required BuildContext context,
        required WidgetBuilder builder,
        bool barrierDismissible = true,
        bool useRootNavigator = true}) =>
    showCaSheet<T>(context,
        title: '',
        body: Builder(builder: builder),
        job: CaSheetJob.confirmation,
        framed: false,
        barrierDismissible: barrierDismissible,
        useRootNavigator: useRootNavigator);

/// The shared frame accepts existing title/content/actions without changing logic.
class CaAlertDialog extends AlertDialog {
  const CaAlertDialog(
      {super.key,
      super.title,
      super.content,
      super.actions,
      super.backgroundColor,
      super.shape,
      super.scrollable,
      super.contentPadding,
      super.insetPadding,
      super.actionsPadding,
      super.titlePadding});
  @override
  Widget build(BuildContext context) => CaDialog(
      title: '',
      titleWidget: title,
      body: content ?? const SizedBox.shrink(),
      actions: actions ?? const []);
}
