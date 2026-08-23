import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../models/chat_report_model.dart';

/// Platform-Wide Chat Moderation Dashboard (v0.8 Checkpoint 4 Phase 1).
/// Admin-tier surface (any AdminHubScreen viewer, not Master-Admin-only like
/// Checkpoint 2 Phase 3's Roles & Permissions tab) for triaging chat_reports:
/// dismiss, delete the reported message, or mute/ban the reported sender for
/// that stream. Every action is server-enforced by RLS regardless of what
/// this screen does (chat_messages_delete_owner_or_admin,
/// chat_muted_users_insert_owner_or_admin, chat_reports_delete_admin -- see
/// 20260827120000) -- this is UX for an admin-tier account, not the
/// security boundary itself.
class ChatModerationView extends StatefulWidget {
  const ChatModerationView({super.key});

  @override
  State<ChatModerationView> createState() => _ChatModerationViewState();
}

class _ChatModerationViewState extends State<ChatModerationView> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _actingOnReportIds = {};

  @override
  void initState() {
    super.initState();
    context.read<AppProvider>().ensureChatReportsLoaded();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.accentRed : AppTheme.accentGreen,
      ),
    );
  }

  Future<void> _runAction(
    ChatReportModel report,
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _actingOnReportIds.add(report.id));
    try {
      await action();
      _showToast(successMessage);
    } catch (e) {
      _showToast('Action failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actingOnReportIds.remove(report.id));
    }
  }

  void _confirmAndRun({
    required BuildContext context,
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: const BorderSide(color: AppTheme.darkBorderSubtle),
        ),
        title: Text(title,
            style: const TextStyle(
                color: AppTheme.textPrimaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        content: Text(body,
            style: const TextStyle(
                color: AppTheme.textSecondaryDark, fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('settings.cancel'.tr(),
                style: const TextStyle(color: AppTheme.textMutedDark)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(dialogContext);
              onConfirm();
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final reports = context
        .select<AppProvider, List<ChatReportModel>>((p) => p.chatReports);

    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? reports
        : reports.where((r) {
            return r.reportedDisplayName.toLowerCase().contains(query) ||
                r.reporterDisplayName.toLowerCase().contains(query) ||
                r.streamId.toLowerCase().contains(query) ||
                r.reason.toLowerCase().contains(query) ||
                r.messageBody.toLowerCase().contains(query);
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.report_gmailerrorred_rounded,
                  color: AppTheme.accentRed, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Chat Moderation',
                style: TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${reports.length}',
                  style: const TextStyle(
                    color: AppTheme.textSecondaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          const Text(
            'Reported live chat messages, platform-wide. Dismiss a report, delete the message (removes it from every viewer in real time), or mute/ban the sender from that stream.',
            style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by sender, reporter, stream, or reason...',
              hintStyle: const TextStyle(
                  color: AppTheme.textSecondaryDark, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppTheme.textSecondaryDark, size: 18),
              filled: true,
              fillColor: AppTheme.darkSurface1,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mark_chat_read_rounded,
                            size: 48, color: AppTheme.textSecondaryDark),
                        const SizedBox(height: 12),
                        Text(
                          reports.isEmpty
                              ? 'No open chat reports.'
                              : 'No reports match your search.',
                          style: const TextStyle(
                              color: AppTheme.textSecondaryDark),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppTheme.spaceMd),
                    itemBuilder: (context, index) =>
                        _buildReportCard(provider, filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(AppProvider provider, ChatReportModel report) {
    final isActing = _actingOnReportIds.contains(report.id);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
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
                    Row(
                      children: [
                        const Icon(Icons.person_rounded,
                            size: 14, color: AppTheme.accentRed),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Reported: ${report.reportedDisplayName}',
                            style: const TextStyle(
                              color: AppTheme.textPrimaryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (report.reportedEmail != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 18),
                        child: Text(report.reportedEmail!,
                            style: const TextStyle(
                                color: AppTheme.textMutedDark, fontSize: 10.5)),
                      ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spaceSm),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface2,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        '"${report.messageBody}"',
                        style: const TextStyle(
                            color: AppTheme.textSecondaryDark,
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reason: ${report.reason}',
                      style: const TextStyle(
                          color: AppTheme.accentAmber, fontSize: 11.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reported by ${report.reporterDisplayName} • Stream: ${report.streamId} • ${DateFormat('yyyy-MM-dd HH:mm').format(report.createdAt)}',
                      style: const TextStyle(
                          color: AppTheme.textMutedDark, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          if (isActing)
            const Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accentBlue),
              ),
            )
          else
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondaryDark,
                    side: const BorderSide(color: AppTheme.darkBorderSubtle),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.done_rounded, size: 15),
                  label: const Text('Dismiss'),
                  onPressed: () => _runAction(
                    report,
                    () => provider.dismissChatReport(report.id),
                    'Report dismissed.',
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentAmber,
                    side: const BorderSide(color: AppTheme.accentAmber),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.volume_off_rounded, size: 15),
                  label: const Text('Mute / Ban Sender'),
                  onPressed: () => _confirmAndRun(
                    context: context,
                    title: 'Mute / Ban Sender?',
                    body:
                        '${report.reportedDisplayName} will no longer be able to send messages in stream "${report.streamId}". This is enforced server-side, not just hidden client-side.',
                    confirmLabel: 'Mute / Ban',
                    confirmColor: AppTheme.accentAmber,
                    onConfirm: () => _runAction(
                      report,
                      () => provider.muteChatSenderAndResolveReport(report),
                      '${report.reportedDisplayName} muted from stream "${report.streamId}".',
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 15),
                  label: const Text('Delete Message'),
                  onPressed: () => _confirmAndRun(
                    context: context,
                    title: 'Delete This Message?',
                    body:
                        'This removes the message from every viewer\'s chat in real time. This cannot be undone.',
                    confirmLabel: 'Delete',
                    confirmColor: AppTheme.accentRed,
                    onConfirm: () => _runAction(
                      report,
                      () => provider.deleteChatMessageAndResolveReport(report),
                      'Message deleted.',
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
