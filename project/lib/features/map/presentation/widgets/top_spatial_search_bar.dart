import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/map_models.dart';

class SearchResultItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isLive;
  final LatLng coordinates;
  final double zoomLevel;

  SearchResultItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isLive = false,
    required this.coordinates,
    required this.zoomLevel,
  });
}

class TopSpatialSearchBar extends StatefulWidget {
  final Function(LatLng coordinates, double zoom, String label)
      onSearchResultSelected;

  const TopSpatialSearchBar({
    super.key,
    required this.onSearchResultSelected,
  });

  @override
  State<TopSpatialSearchBar> createState() => _TopSpatialSearchBarState();
}

class _TopSpatialSearchBarState extends State<TopSpatialSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;

  List<SearchResultItem> _results = [];

  void _onQueryChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _results = [];
      });
      return;
    }

    final q = query.toLowerCase();
    final List<SearchResultItem> matches = [];
    final langCode = context.locale.languageCode;

    // Search Cities
    for (final region in alSharqiaRegions) {
      final name = region.getLocalizedName(langCode);
      if (region.nameEn.toLowerCase().contains(q) ||
          region.nameAr.toLowerCase().contains(q)) {
        matches.add(SearchResultItem(
          title: name,
          subtitle: 'City in AlSharqia',
          icon: Icons.location_city_rounded,
          coordinates: region.centerCoordinates,
          zoomLevel: region.zoomLevelTarget,
        ));
      }
    }

    // Search Streamers & Venues -- the live catalog the provider holds, not a
    // compiled-in sample list (P2 truthful data).
    for (final streamer in context.read<AppProvider>().streamers) {
      final name = streamer.getLocalizedName(langCode);
      final venue = streamer.getLocalizedVenue(langCode);

      if (name.toLowerCase().contains(q) ||
          venue.toLowerCase().contains(q) ||
          streamer.organizationEn.toLowerCase().contains(q)) {
        matches.add(SearchResultItem(
          title: name,
          subtitle: venue,
          icon: streamer.isCurrentlyLive
              ? Icons.sensors_rounded
              : Icons.place_rounded,
          isLive: streamer.isCurrentlyLive,
          coordinates: LatLng(streamer.latitude, streamer.longitude),
          zoomLevel: 14.5,
        ));
      }
    }

    setState(() {
      _results = matches;
      _isSearching = matches.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppTheme.darkSurface1.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(
              color: AppTheme.darkBorderSubtle,
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
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
              color: AppTheme.textPrimaryDark,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'map.search_placeholder'.tr(),
              hintStyle: const TextStyle(
                color: AppTheme.textMutedDark,
                fontSize: 12,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.accentBlue,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.cancel_rounded,
                        size: 18,
                        color: AppTheme.textMutedDark,
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
        if (_isSearching)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface1.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.darkBorderSubtle),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: AppTheme.darkBorderSubtle,
              ),
              itemBuilder: (context, index) {
                final result = _results[index];
                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: result.isLive
                          ? AppTheme.accentRed.withValues(alpha: 0.2)
                          : AppTheme.accentBlue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      result.icon,
                      size: 16,
                      color: result.isLive
                          ? AppTheme.accentRed
                          : AppTheme.accentBlue,
                    ),
                  ),
                  title: Text(
                    result.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    result.subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondaryDark,
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
                            color: AppTheme.accentRed,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                  onTap: () {
                    widget.onSearchResultSelected(
                      result.coordinates,
                      result.zoomLevel,
                      result.title,
                    );
                    _searchController.text = result.title;
                    setState(() {
                      _isSearching = false;
                    });
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
