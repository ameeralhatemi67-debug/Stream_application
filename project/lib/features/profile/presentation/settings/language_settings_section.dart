import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_fields.dart';

class LanguageSettingsSection extends StatelessWidget {
  const LanguageSettingsSection({super.key});
  @override
  Widget build(BuildContext context) => CaCard(
      child: Directionality(
          textDirection: ui.TextDirection.ltr,
          child: CaSegmentedTabs(
              labels: [
                'design_ui.english_us'.tr(),
                'design_copy.arabic_language'.tr()
              ],
              index: context.locale.languageCode == 'ar' ? 1 : 0,
              onChanged: (index) =>
                  context.setLocale(Locale(index == 0 ? 'en' : 'ar')))));
}
