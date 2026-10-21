import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'ds/ca_focus_ring.dart';

class LanguageSwitcher extends StatelessWidget {
  final bool showLabel;
  final bool overlay;
  final bool canopy;

  /// Icon only: no pill, circle or border behind the language glyph.
  final bool bare;
  final EdgeInsetsGeometry? padding;

  const LanguageSwitcher({
    super.key,
    this.showLabel = true,
    this.overlay = false,
    this.canopy = false,
    this.bare = false,
    this.padding,
  });

  /// Switches between English and Arabic and keeps push reminders in the new
  /// language. Shared by every language control.
  static Future<void> toggle(BuildContext context) async {
    final language = context.locale.languageCode == 'ar' ? 'en' : 'ar';
    await context.setLocale(Locale(language));
    if (context.mounted) {
      unawaited(context.read<AppProvider>().syncReminderPush(
          requestPermission: false, language: language));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final targetLangCode = isArabic ? 'EN' : 'عربي';

    return CaFocusRing(
        onDark: overlay,
        child: Tooltip(
          message: 'language.switch_lang'.tr(),
          child: InkWell(
            onTap: () => toggle(context),
            borderRadius: BorderRadius.circular(
                overlay || canopy ? AppTheme.radiusFull : AppTheme.radiusSm),
            child: Container(
              constraints: canopy
                  ? const BoxConstraints(
                      minHeight: CanopySize.target, minWidth: CanopySize.target)
                  : null,
              padding: padding ??
                  (overlay
                      ? const EdgeInsets.all(15)
                      : const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd,
                          vertical: AppTheme.spaceSm,
                        )),
              decoration: bare
                  ? null
                  : BoxDecoration(
                color: overlay
                    ? AppTheme.surface
                        .withValues(alpha: canopy ? CanopySize.glassAlpha : .6)
                    : AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(overlay || canopy
                    ? AppTheme.radiusFull
                    : AppTheme.radiusSm),
                border: overlay
                    ? (canopy
                        ? Border.all(
                            color: Canopy.paper
                                .withValues(alpha: CanopySize.glassBorderAlpha))
                        : null)
                    : Border.all(
                        color: AppTheme.border,
                        width: 1.0,
                      ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/Language.svg',
                    width: canopy ? CanopySize.icon : 18,
                    height: canopy ? CanopySize.icon : 18,
                    colorFilter: ColorFilter.mode(
                      canopy && overlay ? Canopy.paper : AppTheme.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                  if (showLabel &&
                      (!canopy ||
                          (MediaQuery.sizeOf(context).width >= 360 &&
                              MediaQuery.textScalerOf(context).scale(1) <
                                  1.3))) ...[
                    const SizedBox(width: AppTheme.spaceXs),
                    Text(
                      targetLangCode,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: canopy && overlay
                                ? Canopy.paper
                                : AppTheme.textPrimary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ));
  }
}
