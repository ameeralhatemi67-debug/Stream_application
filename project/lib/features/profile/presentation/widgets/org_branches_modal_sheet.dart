import '../../../../core/widgets/ds/ca_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../map/presentation/venue_directions_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../organization/models/org_venue_branch_model.dart';

class OrgBranchesModalSheet extends StatelessWidget {
  final String orgName;
  final List<OrgVenueBranchModel> venues;

  const OrgBranchesModalSheet({
    super.key,
    required this.orgName,
    required this.venues,
  });

  static void show(
    BuildContext context, {
    required String orgName,
    required List<OrgVenueBranchModel> venues,
  }) {
    showCaSheet<void>(context,
        title: orgName,
        body: OrgBranchesModalSheet(orgName: orgName, venues: venues),
        framed: false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Canopy.dawn,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        border: Border(
          top: BorderSide(color: Canopy.hairline, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Canopy.slate.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.domain_rounded,
                      color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'profile.campus_branches'.tr(),
                        style: const TextStyle(
                          color: Canopy.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        orgName,
                        style: const TextStyle(
                          color: Canopy.slate,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: MaterialLocalizations.of(context).closeButtonTooltip,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Canopy.slate),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Canopy.hairline, height: 1),

          // List of Venue Branches
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: venues.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final venue = venues[idx];
                return _buildVenueCard(context, venue, lang);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVenueCard(
    BuildContext context,
    OrgVenueBranchModel venue,
    String lang,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: venue.isMainHeadquarters
              ? AppTheme.primary.withValues(alpha: 0.5)
              : Canopy.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppTheme.spaceSm,
                      runSpacing: AppTheme.spaceXs,
                      children: [
                        Text(
                          venue.getLocalizedName(lang),
                          style: const TextStyle(
                            color: Canopy.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (venue.isMainHeadquarters) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.6)),
                            ),
                            child: Text(
                              'profile.main_hq'.tr(),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: AppTheme.captionFont,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: Canopy.slate),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${venue.getLocalizedCity(lang)} • ${venue.getLocalizedAddress(lang)}',
                            style: const TextStyle(
                              color: Canopy.slate,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Seating pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Canopy.mint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Canopy.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_seat_rounded,
                        size: 12, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${venue.seatingCapacity} ${'profile.seating_capacity'.tr()}',
                      style: const TextStyle(
                        color: Canopy.ink,
                        fontSize: AppTheme.captionFont,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Facilities chips
          if (venue.availableFacilities.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: venue.availableFacilities.map((facility) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Canopy.dawn,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Canopy.hairline),
                  ),
                  child: Text(
                    facility,
                    style: const TextStyle(
                      color: Canopy.slate,
                      fontSize: AppTheme.captionFont,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 14),

          // Action: only a real pinned venue can offer directions.
          if (isUsableVenuePoint(venue.latitude, venue.longitude))
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.directions_rounded, size: 16),
                label: Text('profile.get_directions'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                onPressed: () => openVenueDirections(
                  context,
                  venue.latitude,
                  venue.longitude,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
