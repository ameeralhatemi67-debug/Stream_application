import '../../../../core/widgets/ds/ca_surfaces.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/hadayah_loading_indicator.dart';

class PrivacySettingsSection extends StatefulWidget {
  const PrivacySettingsSection(
      {super.key, this.privacyOnly = false, this.dangerOnly = false});
  final bool privacyOnly, dangerOnly;
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
    context.select<AppProvider, Object?>((p) =>
        (p.consentAcceptedAt, p.consentVersion, p.hasAcceptedCurrentConsent));
    final provider = context.read<AppProvider>();
    return Column(children: [
      if (!widget.dangerOnly) _buildConsentRecordCard(context, provider),
      const SizedBox(height: AppTheme.spaceMd),
      if (!widget.dangerOnly) _buildDataExportCard(context, provider),
      const SizedBox(height: AppTheme.spaceMd),
      if (!widget.privacyOnly) _buildChatHistoryCard(context, provider),
      const SizedBox(height: AppTheme.spaceMd),
      if (!widget.privacyOnly) _buildDeleteAccountCard(context, provider),
    ]);
  }

  /// What this account consented to, and how to withdraw it.
  ///
  /// The consent version and timestamp were already recorded (AppProvider
  /// `recordConsent`, and `profiles.consent_version` / `consent_accepted_at`),
  /// but nothing showed them back to the person who gave them. Withdrawal has
  /// no separate mechanism in this build: deleting the account is the only one,
  /// so the card says that plainly rather than implying a toggle exists.
  Widget _buildConsentRecordCard(BuildContext context, AppProvider provider) {
    final acceptedAt = provider.consentAcceptedAt;
    final version = provider.consentVersion;
    final String status;
    if (version == null || acceptedAt == null) {
      status = 'settings.consent_record_none'.tr();
    } else if (provider.hasAcceptedCurrentConsent) {
      status = 'settings.consent_record_accepted'.tr(namedArgs: {
        'version': version,
        'date': DateFormat.yMMMd(context.locale.languageCode)
            .format(acceptedAt.toLocal()),
      });
    } else {
      status = 'settings.consent_record_outdated'
          .tr(namedArgs: {'version': version});
    }

    return CaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined,
                  size: 18, color: AppTheme.primary),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Text(
                  'settings.consent_record_title'.tr(),
                  style: const TextStyle(
                    color: Canopy.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            status,
            style: const TextStyle(
                color: Canopy.slate, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'settings.consent_withdraw_note'.tr(),
            style: const TextStyle(
                color: Canopy.haze,
                fontSize: AppTheme.captionFont,
                height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDataExportCard(BuildContext context, AppProvider provider) {
    return CaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.data_export_title'.tr(),
            style: const TextStyle(
              color: Canopy.ink,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'settings.data_export_desc'.tr(),
            style: const TextStyle(
                color: Canopy.slate, fontSize: AppTheme.captionFont),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isExportingData
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: HadayahLoadingIndicator(
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
          backgroundColor: Canopy.liveCrimson,
        ),
      );
      return;
    }

    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    if (!context.mounted) return;
    _showDataExportDialog(context, pretty);
  }

  void _showDataExportDialog(BuildContext context, String jsonText) {
    showCaDialog(
      context: context,
      builder: (dialogContext) {
        return CaAlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: const BorderSide(color: Canopy.hairline),
          ),
          title: Text(
            'settings.data_export_dialog_title'.tr(),
            style: const TextStyle(
              color: Canopy.ink,
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
                      color: Canopy.slate, fontSize: 12),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Container(
                  constraints: const BoxConstraints(maxHeight: 360),
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: Canopy.mint,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: Canopy.hairline),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonText,
                      style: const TextStyle(
                        color: Canopy.slate,
                        fontSize: AppTheme.captionFont,
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
                style: const TextStyle(color: Canopy.haze),
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
        border: Border.all(color: Canopy.liveCrimson.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.delete_account_title'.tr(),
            style: const TextStyle(
              color: Canopy.ink,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'settings.delete_account_desc'.tr(),
            style: const TextStyle(
                color: Canopy.slate, fontSize: AppTheme.captionFont),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isDeletingAccount
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: HadayahLoadingIndicator(
                        strokeWidth: 2,
                        color: Canopy.liveCrimson,
                      ),
                    )
                  : const Icon(Icons.delete_forever_rounded, size: 18),
              label: Text('settings.delete_account_btn'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: Canopy.liveCrimson,
                side: const BorderSide(color: Canopy.liveCrimson),
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
    showCaDialog(
      context: context,
      builder: (dialogContext) {
        return CaAlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: const BorderSide(color: Canopy.hairline),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Canopy.liveCrimson, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'settings.delete_account_confirm_title'.tr(),
                  style: const TextStyle(
                    color: Canopy.ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'settings.delete_account_confirm_body'.tr(),
            style: const TextStyle(color: Canopy.slate, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'settings.cancel'.tr(),
                style: const TextStyle(color: Canopy.haze),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Canopy.liveCrimson,
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
          backgroundColor: Canopy.liveCrimson,
        ),
      );
    }
  }

  // ==========================================
  // Chat History & Privacy (Cluster 4 Task 17)
  // ==========================================

  Widget _buildChatHistoryCard(BuildContext context, AppProvider provider) {
    return CaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.chat_history_title'.tr(),
            style: const TextStyle(
              color: Canopy.ink,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'settings.chat_history_desc'.tr(),
            style: const TextStyle(
                color: Canopy.slate, fontSize: AppTheme.captionFont),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isDeletingStreamMessages
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: HadayahLoadingIndicator(
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
                      child: HadayahLoadingIndicator(
                          strokeWidth: 2, color: Canopy.liveCrimson),
                    )
                  : const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text('settings.delete_all_messages_btn'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: Canopy.liveCrimson,
                side: const BorderSide(color: Canopy.liveCrimson),
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
    showCaDialog(
      context: context,
      builder: (dialogContext) => CaAlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: Canopy.hairline),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Canopy.liveCrimson, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'settings.delete_all_messages_confirm_title'.tr(),
                style: const TextStyle(
                  color: Canopy.ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'settings.delete_all_messages_confirm_body'.tr(),
          style: const TextStyle(color: Canopy.slate, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('settings.cancel'.tr(),
                style: const TextStyle(color: Canopy.haze)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Canopy.liveCrimson,
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
        backgroundColor: success ? null : Canopy.liveCrimson,
      ),
    );
  }

  Future<void> _showSelectStreamDialog(
      BuildContext context, AppProvider provider) async {
    final streamIds = await provider.loadMyMessageStreamIds();
    if (!context.mounted) return;

    final selectedStreamId = await showCaDialog<String>(
      context: context,
      builder: (dialogContext) => CaAlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: Canopy.hairline),
        ),
        title: Text('settings.select_stream_dialog_title'.tr(),
            style: const TextStyle(
                color: Canopy.ink, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: streamIds.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: Text(
                    'settings.select_stream_dialog_empty'.tr(),
                    style: const TextStyle(color: Canopy.slate),
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
                          style: const TextStyle(color: Canopy.ink)),
                      onTap: () => Navigator.pop(dialogContext, id),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('settings.cancel'.tr(),
                style: const TextStyle(color: Canopy.haze)),
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
        backgroundColor: success ? null : Canopy.liveCrimson,
      ),
    );
  }
}
