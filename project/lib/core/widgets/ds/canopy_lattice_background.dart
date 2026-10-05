import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_theme.dart';

/// Memory pressure only switches off optional lattice decoration, for this run.
class CanopyTexturePolicy extends ValueNotifier<bool>
    with WidgetsBindingObserver {
  CanopyTexturePolicy._()
      : super(
            const bool.fromEnvironment('CANOPY_TEXTURES', defaultValue: true)) {
    WidgetsBinding.instance.addObserver(this);
  }
  static final instance = CanopyTexturePolicy._();
  @override
  void didHaveMemoryPressure() {
    value = false;
    CanopyLatticeBackground._evictTexture();
  }

  @visibleForTesting
  void restoreForTest() => value = true;
}

/// One emerald entry panel; texture never paints the phone's Dawn canvas.
class CanopyLatticeBackground extends StatefulWidget {
  const CanopyLatticeBackground(
      {super.key,
      required this.child,
      this.texture = true,
      this.gradient = true,
      this.textureColor = Canopy.paper,
      this.textureOpacity = CanopyTexture.starLatticeOpacity,
      this.pointer});
  final Widget child;
  final bool texture;
  final bool gradient;
  final Color textureColor;
  final double textureOpacity;
  final ValueNotifier<Offset?>? pointer;
  static Future<ui.Image>? _tile;
  static ui.Image? _readyTile;
  static int _generation = 0;
  static void _evictTexture() {
    _generation++;
    final image = _readyTile;
    _readyTile = null;
    _tile = null;
    // Mounted painters stop using the image before its native allocation ends.
    WidgetsBinding.instance.addPostFrameCallback((_) => image?.dispose());
  }

  static Future<ui.Image> prepareTexture() => _tile ??= _loadTile();
  static Future<ui.Image> _loadTile() async {
    final generation = _generation;
    final picture = await vg.loadPicture(
        const SvgAssetLoader('assets/canopy/textures/star.svg'), null);
    final image = await picture.picture.toImage(
        CanopyTexture.starTile.toInt(), CanopyTexture.starTile.toInt());
    picture.picture.dispose();
    if (generation == _generation && CanopyTexturePolicy.instance.value) {
      _readyTile = image;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
    }
    return image;
  }

  @override
  State<CanopyLatticeBackground> createState() => _CanopyLatticeBackgroundState();
}

class _CanopyLatticeBackgroundState extends State<CanopyLatticeBackground>
    with TickerProviderStateMixin {
  late final _gradient =
      AnimationController(vsync: this, duration: CanopyMotion.gradientDrift);
  late final _texture =
      AnimationController(vsync: this, duration: CanopyMotion.textureCycle);
  late final _pointer = widget.pointer ?? ValueNotifier<Offset?>(null);
  bool get _showTexture =>
      widget.texture &&
      CanopyTexturePolicy.instance.value &&
      !CanopyMotion.reduced(context);
  bool get _spotlight =>
      _showTexture &&
      kIsWeb &&
      MediaQuery.sizeOf(context).width >= CanopyWindow.expanded;
  @override
  void initState() {
    super.initState();
    CanopyTexturePolicy.instance.addListener(_policyChanged);
  }

  void _policyChanged() {
    if (!mounted) return;
    _syncMotion();
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(CanopyLatticeBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    if (CanopyMotion.reduced(context)) {
      _gradient.stop();
      _gradient.value = 0;
      _texture.stop();
      _texture.value = 0;
      _pointer.value = null;
    } else {
      if (widget.gradient) {
        if (!_gradient.isAnimating) _gradient.repeat();
      } else {
        _gradient.stop();
      }
      final size = MediaQuery.sizeOf(context);
      final nativeMedium = !kIsWeb &&
          size.shortestSide >= CanopyWindow.phoneShortestSideMax &&
          size.width >= CanopyWindow.medium &&
          size.width < CanopyWindow.expanded;
      if (_showTexture && !nativeMedium) {
        if (!_texture.isAnimating) _texture.repeat();
      } else {
        _texture.stop();
        _pointer.value = null;
      }
    }
  }

  @override
  void dispose() {
    CanopyTexturePolicy.instance.removeListener(_policyChanged);
    if (widget.pointer == null) _pointer.dispose();
    _gradient.dispose();
    _texture.dispose();
    super.dispose();
  }

  Widget _lattice(ui.Image image) => RepaintBoundary(
      child: CustomPaint(
          painter: _Lattice(
              image,
              _texture,
              _pointer,
              Directionality.of(context),
              widget.textureColor,
              widget.textureOpacity)));
  @override
  Widget build(BuildContext context) => MouseRegion(
      onHover:
          _spotlight ? (event) => _pointer.value = event.localPosition : null,
      onExit: _spotlight ? (_) => _pointer.value = null : null,
      child: RepaintBoundary(
          child: CustomPaint(
              painter: widget.gradient
                  ? _PanelGradient(_gradient, Directionality.of(context))
                  : null,
              child: RepaintBoundary(
                  child: Stack(fit: StackFit.passthrough, children: [
                if (_showTexture)
                  Positioned.fill(
                      child: IgnorePointer(
                          child: CanopyLatticeBackground._readyTile != null
                              ? _lattice(CanopyLatticeBackground._readyTile!)
                              : FutureBuilder<ui.Image>(
                                  future: CanopyLatticeBackground.prepareTexture(),
                                  builder: (context, snapshot) =>
                                      snapshot.hasData
                                          ? _lattice(snapshot.data!)
                                          : const SizedBox.shrink()))),
                widget.child,
              ])))));
}

class _PanelGradient extends CustomPainter {
  _PanelGradient(this.motion, this.direction) : super(repaint: motion);
  final Animation<double> motion;
  final TextDirection direction;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = CanopyGradients.panelAt(motion.value)
              .createShader(rect, textDirection: direction));
  }

  @override
  bool shouldRepaint(_PanelGradient old) =>
      old.motion != motion || old.direction != direction;
}

class _Lattice extends CustomPainter {
  _Lattice(this.tile, this.motion, this.pointer, this.direction, this.color,
      this.opacity)
      : super(repaint: Listenable.merge([motion, pointer]));
  final ui.Image tile;
  final Animation<double> motion;
  final ValueListenable<Offset?> pointer;
  final TextDirection direction;
  final Color color;
  final double opacity;
  @override
  void paint(Canvas canvas, Size size) {
    final matrix = Matrix4.identity()
      ..translateByDouble(motion.value * CanopyTexture.starTile,
          motion.value * CanopyTexture.starTile, 0, 1);
    final paint = Paint()
      ..shader = ui.ImageShader(
          tile, ui.TileMode.repeated, ui.TileMode.repeated, matrix.storage)
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn)
      ..color = Canopy.paper.withValues(alpha: opacity);
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, paint);
    final centre = pointer.value ??
        Offset(direction == TextDirection.rtl ? 0 : size.width, 0);
    final fade = Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = CanopyGradients.latticeFade.createShader(Rect.fromCircle(
          center: centre, radius: size.longestSide * CanopyTexture.fadeRadius));
    canvas.drawRect(Offset.zero & size, fade);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Lattice old) =>
      old.tile != tile ||
      old.direction != direction ||
      old.color != color ||
      old.opacity != opacity;
}
