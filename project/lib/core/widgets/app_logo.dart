import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/app_identity.dart';
import '../theme/app_palette.dart';

/// Owner-supplied artwork for each palette, without recolouring.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 80, this.monochrome = false});
  final double size;
  final bool monochrome;

  @override
  Widget build(BuildContext context) => !monochrome &&
          paletteOf(context).hidayah
      ? Image.asset(
          'assets/logo/clearlogo2.png',
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
