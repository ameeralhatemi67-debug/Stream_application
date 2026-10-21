import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../admin/models/streamer_custom_placeholder_model.dart';
import '../../../../core/widgets/hadayah_loading_indicator.dart';

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
    return showCaSheet<void>(context,
        title: 'settings.custom_cards_section'.tr(),
        bareChrome: true,
        body: const CustomStreamCardsSection(showHeader: false));
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
        backgroundColor: isError ? Canopy.liveCrimson : AppTheme.primary,
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
              color: Canopy.ink,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          'settings.custom_cards_desc'.tr(),
          style: const TextStyle(
              color: Canopy.slate, fontSize: 11.5, height: 1.4),
        ),
        const SizedBox(height: 10),
        ...StreamPlaceholderType.values.map(_buildCustomCardSlot),
      ],
    );
  }

  Widget _buildCustomCardSlot(StreamPlaceholderType type) {
    // Watching (not reading) so a slot flips from "Pending Review"to
    // "Approved"/"Rejected"the moment an admin acts, without reopening.
    final existing = context.watch<AppProvider>().myPlaceholderFor(type);
    final isUploading = _uploadingCard == type;

    final Color statusColor;
    switch (existing?.status) {
      case StreamPlaceholderStatus.approved:
        statusColor = Canopy.leaf;
        break;
      case StreamPlaceholderStatus.rejected:
        statusColor = Canopy.liveCrimson;
        break;
      case StreamPlaceholderStatus.pending:
        statusColor = AppTheme.warning;
        break;
      case null:
        statusColor = Canopy.haze;
        break;
    }

    return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: AppTheme.spaceMd),
        child: CaCard(
            variant: CaCardVariant.flat,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(CanopyRadius.input),
                      child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: existing != null
                              ? Image.network(existing.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const ColoredBox(
                                          color: Canopy.mist,
                                          child: Icon(
                                              Icons.broken_image_outlined,
                                              color: Canopy.slate)))
                              : const ColoredBox(
                                  color: Canopy.mist,
                                  child: Icon(Icons.image_outlined,
                                      color: Canopy.slate)))),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(type.editorLabelKey.tr(),
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                      existing == null
                          ? 'settings.custom_card_upload'.tr()
                          : existing.status.labelKey.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: statusColor)),
                  if (existing?.rejectionReason != null &&
                      existing!.rejectionReason!.isNotEmpty)
                    Text(existing.rejectionReason!,
                        style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppTheme.spaceSm),
                  isUploading
                      ? const Center(
                          child: HadayahLoadingIndicator(
                              strokeWidth: 2, color: AppTheme.primary))
                      : OutlinedButton.icon(
                          onPressed: () => _pickAndUploadCard(type),
                          icon: const Icon(Icons.upload_rounded),
                          label: Text(existing == null
                              ? 'settings.custom_card_upload'.tr()
                              : 'settings.custom_card_replace'.tr())),
                ])));
  }
}
