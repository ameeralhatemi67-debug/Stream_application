import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/app_identity.dart';

/// The owner-supplied gold mark, without recolouring.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 80, this.monochrome = false});
  final double size;
  final bool monochrome;

  /// The gold mark at display size: 2x of the largest place it is drawn (the
  /// 104 px splash), with a 3.0x variant for phones. The 2.9 MB master
  /// (clearlogo2.png) is not bundled.
  static const hidayahAsset = 'assets/logo/hidayah_mark.png';

  @override
  Widget build(BuildContext context) {
    final label =
        AppIdentity.name(Localizations.localeOf(context).languageCode);
    return monochrome
        ? SvgPicture.asset('assets/logo/black.svg',
            width: size, height: size, fit: BoxFit.contain, semanticsLabel: label)
        : Image.asset(hidayahAsset,
            width: size, height: size, fit: BoxFit.contain, semanticLabel: label);
  }
}
