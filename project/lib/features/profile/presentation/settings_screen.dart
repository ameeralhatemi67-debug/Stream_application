import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/widgets/language_switcher.dart';
import '../../../core/widgets/safe_image_provider.dart';
import '../../profile/models/streamer_models.dart';
import '../models/user_account_model.dart';
import '../../admin/models/broadcaster_application_model.dart';
import '../../admin/models/terms_and_conditions_model.dart';
import '../../../core/services/notifications/notification_models.dart';
import 'widgets/broadcaster_application_sheet.dart';
import 'widgets/custom_stream_cards_section.dart';
import 'widgets/legal_document_reader_screen.dart';
import 'widgets/viewer_profile_editor_dialog.dart';

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
  bool _isDeletingAccount = false;
  bool _isExportingData = false;
  bool _isDeletingAllMessages = false;
  bool _isDeletingStreamMessages = false;

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

  /// Public @handle shown on the streamer profile card. Derived from the
  /// broadcaster application's youtubeHandle (collected in the verification
  /// wizard's step 3) rather than a dedicated UserProfileModel field, since
  /// that data already exists one hop away via provider.myApplication.
  String _displayHandle(AppProvider provider, UserProfileModel profile) {
    final fromApp = provider.myApplication?.youtubeHandle.trim();
    if (fromApp != null && fromApp.isNotEmpty) {
      return fromApp.startsWith('@') ? fromApp : '@$fromApp';
    }
    final slug =
        profile.nameEn.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return '@${slug.isEmpty ? profile.id : slug}';
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
          bool isPermittedAdmin,
          bool isAdminUser,
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
          isPermittedAdmin: p.isPermittedAdmin,
          isAdminUser: p.isAdminUser,
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
        actions: const [
          LanguageSwitcher(showLabel: false),
          SizedBox(width: AppTheme.spaceSm),
        ],
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

          // Section 3: Language Preference
          _buildSectionHeader(
            context,
            title: 'settings.language'.tr(),
            icon: Icons.language_rounded,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildLanguageSelectorCard(context, currentLocale),
          const SizedBox(height: AppTheme.spaceLg),

          // Section 3.5: Notification Preferences -- summary row opening a
          // dedicated modal sheet instead of an always-expanded card.
          _buildSummaryRow(
            icon: Icons.notifications_active_rounded,
            iconColor: AppTheme.accentBlue,
            title: isAr
                ? 'إعدادات الإشعارات والتنبيهات'
                : 'Notification Preferences',
            subtitle: isAr
                ? '${appProvider.notificationPreferences.maxPer10Min} إشعارات كل 10 دقائق'
                : '${appProvider.notificationPreferences.maxPer10Min} alerts / 10min',
            onTap: () =>
                _showNotificationPreferencesSheet(context, appProvider),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // Section 4 (Streamer Only): Broadcaster & Studio Preferences --
          // summary row opening a dedicated modal sheet (Go Live Studio +
          // Streaming Quality Defaults, both unchanged, just relocated).
          if (isStreamer) ...[
            _buildSummaryRow(
              icon: Icons.movie_creation_rounded,
              iconColor: AppTheme.accentRed,
              title: isAr
                  ? 'تفضيلات الاستوديو والبث'
                  : 'Broadcaster & Studio Preferences',
              subtitle: appProvider.isBroadcastingLive
                  ? 'settings.broadcast_status_live'.tr()
                  : 'settings.broadcast_status_offline'.tr(),
              onTap: () =>
                  _showBroadcasterStudioPreferencesSheet(context, appProvider),
            ),
            const SizedBox(height: AppTheme.spaceMd),
          ],

          // Section 4.5 (Org Owner/Co-Owner Only): Organization Management
          if (appProvider.isPermittedAdmin) ...[
            _buildSectionHeader(
              context,
              title: 'settings.org_management_title'.tr(),
              icon: Icons.apartment_rounded,
              iconColor: AppTheme.accentAmber,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            _buildOrgManagementShortcutCard(context),
            const SizedBox(height: AppTheme.spaceLg),
          ],

          // Section 4.6 (Admin/Master Admin Only): Admin Hub Shortcut
          if (appProvider.isAdminUser) ...[
            _buildSectionHeader(
              context,
              title: 'settings.admin_hub_title'.tr(),
              icon: Icons.admin_panel_settings_rounded,
              iconColor: AppTheme.accentPurple,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            _buildAdminHubShortcutCard(context),
            const SizedBox(height: AppTheme.spaceLg),
          ],

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

          // Section 6.5: Account & Data (Delete Account) -- baseline for
          // every signed-in account (v0.9 Checkpoint 2 Phase 1); nothing to
          // delete for a guest viewer who never signed in.
          if (appProvider.isLoggedInStreamer) ...[
            _buildSectionHeader(
              context,
              title: 'settings.danger_zone'.tr(),
              icon: Icons.warning_amber_rounded,
              iconColor: AppTheme.accentRed,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            _buildDataExportCard(context, appProvider),
            const SizedBox(height: AppTheme.spaceMd),
            _buildChatHistoryCard(context, appProvider),
            const SizedBox(height: AppTheme.spaceMd),
            _buildDeleteAccountCard(context, appProvider),
            const SizedBox(height: AppTheme.spaceLg),
          ],

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
    final isAr = context.locale.languageCode == 'ar';
    final isStreamerCard = provider.isApprovedStreamer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        isStreamerCard
            ? _buildStreamerProfileCard(context, provider, isAr)
            : _buildViewerProfileCard(context, provider, isAr),
        const SizedBox(height: AppTheme.spaceSm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: Text('settings.edit_profile'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimaryDark,
              side: const BorderSide(color: AppTheme.darkBorderSubtle),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            onPressed: () {
              // "Edit Profile" must never open the broadcaster onboarding
              // flow for a non-verified viewer -- issue_log.md: "clicking
              // 'Edit account Profile' as a non verified streamer should
              // not be an option, as it opened the streamer onboarding."
              // The broadcaster application flow stays reachable strictly
              // via the dedicated "Apply for Verification" card/button.
              if (provider.isApprovedStreamer) {
                BroadcasterApplicationSheet.show(
                  context,
                  application: provider.myApplication,
                );
              } else {
                ViewerProfileEditorDialog.show(context);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildViewerProfileCard(
      BuildContext context, AppProvider provider, bool isAr) {
    final profile = provider.userProfile;
    final email = provider.googleUserEmail ?? 'settings.guest_not_signed_in'.tr();

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
            radius: 24,
            backgroundImage: buildSafeImageProvider(path: profile.avatarUrl),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? profile.nameAr : profile.nameEn,
                  style: const TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(
                      color: AppTheme.textSecondaryDark, fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border:
                  Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_rounded,
                    color: AppTheme.accentBlue, size: 13),
                const SizedBox(width: 4),
                Text(
                  'settings.viewer_badge'.tr(),
                  style: const TextStyle(
                    color: AppTheme.accentBlue,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamerProfileCard(
      BuildContext context, AppProvider provider, bool isAr) {
    final profile = provider.userProfile;
    final handle = _displayHandle(provider, profile);
    final email = provider.googleUserEmail ?? provider.myApplication?.email ?? '';
    const bannerHeight = 96.0;
    const avatarRadius = 36.0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Column(
                children: [
                  Container(
                    height: bannerHeight,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.accentBlue, AppTheme.accentPurple],
                      ),
                    ),
                    child: Image(
                      image: buildSafeImageProvider(path: profile.bannerUrl),
                      height: bannerHeight,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: avatarRadius),
                ],
              ),
              Positioned(
                top: bannerHeight - avatarRadius,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppTheme.darkSurface1,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: avatarRadius,
                        backgroundImage:
                            buildSafeImageProvider(path: profile.avatarUrl),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppTheme.darkSurface1,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_rounded,
                            color: AppTheme.accentGreen, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg,
                AppTheme.spaceSm, AppTheme.spaceLg, AppTheme.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  isAr ? profile.nameAr : profile.nameEn,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  handle,
                  style: const TextStyle(
                      color: AppTheme.accentBlue, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  isAr ? profile.organizationAr : profile.organizationEn,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textSecondaryDark, fontSize: 11.5),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(
                        color: AppTheme.textMutedDark, fontSize: 11),
                  ),
                ],
                if ((isAr ? profile.bioAr : profile.bioEn).isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spaceSm),
                  Text(
                    isAr ? profile.bioAr : profile.bioEn,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondaryDark,
                        fontSize: 11.5,
                        height: 1.4),
                  ),
                ],
              ],
            ),
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
          // A single "Edit"/"Reapply" action only -- no parallel "New
          // Application" button. An account is strictly limited to one
          // personal broadcaster channel (issue_log.md: "I should not have
          // the ability to own two channels"); an existing application
          // (pending, approved, or rejected) is always edited in place.
          SizedBox(
            width: double.infinity,
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
      padding: const EdgeInsets.all(AppTheme.spaceLg),
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

  Widget _buildOrgManagementShortcutCard(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/org-admin'),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border:
              Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Icon(Icons.apartment_rounded,
                  color: AppTheme.accentAmber, size: 22),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.org_management_title'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'settings.org_management_desc'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondaryDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminHubShortcutCard(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/admin'),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border:
              Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  color: AppTheme.accentPurple, size: 22),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.admin_hub_title'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'settings.admin_hub_desc'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondaryDark),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
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
      padding: const EdgeInsets.all(AppTheme.spaceLg),
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
            onTap: () => _openLegalReader(context, terms, 0),
          ),
          const Divider(height: 16, color: AppTheme.darkBorderSubtle),
          _buildGovernanceRow(
            icon: Icons.verified_user_rounded,
            title: 'settings.view_guidelines'.tr(),
            subtitle: 'Academic integrity & broadcast standards',
            onTap: () => _openLegalReader(context, terms, 1),
          ),
          const Divider(height: 16, color: AppTheme.darkBorderSubtle),
          _buildGovernanceRow(
            icon: Icons.privacy_tip_rounded,
            title: 'settings.view_privacy'.tr(),
            subtitle: 'PDPL KSA Regulatory Compliance',
            onTap: () => _openLegalReader(context, terms, 2),
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

  void _openLegalReader(
      BuildContext context, TermsAndConditionsModel terms, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentReaderScreen(
          terms: terms,
          initialDocumentIndex: index,
        ),
      ),
    );
  }

  Widget _buildDataExportCard(BuildContext context, AppProvider provider) {
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
          Text(
            'settings.data_export_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimaryDark,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'settings.data_export_desc'.tr(),
            style: const TextStyle(
                color: AppTheme.textSecondaryDark, fontSize: 11),
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
                        color: AppTheme.accentBlue,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text('settings.data_export_btn'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentBlue,
                side: const BorderSide(color: AppTheme.accentBlue),
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
          backgroundColor: AppTheme.accentRed,
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
          backgroundColor: AppTheme.darkSurface1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: const BorderSide(color: AppTheme.darkBorderSubtle),
          ),
          title: Text(
            'settings.data_export_dialog_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimaryDark,
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
                      color: AppTheme.textSecondaryDark, fontSize: 12),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Container(
                  constraints: const BoxConstraints(maxHeight: 360),
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface2,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.darkBorderSubtle),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonText,
                      style: const TextStyle(
                        color: AppTheme.textSecondaryDark,
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
                style: const TextStyle(color: AppTheme.textMutedDark),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
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
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.delete_account_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimaryDark,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'settings.delete_account_desc'.tr(),
            style: const TextStyle(
                color: AppTheme.textSecondaryDark, fontSize: 11),
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
                        color: AppTheme.accentRed,
                      ),
                    )
                  : const Icon(Icons.delete_forever_rounded, size: 18),
              label: Text('settings.delete_account_btn'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentRed,
                side: const BorderSide(color: AppTheme.accentRed),
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
          backgroundColor: AppTheme.darkSurface1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: const BorderSide(color: AppTheme.darkBorderSubtle),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.accentRed, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'settings.delete_account_confirm_title'.tr(),
                  style: const TextStyle(
                    color: AppTheme.textPrimaryDark,
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
                color: AppTheme.textSecondaryDark, fontSize: 13),
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
          backgroundColor: AppTheme.accentRed,
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
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.chat_history_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimaryDark,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'settings.chat_history_desc'.tr(),
            style:
                const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 11),
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
                          strokeWidth: 2, color: AppTheme.accentBlue),
                    )
                  : const Icon(Icons.forum_outlined, size: 18),
              label: Text('settings.delete_messages_by_stream_btn'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentBlue,
                side: const BorderSide(color: AppTheme.accentBlue),
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
                          strokeWidth: 2, color: AppTheme.accentRed),
                    )
                  : const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text('settings.delete_all_messages_btn'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentRed,
                side: const BorderSide(color: AppTheme.accentRed),
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

  void _showDeleteAllMessagesDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: AppTheme.darkBorderSubtle),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.accentRed, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'settings.delete_all_messages_confirm_title'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'settings.delete_all_messages_confirm_body'.tr(),
          style: const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('settings.cancel'.tr(),
                style: const TextStyle(color: AppTheme.textMutedDark)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed, foregroundColor: Colors.white),
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
        backgroundColor: success ? null : AppTheme.accentRed,
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
        backgroundColor: AppTheme.darkSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: AppTheme.darkBorderSubtle),
        ),
        title: Text('settings.select_stream_dialog_title'.tr(),
            style: const TextStyle(
                color: AppTheme.textPrimaryDark, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: streamIds.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: Text(
                    'settings.select_stream_dialog_empty'.tr(),
                    style: const TextStyle(color: AppTheme.textSecondaryDark),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: streamIds.length,
                  itemBuilder: (context, index) {
                    final id = streamIds[index];
                    return ListTile(
                      leading: const Icon(Icons.forum_outlined,
                          color: AppTheme.accentBlue),
                      title: Text(id,
                          style: const TextStyle(color: AppTheme.textPrimaryDark)),
                      onTap: () => Navigator.pop(dialogContext, id),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('settings.cancel'.tr(),
                style: const TextStyle(color: AppTheme.textMutedDark)),
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
        backgroundColor: success ? null : AppTheme.accentRed,
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

  /// Tappable summary row that opens a dedicated modal sheet -- styled like
  /// the existing governance rows, reused for Notification Preferences and
  /// Broadcaster & Studio Preferences so those sections declutter the flat
  /// ListView without duplicating any of their (already functional) bodies.
  Widget _buildSummaryRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = AppTheme.accentBlue,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.darkBorderSubtle),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondaryDark),
          ],
        ),
      ),
    );
  }

  void _showModalSheet(BuildContext context, Widget child) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: child,
        ),
      ),
    );
  }

  void _showNotificationPreferencesSheet(
      BuildContext context, AppProvider provider) {
    _showModalSheet(
      context,
      _buildNotificationPreferencesCard(context, provider),
    );
  }

  void _showBroadcasterStudioPreferencesSheet(
      BuildContext context, AppProvider provider) {
    _showModalSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStreamerStudioCard(context, provider),
          const SizedBox(height: AppTheme.spaceMd),
          _buildStreamingQualityCard(context, provider),
          const SizedBox(height: AppTheme.spaceMd),
          _buildCustomStreamCardsEntry(context),
        ],
      ),
    );
  }

  /// Cluster 1 Task 4b -- the streamer's own way into the custom stream-card
  /// slots. StreamerEditorSheet also hosts them, but that sheet is only
  /// reachable from the Admin Hub, so without this entry point a broadcaster
  /// who is not also an admin could never upload a card.
  Widget _buildCustomStreamCardsEntry(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: ListTile(
        leading: const Icon(Icons.photo_library_rounded,
            color: AppTheme.accentBlue, size: 20),
        title: Text(
          'settings.custom_cards_section'.tr(),
          style: const TextStyle(
            color: AppTheme.textPrimaryDark,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'settings.custom_cards_desc'.tr(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: AppTheme.textSecondaryDark, fontSize: 11),
        ),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppTheme.textMutedDark, size: 20),
        onTap: () => CustomStreamCardsSection.show(context),
      ),
    );
  }
}
