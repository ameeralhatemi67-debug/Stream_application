import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/widgets/ds/ca_button.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../profile/models/upcoming_schedule.dart';
import '../../../profile/models/vod_models.dart';
import '../../models/bookmark_entry.dart';

class BookmarkButton extends StatelessWidget {
  const BookmarkButton({super.key, this.vod, this.schedule})
      : assert((vod == null) != (schedule == null));
  final VodModel? vod;
  final UpcomingSchedule? schedule;

  @override
  Widget build(BuildContext context) {
    final id = vod == null
        ? BookmarkEntry.upcomingKey(schedule!.id)
        : BookmarkEntry.recording(vod!).id;
    final saved = context.select<AppProvider, bool>((p) => p.isBookmarked(id));
    final pending =
        context.select<AppProvider, bool>((p) => p.isBookmarkPending(id));
    return Semantics(
      toggled: saved,
      child: CaButton(
        icon: saved ? CaGlyph.check : CaGlyph.bookmark,
        confirm: saved,
        loading: pending,
        variant: saved ? CaButtonVariant.primary : CaButtonVariant.secondary,
        label: (saved
                ? 'profile.saved_lecture'
                : vod == null
                    ? 'bookmarks.save_stream'
                    : 'profile.save_lecture')
            .tr(),
        onPressed: pending
            ? null
            : () async {
                final provider = context.read<AppProvider>();
                try {
                  if (vod != null) {
                    await provider.toggleVodBookmark(vod!);
                  } else {
                    await provider.toggleUpcomingBookmark(schedule!);
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('bookmarks.save_failed'.tr())));
                  }
                }
              },
      ),
    );
  }
}
