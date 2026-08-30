import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../admin/models/streamer_custom_placeholder_model.dart';

/// Cluster 1 Task 4b -- the streamer-facing half of the custom stream-card
/// pipeline: one upload slot per brandable stream state, each showing that
/// slot's live moderation status and, on rejection, the admin's reason.
///
/// Extracted into its own widget because it has two entry points, and both
/// are legitimate: [StreamerEditorSheet] (where the rest of a broadcaster's
/// profile is edited) and the Broadcaster Studio preferences sheet in
/// Settings (the only surface a streamer who is not also an admin can
/// actually reach today).
///
/// Every upload is recorded against the *signed-in* account -- the RLS
/// insert policy on streamer_custom_placeholders admits only
/// `streamer_id = auth.uid()` and only `status = 'pending'`. An admin
/// editing someone else's registry entry therefore cannot upload artwork on
/// their behalf, which is why this section is hidden in that case rather
/// than silently filing the card under the wrong streamer.
class CustomStreamCardsSection extends StatefulWidget {
  /// Whether to draw the section's own heading. The editor sheet supplies a
  /// numbered heading of its own; the standalone settings sheet does not.
  final bool showHeader;

  const CustomStreamCardsSection({super.key, this.showHeader = true});

  /// Opens the section as a standalone bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface1,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (sheetContext) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spaceLg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [CustomStreamCardsSection()],
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<CustomStreamCardsSection> createState() =>
      _CustomStreamCardsSectionState();
}

class _CustomStreamCardsSectionState extends State<CustomStreamCardsSection> {
  final ImagePicker _picker = ImagePicker();

  /// Which slot has an upload in flight, so only that slot shows a spinner
  /// rather than locking the whole form.
  StreamPlaceholderType? _uploadingCard;

  @override
  void initState() {
    super.initState();
    // Pull this streamer's own submissions so each slot shows its real
    // moderation status instead of an empty upload button.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppProvider>().refreshCustomPlaceholders();
    });
  }

  Future<void> _pickAndUploadCard(StreamPlaceholderType type) async {
    if (_uploadingCard != null) return;
    final provider = context.read<AppProvider>();
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() => _uploadingCard = type);

      final created = await provider.submitCustomPlaceholder(
        placeholderType: type,
        fileName: image.name,
        fileBytes: bytes,
        contentType: image.mimeType ?? 'image/jpeg',
      );
      if (!mounted) return;
      setState(() => _uploadingCard = null);

      _showResult(
        created == null
            ? 'settings.custom_card_upload_failed_toast'.tr()
            : 'settings.custom_card_uploaded_toast'.tr(),
        isError: created == null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingCard = null);
      _showResult('${'settings.custom_card_upload_failed_toast'.tr()} $e',
          isError: true);
    }
  }

  void _showResult(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.accentRed : AppTheme.accentBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showHeader) ...[
          Text(
            'settings.custom_cards_section'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          'settings.custom_cards_desc'.tr(),
          style: const TextStyle(
              color: AppTheme.textSecondaryDark, fontSize: 11.5, height: 1.4),
        ),
        const SizedBox(height: 10),
        ...StreamPlaceholderType.values.map(_buildCustomCardSlot),
      ],
    );
  }

  Widget _buildCustomCardSlot(StreamPlaceholderType type) {
    // Watching (not reading) so a slot flips from "Pending Review" to
    // "Approved"/"Rejected" the moment an admin acts, without reopening.
    final existing = context.watch<AppProvider>().myPlaceholderFor(type);
    final isUploading = _uploadingCard == type;

    final Color statusColor;
    switch (existing?.status) {
      case StreamPlaceholderStatus.approved:
        statusColor = AppTheme.accentGreen;
        break;
      case StreamPlaceholderStatus.rejected:
        statusColor = AppTheme.accentRed;
        break;
      case StreamPlaceholderStatus.pending:
        statusColor = AppTheme.accentAmber;
        break;
      case null:
        statusColor = AppTheme.textMutedDark;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: SizedBox(
              width: 72,
              height: 44,
              child: existing != null
                  ? Image.network(
                      existing.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppTheme.darkSurface3,
                        child: Icon(Icons.broken_image_outlined,
                            size: 18, color: AppTheme.textMutedDark),
                      ),
                    )
                  : const ColoredBox(
                      color: AppTheme.darkSurface3,
                      child: Icon(Icons.image_outlined,
                          size: 18, color: AppTheme.textMutedDark),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  type.editorLabelKey.tr(),
                  style: const TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  existing == null
                      ? 'settings.custom_card_upload'.tr()
                      : existing.status.labelKey.tr(),
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
                // An admin's rejection note is the whole point of rejecting
                // rather than deleting -- show it inline so the streamer can
                // fix and resubmit without hunting through notifications.
                if (existing?.rejectionReason != null &&
                    existing!.rejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    existing.rejectionReason!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textMutedDark, fontSize: 10.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          isUploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.accentBlue),
                )
              : OutlinedButton.icon(
                  onPressed: () => _pickAndUploadCard(type),
                  icon: const Icon(Icons.upload_rounded, size: 15),
                  label: Text(
                    existing == null
                        ? 'settings.custom_card_upload'.tr()
                        : 'settings.custom_card_replace'.tr(),
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentBlue,
                    side: const BorderSide(color: AppTheme.accentBlue),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
        ],
      ),
    );
  }
}
