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
import 'package:share_plus/share_plus.dart';
import '../../../../core/config/app_identity.dart';
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
              Icon(Icons.fact_check_outlined,
                  size: 18, color: paletteColor(context, AppTheme.primary)),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Text(
                  'settings.consent_record_title'.tr(),
                  style: TextStyle(
                    color: paletteColor(context, Canopy.ink),
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
            style:
                TextStyle(color: paletteColor(context, Canopy.slate), fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'settings.consent_withdraw_note'.tr(),
            style: TextStyle(
                color: paletteColor(context, Canopy.haze),
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
            style: TextStyle(
              color: paletteColor(context, Canopy.ink),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'settings.data_export_desc'.tr(),
            style: TextStyle(
                color: paletteColor(context, Canopy.slate), fontSize: AppTheme.captionFont),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isExportingData
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: HadayahLoadingIndicator(
                        strokeWidth: 2,
                        color: paletteColor(context, AppTheme.primary),
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text('settings.data_export_btn'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: paletteColor(context, AppTheme.primary),
                side: BorderSide(color: paletteColor(context, AppTheme.primary)),
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
          backgroundColor: paletteColor(context, Canopy.liveCrimson),
        ),
      );
      return;
    }

    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    if (!context.mounted) return;
    _showDataExportDialog(context, pretty);
  }

  /// Saves the export as a JSON file: the share sheet on phones (Files,
  /// Drive, email), a download in the browser.
  Future<void> _saveDataExportFile(
      BuildContext context, String jsonText) async {
    final now = DateTime.now();
    final fileName = 'hadayah-data-${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}.json';
    try {
      await Share.shareXFiles(
        [
          XFile.fromData(Uint8List.fromList(utf8.encode(jsonText)),
              mimeType: 'application/json', name: fileName)
        ],
        fileNameOverrides: [fileName],
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.data_export_save_error_toast'.tr()),
          backgroundColor: paletteColor(context, Canopy.liveCrimson),
        ),
      );
    }
  }

  void _showDataExportDialog(BuildContext context, String jsonText) {
    showCaDialog(
      context: context,
      builder: (dialogContext) {
        return CaAlertDialog(
          backgroundColor: paletteColor(dialogContext, AppTheme.surface),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: BorderSide(color: paletteColor(dialogContext, Canopy.hairline)),
          ),
          title: Text(
            'settings.data_export_dialog_title'.tr(),
            style: TextStyle(
              color: paletteColor(dialogContext, Canopy.ink),
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
                  style: TextStyle(color: paletteColor(dialogContext, Canopy.slate), fontSize: 12),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Container(
                  constraints: const BoxConstraints(maxHeight: 360),
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: paletteColor(dialogContext, Canopy.mint),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: paletteColor(dialogContext, Canopy.hairline)),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonText,
                      style: TextStyle(
                        color: paletteColor(dialogContext, Canopy.slate),
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
                style: TextStyle(color: paletteColor(dialogContext, Canopy.haze)),
              ),
            ),
            TextButton.icon(
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
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: paletteColor(dialogContext, AppTheme.primary),
                foregroundColor: paletteColor(dialogContext, AppTheme.onMedia),
              ),
              icon: const Icon(Icons.save_alt_rounded, size: 16),
              label: Text('settings.data_export_save_btn'.tr()),
              onPressed: () => _saveDataExportFile(dialogContext, jsonText),
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
        color: paletteColor(context, AppTheme.surface),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: paletteColor(context, Canopy.liveCrimson).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.delete_account_title'.tr(),
            style: TextStyle(
              color: paletteColor(context, Canopy.ink),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'settings.delete_account_desc'.tr(),
            style: TextStyle(
                color: paletteColor(context, Canopy.slate), fontSize: AppTheme.captionFont),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isDeletingAccount
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: HadayahLoadingIndicator(
                        strokeWidth: 2,
                        color: paletteColor(context, Canopy.liveCrimson),
                      ),
                    )
                  : const Icon(Icons.delete_forever_rounded, size: 18),
              label: Text('settings.delete_account_btn'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: paletteColor(context, Canopy.liveCrimson),
                side: BorderSide(color: paletteColor(context, Canopy.liveCrimson)),
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
          backgroundColor: paletteColor(dialogContext, AppTheme.surface),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: BorderSide(color: paletteColor(dialogContext, Canopy.hairline)),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: paletteColor(dialogContext, Canopy.liveCrimson), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'settings.delete_account_confirm_title'.tr(),
                  style: TextStyle(
                    color: paletteColor(dialogContext, Canopy.ink),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'settings.delete_account_confirm_body'.tr(),
            style: TextStyle(
                color: paletteColor(dialogContext, Canopy.ink), fontWeight: FontWeight.w500, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'settings.cancel'.tr(),
                style: TextStyle(color: paletteColor(dialogContext, Canopy.haze)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: paletteColor(dialogContext, Canopy.liveCrimson),
                foregroundColor: paletteColor(dialogContext, AppTheme.onMedia),
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
    final error = await provider.deleteOwnAccount();
    if (!context.mounted) return;
    setState(() => _isDeletingAccount = false);

    if (error == null) {
      context.go('/welcome');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.delete_account_success_toast'.tr())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deleteAccountErrorText(error)),
          backgroundColor: paletteColor(context, Canopy.liveCrimson),
          duration: const Duration(seconds: 8),
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
            style: TextStyle(
              color: paletteColor(context, Canopy.ink),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'settings.chat_history_desc'.tr(),
            style: TextStyle(
                color: paletteColor(context, Canopy.slate), fontSize: AppTheme.captionFont),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isDeletingStreamMessages
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: HadayahLoadingIndicator(
                          strokeWidth: 2, color: paletteColor(context, AppTheme.primary)),
                    )
                  : const Icon(Icons.forum_outlined, size: 18),
              label: Text('settings.delete_messages_by_stream_btn'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: paletteColor(context, AppTheme.primary),
                side: BorderSide(color: paletteColor(context, AppTheme.primary)),
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
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: HadayahLoadingIndicator(
                          strokeWidth: 2, color: paletteColor(context, Canopy.liveCrimson)),
                    )
                  : const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text('settings.delete_all_messages_btn'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: paletteColor(context, Canopy.liveCrimson),
                side: BorderSide(color: paletteColor(context, Canopy.liveCrimson)),
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
        backgroundColor: paletteColor(dialogContext, AppTheme.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: BorderSide(color: paletteColor(dialogContext, Canopy.hairline)),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: paletteColor(dialogContext, Canopy.liveCrimson), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'settings.delete_all_messages_confirm_title'.tr(),
                style: TextStyle(
                  color: paletteColor(dialogContext, Canopy.ink),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'settings.delete_all_messages_confirm_body'.tr(),
          style: TextStyle(color: paletteColor(dialogContext, Canopy.slate), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('settings.cancel'.tr(),
                style: TextStyle(color: paletteColor(dialogContext, Canopy.haze))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: paletteColor(dialogContext, Canopy.liveCrimson),
                foregroundColor: paletteColor(dialogContext, AppTheme.onMedia)),
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
        backgroundColor: success ? null : paletteColor(context, Canopy.liveCrimson),
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
        backgroundColor: paletteColor(dialogContext, AppTheme.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: BorderSide(color: paletteColor(dialogContext, Canopy.hairline)),
        ),
        title: Text('settings.select_stream_dialog_title'.tr(),
            style: TextStyle(
                color: paletteColor(dialogContext, Canopy.ink), fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: streamIds.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: Text(
                    'settings.select_stream_dialog_empty'.tr(),
                    style: TextStyle(color: paletteColor(dialogContext, Canopy.slate)),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: streamIds.length,
                  itemBuilder: (context, index) {
                    final id = streamIds[index];
                    return ListTile(
                      leading: Icon(Icons.forum_outlined,
                          color: paletteColor(context, AppTheme.primary)),
                      title:
                          Text(id, style: TextStyle(color: paletteColor(context, Canopy.ink))),
                      onTap: () => Navigator.pop(dialogContext, id),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('settings.cancel'.tr(),
                style: TextStyle(color: paletteColor(dialogContext, Canopy.haze))),
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
        backgroundColor: success ? null : paletteColor(context, Canopy.liveCrimson),
      ),
    );
  }
}

/// Explains why `AppProvider.deleteOwnAccount` stopped, so a blocked person
/// knows the next step instead of seeing a generic failure.
@visibleForTesting
String deleteAccountErrorText(String code) {
  if (code == 'account_restricted_apple') {
    return '${deleteAccountErrorText('account_restricted')} '
        '${'settings.delete_account_apple_linked_requirement'.tr()}';
  }
  if (!AppProvider.accountDeletionBlockers.contains(code)) {
    return 'settings.delete_account_error_toast'.tr();
  }
  return 'settings.delete_account_blocked_$code'
      .tr(namedArgs: {'email': AppIdentity.supportEmail});
}
