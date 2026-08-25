import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

class LanguageSwitcher extends StatelessWidget {
  final bool showLabel;
  final EdgeInsetsGeometry? padding;

  const LanguageSwitcher({
    super.key,
    this.showLabel = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final targetLangCode = isArabic ? 'EN' : 'عربي';

    return InkWell(
      onTap: () {
        if (isArabic) {
          context.setLocale(const Locale('en'));
        } else {
          context.setLocale(const Locale('ar'));
        }
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: padding ??
            const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMd,
              vertical: AppTheme.spaceSm,
            ),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: AppTheme.darkBorderSubtle,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/Language.svg',
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                AppTheme.accentBlue,
                BlendMode.srcIn,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(width: AppTheme.spaceXs),
              Text(
                targetLangCode,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryDark,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
