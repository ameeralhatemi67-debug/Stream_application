import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';

/// Cluster 4 Task 16: full-screen block shown instead of the app when
/// `AppProvider.isCurrentUserBanned` is true. `AppRouter`'s redirect guard
/// sends every guarded path here; this screen itself only offers the ban
/// reason, a support contact, and sign-out (there is nothing else a banned
/// account can do).
class AccountBannedScreen extends StatefulWidget {
  const AccountBannedScreen({super.key});

  @override
  State<AccountBannedScreen> createState() => _AccountBannedScreenState();
}

class _AccountBannedScreenState extends State<AccountBannedScreen> {
  bool _toastShown = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final reason = provider.currentUserBanReason;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    // Explicit toast on top of the full reason page below -- Task 16 asks
    // for an unmissable alert the moment a banned account tries to sign in,
    // not just a static page (testing_check_list.md: "need to add a
    // message to that user when he try's inteing using that same email").
    if (!_toastShown) {
      _toastShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            content: Text(
              reason != null && reason.trim().isNotEmpty
                  ? '${'account_banned.title'.tr()}: $reason'
                  : 'account_banned.title'.tr(),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBgBase,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceLg,
              vertical: AppTheme.spaceMd,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 560 : 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(color: AppTheme.accentRed, width: 2),
                    ),
                    child: const Icon(Icons.block_rounded,
                        color: AppTheme.accentRed, size: 40),
                  ),
                  const SizedBox(height: AppTheme.spaceXl),
                  Text(
                    'account_banned.title'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    'account_banned.body'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  if (reason != null && reason.trim().isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spaceLg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spaceMd),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface1,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                            color: AppTheme.accentRed.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'account_banned.reason_label'.tr(),
                            style: const TextStyle(
                              color: AppTheme.textMutedDark,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reason,
                            style: const TextStyle(
                              color: AppTheme.textPrimaryDark,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.spaceXl),
                  Text(
                    'account_banned.contact_support'.tr(
                      namedArgs: {'email': 'support@streamer.app'},
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textMutedDark,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.darkSurface2,
                        foregroundColor: AppTheme.textPrimaryDark,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text('account_banned.sign_out'.tr()),
                      onPressed: () async {
                        await context.read<AppProvider>().signOut();
                        if (context.mounted) context.go('/welcome');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
