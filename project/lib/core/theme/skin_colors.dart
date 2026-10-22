import 'package:flutter/widgets.dart';

import 'app_skin.dart';
import 'canopy_tokens.dart';
import 'hedayah_skin.dart';

/// Colours that change with the skin (ADR-016). Screens set their page
/// ground explicitly, so they ask here rather than for a fixed token.
extension SkinColors on BuildContext {
  /// Ivory in gold & black; the website's mist in the Hedayah skin.
  Color get pageGround => isHedayahSkin ? HedayahSkin.page : Canopy.dawn;
}
