import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/models/streamer_models.dart';
import '../../models/map_models.dart';
import '../../models/map_tricity_domain.dart';
import '../map_visible_catalog.dart';

class SearchResultItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isLive;
  final String? cityId;
  final String? streamerId;
  final MapMarkerModel? cachedMarker;

  SearchResultItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isLive = false,
    this.cityId,
    this.streamerId,
    this.cachedMarker,
  });
}

/// Search over the three city views and the venues currently eligible for
/// the map. Every selection goes back to the map screen's single camera
/// policy; this widget never moves the camera itself.
class TopSpatialSearchBar extends StatefulWidget {
  final List<StreamerModel> visibleStreamers;

  /// Saved venue pins, searched by name only when no current public catalog
  /// is loaded (cold offline start). Their details stay unavailable.
  final List<MapMarkerModel> cachedMarkers;
  final ValueChanged<String> onCitySelected;
  final ValueChanged<String>? onStreamerSelected;
  final ValueChanged<MapMarkerModel>? onCachedMarkerSelected;

  const TopSpatialSearchBar({
    super.key,
    this.visibleStreamers = const [],
    this.cachedMarkers = const [],
    required this.onCitySelected,
    this.onStreamerSelected,
    this.onCachedMarkerSelected,
  });

  @override
  State<TopSpatialSearchBar> createState() => _TopSpatialSearchBarState();
}

class _TopSpatialSearchBarState extends State<TopSpatialSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
        if (_isFocused && _searchController.text.trim().isNotEmpty) {
          _showResults = true;
        }
      });
    }
  }

  void _onQueryChanged(String query) {
    setState(() => _showResults = query.trim().isNotEmpty);
  }

  List<SearchResultItem> _resultsFor(String query) {
    if (query.trim().isEmpty) return const [];
    final q = query.toLowerCase();
    final List<SearchResultItem> matches = [];
    final langCode = EasyLocalization.of(context)?.locale.languageCode ?? 'en';

    for (final view in kTricityCityViews) {
      if (view.nameEn.toLowerCase().contains(q) ||
          view.nameAr.toLowerCase().contains(q)) {
        matches.add(SearchResultItem(
          title: view.localizedName(langCode),
          subtitle: 'map.place_preset'.tr(),
          icon: Icons.location_city_rounded,
          cityId: view.id,
        ));
      }
    }

    // Recompute from the current visible catalog on every build. A provider
    // refresh removes withdrawn/hidden/unverified results immediately.
    final streamerIds = <String>{};
    for (final streamer in searchMapStreamers(widget.visibleStreamers, q)) {
      streamerIds.add(streamer.streamerId);
      matches.add(SearchResultItem(
        title: streamer.getLocalizedName(langCode),
        subtitle: streamer.getLocalizedVenue(langCode),
        icon: streamer.isCurrentlyLive
            ? Icons.sensors_rounded
            : Icons.place_rounded,
        isLive: streamer.isCurrentlyLive,
        streamerId: streamer.streamerId,
      ));
    }
    for (final marker in widget.cachedMarkers) {
      if (streamerIds.contains(marker.streamerId)) continue;
      final hit = [
        marker.displayNameEn,
        marker.displayNameAr,
        marker.venueNameEn,
        marker.venueNameAr,
      ].any((v) => v.toLowerCase().contains(q));
      if (!hit) continue;
      matches.add(SearchResultItem(
        title: marker.getLocalizedName(langCode),
        subtitle: marker.getLocalizedVenue(langCode),
        icon: Icons.place_outlined,
        cachedMarker: marker,
      ));
    }

    return matches;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _resultsFor(_searchController.text);
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: AppTheme.searchBarHeight,
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(AppTheme.searchBarRadius),
            // UI-01: same focus treatment as the feed search bar -- neither
            // had one before, which is its own contrast/affordance gap.
            border: Border.all(
              color: _isFocused ? AppTheme.primary : AppTheme.border,
              width: _isFocused ? 1.6 : AppTheme.searchBarBorderWidth,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppTheme.shadowSoft,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            onChanged: _onQueryChanged,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: context.tr('map.search_placeholder'),
              hintStyle: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.cancel_rounded,
                        size: 18,
                        color: AppTheme.textMuted,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // Autocomplete Results Dropdown Card
        if (hasQuery && _showResults)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border),
              boxShadow: const [
                BoxShadow(
                  color: AppTheme.shadow,
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: results.isEmpty ? 1 : results.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: AppTheme.border,
              ),
              itemBuilder: (context, index) {
                if (results.isEmpty) {
                  return ListTile(
                    title: Text('map.no_search_results'.tr()),
                    leading: const Icon(Icons.search_off_rounded,
                        color: AppTheme.textMuted),
                  );
                }
                final result = results[index];
                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: result.isLive
                          ? AppTheme.danger.withValues(alpha: 0.2)
                          : AppTheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      result.icon,
                      size: 16,
                      color: result.isLive ? AppTheme.danger : AppTheme.primary,
                    ),
                  ),
                  title: Text(
                    result.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    result.subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  trailing: result.isLive
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.danger,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'design_ui.live'.tr(),
                            style: const TextStyle(
                              color: AppTheme.onMedia,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  onTap: () {
                    if (result.streamerId != null) {
                      widget.onStreamerSelected?.call(result.streamerId!);
                    } else if (result.cachedMarker != null) {
                      widget.onCachedMarkerSelected?.call(result.cachedMarker!);
                    } else if (result.cityId != null) {
                      widget.onCitySelected(result.cityId!);
                    }
                    _searchController.text = result.title;
                    setState(() => _showResults = false);
                    _focusNode.unfocus();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
