import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/app_identity.dart';

/// Owner-supplied artwork, without recolouring or changes to its geometry.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 80, this.monochrome = false});
  final double size;
  final bool monochrome;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    monochrome ? 'assets/logo/black.svg' : 'assets/logo/colored.svg',
    width: size, height: size, fit: BoxFit.contain,
    semanticsLabel: AppIdentity.name(Localizations.localeOf(context).languageCode),
  );
}
