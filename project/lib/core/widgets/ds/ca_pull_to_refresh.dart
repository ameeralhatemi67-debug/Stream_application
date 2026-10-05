import 'dart:math' as math;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// Pull the top of a list down: a star draws itself as you pull, turns once
/// past the threshold, then spins while [onRefresh] runs and the list springs
/// back. The star is drawn bare, with no disc behind it.
class CaPullToRefresh extends StatefulWidget {
  const CaPullToRefresh(
      {super.key, required this.child, required this.onRefresh});
  final Widget child;
  final Future<void> Function() onRefresh;

  /// How far the list must overscroll before a release refreshes.
  static const threshold = 64.0;

  @override
  State<CaPullToRefresh> createState() => _CaPullToRefreshState();
}

class _CaPullToRefreshState extends State<CaPullToRefresh>
    with SingleTickerProviderStateMixin {
  final _pull = ValueNotifier<double>(0);
  final _refreshing = ValueNotifier<bool>(false);
  late final _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  bool _dragging = false, _armed = false;
  double _lastDragPull = 0;

  @override
  void dispose() {
    _pull.dispose();
    _refreshing.dispose();
    _spin.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    // Only the outermost vertical list reacts, and only at its start.
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (_refreshing.value) return false;
    final pulled = math.max(0.0, -n.metrics.pixels);
    if (n is ScrollUpdateNotification || n is OverscrollNotification) {
      final dragging = n is ScrollUpdateNotification
          ? n.dragDetails != null
          : (n as OverscrollNotification).dragDetails != null;
      if (dragging) {
        _dragging = true;
        _lastDragPull = pulled;
        final over = pulled >= CaPullToRefresh.threshold;
        if (over && !_armed) HapticFeedback.selectionClick();
        _armed = over;
      } else if (_dragging) {
        // The finger lifted: refresh if it had pulled far enough.
        _dragging = false;
        if (_lastDragPull >= CaPullToRefresh.threshold) _start();
      }
      _pull.value = pulled;
    } else if (n is ScrollEndNotification) {
      _dragging = false;
      _armed = false;
      if (!_refreshing.value) _pull.value = 0;
    }
    return false;
  }

  Future<void> _start() async {
    _refreshing.value = true;
    _armed = false;
    if (!CanopyMotion.reduced(context)) _spin.repeat();
    try {
      await widget.onRefresh();
    } finally {
      // Give a very quick refresh time to be seen turning.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      _spin.stop();
      _spin.value = 0;
      if (mounted) {
        _refreshing.value = false;
        _pull.value = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context).copyWith(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        overscroll: false,
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        });
    return Stack(children: [
      NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ScrollConfiguration(behavior: behavior, child: widget.child)),
      Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
              child: ListenableBuilder(
                  listenable: Listenable.merge([_pull, _refreshing, _spin]),
                  builder: (context, _) {
                    final refreshing = _refreshing.value;
                    final progress = refreshing
                        ? 1.0
                        : (_pull.value / CaPullToRefresh.threshold)
                            .clamp(0.0, 1.0);
                    if (progress == 0 && !refreshing) {
                      return const SizedBox.shrink();
                    }
                    final dy = refreshing
                        ? AppTheme.spaceLg
                        : AppTheme.spaceSm + _pull.value * .4;
                    final angle = refreshing
                        ? math.pi + _spin.value * 2 * math.pi
                        : progress * math.pi;
                    return Align(
                        alignment: Alignment.topCenter,
                        child: Transform.translate(
                            offset: Offset(0, dy),
                            child: Opacity(
                                opacity: progress,
                                child: Transform.rotate(
                                    angle: angle,
                                    child: CustomPaint(
                                        size: const Size.square(36),
                                        painter: _StarPainter(
                                            progress: progress,
                                            color: Canopy.brandGreen))))));
                  }))),
    ]);
  }
}

/// An eight-point star that draws itself as [progress] goes from 0 to 1.
class _StarPainter extends CustomPainter {
  const _StarPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  // The star's points on a 40 x 40 grid.
  static const _points = [
    (20.0, 3.0),
    (24.0, 12.0),
    (33.0, 8.0),
    (29.0, 17.0),
    (37.0, 20.0),
    (29.0, 23.0),
    (33.0, 32.0),
    (24.0, 28.0),
    (20.0, 37.0),
    (16.0, 28.0),
    (7.0, 32.0),
    (11.0, 23.0),
    (3.0, 20.0),
    (11.0, 17.0),
    (7.0, 8.0),
    (16.0, 12.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 40;
    final path = Path()..moveTo(_points[0].$1 * scale, _points[0].$2 * scale);
    for (final p in _points.skip(1)) {
      path.lineTo(p.$1 * scale, p.$2 * scale);
    }
    path.close();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.progress != progress || old.color != color;
}
