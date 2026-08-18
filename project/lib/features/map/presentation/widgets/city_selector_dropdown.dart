import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/map_models.dart';

class CitySelectorDropdown extends StatelessWidget {
  final MapRegionModel selectedCity;
  final ValueChanged<MapRegionModel> onCitySelected;

  const CitySelectorDropdown({
    super.key,
    required this.selectedCity,
    required this.onCitySelected,
  });

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;

    return PopupMenuButton<MapRegionModel>(
      onSelected: onCitySelected,
      color: AppTheme.darkSurface3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: const BorderSide(color: AppTheme.accentRed, width: 1.2),
      ),
      offset: const Offset(0, 44),
      itemBuilder: (context) {
        return alSharqiaRegions.map((region) {
          final isCurrent = region.regionId == selectedCity.regionId;
          return PopupMenuItem<MapRegionModel>(
            value: region,
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: isCurrent ? AppTheme.accentRed : AppTheme.textMutedDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    region.getLocalizedName(langCode),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? AppTheme.accentRed : AppTheme.textPrimaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCurrent)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppTheme.accentRed,
                  ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface3.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentRed.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: AppTheme.accentRed,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      selectedCity.getLocalizedName(langCode),
                      style: const TextStyle(
                        color: AppTheme.textPrimaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppTheme.accentRed,
            ),
          ],
        ),
      ),
    );
  }
}
