import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../models/streamer_custom_placeholder_model.dart';

/// Streamer Custom Stream-Card Review Queue (Cluster 1 Task 4b).
///
/// Admin-tier surface for the artwork streamers upload to replace the
/// "Starting Soon" / "Break" / "Ended"placeholders. Approving activates the
/// card for every viewer of that streamer; rejecting requires a reason,
/// which is dispatched to the streamer as an
/// [NotificationType.adminCardEditRequestStreamer] notification so they know
/// what to fix.
///
/// The queue is UX for an admin-tier account, not the security boundary: the
/// streamer_custom_placeholders RLS policies (20260830120000) already make
/// the update path admin-only and make unapproved cards unreadable by
/// viewers, so an unmoderated upload is inert regardless of this screen.
class CustomPlaceholderReviewView extends StatefulWidget {
  const CustomPlaceholderReviewView({super.key});

  @override
  State<CustomPlaceholderReviewView> createState() =>
      _CustomPlaceholderReviewViewState();
}

class _CustomPlaceholderReviewViewState
    extends State<CustomPlaceholderReviewView> {
  final Set<String> _actingOnIds = {};

  @override
  void initState() {
    super.initState();
    context.read<AppProvider>().ensureCustomPlaceholdersLoaded();
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
      ),
    );
  }

  Future<void> _runAction(
    StreamerCustomPlaceholderModel card,
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _actingOnIds.add(card.id));
    try {
      await action();
      _showToast(successMessage);
    } catch (e) {
      _showToast('Action failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actingOnIds.remove(card.id));
    }
  }

  Future<void> _approve(
      AppProvider provider, StreamerCustomPlaceholderModel card) {
    return _runAction(
      card,
      () => provider.approveCustomPlaceholder(card),
      'admin.custom_card_approve_toast'.tr(),
    );
  }

  /// Rejection is gated on a non-empty reason at three layers -- this
  /// dialog's validator, AppProvider.rejectCustomPlaceholder, and the
  /// table's own check constraint. The streamer's notification body *is*
  /// this text, so "rejected, no reason given"is not a reachable state.
  Future<void> _promptRejectionReason(
      AppProvider provider, StreamerCustomPlaceholderModel card) async {
    final controller = TextEditingController();
    String? errorText;

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceAlt,
          title: Text(
            'admin.custom_card_reject_title'.tr(),
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'admin.custom_card_reject_hint'.tr(),
              errorText: errorText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: AppTheme.onMedia,
              ),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  setDialogState(() => errorText =
                      'admin.custom_card_reject_reason_required'.tr());
                  return;
                }
                Navigator.of(dialogContext).pop(text);
              },
              child: Text('admin.btn_reject'.tr()),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (reason == null || !mounted) return;

    await _runAction(
      card,
      () => provider.rejectCustomPlaceholder(
        card,
        reason: reason,
        context: mounted ? context : null,
      ),
      'admin.custom_card_reject_toast'.tr(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final queue = provider.pendingCustomPlaceholders;

    return RefreshIndicator(
      onRefresh: provider.refreshCustomPlaceholders,
      color: AppTheme.primary,
      backgroundColor: AppTheme.surfaceAlt,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            'admin.custom_cards_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            'admin.custom_cards_desc'.tr(),
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          if (queue.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inbox_rounded,
                      color: AppTheme.textMuted, size: 22),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Text(
                      'admin.custom_cards_empty'.tr(),
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            )
          else
            ...queue.map((card) => _buildQueueCard(provider, card)),

          const SizedBox(height: AppTheme.spaceXl),
          _buildApprovedPresetsSection(provider),
        ],
      ),
    );
  }

  /// Task 4b: alongside the pending queue above, show what's already
  /// approved and live -- an already-approved image reused for a different
  /// slot is auto-fast-tracked client-side (see
  /// AppProvider.submitCustomPlaceholder) and never reaches this queue, so
  /// this section is the only place admins can see it happened.
  Widget _buildApprovedPresetsSection(AppProvider provider) {
    final approved = provider.approvedCustomPlaceholders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_rounded,
                color: AppTheme.success, size: 18),
            const SizedBox(width: AppTheme.spaceSm),
            Text(
              'admin.custom_cards_approved_title'.tr(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSm),
        if (approved.isEmpty)
          Text(
            'admin.custom_cards_approved_empty'.tr(),
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppTheme.spaceSm,
              mainAxisSpacing: AppTheme.spaceSm,
              childAspectRatio: 16 / 9,
            ),
            itemCount: approved.length,
            itemBuilder: (context, index) {
              final card = approved[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      card.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppTheme.surface,
                        child: Icon(Icons.broken_image_outlined,
                            color: AppTheme.textMuted, size: 20),
                      ),
                    ),
                    PositionedDirectional(
                      start: 4,
                      bottom: 4,
                      end: 4,
                      child: Text(
                        card.streamerDisplayName ?? card.streamerId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.onMedia,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4, color: AppTheme.media)],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildQueueCard(
      AppProvider provider, StreamerCustomPlaceholderModel card) {
    final isBusy = _actingOnIds.contains(card.id);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The artwork itself, at the aspect ratio viewers will see it in.
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMd)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                card.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: AppTheme.surface,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: AppTheme.textMuted, size: 28),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                      ),
                      child: Text(
                        card.placeholderType.labelKey.tr(),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: Text(
                        card.streamerDisplayName ?? card.streamerId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isBusy
                            ? null
                            : () => _promptRejectionReason(provider, card),
                        icon: const Icon(Icons.block_rounded, size: 16),
                        label: Text('admin.btn_reject'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.danger),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            isBusy ? null : () => _approve(provider, card),
                        icon: isBusy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppTheme.onMedia),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 16),
                        label: Text('admin.btn_approve'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: AppTheme.bg,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
