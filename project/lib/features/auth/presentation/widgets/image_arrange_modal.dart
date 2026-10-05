import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../../core/widgets/ds/ca_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';

enum ImageArrangeType {
  avatarCircle,
  banner16x9,
}

/// X & WhatsApp Style Interactive Media Cropper with Anti-Black-Bar Boundary Clamping
class ImageArrangeModal extends StatefulWidget {
  final String imagePath;
  final Uint8List? imageBytes;
  final ImageArrangeType arrangeType;
  final String title;

  const ImageArrangeModal({
    super.key,
    required this.imagePath,
    this.imageBytes,
    required this.arrangeType,
    this.title = 'Edit Media',
  });

  static Future<Uint8List?> show({
    required BuildContext context,
    required String imagePath,
    Uint8List? imageBytes,
    required ImageArrangeType arrangeType,
    String? title,
  }) {
    return showCaSheet<Uint8List?>(context,
        title: '',
        framed: false,
        useRootNavigator: false,
        body: Builder(
            builder: (ctx) => ImageArrangeModal(
                  imagePath: imagePath,
                  imageBytes: imageBytes,
                  arrangeType: arrangeType,
                  title: title ??
                      (arrangeType == ImageArrangeType.avatarCircle
                          ? 'Crop Profile Photo'
                          : 'Crop Header Banner'),
                )));
  }

  @override
  State<ImageArrangeModal> createState() => _ImageArrangeModalState();
}

