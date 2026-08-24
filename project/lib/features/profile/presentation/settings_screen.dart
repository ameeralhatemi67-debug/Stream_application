import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import '../../profile/models/streamer_models.dart';
import '../models/user_account_model.dart';
import '../../admin/models/broadcaster_application_model.dart';
import '../../admin/models/terms_and_conditions_model.dart';
import '../../../core/services/notifications/notification_models.dart';
import 'widgets/broadcaster_application_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _youtubeUrlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _slidesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _youtubeUrlController.text = provider.customYouTubeLiveUrl;
    _titleController.text = provider.customLiveTitle;
    _venueController.text = provider.customLiveVenue;
    _slidesController.text = provider.customSlidesUrl;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppProvider>().refreshMyApplicationAndStreamerStatus();
      }
    });
  }

  @override
  void dispose() {
    _youtubeUrlController.dispose();
    _titleController.dispose();
    _venueController.dispose();
    _slidesController.dispose();
    super.dispose();
  }

  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }
    return NetworkImage(url);
  }

  void _showEditProfileDialog(BuildContext context) {
    final provider = context.read<AppProvider>();
    final profile = provider.userProfile;

    final nameController = TextEditingController(text: profile.nameEn);
    final titleController = TextEditingController(text: profile.titleEn);
    final orgController = TextEditingController(text: profile.organizationEn);
    final bioController = TextEditingController(text: profile.bioEn);
    final youtubeController =
        TextEditingController(text: profile.youtubeChannelUrl);
    final avatarController = TextEditingController(text: profile.avatarUrl);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.darkSurface1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: const BorderSide(color: AppTheme.darkBorderSubtle),
          ),
          title: Text(
            'settings.edit_profile'.tr(),
            style: const TextStyle(
                color: AppTheme.textPrimaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(
                      color: AppTheme.textPrimaryDark, fontSize: 13),
                  decoration:
                      InputDecoration(labelText: 'settings.full_name'.tr()),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: titleController,
                  style: const TextStyle(
                      color: AppTheme.textPrimaryDark, fontSize: 13),
                  decoration: InputDecoration(
                      labelText: 'settings.academic_title'.tr()),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: orgController,
                  style: const TextStyle(
                      color: AppTheme.textPrimaryDark, fontSize: 13),
                  decoration: InputDecoration(
                      labelText: 'settings.university_org'.tr()),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: youtubeController,
                  style: const TextStyle(
                      color: AppTheme.textPrimaryDark, fontSize: 13),
                  decoration: InputDecoration(
                      labelText: 'settings.linked_youtube'.tr()),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: avatarController,
                  style: const TextStyle(
                      color: AppTheme.textPrimaryDark, fontSize: 13),
                  decoration: InputDecoration(
                      labelText: 'settings.profile_pic_url'.tr()),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: bioController,
                  maxLines: 2,
                  style: const TextStyle(
                      color: AppTheme.textPrimaryDark, fontSize: 13),
                  decoration:
                      InputDecoration(labelText: 'settings.bio_research'.tr()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'settings.cancel'.tr(),
                style: const TextStyle(color: AppTheme.textMutedDark),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                provider.updateUserProfile(
                  profile.copyWith(
                    nameEn: nameController.text.trim(),
                    nameAr: nameController.text.trim(),
                    titleEn: titleController.text.trim(),
                    titleAr: titleController.text.trim(),
                    organizationEn: orgController.text.trim(),
                    organizationAr: orgController.text.trim(),
                    youtubeChannelUrl: youtubeController.text.trim(),
                    avatarUrl: avatarController.text.trim().isNotEmpty
                        ? avatarController.text.trim()
                        : profile.avatarUrl,
                    bioEn: bioController.text.trim(),
                    bioAr: bioController.text.trim(),
                  ),
                );
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('settings.profile_saved_toast'.tr())),
                );
              },
              child: Text('settings.save_profile'.tr()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // context.read for the instance the many _build* helpers below need (they
    // call mutation methods like setRoleMode/signOut/loginWithGoogle directly
    // on it). context.select registers this screen's rebuild dependency on
    // exactly the fields those helpers read -- context.watch<AppProvider>()
    // previously rebuilt this whole multi-section screen on ANY AppProvider
    // change anywhere in the app (map streamers, other users' notifications,
    // admin audit logs, none of which this screen displays).
    final appProvider = context.read<AppProvider>();
    context.select<
        AppProvider,
        ({
          UserProfileModel userProfile,
          bool isStreamerModeEnabled,
          bool isLoggedInStreamer,
          String? googleUserEmail,
          String? googleUserName,
          List<BroadcasterApplicationModel> applications,
          bool isBroadcastingLive,
          BroadcastType customBroadcastType,
          String? selectedBroadcastOrgId,
          String? selectedVenueBranchId,
          List<String> selectedCoSpeakerIds,
          String selectedStreamingQuality,
          TermsAndConditionsModel termsAndConditions,
          NotificationPreferencesModel notificationPreferences,
        })>((p) => (
          userProfile: p.userProfile,
          isStreamerModeEnabled: p.isStreamerModeEnabled,
          isLoggedInStreamer: p.isLoggedInStreamer,
          googleUserEmail: p.googleUserEmail,
          googleUserName: p.googleUserName,
          applications: p.applications,
          isBroadcastingLive: p.isBroadcastingLive,
          customBroadcastType: p.customBroadcastType,
          selectedBroadcastOrgId: p.selectedBroadcastOrgId,
          selectedVenueBranchId: p.selectedVenueBranchId,
          selectedCoSpeakerIds: p.selectedCoSpeakerIds,
          selectedStreamingQuality: p.selectedStreamingQuality,
          termsAndConditions: p.termsAndConditions,
          notificationPreferences: p.notificationPreferences,
        ));
    final currentLocale = context.locale.languageCode;
    final isAr = currentLocale == 'ar';
    final isStreamer = appProvider.isStreamerModeEnabled;

    return Scaffold(
      backgroundColor: AppTheme.darkBgBase,
      appBar: AppBar(
        title: Text('settings.title'.tr()),
        backgroundColor: AppTheme.darkBgBase,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        children: [
          // 👑 Top Option: My Account Profile (Protected, cannot be deleted)
          _buildUserProfileHeaderCard(context, appProvider),
          const SizedBox(height: AppTheme.spaceLg),

          // 🎭 Section 1: Streamer vs. Viewer Role Mode Toggle
          _buildSectionHeader(
            context,
            title: 'settings.role_mode_title'.tr(),
            icon: Icons.switch_account_rounded,
            iconColor: AppTheme.accentRed,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildRoleModeToggleCard(context, appProvider),
          const SizedBox(height: AppTheme.spaceLg),

          // 📝 Section 1.5: Broadcaster & Organization Verification Application & Live Tracking Banner
          _buildSectionHeader(
            context,
            title: 'application.title'.tr(),
            icon: Icons.verified_rounded,
            iconColor: AppTheme.accentBlue,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildApplicationSection(context, appProvider),
          const SizedBox(height: AppTheme.spaceLg),

          // 📡 Section 2 (Streamer Only): Streamer Go Live Studio & YouTube Linker
          if (isStreamer) ...[
            _buildSectionHeader(
              context,
              title: 'settings.go_live_studio'.tr(),
              icon: Icons.videocam_rounded,
              iconColor: AppTheme.accentRed,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            _buildStreamerStudioCard(context, appProvider),
            const SizedBox(height: AppTheme.spaceLg),
          ],

          // Section 3: Language Preference
          _buildSectionHeader(
            context,
            title: 'settings.language'.tr(),
            icon: Icons.language_rounded,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildLanguageSelectorCard(context, currentLocale),
          const SizedBox(height: AppTheme.spaceLg),

          // Section 3.5: Notification Preferences & Anti-Spam Throttling
          _buildSectionHeader(
            context,
            title: isAr
                ? 'إعدادات الإشعارات والتنبيهات'
                : 'Notification Preferences',
            icon: Icons.notifications_active_rounded,
            iconColor: AppTheme.accentBlue,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildNotificationPreferencesCard(context, appProvider),
          const SizedBox(height: AppTheme.spaceLg),

          // Section 4: Streaming Quality
          _buildSectionHeader(
            context,
            title: 'settings.streaming'.tr(),
            icon: Icons.tune_rounded,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildStreamingQualityCard(context, appProvider),
          const SizedBox(height: AppTheme.spaceLg),

          // Section 6: Platform Governance, Terms & Privacy
          _buildSectionHeader(
            context,
            title: 'settings.governance_legal'.tr(),
            icon: Icons.gavel_rounded,
            iconColor: AppTheme.accentBlue,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildGovernanceCard(context, appProvider),
          const SizedBox(height: AppTheme.spaceLg),

          // Section 7: About
          _buildSectionHeader(
            context,
            title: 'settings.about'.tr(),
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildVersionInfoCard(context),
          const SizedBox(height: AppTheme.spaceXl),
        ],
      ),
    );
  }

  Widget _buildUserProfileHeaderCard(
      BuildContext context, AppProvider provider) {
    final profile = provider.userProfile;
    final isAr = context.locale.languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: _getImageProvider(profile.avatarUrl),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isAr ? profile.nameAr : profile.nameEn,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryDark,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded,
                        color: AppTheme.accentPurple, size: 15),
                  ],
                ),
                Text(
                  isAr ? profile.titleAr : profile.titleEn,
                  style: const TextStyle(
                      color: AppTheme.textSecondaryDark, fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isAr ? profile.organizationAr : profile.organizationEn,
                  style: const TextStyle(
                      color: AppTheme.accentBlue, fontSize: 10.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: Text('settings.edit_profile'.tr(),
                style: const TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkSurface2,
              foregroundColor: AppTheme.textPrimaryDark,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                side: const BorderSide(color: AppTheme.darkBorderSubtle),
              ),
            ),
            onPressed: () => _showEditProfileDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleModeToggleCard(BuildContext context, AppProvider provider) {
    final isApproved = provider.isApprovedStreamer;
    final isStreamer = provider.isStreamerModeEnabled && isApproved;
    final isLoggedIn = provider.isLoggedInStreamer;
    final googleEmail = provider.googleUserEmail ?? '';
    final googleName = provider.googleUserName ?? '';
    final isAr = context.locale.languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isStreamer
              ? AppTheme.accentRed.withValues(alpha: 0.5)
              : AppTheme.darkBorderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isStreamer
                      ? AppTheme.accentRed.withValues(alpha: 0.15)
                      : AppTheme.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  isStreamer
                      ? Icons.videocam_rounded
                      : Icons.visibility_rounded,
                  color: isStreamer ? AppTheme.accentRed : AppTheme.accentBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isStreamer
                          ? 'settings.role_streamer_active'.tr()
                          : 'settings.role_viewer_active'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textPrimaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isApproved
                          ? (isStreamer
                              ? 'settings.role_streamer_desc'.tr()
                              : 'settings.role_viewer_desc'.tr())
                          : (isAr
                              ? 'حساب مشاهد عادي (يتطلب توثيق المذيع لتفعيل وضع البث)'
                              : 'Viewer Mode (Streamer Studio unlocked upon Broadcaster verification)'),
                      style: const TextStyle(
                        color: AppTheme.textSecondaryDark,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isStreamer,
                activeThumbColor: AppTheme.accentRed,
                onChanged: isApproved
                    ? (val) {
                        provider.setRoleMode(val);
                      }
                    : null,
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spaceMd),
          const Divider(color: AppTheme.darkBorderSubtle, height: 1),
          const SizedBox(height: AppTheme.spaceMd),

          // Google Account Status / Action
          if (isLoggedIn && isStreamer) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface2,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                    color: AppTheme.accentRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          googleName,
                          style: const TextStyle(
                            color: AppTheme.textPrimaryDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          googleEmail,
                          style: const TextStyle(
                            color: AppTheme.textMutedDark,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'BROADCASTER',
                      style: TextStyle(
                        color: AppTheme.accentRed,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondaryDark,
                  side: const BorderSide(color: AppTheme.darkBorderSubtle),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: Text('settings.logout_to_viewer'.tr()),
                onPressed: () async {
                  await provider.signOut();
                  if (context.mounted) {
                    context.go('/welcome');
                  }
                },
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                label: Text('settings.signin_as_streamer'.tr()),
                onPressed: () {
                  provider.loginWithGoogle();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('settings.signed_in_toast'.tr()),
                      backgroundColor: AppTheme.accentRed,
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: AppTheme.spaceSm),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentBlue,
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: Text('settings.reopen_onboarding'.tr()),
              onPressed: () {
                context.push('/onboarding');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationSection(BuildContext context, AppProvider provider) {
    final isAr = context.locale.languageCode == 'ar';
    final userApp = provider.myApplication;

    if (userApp == null) {
      return _buildBecomeBroadcasterPromoCard(context);
    }

    return _buildApplicationStatusCard(context, provider, userApp, isAr);
  }

  Widget _buildBecomeBroadcasterPromoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.school_rounded,
                    color: AppTheme.accentBlue, size: 24),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'application.apply_card_title'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textPrimaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'application.apply_card_desc'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textSecondaryDark,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
              label: Text(
                'application.apply_btn'.tr(),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: () => context.push('/streamer-apply'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationStatusCard(
    BuildContext context,
    AppProvider provider,
    BroadcasterApplicationModel app,
    bool isAr,
  ) {
    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;

    switch (app.status) {
      case ApplicationStatus.approved:
        statusColor = AppTheme.accentGreen;
        statusIcon = Icons.verified_rounded;
        statusTitle = 'application.status_approved'.tr();
        statusSubtitle = 'application.status_approved_desc'.tr();
        break;
      case ApplicationStatus.rejected:
        statusColor = AppTheme.accentRed;
        statusIcon = Icons.error_outline_rounded;
        statusTitle = 'application.status_rejected'.tr();
        statusSubtitle =
            app.reviewNotes ?? 'Changes requested before verification.';
        break;
      case ApplicationStatus.pending:
      default:
        statusColor = AppTheme.accentAmber;
        statusIcon = Icons.hourglass_top_rounded;
        statusTitle = 'application.status_pending'.tr();
        statusSubtitle = 'application.status_pending_desc'.tr();
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            statusTitle,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface2,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: AppTheme.darkBorderSubtle, width: 0.6),
                          ),
                          child: Text(
                            app.isOrganization ? 'ORGANIZATION' : 'SCHOLAR',
                            style: const TextStyle(
                                color: AppTheme.textMutedDark, fontSize: 8.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isAr ? app.applicantNameAr : app.applicantNameEn} • ${app.email}',
                      style: const TextStyle(
                        color: AppTheme.textPrimaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spaceSm),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface2,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (app.status == ApplicationStatus.rejected &&
                    app.reviewNotes != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 13, color: AppTheme.accentRed),
                      const SizedBox(width: 4),
                      Text(
                        'application.admin_feedback'.tr(),
                        style: const TextStyle(
                          color: AppTheme.accentRed,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app.reviewNotes!,
                    style: const TextStyle(
                        color: AppTheme.textSecondaryDark, fontSize: 11),
                  ),
                ] else ...[
                  Text(
                    statusSubtitle,
                    style: const TextStyle(
                        color: AppTheme.textSecondaryDark, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentBlue,
                    side: const BorderSide(color: AppTheme.darkBorderSubtle),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: Text(
                    app.status == ApplicationStatus.rejected
                        ? 'application.reapply_btn'.tr()
                        : 'Edit Application',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  onPressed: () => context.push('/streamer-apply'),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkSurface2,
                    foregroundColor: AppTheme.textPrimaryDark,
                    elevation: 0,
                    side: const BorderSide(color: AppTheme.darkBorderSubtle),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  icon: const Icon(Icons.add_task_rounded, size: 16),
                  label: const Text(
                    'New Application',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  onPressed: () => BroadcasterApplicationSheet.show(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreamerStudioCard(BuildContext context, AppProvider provider) {
    final isBroadcasting = provider.isBroadcastingLive;
    final isAudioLive = provider.customBroadcastType == BroadcastType.liveAudio;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isBroadcasting
              ? (isAudioLive ? const Color(0xFFA1A1AA) : AppTheme.accentRed)
              : AppTheme.darkBorderSubtle,
          width: isBroadcasting ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isBroadcasting
                          ? (isAudioLive
                              ? const Color(0xFFA1A1AA)
                              : AppTheme.accentRed)
                          : AppTheme.textMutedDark,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isBroadcasting
                        ? (isAudioLive
                            ? 'settings.broadcast_status_audio_live'.tr()
                            : 'settings.broadcast_status_live'.tr())
                        : 'settings.broadcast_status_offline'.tr(),
                    style: TextStyle(
                      color: isBroadcasting
                          ? (isAudioLive
                              ? const Color(0xFFE4E4E7)
                              : AppTheme.accentRed)
                          : AppTheme.textMutedDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (isBroadcasting)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAudioLive
                        ? const Color(0xFF3F3F46)
                        : AppTheme.accentRed.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: isAudioLive
                        ? Border.all(color: const Color(0xFFA1A1AA), width: 0.8)
                        : null,
                  ),
                  child: Text(
                    isAudioLive
                        ? '342 ${'live.listening_count'.tr()}'
                        : '342 ${'settings.viewers_count'.tr()}',
                    style: TextStyle(
                      color: isAudioLive
                          ? const Color(0xFFE4E4E7)
                          : AppTheme.accentRed,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // 🏢 Broadcast Identity Selector (Scholar vs Organization)
          Text(
            'admin.broadcast_identity'.tr(),
            style: const TextStyle(
              color: AppTheme.textSecondaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_rounded, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'admin.broadcast_as_individual'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  selected: provider.selectedBroadcastOrgId == null,
                  selectedColor: AppTheme.accentBlue.withValues(alpha: 0.2),
                  backgroundColor: AppTheme.darkSurface2,
                  labelStyle: TextStyle(
                    color: provider.selectedBroadcastOrgId == null
                        ? AppTheme.accentBlue
                        : AppTheme.textSecondaryDark,
                    fontSize: 11,
                    fontWeight: provider.selectedBroadcastOrgId == null
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: provider.selectedBroadcastOrgId == null
                        ? AppTheme.accentBlue
                        : AppTheme.darkBorderSubtle,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      provider.setSelectedBroadcastOrgId(null);
                    }
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: ChoiceChip(
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.apartment_rounded, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'admin.broadcast_as_org'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  selected: provider.selectedBroadcastOrgId == 'org_dalilk_04',
                  selectedColor: AppTheme.accentAmber.withValues(alpha: 0.2),
                  backgroundColor: AppTheme.darkSurface2,
                  labelStyle: TextStyle(
                    color: provider.selectedBroadcastOrgId == 'org_dalilk_04'
                        ? AppTheme.accentAmber
                        : AppTheme.textSecondaryDark,
                    fontSize: 11,
                    fontWeight:
                        provider.selectedBroadcastOrgId == 'org_dalilk_04'
                            ? FontWeight.bold
                            : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: provider.selectedBroadcastOrgId == 'org_dalilk_04'
                        ? AppTheme.accentAmber
                        : AppTheme.darkBorderSubtle,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      provider.setSelectedBroadcastOrgId('org_dalilk_04');
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // 🎙️ / 🎥 Broadcast Format Segmented Selector
          Text(
            'settings.broadcast_format'.tr(),
            style: const TextStyle(
              color: AppTheme.textSecondaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () =>
                      provider.setBroadcastType(BroadcastType.liveVideo),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                    decoration: BoxDecoration(
                      color: provider.customBroadcastType ==
                              BroadcastType.liveVideo
                          ? AppTheme.accentRed.withValues(alpha: 0.2)
                          : AppTheme.darkSurface2,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: provider.customBroadcastType ==
                                BroadcastType.liveVideo
                            ? AppTheme.accentRed
                            : AppTheme.darkBorderSubtle,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videocam_rounded,
                          size: 16,
                          color: provider.customBroadcastType ==
                                  BroadcastType.liveVideo
                              ? AppTheme.accentRed
                              : AppTheme.textMutedDark,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'settings.format_video'.tr(),
                            style: TextStyle(
                              color: provider.customBroadcastType ==
                                      BroadcastType.liveVideo
                                  ? Colors.white
                                  : AppTheme.textSecondaryDark,
                              fontSize: 12,
                              fontWeight: provider.customBroadcastType ==
                                      BroadcastType.liveVideo
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: InkWell(
                  onTap: () =>
                      provider.setBroadcastType(BroadcastType.liveAudio),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                    decoration: BoxDecoration(
                      color: provider.customBroadcastType ==
                              BroadcastType.liveAudio
                          ? const Color(0xFF3F3F46)
                          : AppTheme.darkSurface2,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: provider.customBroadcastType ==
                                BroadcastType.liveAudio
                            ? const Color(0xFFA1A1AA)
                            : AppTheme.darkBorderSubtle,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic_rounded,
                          size: 16,
                          color: provider.customBroadcastType ==
                                  BroadcastType.liveAudio
                              ? const Color(0xFFE4E4E7)
                              : AppTheme.textMutedDark,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'settings.format_audio'.tr(),
                            style: TextStyle(
                              color: provider.customBroadcastType ==
                                      BroadcastType.liveAudio
                                  ? Colors.white
                                  : AppTheme.textSecondaryDark,
                              fontSize: 12,
                              fontWeight: provider.customBroadcastType ==
                                      BroadcastType.liveAudio
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),

          TextField(
            controller: _youtubeUrlController,
            style:
                const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'settings.youtube_url_label'.tr(),
              prefixIcon: const Icon(Icons.smart_display_rounded,
                  color: AppTheme.accentRed, size: 20),
            ),
            onChanged: (val) => provider.setCustomStreamerYouTubeUrl(val),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          TextField(
            controller: _titleController,
            style:
                const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'settings.lecture_title_label'.tr(),
              prefixIcon: const Icon(Icons.title_rounded,
                  color: AppTheme.accentBlue, size: 20),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // Conditional Venue Section (Organization Campus Dropdown vs Custom Text Field)
          if (provider.selectedBroadcastOrgId != null) ...[
            Text(
              'admin.select_campus_branch'.tr(),
              style: const TextStyle(
                color: AppTheme.textSecondaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Builder(
              builder: (ctx) {
                final branches = provider
                    .getOrganizationVenues(provider.selectedBroadcastOrgId!);
                final langCode = context.locale.languageCode;
                return InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.apartment_rounded,
                        color: AppTheme.accentAmber, size: 20),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: provider.selectedVenueBranchId,
                      isExpanded: true,
                      dropdownColor: AppTheme.darkSurface2,
                      style: const TextStyle(
                          color: AppTheme.textPrimaryDark, fontSize: 13),
                      items: branches.map((b) {
                        return DropdownMenuItem<String>(
                          value: b.venueId,
                          child: Text(
                            '${b.getLocalizedName(langCode)} (${b.seatingCapacity} seats)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          provider.setSelectedVenueBranchId(val),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppTheme.spaceMd),

            // Presenters / Co-Hosts Multi-Select Chips
            Text(
              'admin.select_co_speakers'.tr(),
              style: const TextStyle(
                color: AppTheme.textSecondaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Builder(
              builder: (ctx) {
                final speakers = provider
                    .getOrganizationSpeakers(provider.selectedBroadcastOrgId!);
                final langCode = context.locale.languageCode;
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: speakers.map((spk) {
                    final isChecked =
                        provider.selectedCoSpeakerIds.contains(spk.speakerId);
                    return FilterChip(
                      avatar: CircleAvatar(
                        radius: 12,
                        backgroundImage: AssetImage(spk.avatarUrl),
                      ),
                      label: Text(spk.getLocalizedName(langCode)),
                      selected: isChecked,
                      selectedColor:
                          AppTheme.accentAmber.withValues(alpha: 0.25),
                      backgroundColor: AppTheme.darkSurface2,
                      labelStyle: TextStyle(
                        color: isChecked
                            ? AppTheme.accentAmber
                            : AppTheme.textSecondaryDark,
                        fontSize: 11,
                        fontWeight:
                            isChecked ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isChecked
                            ? AppTheme.accentAmber
                            : AppTheme.darkBorderSubtle,
                      ),
                      onSelected: (_) =>
                          provider.toggleCoSpeaker(spk.speakerId),
                    );
                  }).toList(),
                );
              },
            ),
          ] else ...[
            TextField(
              controller: _venueController,
              style: const TextStyle(
                  color: AppTheme.textPrimaryDark, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'settings.venue_location_label'.tr(),
                prefixIcon: const Icon(Icons.location_pin,
                    color: AppTheme.accentRed, size: 20),
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spaceLg),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isBroadcasting ? AppTheme.darkSurface3 : AppTheme.accentRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              icon: Icon(isBroadcasting
                  ? Icons.stop_circle_outlined
                  : Icons.rocket_launch_rounded),
              label: Text(
                isBroadcasting
                    ? 'settings.end_live_btn'.tr()
                    : 'settings.go_live_btn'.tr(),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: () {
                provider.setCustomBroadcastDetails(
                  title: _titleController.text.trim(),
                  category: 'computer_science',
                  venue: _venueController.text.trim(),
                  slidesUrl: _slidesController.text.trim(),
                );
                provider.toggleBroadcasterGoLive(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelectorCard(
      BuildContext context, String currentLocale) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Icon(
              currentLocale == 'en'
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: currentLocale == 'en'
                  ? AppTheme.accentRed
                  : AppTheme.textMutedDark,
              size: 20,
            ),
            title: const Text('English (US)',
                style:
                    TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13)),
            subtitle: const Text('LTR Interface',
                style: TextStyle(color: AppTheme.textMutedDark, fontSize: 11)),
            onTap: () => context.setLocale(const Locale('en')),
          ),
          const Divider(height: 1, color: AppTheme.darkBorderSubtle),
          ListTile(
            dense: true,
            leading: Icon(
              currentLocale == 'ar'
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: currentLocale == 'ar'
                  ? AppTheme.accentRed
                  : AppTheme.textMutedDark,
              size: 20,
            ),
            title: const Text('العربية (Arabic)',
                style:
                    TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13)),
            subtitle: const Text('واجهة من اليمين إلى اليسار (RTL)',
                style: TextStyle(color: AppTheme.textMutedDark, fontSize: 11)),
            onTap: () => context.setLocale(const Locale('ar')),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingQualityCard(
      BuildContext context, AppProvider provider) {
    final quality = provider.selectedStreamingQuality;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.quality'.tr(),
            style: const TextStyle(
                color: AppTheme.textSecondaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          DropdownButtonFormField<String>(
            initialValue: quality,
            dropdownColor: AppTheme.darkSurface2,
            style:
                const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon:
                  Icon(Icons.hd_outlined, color: AppTheme.accentBlue, size: 20),
            ),
            items: [
              DropdownMenuItem(
                  value: 'Auto (1080p)',
                  child: Text('settings.quality_auto'.tr())),
              DropdownMenuItem(
                  value: 'High (720p HD)',
                  child: Text('settings.quality_high'.tr())),
              DropdownMenuItem(
                  value: 'Medium (480p SD)',
                  child: Text('settings.quality_medium'.tr())),
              DropdownMenuItem(
                  value: 'Low (360p)',
                  child: Text('settings.quality_low'.tr())),
              DropdownMenuItem(
                  value: 'Audio Only',
                  child: Text('settings.quality_audio'.tr())),
            ],
            onChanged: (val) {
              if (val != null) provider.setSelectedStreamingQuality(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVersionInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Column(
        children: [
          _buildInfoRow('settings.version'.tr(), '2.0.0 (Production Release)'),
          const Divider(height: 16, color: AppTheme.darkBorderSubtle),
          _buildInfoRow(
              'settings.region'.tr(), 'Eastern Province (AlSharqia), KSA'),
          const Divider(height: 16, color: AppTheme.darkBorderSubtle),
          _buildInfoRow('settings.status'.tr(), 'All Services Operational 🟢'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondaryDark, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                color: AppTheme.textPrimaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildGovernanceCard(BuildContext context, AppProvider provider) {
    final terms = provider.termsAndConditions;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Column(
        children: [
          _buildGovernanceRow(
            icon: Icons.description_rounded,
            title: 'settings.view_terms'.tr(),
            subtitle:
                '${'settings.terms_version_label'.tr()}: ${terms.version}',
            onTap: () => _showTermsDialog(
              context,
              'settings.view_terms'.tr(),
              terms.getLocalizedTerms(context.locale.languageCode),
            ),
          ),
          const Divider(height: 16, color: AppTheme.darkBorderSubtle),
          _buildGovernanceRow(
            icon: Icons.verified_user_rounded,
            title: 'settings.view_guidelines'.tr(),
            subtitle: 'Academic integrity & broadcast standards',
            onTap: () => _showTermsDialog(
              context,
              'settings.view_guidelines'.tr(),
              terms.getLocalizedGuidelines(context.locale.languageCode),
            ),
          ),
          const Divider(height: 16, color: AppTheme.darkBorderSubtle),
          _buildGovernanceRow(
            icon: Icons.privacy_tip_rounded,
            title: 'settings.view_privacy'.tr(),
            subtitle: 'PDPL KSA Regulatory Compliance',
            onTap: () => _showTermsDialog(
              context,
              'settings.view_privacy'.tr(),
              terms.getLocalizedPrivacy(context.locale.languageCode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGovernanceRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.accentBlue),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMutedDark,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppTheme.textSecondaryDark),
          ],
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: AppTheme.darkBorderSubtle),
        ),
        title: Row(
          children: [
            const Icon(Icons.gavel_rounded,
                color: AppTheme.accentBlue, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(
                color: AppTheme.textSecondaryDark,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPreferencesCard(
      BuildContext context, AppProvider provider) {
    final isAr = context.locale.languageCode == 'ar';
    final prefs = provider.notificationPreferences;
    final mutedIds = prefs.mutedEntityIds;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⏱️ 10-Minute Rolling Rate Limiter Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAr
                    ? 'الحد الأقصى للتنبيهات (كل 10 دقائق)'
                    : '10-Minute Alert Limit',
                style: const TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  border: Border.all(
                      color: AppTheme.accentBlue.withValues(alpha: 0.5)),
                ),
                child: Text(
                  isAr
                      ? '${prefs.maxPer10Min} إشعارات'
                      : '${prefs.maxPer10Min} alerts',
                  style: const TextStyle(
                    color: AppTheme.accentBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isAr
                ? 'يمنع التكرار والإزعاج بدمج التنبيهات الزائدة في ملخص ذكي.'
                : 'Prevents notification fatigue by bundling excess alerts into a smart digest.',
            style: const TextStyle(color: AppTheme.textMutedDark, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Slider(
            value: prefs.maxPer10Min.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: AppTheme.accentBlue,
            inactiveColor: AppTheme.darkBorderSubtle,
            label: '${prefs.maxPer10Min}',
            onChanged: (val) {
              provider.setNotificationRateLimit(val.round());
            },
          ),
          const Divider(color: AppTheme.darkBorderSubtle, height: 24),

          // 🔔 Granular Notification Category Toggles
          Text(
            isAr
                ? 'أقسام التنبيهات المفعّلة'
                : 'Active Notification Categories',
            style: const TextStyle(
              color: AppTheme.textPrimaryDark,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),

          _buildNotifSwitch(
            title:
                isAr ? '🔴 بثوث الفيديو المباشرة' : '🔴 Live Video Broadcasts',
            value: prefs.liveVideoEnabled,
            onChanged: (val) {
              provider.updateNotificationPreferences(
                prefs.copyWith(liveVideoEnabled: val),
              );
            },
          ),
          _buildNotifSwitch(
            title: isAr
                ? '🎙️ المساحات الصوتية المباشرة'
                : '🎙️ Live Audio Stages',
            value: prefs.liveAudioEnabled,
            onChanged: (val) {
              provider.updateNotificationPreferences(
                prefs.copyWith(liveAudioEnabled: val),
              );
            },
          ),
          _buildNotifSwitch(
            title: isAr
                ? '🌟 مكافأة إتمام ساعة مشاهدة'
                : '🌟 1-Hour Watch Milestone Rewards',
            value: prefs.watchMilestonesEnabled,
            onChanged: (val) {
              provider.updateNotificationPreferences(
                prefs.copyWith(watchMilestonesEnabled: val),
              );
            },
          ),
          _buildNotifSwitch(
            title: isAr
                ? '🏛️ دعوات المنظمات والمشاركات'
                : '🏛️ Org Invites & Guest Roles',
            value: prefs.orgInvitesEnabled,
            onChanged: (val) {
              provider.updateNotificationPreferences(
                prefs.copyWith(orgInvitesEnabled: val),
              );
            },
          ),
          _buildNotifSwitch(
            title: isAr
                ? '📩 الرسائل والتوجيهات الإدارية'
                : '📩 Administrative Governance Notes',
            value: prefs.adminNotesEnabled,
            onChanged: (val) {
              provider.updateNotificationPreferences(
                prefs.copyWith(adminNotesEnabled: val),
              );
            },
          ),
          _buildNotifSwitch(
            title: isAr
                ? '🎬 المحاضرات والفيديوهات الجديدة'
                : '🎬 New VODs & Lectures',
            value: prefs.vodsEnabled,
            onChanged: (val) {
              provider.updateNotificationPreferences(
                prefs.copyWith(vodsEnabled: val),
              );
            },
          ),

          // 🔕 Muted Streamers / Organizations List
          if (mutedIds.isNotEmpty) ...[
            const Divider(color: AppTheme.darkBorderSubtle, height: 24),
            Text(
              isAr
                  ? 'القنوات المكتومة (${mutedIds.length})'
                  : 'Muted Channels (${mutedIds.length})',
              style: const TextStyle(
                color: AppTheme.textPrimaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: mutedIds.map((id) {
                final streamer = provider.getStreamerById(id);
                final name = streamer != null
                    ? streamer.getLocalizedName(isAr ? 'ar' : 'en')
                    : id;
                return Chip(
                  backgroundColor: AppTheme.darkSurface2,
                  label: Text(
                    name,
                    style: const TextStyle(
                        color: AppTheme.textSecondaryDark, fontSize: 11),
                  ),
                  deleteIcon: const Icon(Icons.close_rounded,
                      size: 14, color: AppTheme.accentRed),
                  onDeleted: () {
                    provider.toggleMuteEntity(id);
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotifSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  color: AppTheme.textSecondaryDark, fontSize: 12),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppTheme.accentBlue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    Color iconColor = AppTheme.textSecondaryDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textSecondaryDark,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
