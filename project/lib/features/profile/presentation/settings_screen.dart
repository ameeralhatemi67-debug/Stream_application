import '../../../core/widgets/ds/canopy_lattice_background.dart';
import '../../../core/widgets/safe_image_provider.dart';
import '../../profile/models/streamer_models.dart';
import '../../../core/widgets/ds/ca_cards.dart';
import '../../../core/widgets/ds/ca_fields.dart';
import '../../../core/layout/window_class.dart';
import '../../../core/widgets/ds/ca_rows.dart';
import '../../../core/widgets/ds/ca_icon.dart';
import '../../../core/widgets/ds/ca_surfaces.dart';
import '../../../core/widgets/ds/ca_navigation.dart';

import 'settings/notification_settings_section.dart';
import 'settings/legal_settings_section.dart';
import 'settings/application_settings_section.dart';
import 'settings/broadcasting_settings_section.dart';
import 'settings/privacy_settings_section.dart';
import 'settings/about_settings_section.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/widgets/language_switcher.dart';
import '../models/user_account_model.dart';
import '../../admin/models/broadcaster_application_model.dart';
import '../../admin/models/terms_and_conditions_model.dart';
import '../../../core/services/notifications/notification_models.dart';
import 'settings/blocked_accounts_sheet.dart';
import 'widgets/broadcaster_application_sheet.dart';
import 'widgets/custom_stream_cards_section.dart';
import 'widgets/viewer_profile_editor_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _desktopSection = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppProvider>().refreshMyApplicationAndStreamerStatus();
      }
    });
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
    // Falls back to the signed-in account's own name/email, never to a
    // default fixture profile (P1.6): an account with no name yet shows no
    // handle rather than someone else's.
    final source = profile.nameEn.isNotEmpty
        ? profile.nameEn
        : (provider.googleUserName ??
            provider.googleUserEmail?.split('@').first ??
            '');
    final slug = source.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return slug.isEmpty ? '' : '@$slug';
  }

  @override
  Widget build(BuildContext context) {
    // context.read for the instance the many _build* helpers below need (they
    // call mutation methods like setRoleMode/signOut/loginWithGoogle directly
    // on it). context.select registers this screen's rebuild dependency on
    // exactly the fields those helpers read -- context.watch<AppProvider>()
    // previously rebuilt this whole multi-section screen on ANY AppProvider
    // change anywhere in the app (map streamers, other users'notifications,
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
          bool isApprovedStreamer,
          BroadcasterApplicationModel? myApplication,
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
          // Approval and revocation must re-render this page immediately.
          isApprovedStreamer: p.isApprovedStreamer,
          myApplication: p.myApplication,
        ));
    final currentLocale = context.locale.languageCode;
    final isAr = currentLocale == 'ar';
    final isStreamer = appProvider.isStreamerModeEnabled;

    return Scaffold(
      backgroundColor: Canopy.dawn,
      appBar: CaAppBar(
        title: Text('settings.title'.tr()),
        backgroundColor: Canopy.dawn,
        elevation: 0,
        actions: const [
          // Icon only, without a pill or circle behind it.
          LanguageSwitcher(showLabel: false, canopy: true, bare: true),
          SizedBox(width: AppTheme.spaceSm),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= CanopyWindow.expanded && !context.isPhone;
        final personal = <Widget>[
          //  Top Option: My Account Profile (Protected, cannot be deleted)
          _buildUserProfileHeaderCard(context, appProvider),
          const SizedBox(height: AppTheme.spaceLg),

          //  Section 1: Streamer vs. Viewer Role Mode Toggle
          _buildSectionHeader(
            context,
            title: 'settings.role_mode_title'.tr(),
            icon: Icons.switch_account_rounded,
            iconColor: AppTheme.primary,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildRoleModeToggleCard(context, appProvider),
          const SizedBox(height: AppTheme.spaceLg),

          //  Section 1.5: Broadcaster & Organization Verification Application & Live Tracking Banner

          const ApplicationSettingsSection(),
          const SizedBox(height: AppTheme.spaceLg),
          if (appProvider.isLoggedInStreamer || isStreamer) ...[
            CaCard(
                key: const ValueKey('settings-broadcasting-links'),
                child: Column(children: [
                  // Organizations: invitations, memberships, shows and transfers for
                  // every signed-in account, including organization-only presenters.
                  if (appProvider.isLoggedInStreamer) ...[
                    Builder(builder: (context) {
                      final invitations = context.select<AppProvider, int>(
                          (p) => p.myOrganizationInvitations.length);
                      return _buildSummaryRow(
                        icon: CaGlyph.home,
                        title: 'organization_v1.organizations'.tr(),
                        subtitle: invitations > 0
                            ? 'organization_v1.invitations_waiting'
                                .tr(namedArgs: {'count': '$invitations'})
                            : 'organization_v1.organizations_hint'.tr(),
                        onTap: () => context.push('/organizations'),
                      );
                    }),
                  ],

                  // Section 4 (Streamer Only): Broadcaster & Studio Preferences --
                  // summary row opening a dedicated modal sheet (Go Live Studio +
                  // Streaming Quality Defaults, both unchanged, just relocated).
                  if (isStreamer) ...[
                    if (appProvider.isLoggedInStreamer)
                      const Divider(
                          height: CanopySize.stroke, color: Canopy.hairline),
                    _buildSummaryRow(
                      icon: CaGlyph.video,
                      title: 'organization_v1.channels'.tr(),
                      subtitle: 'organization_v1.channel_consent_hint'.tr(),
                      onTap: () => context.push('/channels'),
                    ),
                    const Divider(
                        height: CanopySize.stroke, color: Canopy.hairline),
                    _buildSummaryRow(
                      icon: CaGlyph.sliders,
                      title: 'design_copy.broadcaster_studio_preferences'.tr(),
                      badge: CaStatusChip(
                          key: const ValueKey('settings-broadcast-status'),
                          kind: appProvider.isBroadcastingLive
                              ? CaStatusKind.live
                              : CaStatusKind.offline),
                      onTap: () => _showBroadcasterStudioPreferencesSheet(
                          context, appProvider),
                    ),
                  ],
                ])),
            const SizedBox(height: AppTheme.spaceLg),
          ],
        ];
        final preferences = <Widget>[
          CaCard(
              child: Column(children: [
            // Section 3.5: Notification Preferences -- summary row opening a
            // dedicated modal sheet instead of an always-expanded card.
            _buildSummaryRow(
              icon: CaGlyph.bell,
              title: 'design_copy.notification_preferences'.tr(),
              subtitle: isAr
                  ? '${appProvider.notificationPreferences.maxPer10Min} إشعارات كل 10 دقائق'
                  : '${appProvider.notificationPreferences.maxPer10Min} alerts / 10min',
              onTap: () =>
                  _showNotificationPreferencesSheet(context, appProvider),
            ),
            const Divider(height: CanopySize.stroke, color: Canopy.hairline),

            // Section 3.6: Chat blocks, server-owned and shared across devices.
            _buildSummaryRow(
              icon: CaGlyph.shield,
              title: 'settings.blocked_accounts_title'.tr(),
              subtitle: 'settings.blocked_accounts_hint'.tr(),
              onTap: () => BlockedAccountsSheet.show(context),
            ),
          ])),
          const SizedBox(height: AppTheme.spaceLg),
        ];
        final privacy = <Widget>[
          if (appProvider.isLoggedInStreamer) ...[
            const PrivacySettingsSection(privacyOnly: true),
            const SizedBox(height: AppTheme.spaceLg)
          ],
        ];
        final governance = <Widget>[
          // Section 6: Platform Governance, Terms & Privacy
          _buildSectionHeader(
            context,
            title: 'settings.governance_legal'.tr(),
            icon: Icons.gavel_rounded,
            iconColor: AppTheme.primary,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          const LegalSettingsSection(),
          const SizedBox(height: AppTheme.spaceLg),

          // Section 4.5 (Org Owner/Co-Owner Only): Organization Management
          if (appProvider.isPermittedAdmin) ...[
            _buildOrgManagementShortcutCard(context),
            const SizedBox(height: AppTheme.spaceLg),
          ],

          // Section 4.6 (Admin/Master Admin Only): Admin Hub Shortcut
          if (appProvider.isAdminUser) ...[
            _buildAdminHubShortcutCard(context),
            const SizedBox(height: AppTheme.spaceLg),
          ],
        ];
        final about = <Widget>[
          // Section 7: About

          const AboutSettingsSection(),
          _buildIntroAction(context),
          if (MediaQuery.sizeOf(context).width < 900)
            Center(
              child: Semantics(
                label: 'common.hadayah_charity'.tr(),
                child: Image.asset(
                  'assets/images/hadayah_charity_parent.png',
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ];
        final accountData = <Widget>[
          // Section 6.5: Account & Data (Delete Account) -- baseline for
          // every signed-in account (v0.9 Checkpoint 2 Phase 1); nothing to
          // delete for a guest viewer who never signed in.
          if (appProvider.isLoggedInStreamer) ...[
            _buildSectionHeader(
              context,
              title: 'settings.danger_zone'.tr(),
              icon: Icons.warning_amber_rounded,
              iconColor: AppTheme.primary,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            if (appProvider.isLoggedInStreamer &&
                appProvider.isStreamerModeEnabled &&
                appProvider.isApprovedStreamer)
              _buildSignOutActions(context, appProvider),
            const PrivacySettingsSection(dangerOnly: true),
            const SizedBox(height: AppTheme.spaceLg),
          ],

          const SizedBox(height: AppTheme.spaceXl),
        ];
        if (wide) {
          final sections =
              <({String label, CaGlyph icon, List<Widget> children})>[
            (
              label: 'settings.desktop_account'.tr(),
              icon: CaGlyph.user,
              children: personal.skip(2).toList()
            ),
            (
              label: 'nav.notifications'.tr(),
              icon: CaGlyph.bell,
              children: preferences
            ),
            if (appProvider.isLoggedInStreamer)
              (
                label: 'settings.desktop_privacy'.tr(),
                icon: CaGlyph.shield,
                children: [...privacy, ...accountData]
              ),
            (
              label: 'settings.desktop_legal'.tr(),
              icon: CaGlyph.scale,
              children: governance
            ),
            (
              label: 'settings.desktop_about'.tr(),
              icon: CaGlyph.info,
              children: about
            ),
          ];
          final selected = _desktopSection.clamp(0, sections.length - 1);
          return Center(
              child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: CanopySize.settingsMax),
                  child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceXl),
                      child: Column(children: [
                        _buildUserProfileHeaderCard(context, appProvider),
                        const SizedBox(height: AppTheme.spaceXl),
                        Expanded(
                            child: Row(
                                key: const ValueKey(
                                    'settings-desktop-workspace'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              SizedBox(
                                  width: CanopySize.railExpanded,
                                  child: ListView(children: [
                                    for (var i = 0; i < sections.length; i++)
                                      Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: AppTheme.spaceSm),
                                          child: ListTile(
                                              key: ValueKey(
                                                  'settings-category-$i'),
                                              selected: selected == i,
                                              selectedTileColor: Canopy.mint,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          CanopyRadius.input)),
                                              leading: CaIcon(sections[i].icon),
                                              title: Text(sections[i].label),
                                              onTap: () => setState(
                                                  () => _desktopSection = i))),
                                  ])),
                              const SizedBox(width: AppTheme.spaceXl),
                              Expanded(
                                  child: ListView(
                                      key: ValueKey(
                                          'settings-content-$selected'),
                                      padding: const EdgeInsets.only(
                                          bottom: AppTheme.spaceLg),
                                      children: sections[selected].children)),
                            ])),
                      ]))));
        }
        return Center(
            child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: CanopySize.settingsMax),
                child: ListView(
                    padding: const EdgeInsets.all(AppTheme.spaceLg),
                    children: [
                      ...personal,
                      ...preferences,
                      ...privacy,
                      ...governance,
                      ...about,
                      ...accountData
                    ])));
      }),
    );
  }

  Widget _buildUserProfileHeaderCard(
      BuildContext context, AppProvider provider) {
    final profile = provider.userProfile;
    final isAr = context.locale.languageCode == 'ar';
    final isStreamerCard = provider.isApprovedStreamer;
    final email =
        provider.googleUserEmail ?? 'settings.guest_not_signed_in'.tr();
    final handle = isStreamerCard ? _displayHandle(provider, profile) : '';
    final identity = Row(children: [
      CaAvatar(
          name: isAr ? profile.nameAr : profile.nameEn,
          url: profile.avatarUrl,
          // Broadcaster and organization accounts wear the identity ring, and
          // the spinning live ring while they are on air.
          ring: isStreamerCard ? CaAvatarRing.brand : CaAvatarRing.none,
          live: isStreamerCard && provider.isBroadcastingLive,
          verified: profile.isVerifiedScholar),
      const SizedBox(width: AppTheme.spaceMd),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isAr ? profile.nameAr : profile.nameEn,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Canopy.paper)),
        if (handle.isNotEmpty)
          Text(handle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Canopy.paper)),
        Text(email,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Canopy.paper)),
        const SizedBox(height: AppTheme.spaceSm),
        CaStatusChip(
            kind: CaStatusKind.offline,
            label: isStreamerCard
                ? 'organization_v1.broadcaster'.tr()
                : 'settings.viewer_badge'.tr()),
      ])),
    ]);
    final edit = OutlinedButton.icon(
      icon: const Icon(Icons.edit_outlined),
      label: Text('settings.edit_profile'.tr()),
      style: OutlinedButton.styleFrom(
          foregroundColor: Canopy.paper,
          side: const BorderSide(color: Canopy.paper)),
      onPressed: () {
        // "Edit Profile"must never open the broadcaster onboarding
        // flow for a non-verified viewer -- issue_log.md: "clicking
        // 'Edit account Profile'as a non verified streamer should
        // not be an option, as it opened the streamer onboarding."
        // The broadcaster application flow stays reachable strictly
        // via the dedicated "Apply for Verification"card/button.
        if (provider.isApprovedStreamer) {
          BroadcasterApplicationSheet.show(
            context,
            application: provider.myApplication,
            editingProfile: true,
          );
        } else {
          ViewerProfileEditorDialog.show(context);
        }
      },
    );
    // The account card shows the user's own banner; without one it keeps the
    // Canopy lattice. A scrim keeps the white identity text readable on any
    // photo.
    final banner = (isStreamerCard
            ? provider.currentBroadcasterStreamer.bannerUrl
            : profile.bannerUrl)
        .trim();
    Widget backdrop(Widget child) => banner.isEmpty
        ? DecoratedBox(
            decoration: const BoxDecoration(gradient: CanopyGradients.panel),
            child: CanopyLatticeBackground(
                gradient: false,
                child: ColoredBox(
                    color: CanopyGradients.entryTextScrim, child: child)))
        : DecoratedBox(
            decoration: BoxDecoration(
                color: Canopy.forestDeep,
                image: DecorationImage(
                    image: downscaledImage(buildSafeImageProvider(path: banner),
                        width: 1200),
                    fit: BoxFit.cover,
                    onError: (_, __) {})),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                      Canopy.forestDeep.withValues(alpha: .45),
                      Canopy.forestDeep.withValues(alpha: .82),
                    ])),
                child: child));
    return CaCard(
        key: const ValueKey('settings-account-panel'),
        padding: EdgeInsets.zero,
        variant: CaCardVariant.feature,
        child: backdrop(Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceLg),
                    child: LayoutBuilder(builder: (context, constraints) {
                      if (constraints.maxWidth >= CanopyWindow.expanded &&
                          !context.isPhone &&
                          MediaQuery.textScalerOf(context).scale(1) < 1.3) {
                        return Row(children: [
                          Expanded(child: identity),
                          const SizedBox(width: AppTheme.spaceLg),
                          edit
                        ]);
                      }
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            identity,
                            const SizedBox(height: AppTheme.spaceMd),
                            edit
                          ]);
                    }))));
  }

  Widget _buildRoleModeToggleCard(BuildContext context, AppProvider provider) {
    final isApproved = provider.isApprovedStreamer;
    final isStreamer = provider.isStreamerModeEnabled && isApproved;
    final isLoggedIn = provider.isLoggedInStreamer;

    return CaCard(
      key: const ValueKey('settings-role-mode-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  isStreamer
                      ? Icons.videocam_rounded
                      : Icons.visibility_rounded,
                  color: AppTheme.primary,
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
                        color: Canopy.ink,
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
                          : ('design_copy.viewer_mode_streamer_studio_unlocked_upon_broadcaster_verificatio'
                              .tr()),
                      style: const TextStyle(
                        color: Canopy.slate,
                        fontSize: AppTheme.captionFont,
                      ),
                    ),
                  ],
                ),
              ),
              CaSwitch(
                value: isStreamer,
                onChanged: isApproved
                    ? (val) {
                        provider.setRoleMode(val);
                      }
                    : null,
              ),
            ],
          ),

          // The hairline only separates a following action; a signed-in
          // broadcaster has none, so no empty divider block is drawn.
          if (!isLoggedIn || !isStreamer) ...[
            const SizedBox(height: AppTheme.spaceMd),
            const Divider(color: Canopy.hairline, height: 1),
            const SizedBox(height: AppTheme.spaceMd),
          ],

          // Google Account Status / Action
          if (isLoggedIn && !isStreamer) ...[
            Text('broadcast_approval_required'.tr()),
            TextButton(
              // Push, so Back returns to Settings. Only a pending application
              // shows the waiting screen; a rejected or revoked one reapplies
              // (P6-R09: go() replaced the stack and left no way back).
              onPressed: () => context.push(
                  provider.myApplication?.status == ApplicationStatus.pending
                      ? '/application-pending'
                      : '/streamer-apply'),
              child: Text('role_select.streamer_btn'.tr()),
            ),
          ] else if (!isLoggedIn) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.onMedia,
                  foregroundColor: Canopy.ink,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.onMedia,
                  ),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                label: Text('settings.signin_as_streamer'.tr()),
                onPressed: () async {
                  // Only the browser opens here; sign-in completes (or is
                  // refused) later, so nothing may claim success yet.
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await provider.loginWithGoogle();
                    messenger.showSnackBar(SnackBar(
                        content: Text('settings.opening_google_sign_in'.tr())));
                  } catch (_) {
                    messenger.showSnackBar(SnackBar(
                      content: Text('auth_welcome.sign_in_failed'.tr()),
                      backgroundColor: Canopy.liveCrimson,
                    ));
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignOutActions(BuildContext context, AppProvider provider) =>
      CaCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Canopy.slate,
              side: const BorderSide(color: Canopy.hairline),
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
        TextButton.icon(
          icon: const Icon(Icons.devices_other),
          label: Text('sign_out_other_devices'.tr()),
          onPressed: () async {
            try {
              await provider.signOutOtherDevices();
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('broadcast_state_failed'.tr())));
              }
            }
          },
        ),
      ]));

  Widget _buildIntroAction(BuildContext context) => Column(children: [
        const SizedBox(height: AppTheme.spaceSm),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: Text('settings.reopen_onboarding'.tr()),
            onPressed: () {
              context.push('/onboarding');
            },
          ),
        ),
      ]);

  Widget _buildOrgManagementShortcutCard(BuildContext context) => CaSettingsRow(
      title: 'settings.org_management_title'.tr(),
      subtitle: 'settings.org_management_desc'.tr(),
      icon: CaGlyph.users,
      trailing: const RotatedBox(quarterTurns: 2, child: CaIcon(CaGlyph.back)),
      onTap: () => context.push('/org-admin'));

  Widget _buildAdminHubShortcutCard(BuildContext context) => CaSettingsRow(
      title: 'settings.admin_hub_title'.tr(),
      subtitle: 'settings.admin_hub_desc'.tr(),
      icon: CaGlyph.globe,
      trailing: const RotatedBox(quarterTurns: 2, child: CaIcon(CaGlyph.back)),
      onTap: () => context.push('/admin'));

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    Color iconColor = Canopy.slate,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
          title,
          style: const TextStyle(
            color: Canopy.slate,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        )),
      ],
    );
  }

  /// Tappable summary row that opens a dedicated modal sheet -- styled like
  /// the existing governance rows, reused for Notification Preferences and
  /// Broadcaster & Studio Preferences so those sections declutter the flat
  /// ListView without duplicating any of their (already functional) bodies.
  Widget _buildSummaryRow({
    required CaGlyph icon,
    required String title,
    String? subtitle,
    Widget? badge,
    required VoidCallback onTap,
  }) =>
      CaSettingsRow(
          title: title,
          subtitle: subtitle,
          badge: badge,
          icon: icon,
          trailing:
              const RotatedBox(quarterTurns: 2, child: CaIcon(CaGlyph.back)),
          onTap: onTap);

  void _showModalSheet(BuildContext context, Widget child, String title) {
    showCaSheet<void>(context, title: title, body: child);
  }

  void _showNotificationPreferencesSheet(
      BuildContext context, AppProvider provider) {
    _showModalSheet(
      context,
      const NotificationSettingsSection(),
      'design_copy.notification_preferences'.tr(),
    );
  }

  void _showBroadcasterStudioPreferencesSheet(
      BuildContext context, AppProvider provider) {
    _showModalSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BroadcastingSettingsSection(),
          const SizedBox(height: AppTheme.spaceMd),
          _buildCustomStreamCardsEntry(context),
        ],
      ),
      'design_copy.broadcaster_studio_preferences'.tr(),
    );
  }

  /// Cluster 1 Task 4b -- the streamer's own way into the custom stream-card
  /// slots. StreamerEditorSheet also hosts them, but that sheet is only
  /// reachable from the Admin Hub, so without this entry point a broadcaster
  /// who is not also an admin could never upload a card.
  Widget _buildCustomStreamCardsEntry(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Canopy.hairline),
      ),
      child: ListTile(
        leading: const Icon(Icons.photo_library_rounded,
            color: AppTheme.primary, size: 20),
        title: Text(
          'settings.custom_cards_section'.tr(),
          style: const TextStyle(
            color: Canopy.ink,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'settings.custom_cards_desc'.tr(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Canopy.slate, fontSize: AppTheme.captionFont),
        ),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: Canopy.haze, size: 20),
        onTap: () => CustomStreamCardsSection.show(context),
      ),
    );
  }
}
