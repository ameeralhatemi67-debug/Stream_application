import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/app_identity.dart';
import '../theme/app_palette.dart';

/// Owner-supplied artwork for each palette, without recolouring.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 80, this.monochrome = false});
  final double size;
  final bool monochrome;

  /// The gold mark at display size: 2x of the largest place it is drawn (the
  /// 104 px splash), with a 3.0x variant for phones. The 2.9 MB master
  /// (clearlogo2.png) is not bundled.
  static const hidayahAsset = 'assets/logo/hidayah_mark.png';

  @override
  Widget build(BuildContext context) => !monochrome &&
          paletteOf(context).hidayah
      ? Image.asset(
          hidayahAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          semanticLabel:
              AppIdentity.name(Localizations.localeOf(context).languageCode),
        )
      : SvgPicture.asset(
          monochrome ? 'assets/logo/black.svg' : 'assets/logo/colored.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
          semanticsLabel:
              AppIdentity.name(Localizations.localeOf(context).languageCode),
        );
}