class _ImageArrangeModalState extends State<ImageArrangeModal> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformationController =
      TransformationController();
  double _currentScale = 1.0;
  bool _isProcessing = false;
  bool _hasDecodeError = false;
  String? _decodeErrorMessage;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (mounted && (_currentScale - scale).abs() > 0.02) {
      setState(() {
        _currentScale = scale.clamp(1.0, 3.5);
      });
    }
  }

  void _onSliderChanged(double newScale) {
    setState(() {
      _currentScale = newScale;
      _transformationController.value =
          Matrix4.diagonal3Values(newScale, newScale, 1.0);
    });
  }

  Future<void> _applyCrop() async {
    setState(() => _isProcessing = true);

    try {
      // Allow frame to render fully
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;

      final boundary =
          _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.of(context).pop(widget.imageBytes);
        return;
      }

      // Cap the export at 512 px (avatar) / 1280 px (banner) wide. A fixed 3x
      // ratio produced multi-MB PNGs that every viewer downloaded per card.
      final targetWidth =
          widget.arrangeType == ImageArrangeType.avatarCircle ? 512.0 : 1280.0;
      final ratio = (targetWidth / boundary.size.width).clamp(0.5, 3.0);
      final ui.Image image = await boundary.toImage(pixelRatio: ratio);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List croppedBytes = byteData.buffer.asUint8List();
        if (mounted) {
          Navigator.of(context).pop(croppedBytes);
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop(widget.imageBytes);
        }
      }
    } catch (e) {
      debugPrint('Crop render error: $e');
      if (mounted) {
        Navigator.of(context).pop(widget.imageBytes);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildRawImage(double width, double height) {
    if (_hasDecodeError) {
      return Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: Canopy.liveCrimson, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Canopy.liveCrimson, size: 36),
            const SizedBox(height: 10),
            Text(
              'design_ui.image_decode_error'.tr(),
              style: const TextStyle(
                  color: AppTheme.onMedia,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              _decodeErrorMessage ??
                  'Unable to parse image data on this device.',
              style: const TextStyle(
                  color: Canopy.slate,
                  fontSize: AppTheme.captionFont),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final provider = buildSafeImageProvider(
      path: widget.imagePath,
      bytes: widget.imageBytes,
      defaultAsset: widget.arrangeType == ImageArrangeType.avatarCircle
          ? 'assets/images/Amir_Alhatemi/amir_person_pic.jpg'
          : 'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
    );

    // Anti-Black-Bar Invariant: Always size the underlying image using BoxFit.cover
    // so at scale 1.0 it completely fills the cutout box in all dimensions with zero void
    return SizedBox(
      width: width,
      height: height,
      child: Image(
        image: provider,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasDecodeError) {
              setState(() {
                _hasDecodeError = true;
                _decodeErrorMessage = 'Load Error: $error';
              });
            }
          });
          return const SizedBox.shrink();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isAvatar = widget.arrangeType == ImageArrangeType.avatarCircle;
    final cutoutWidth =
        isAvatar ? 260.0 : (size.width - 40).clamp(280.0, 520.0);
    final cutoutHeight = isAvatar ? 260.0 : (cutoutWidth * (9 / 16));

    return Container(
      height: size.height * 0.92,
      color: AppTheme.media,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Row(children: [
                Expanded(
                    child: Text(widget.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Canopy.paper))),
                CaIconButton(
                    icon: CaGlyph.close,
                    glass: true,
                    bare: true,
                    label: 'design_ui.cancel'.tr(),
                    onPressed: () => Navigator.of(context).pop(null)),
              ]),
            ),
            const Divider(height: 1, color: Canopy.hairline),
            Expanded(child: LayoutBuilder(builder: (context, bounds) {
              // Keep the original capture box dimensions even in a short viewport.
              // Scrolling reveals it rather than squeezing the exported pixels.
              final canvas = LayoutBuilder(
                  builder: (context, area) => SingleChildScrollView(
                      child: SizedBox(
                          height: area.maxHeight < cutoutHeight
                              ? cutoutHeight
                              : area.maxHeight,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Full Screen Dimmed Backdrop
                              Positioned.fill(
                                child: Container(
                                  color: AppTheme.media,
                                ),
                              ),

                              //  The Strict Anti-Black-Bar Viewport Box (RepaintBoundary)
                              RepaintBoundary(
                                key: _cropKey,
                                child: ClipRRect(
                                  borderRadius: isAvatar
                                      ? BorderRadius.circular(cutoutWidth / 2)
                                      : BorderRadius.circular(0),
                                  child: Container(
                                    width: cutoutWidth,
                                    height: cutoutHeight,
                                    color: AppTheme.media,
                                    child: InteractiveViewer(
                                      transformationController:
                                          _transformationController,
                                      minScale: 1.0,
                                      maxScale: 3.5,
                                      // BoundaryMargin = zero strictly prevents panning the image inside or revealing black borders
                                      boundaryMargin: EdgeInsets.zero,
                                      clipBehavior: Clip.hardEdge,
                                      child: _buildRawImage(
                                          cutoutWidth, cutoutHeight),
                                    ),
                                  ),
                                ),
                              ),

                              //  Visual Cutout Border Overlay (Guiding Ring / Frame)
                              if (!_hasDecodeError)
                                IgnorePointer(
                                  child: Container(
                                    width: cutoutWidth,
                                    height: cutoutHeight,
                                    decoration: BoxDecoration(
                                      shape: isAvatar
                                          ? BoxShape.circle
                                          : BoxShape.rectangle,
                                      borderRadius: isAvatar
                                          ? null
                                          : BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AppTheme.onMedia
                                            .withValues(alpha: 0.9),
                                        width: 2.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.media
                                              .withValues(alpha: 0.6),
                                          blurRadius: 20,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ))));
              final controls =
                  Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: AppTheme.media,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.photo_size_select_small_rounded,
                              color: AppTheme.onMedia.withValues(alpha: 0.7),
                              size: 20),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppTheme.onMedia,
                                inactiveTrackColor: Canopy.hairline,
                                thumbColor: AppTheme.onMedia,
                                overlayColor:
                                    AppTheme.onMedia.withValues(alpha: 0.2),
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7),
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: _currentScale,
                                min: 1.0,
                                max: 3.5,
                                onChanged: _onSliderChanged,
                              ),
                            ),
                          ),
                          const Icon(Icons.photo_size_select_actual_rounded,
                              color: AppTheme.onMedia, size: 24),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'design_ui.pinch_to_zoom_and_drag_to_reposition'.tr(),
                        style:
                            const TextStyle(color: Canopy.mist, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceLg),
                  child: Row(children: [
                    Flexible(
                        child: CaButton(
                            label: 'design_ui.cancel'.tr(),
                            variant: CaButtonVariant.secondary,
                            onPressed: () => Navigator.of(context).pop(null))),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(
                        child: CaButton(
                            label: 'design_ui.apply'.tr(),
                            loading: _isProcessing,
                            onPressed: _isProcessing ? null : _applyCrop)),
                  ]),
                )
              ]);
              if (size.width > size.height && size.width >= 600) {
                return Row(children: [
                  Expanded(child: canvas),
                  SizedBox(
                      width: CanopySize.wizardRail,
                      child: SingleChildScrollView(child: controls))
                ]);
              }
              return Column(children: [Expanded(child: canvas), controls]);
            })),
          ],
        ),
      ),
    );
  }
}
