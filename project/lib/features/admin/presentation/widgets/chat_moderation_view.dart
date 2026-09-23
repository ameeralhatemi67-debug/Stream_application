import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../models/chat_report_model.dart';
import '../../models/chat_mute_audit_entry.dart';
import '../../../live_stream/services/live_chat_controller.dart'
    show ChatReportReason;

/// Platform-Wide Chat Moderation Dashboard (v0.8 Checkpoint 4 Phase 1).
/// Admin-tier surface (any AdminHubScreen viewer, not Master-Admin-only like
/// Checkpoint 2 Phase 3's Roles & Permissions tab) for triaging chat_reports:
/// dismiss, delete the reported message, or mute/ban the reported sender for
/// that stream. Every action is server-enforced by RLS regardless of what
/// this screen does (chat_messages_delete_owner_or_admin,
/// chat_muted_users_insert_owner_or_admin, chat_reports_delete_admin -- see
/// 20260827120000) -- this is UX for an admin-tier account, not the
/// security boundary itself.
/// Stored report codes read as labels; historical free text stays as written.
String _reasonLabel(String reason) =>
    ChatReportReason.labelKey(reason)?.tr() ?? reason;

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
    context.read<AppProvider>().ensureMutedChattersAuditLoaded();
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
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
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
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Text(title,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        content: Text(body,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('settings.cancel'.tr(),
                style: const TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor, foregroundColor: AppTheme.onMedia),
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

  /// Cluster 4 Task 14: mute duration picker (10 min / 1 hour / permanent)
  /// before actually muting the reported sender.
  Future<void> _showMuteDurationSheet(
      AppProvider provider, ChatReportModel report) async {
    final durationHours = await showModalBottomSheet<double?>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('design_ui.mute_duration'.tr(),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ),
            ListTile(
              title: const Text('10 minutes',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(sheetContext, 10 / 60),
            ),
            ListTile(
              title: const Text('1 hour',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(sheetContext, 1.0),
            ),
            ListTile(
              title: Text('design_ui.permanent'.tr(),
                  style: const TextStyle(color: AppTheme.textPrimary)),
              // 0.0 is a sentinel for "permanent" (translated to a null
              // muteDurationHours below) -- kept distinct from the sheet's
              // own null, which means "dismissed without choosing".
              onTap: () => Navigator.pop(sheetContext, 0.0),
            ),
            const SizedBox(height: AppTheme.spaceSm),
          ],
        ),
      ),
    );
    if (!mounted || durationHours == null) return;
    _confirmAndRun(
      context: context,
      title: 'Mute Sender?',
      body:
          '${report.reportedDisplayName} will not be able to send messages in stream "${report.streamId}"for the selected duration. This is enforced server-side, not just hidden client-side.',
      confirmLabel: 'Mute',
      confirmColor: AppTheme.warning,
      onConfirm: () => _runAction(
        report,
        () => provider.muteChatSenderAndResolveReport(report,
            muteDurationHours: durationHours == 0 ? null : durationHours),
        '${report.reportedDisplayName} muted from stream "${report.streamId}".',
      ),
    );
  }

  /// Cluster 4 Task 14: bans the reported sender platform-wide and resolves
  /// the report -- requires a reason (shown to the banned user on
  /// /account-banned).
  Future<void> _showBanDialog(
      AppProvider provider, ChatReportModel report) async {
    final reasonController =
        TextEditingController(text: _reasonLabel(report.reason));
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Text('design_ui.ban_account_platform_wide'.tr(),
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${report.reportedDisplayName} will be signed out of every device and redirected to a suspension screen platform-wide.',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'admin.ban_reason_label'.tr(),
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceAlt,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('settings.cancel'.tr(),
                style: const TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger, foregroundColor: AppTheme.onMedia),
            onPressed: () => Navigator.pop(dialogContext, reasonController.text.trim()),
            child: Text('design_ui.ban_platform_wide'.tr()),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    await _runAction(
      report,
      () => provider.banChatSenderAndResolveReport(report, reason: reason),
      '${report.reportedDisplayName} banned platform-wide.',
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
                  color: AppTheme.danger, size: 20),
              const SizedBox(width: 8),
              Text('design_ui.chat_moderation'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${reports.length}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text('design_ui.reported_live_chat_messages_platform_wide_dismiss_a_report_delete'.tr(),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by sender, reporter, stream, or reason...',
              hintStyle: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppTheme.textSecondary, size: 18),
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          _buildMutedChattersAuditSection(context),
          const SizedBox(height: AppTheme.spaceLg),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mark_chat_read_rounded,
                            size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          reports.isEmpty
                              ? 'No open chat reports.'
                              : 'No reports match your search.',
                          style: const TextStyle(
                              color: AppTheme.textSecondary),
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

  /// Cluster 4 Tasks 13 & 15: "Muted Chatters Audit Log" -- collapsed by
  /// default (it's secondary to the live reports queue above), showing
  /// every muted profile's name, how many streams they've been muted in,
  /// the triggering reason, and their last messages before the mute.
  Widget _buildMutedChattersAuditSection(BuildContext context) {
    final entries = context.select<AppProvider, List<ChatMuteAuditEntry>>(
        (p) => p.mutedChattersAuditLog);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: const Icon(Icons.volume_off_rounded,
              color: AppTheme.warning, size: 20),
          title: Row(
            children: [
              Text('design_ui.muted_chatters_audit_log'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${entries.length}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
              AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceMd),
          children: [
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                child: Text('design_ui.no_chatters_have_been_muted_yet'.tr(),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              )
            else
              ...entries.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.email != null
                                    ? '${e.displayName} (${e.email})'
                                    : e.displayName,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${e.streamsMutedCount} streams',
                                style: const TextStyle(
                                    color: AppTheme.warning,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.lastReason,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11),
                        ),
                        if (e.lastMessages.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...e.lastMessages.map((m) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '"$m"',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 10.5,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                        ],
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(AppProvider provider, ChatReportModel report) {
    final isActing = _actingOnReportIds.contains(report.id);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
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
                            size: 14, color: AppTheme.danger),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Reported: ${report.reportedDisplayName}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (report.reportedEmail != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 18),
                        child: Text(report.reportedEmail!,
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 10.5)),
                      ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spaceSm),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        '"${report.messageBody}"',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reason: ${_reasonLabel(report.reason)}',
                      style: const TextStyle(
                          color: AppTheme.warning, fontSize: 11.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reported by ${report.reporterDisplayName} • Stream: ${report.streamId} • ${DateFormat('yyyy-MM-dd HH:mm').format(report.createdAt)}',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          if (isActing)
            const Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primary),
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
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.done_rounded, size: 15),
                  label: Text('design_ui.dismiss'.tr()),
                  onPressed: () => _runAction(
                    report,
                    () => provider.dismissChatReport(report.id),
                    'Report dismissed.',
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.warning,
                    side: const BorderSide(color: AppTheme.warning),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.volume_off_rounded, size: 15),
                  label: Text('design_ui.mute_in_stream'.tr()),
                  onPressed: () => _showMuteDurationSheet(provider, report),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.person_off_rounded, size: 15),
                  label: Text('design_ui.ban_platform_wide'.tr()),
                  onPressed: () => _showBanDialog(provider, report),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: AppTheme.onMedia,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 15),
                  label: Text('design_ui.delete_message'.tr()),
                  onPressed: () => _confirmAndRun(
                    context: context,
                    title: 'Delete This Message?',
                    body:
                        'This removes the message from every viewer\'s chat in real time. This cannot be undone.',
                    confirmLabel: 'Delete',
                    confirmColor: AppTheme.danger,
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
