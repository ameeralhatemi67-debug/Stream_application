import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/safe_image_provider.dart';

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
    return showModalBottomSheet<Uint8List?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => ImageArrangeModal(
        imagePath: imagePath,
        imageBytes: imageBytes,
        arrangeType: arrangeType,
        title: title ?? (arrangeType == ImageArrangeType.avatarCircle ? 'Crop Profile Photo' : 'Crop Header Banner'),
      ),
    );
  }

  @override
  State<ImageArrangeModal> createState() => _ImageArrangeModalState();
}

class _ImageArrangeModalState extends State<ImageArrangeModal> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();
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
      _transformationController.value = Matrix4.diagonal3Values(newScale, newScale, 1.0);
    });
  }

  Future<void> _applyCrop() async {
    setState(() => _isProcessing = true);

    try {
      // Allow frame to render fully
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;

      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.of(context).pop(widget.imageBytes);
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

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
          color: AppTheme.darkSurface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.accentRed, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.accentRed, size: 36),
            const SizedBox(height: 10),
            const Text(
              'Image Decode Error',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              _decodeErrorMessage ?? 'Unable to parse image data on this device.',
              style: const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 11),
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
    final size = MediaQuery.of(context).size;
    final isAvatar = widget.arrangeType == ImageArrangeType.avatarCircle;
    final cutoutWidth = isAvatar ? 260.0 : (size.width - 40).clamp(280.0, 520.0);
    final cutoutHeight = isAvatar ? 260.0 : (cutoutWidth * (9 / 16));

    return Container(
      height: size.height * 0.92,
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            // 🏷️ Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: _isProcessing ? null : _applyCrop,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text(
                            'Apply',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2F3336)),

            // 🖼️ Canvas Cropper Area with Anti-Black-Bar Boundary Clamping
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Full Screen Dimmed Backdrop
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                    ),
                  ),

                  // 🎯 The Strict Anti-Black-Bar Viewport Box (RepaintBoundary)
                  RepaintBoundary(
                    key: _cropKey,
                    child: ClipRRect(
                      borderRadius: isAvatar ? BorderRadius.circular(cutoutWidth / 2) : BorderRadius.circular(0),
                      child: Container(
                        width: cutoutWidth,
                        height: cutoutHeight,
                        color: Colors.black,
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 1.0,
                          maxScale: 3.5,
                          // BoundaryMargin = zero strictly prevents panning the image inside or revealing black borders
                          boundaryMargin: EdgeInsets.zero,
                          clipBehavior: Clip.hardEdge,
                          child: _buildRawImage(cutoutWidth, cutoutHeight),
                        ),
                      ),
                    ),
                  ),

                  // 🔲 Visual Cutout Border Overlay (Guiding Ring / Frame)
                  if (!_hasDecodeError)
                    IgnorePointer(
                      child: Container(
                        width: cutoutWidth,
                        height: cutoutHeight,
                        decoration: BoxDecoration(
                          shape: isAvatar ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: isAvatar ? null : BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 🔍 Bottom Zoom Slider Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: Colors.black,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.photo_size_select_small_rounded, color: Colors.white70, size: 20),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: const Color(0xFF2F3336),
                            thumbColor: Colors.white,
                            overlayColor: Colors.white.withValues(alpha: 0.2),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
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
                      const Icon(Icons.photo_size_select_actual_rounded, color: Colors.white, size: 24),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pinch to zoom and drag to reposition',
                    style: TextStyle(color: Color(0xFF71767B), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
