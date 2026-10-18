import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/map_tricity_domain.dart';

/// Id used for the "All three cities" overview entry.
const String kAllCitiesId = 'all';

/// City view selector for the three-city map. Choosing an entry only moves
/// the map view; it never claims a municipal boundary.
class CitySelectorDropdown extends StatelessWidget {
  final String selectedCityId;
  final ValueChanged<String> onCitySelected;

  const CitySelectorDropdown({
    super.key,
    this.selectedCityId = kAllCitiesId,
    required this.onCitySelected,
  });

  static String labelFor(String cityId, String languageCode) =>
      cityViewById(cityId)?.localizedName(languageCode) ??
      'map.all_cities'.tr();

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final ids = [kAllCitiesId, for (final view in kTricityCityViews) view.id];

    return PopupMenuButton<String>(
      tooltip: 'map.choose_place'.tr(),
      onSelected: onCitySelected,
      color: paletteColor(context, AppTheme.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(color: paletteColor(context, AppTheme.border), width: 1.0),
      ),
      offset: const Offset(0, 44),
      itemBuilder: (context) {
        return ids.map((id) {
          final isCurrent = id == selectedCityId;
          return PopupMenuItem<String>(
            value: id,
            child: Row(
              children: [
                Icon(
                  id == kAllCitiesId
                      ? Icons.map_outlined
                      : Icons.location_on_rounded,
                  size: 18,
                  color: isCurrent ? paletteColor(context, AppTheme.primary) : paletteColor(context, AppTheme.textMuted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    labelFor(id, langCode),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                      color:
                          isCurrent ? paletteColor(context, AppTheme.primary) : paletteColor(context, AppTheme.textPrimary),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCurrent)
                  Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: paletteColor(context, AppTheme.primary),
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
          color: paletteColor(context, AppTheme.surface).withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: paletteColor(context, AppTheme.border),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: paletteColor(context, AppTheme.shadowSoft),
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
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: paletteColor(context, AppTheme.primary),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      labelFor(selectedCityId, langCode),
                      style: TextStyle(
                        color: paletteColor(context, AppTheme.textPrimary),
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
            Icon(
              Icons.arrow_drop_down_rounded,
              color: paletteColor(context, AppTheme.textMuted),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
