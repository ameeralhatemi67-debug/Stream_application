import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';

/// Post-Registration Role Selection Screen (Viewer vs. Streamer Application)
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final userName = provider.googleUserName ?? 'Welcome';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceLg,
              vertical: AppTheme.spaceMd,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 720 : 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Greeting & Avatar Header
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: provider.googleUserAvatar != null
                        ? (provider.googleUserAvatar!.startsWith('http')
                            ? NetworkImage(provider.googleUserAvatar!)
                            : AssetImage(provider.googleUserAvatar!) as ImageProvider)
                        : const AssetImage('assets/images/Amir_Alhatemi/amir_person_pic.jpg'),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    'role_select.welcome_user'.tr(args: [userName]),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'role_select.prompt_title'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spaceXl),

                  // Option 1: Viewer / Student Role Card
                  _buildOptionCard(
                    context: context,
                    icon: Icons.explore_rounded,
                    accentColor: AppTheme.primary,
                    title: 'role_select.viewer_title'.tr(),
                    badge: 'role_select.viewer_badge'.tr(),
                    description: 'role_select.viewer_desc'.tr(),
                    buttonText: 'role_select.viewer_btn'.tr(),
                    onTap: () {
                      provider.selectViewerRole();
                      context.go('/feed');
                    },
                  ),
                  const SizedBox(height: AppTheme.spaceMd),

                  // Option 2: Apply to become a Broadcaster / Organization
                  _buildOptionCard(
                    context: context,
                    icon: Icons.podcasts_rounded,
                    accentColor: AppTheme.danger,
                    title: 'role_select.streamer_title'.tr(),
                    badge: 'role_select.streamer_badge'.tr(),
                    description: 'role_select.streamer_desc'.tr(),
                    buttonText: 'role_select.streamer_btn'.tr(),
                    onTap: () {
                      provider.selectBroadcasterRole();
                      context.go('/streamer-apply');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String badge,
    required String description,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    final isRtl = context.locale.languageCode == 'ar';
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: accentColor, width: 1.2),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            description,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: AppTheme.onMedia,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                elevation: 0,
              ),
              onPressed: onTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Transform.scale(
                    scaleX: isRtl ? -1.0 : 1.0,
                    child: const Icon(Icons.arrow_forward_rounded, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
