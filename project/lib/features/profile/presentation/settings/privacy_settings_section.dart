import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class PrivacySettingsSection extends StatefulWidget {
  const PrivacySettingsSection({super.key});
  @override
  State<PrivacySettingsSection> createState() => _PrivacySettingsSectionState();
}
class _PrivacySettingsSectionState extends State<PrivacySettingsSection> {
  bool _isDeletingAccount = false;
  bool _isExportingData = false;
  bool _isDeletingAllMessages = false;
  bool _isDeletingStreamMessages = false;
  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    return Column(children: [
      _buildDataExportCard(context, provider),
      const SizedBox(height: AppTheme.spaceMd),
      _buildChatHistoryCard(context, provider),
      const SizedBox(height: AppTheme.spaceMd),
      _buildDeleteAccountCard(context, provider),
    ]);
  }
  Widget _buildDataExportCard(BuildContext context, AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.data_export_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'settings.data_export_desc'.tr(),
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isExportingData
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text('settings.data_export_btn'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              onPressed: _isExportingData
                  ? null
                  : () => _handleDataExport(context, provider),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDataExport(
      BuildContext context, AppProvider provider) async {
    setState(() => _isExportingData = true);
    Map<String, dynamic>? data;
    try {
      data = await provider.exportMyData();
    } catch (e) {
      data = null;
    }
    if (!context.mounted) return;
    setState(() => _isExportingData = false);

    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.data_export_error_toast'.tr()),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    if (!context.mounted) return;
    _showDataExportDialog(context, pretty);
  }

  void _showDataExportDialog(BuildContext context, String jsonText) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: Text(
            'settings.data_export_dialog_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          content: SizedBox(
            width: 550,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'settings.data_export_dialog_desc'.tr(),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Container(
                  constraints: const BoxConstraints(maxHeight: 360),
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonText,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'common.close'.tr(),
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onMedia,
              ),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text('settings.data_export_copy_btn'.tr()),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: jsonText));
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                      content: Text('settings.data_export_copied_toast'.tr())),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeleteAccountCard(BuildContext context, AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.delete_account_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'settings.delete_account_desc'.tr(),
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isDeletingAccount
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.danger,
                      ),
                    )
                  : const Icon(Icons.delete_forever_rounded, size: 18),
              label: Text('settings.delete_account_btn'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.danger,
                side: const BorderSide(color: AppTheme.danger),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              onPressed: _isDeletingAccount
                  ? null
                  : () => _showDeleteAccountDialog(context, provider),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.danger, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'settings.delete_account_confirm_title'.tr(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'settings.delete_account_confirm_body'.tr(),
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'settings.cancel'.tr(),
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: AppTheme.onMedia,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _handleDeleteAccount(context, provider);
              },
              child: Text('settings.delete_account_confirm_btn'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleDeleteAccount(
      BuildContext context, AppProvider provider) async {
    setState(() => _isDeletingAccount = true);
    final success = await provider.deleteOwnAccount();
    if (!context.mounted) return;
    setState(() => _isDeletingAccount = false);

    if (success) {
      context.go('/welcome');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.delete_account_success_toast'.tr())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.delete_account_error_toast'.tr()),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  // ==========================================
  // Chat History & Privacy (Cluster 4 Task 17)
  // ==========================================

  Widget _buildChatHistoryCard(BuildContext context, AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.chat_history_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'settings.chat_history_desc'.tr(),
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isDeletingStreamMessages
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary),
                    )
                  : const Icon(Icons.forum_outlined, size: 18),
              label: Text('settings.delete_messages_by_stream_btn'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              onPressed: _isDeletingStreamMessages
                  ? null
                  : () => _showSelectStreamDialog(context, provider),
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isDeletingAllMessages
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.danger),
                    )
                  : const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text('settings.delete_all_messages_btn'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.danger,
                side: const BorderSide(color: AppTheme.danger),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              onPressed: _isDeletingAllMessages
                  ? null
                  : () => _showDeleteAllMessagesDialog(context, provider),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllMessagesDialog(
      BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.danger, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'settings.delete_all_messages_confirm_title'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'settings.delete_all_messages_confirm_body'.tr(),
          style:
              const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('settings.cancel'.tr(),
                style: const TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: AppTheme.onMedia),
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleDeleteAllMessages(context, provider);
            },
            child: Text('settings.delete_all_messages_btn'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAllMessages(
      BuildContext context, AppProvider provider) async {
    setState(() => _isDeletingAllMessages = true);
    final success = await provider.deleteAllMyMessages();
    if (!context.mounted) return;
    setState(() => _isDeletingAllMessages = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'settings.delete_all_messages_success_toast'.tr()
            : 'settings.delete_all_messages_error_toast'.tr()),
        backgroundColor: success ? null : AppTheme.danger,
      ),
    );
  }

  Future<void> _showSelectStreamDialog(
      BuildContext context, AppProvider provider) async {
    final streamIds = await provider.loadMyMessageStreamIds();
    if (!context.mounted) return;

    final selectedStreamId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Text('settings.select_stream_dialog_title'.tr(),
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: streamIds.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: Text(
                    'settings.select_stream_dialog_empty'.tr(),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: streamIds.length,
                  itemBuilder: (context, index) {
                    final id = streamIds[index];
                    return ListTile(
                      leading: const Icon(Icons.forum_outlined,
                          color: AppTheme.primary),
                      title: Text(id,
                          style:
                              const TextStyle(color: AppTheme.textPrimary)),
                      onTap: () => Navigator.pop(dialogContext, id),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('settings.cancel'.tr(),
                style: const TextStyle(color: AppTheme.textMuted)),
          ),
        ],
      ),
    );
    if (selectedStreamId == null || !context.mounted) return;
    setState(() => _isDeletingStreamMessages = true);
    final success = await provider.deleteMyMessagesForStream(selectedStreamId);
    if (!context.mounted) return;
    setState(() => _isDeletingStreamMessages = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'settings.delete_messages_by_stream_success_toast'.tr()
            : 'settings.delete_all_messages_error_toast'.tr()),
        backgroundColor: success ? null : AppTheme.danger,
      ),
    );
  }

}
