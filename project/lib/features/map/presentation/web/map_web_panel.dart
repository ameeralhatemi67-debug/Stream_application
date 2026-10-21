import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../profile/models/streamer_models.dart';
import '../../../web/presentation/hidayah_web_kit.dart';

/// The map page's website panel: title, the existing search and filters,
/// and every venue on the map as a list, so the map is browsable without
/// hunting for pins.
class MapWebPanel extends StatelessWidget {
  const MapWebPanel(
      {super.key,
      required this.streamers,
      required this.selectedId,
      required this.onSelect,
      required this.searchBar,
      required this.cityDropdown,
      required this.topicDropdown,
      this.notice});
  final List<StreamerModel> streamers;
  final String? selectedId;
  final ValueChanged<StreamerModel> onSelect;
  final Widget searchBar, cityDropdown, topicDropdown;
  final Widget? notice;
  static const width = 400.0;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final live = streamers.where((s) => s.isLiveForRoom).length;
    return Container(
        width: width,
        decoration: const BoxDecoration(
            color: HidayahGold.card,
            border: BorderDirectional(
                end: BorderSide(color: HidayahGold.hairline))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('web.map_page_title'.tr(),
                        style: HidayahText.display(26)),
                    const SizedBox(height: 6),
                    Text('web.map_body'.tr(),
                        style: HidayahText.body(13.5, height: 1.5)),
                    const SizedBox(height: 16),
                    if (notice != null) ...[notice!, const SizedBox(height: 12)],
                    searchBar,
                    const SizedBox(height: 10),
                    cityDropdown,
                    const SizedBox(height: 10),
                    topicDropdown,
                    const SizedBox(height: 18),
                    Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                      Text('web.map_count'.plural(streamers.length),
                          style: HidayahText.body(13,
                              color: HidayahGold.s900,
                              weight: FontWeight.w700)),
                      if (live > 0) ...[
                        HidayahLiveBadge(
                            label: 'web.live_count'.plural(live)),
                      ],
                    ]),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: HidayahGold.hairline),
                  ])),
          Expanded(
              child: streamers.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('map.empty_body'.tr(),
                          style: HidayahText.body(14)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      itemCount: streamers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, i) {
                        final s = streamers[i];
                        final selected = s.streamerId == selectedId;
                        final live = s.isLiveForRoom;
                        return Material(
                            color: selected
                                ? HidayahGold.g100
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => onSelect(s),
                                child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(children: [
                                      CaAvatar(
                                          name: s.getLocalizedName(lang),
                                          url: s.avatarUrl,
                                          org: s.isOrganization,
                                          live: live,
                                          ring: CaAvatarRing.brand,
                                          radius: 22),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(s.getLocalizedName(lang),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: HidayahText.body(14.5,
                                                    color: HidayahGold.s900,
                                                    weight: FontWeight.w700,
                                                    height: 1.3)),
                                            const SizedBox(height: 2),
                                            HidayahMeta(
                                                icon: CaGlyph.pin,
                                                text: [
                                                  s.getLocalizedVenue(lang),
                                                  s.getLocalizedCity(lang)
                                                ]
                                                    .where((t) => t.isNotEmpty)
                                                    .join(' · ')),
                                          ])),
                                      if (live) ...[
                                        const SizedBox(width: 8),
                                        HidayahLiveBadge(
                                            audio: s.isAudioLive,
                                            label: (s.isAudioLive
                                                    ? 'web.badge_audio'
                                                    : 'web.badge_live')
                                                .tr()),
                                      ] else
                                        const HidayahForwardIcon(size: 16),
                                    ]))));
                      })),
        ]));
  }
}
