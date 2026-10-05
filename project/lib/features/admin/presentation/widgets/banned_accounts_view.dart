import '../admin_surface.dart';
import '../../../../core/widgets/phone_input_guard.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../models/banned_user_model.dart';
import '../../../../core/widgets/hadayah_loading_indicator.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';

/// Admin "Banned Accounts"manager (Cluster 4 Task 16): ban a platform
/// account by email (reason + duration) and manage existing bans. A banned
/// account is redirected to /account-banned platform-wide by AppRouter's
/// guard, backed by `is_current_user_banned()`.
class BannedAccountsView extends StatefulWidget {
  const BannedAccountsView({super.key});

  @override
  State<BannedAccountsView> createState() => _BannedAccountsViewState();
}

class _BannedAccountsViewState extends State<BannedAccountsView> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _actingOnIds = {};

  @override
  void initState() {
    super.initState();
    context.read<AppProvider>().ensureBannedUsersLoaded();
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
        backgroundColor: isError ? Canopy.liveCrimson : Canopy.leaf,
      ),
    );
  }

  Future<void> _run(
      String id, Future<void> Function() action, String successMessage) async {
    setState(() => _actingOnIds.add(id));
    try {
      await action();
      _showToast(successMessage);
    } catch (e) {
      _showToast('$e', isError: true);
    } finally {
      if (mounted) setState(() => _actingOnIds.remove(id));
    }
  }

  void _showBanDialog(AppProvider provider) {
    final emailController = TextEditingController();
    final reasonController = TextEditingController();
    double? durationHours = 0; // 0 == permanent sentinel for this dialog

    showCaDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => CaAlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: const BorderSide(color: Canopy.hairline),
          ),
          title: Text('admin.ban_user_dialog_title'.tr(),
              style: const TextStyle(
                  color: Canopy.ink, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PhoneInputGuard(builder: (context, blocked) => TextField(
                          readOnly: blocked,
                          controller: emailController,
                          style: const TextStyle(color: Canopy.ink),
                          decoration: InputDecoration(
                            labelText: 'Account email...',
                            labelStyle:
                                const TextStyle(color: Canopy.slate),
                            filled: true,
                            fillColor: Canopy.mint,
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd)),
                          ),
                        )),
                const SizedBox(height: AppTheme.spaceMd),
                PhoneInputGuard(builder: (context, blocked) => TextField(
                          readOnly: blocked,
                          controller: reasonController,
                          maxLines: 2,
                          style: const TextStyle(color: Canopy.ink),
                          decoration: InputDecoration(
                            labelText: 'admin.ban_reason_label'.tr(),
                            labelStyle:
                                const TextStyle(color: Canopy.slate),
                            filled: true,
                            fillColor: Canopy.mint,
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd)),
                          ),
                        )),
                const SizedBox(height: AppTheme.spaceMd),
                Text('admin.ban_duration_label'.tr(),
                    style: const TextStyle(
                        color: Canopy.slate, fontSize: 12)),
                DropdownButton<double?>(
                  value: durationHours,
                  isExpanded: true,
                  dropdownColor: Canopy.mint,
                  style: const TextStyle(
                      color: Canopy.ink, fontSize: 13),
                  items: [
                    DropdownMenuItem(
                        value: 0.0,
                        child: Text('admin.ban_duration_permanent'.tr())),
                    DropdownMenuItem(
                        value: 24.0,
                        child: Text('admin.ban_duration_24h'.tr())),
                    DropdownMenuItem(
                        value: 24.0 * 7,
                        child: Text('admin.ban_duration_7d'.tr())),
                    DropdownMenuItem(
                        value: 24.0 * 30,
                        child: Text('admin.ban_duration_30d'.tr())),
                  ],
                  onChanged: (v) => setDialogState(() => durationHours = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('common.cancel'.tr(),
                  style: const TextStyle(color: Canopy.haze)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Canopy.liveCrimson,
                  foregroundColor: AppTheme.onMedia),
              onPressed: () {
                final email = emailController.text.trim();
                final reason = reasonController.text.trim();
                if (email.isEmpty || reason.isEmpty) return;
                Navigator.pop(dialogContext);
                final expiresAt = (durationHours == null || durationHours == 0)
                    ? null
                    : DateTime.now()
                        .add(Duration(minutes: (durationHours! * 60).round()));
                _run(
                  email,
                  () => provider.banAccountByEmail(
                      email: email, reason: reason, expiresAt: expiresAt),
                  'admin.user_banned_toast'.tr(),
                );
              },
              child: Text('admin.ban_user_btn'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmUnban(AppProvider provider, BannedUserModel user) {
    showCaDialog(
      context: context,
      builder: (dialogContext) => CaAlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: const BorderSide(color: Canopy.hairline),
        ),
        title: Text('admin.unban_confirm_title'.tr(),
            style: const TextStyle(
                color: Canopy.ink, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('common.cancel'.tr(),
                style: const TextStyle(color: Canopy.haze)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Canopy.leaf,
                foregroundColor: AppTheme.onMedia),
            onPressed: () {
              Navigator.pop(dialogContext);
              _run(
                user.id,
                () => provider.unbanAccount(user.profileId),
                'admin.user_unbanned_toast'.tr(),
              );
            },
            child: Text('admin.unban_btn'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final bannedUsers = context
        .select<AppProvider, List<BannedUserModel>>((p) => p.bannedUsers);

    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? bannedUsers
        : bannedUsers
            .where((u) =>
                u.email.toLowerCase().contains(query) ||
                (u.displayName ?? '').toLowerCase().contains(query))
            .toList();

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminFlow(
            children: [
              const Icon(Icons.person_off_rounded,
                  color: Canopy.liveCrimson, size: 20),
              const SizedBox(width: 8),
              Text(
                'admin.banned_accounts_title'.tr(),
                style: const TextStyle(
                  color: Canopy.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Canopy.liveCrimson,
                    foregroundColor: AppTheme.onMedia),
                icon: const Icon(Icons.block_rounded, size: 16),
                label: Text('admin.ban_user_btn'.tr()),
                onPressed: () => _showBanDialog(provider),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text('admin.banned_accounts_desc'.tr(),
              style:
                  const TextStyle(color: Canopy.slate, fontSize: 12)),
          const SizedBox(height: AppTheme.spaceLg),
          PhoneInputGuard(builder: (context, blocked) => TextField(
                    readOnly: blocked,
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                        color: Canopy.ink, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'admin.search_banned_accounts'.tr(),
                      hintStyle: const TextStyle(
                          color: Canopy.slate, fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: Canopy.slate, size: 18),
                      filled: true,
                      fillColor: AppTheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: const BorderSide(color: Canopy.hairline),
                      ),
                    ),
                  )),
          const SizedBox(height: AppTheme.spaceLg),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('admin.no_banned_accounts'.tr(),
                        style: const TextStyle(color: Canopy.slate)))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppTheme.spaceMd),
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      final isActing = _actingOnIds.contains(user.id);
                      return Container(
                        padding: const EdgeInsets.all(AppTheme.spaceMd),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                              color: Canopy.liveCrimson.withValues(alpha: 0.3)),
                        ),
                        child: AdminFlow(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName ?? user.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Canopy.ink,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  Text(
                                    user.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Canopy.haze,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.reason,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppTheme.warning, fontSize: 12),
                                  ),
                                  Text(
                                    user.isPermanent
                                        ? 'admin.ban_duration_permanent'.tr()
                                        : DateFormat('yyyy-MM-dd HH:mm')
                                            .format(user.expiresAt!),
                                    style: const TextStyle(
                                        color: Canopy.haze,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (isActing)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: HadayahLoadingIndicator(
                                    strokeWidth: 2, color: AppTheme.primary),
                              )
                            else
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Canopy.leaf,
                                  side:
                                      const BorderSide(color: Canopy.leaf),
                                ),
                                onPressed: () => _confirmUnban(provider, user),
                                child: Text('admin.unban_btn'.tr()),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
