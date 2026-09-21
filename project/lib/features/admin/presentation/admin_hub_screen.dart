import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../profile/presentation/widgets/streamer_editor_sheet.dart';
import 'widgets/org_management_view.dart';
import '../models/broadcaster_application_model.dart';
import '../models/terms_and_conditions_model.dart';
import '../models/viewer_analytics_model.dart';
import '../models/chat_report_model.dart';
import '../models/tag_moderation_model.dart';
import '../../profile/models/streamer_models.dart';
import 'widgets/role_permission_management_view.dart';
import 'widgets/chat_moderation_view.dart';
import 'widgets/custom_placeholder_review_view.dart';
import 'widgets/academic_categories_view.dart';
import 'widgets/tag_moderation_view.dart';
import 'widgets/banned_accounts_view.dart';
import '../../../../core/widgets/safe_image_provider.dart';

/// Desktop Admin Moderation & Platform Governance Hub Screen
class AdminHubScreen extends StatefulWidget {
  const AdminHubScreen({super.key});

  @override
  State<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends State<AdminHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  // Decided once in initState from the role known at navigation time (Admin
  // Hub is only reachable after sign-in already resolved is_master_admin(),
  // see AppProvider._refreshAdminRoleFromBackend) -- the tab count can't
  // change out from under a live TabController, so this mirrors whichever
  // value initState used to size it.
  late final bool _isMasterAdminForTabs;

  // Search & Filter Controllers
  final TextEditingController _appSearchController = TextEditingController();
  final TextEditingController _streamerSearchController =
      TextEditingController();
  ApplicationStatus? _applicationFilter;
  String _streamerTypeFilter = 'all';

  // Verification Queue Batch Selection (v0.8 Checkpoint 2 Phase 2) -- only
  // pending applications are selectable, since approve/reject only make
  // sense for those.
  final Set<String> _selectedApplicationIds = {};

  // Terms & Conditions Edit Controllers
  late final TextEditingController _termsEnController;
  late final TextEditingController _termsArController;
  late final TextEditingController _guidelinesEnController;
  late final TextEditingController _guidelinesArController;
  late final TextEditingController _privacyEnController;
  late final TextEditingController _privacyArController;

  // Testing Tools / Pitch Director controls (v0.9 Checkpoint 1 Phase 1 --
  // moved here from the general Settings screen; only admin-tier viewers
  // reach this hub at all).
  late final TextEditingController _rtmpIpController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _isMasterAdminForTabs = provider.isMasterAdmin;
    // +1 for the always-present Chat Moderation tab (Checkpoint 4 Phase 1,
    // any admin-tier viewer), +1 for the always-present Testing Tools tab
    // (v0.9 Checkpoint 1 Phase 1), +1 for the always-present Custom Cards
    // review queue (Cluster 1 Task 4b), +3 for the always-present Academic
    // Categories / Tag Moderation / Banned Accounts tabs (Cluster 3 Task
    // 11/12, Cluster 4 Task 16), +1 more for Roles & Permissions when this
    // viewer is also a Master Admin (Checkpoint 2 Phase 3).
    _tabController =
        TabController(length: (_isMasterAdminForTabs ? 12 : 11) + (kDebugMode ? 1 : 0), vsync: this);
    if (_isMasterAdminForTabs) {
      provider.ensureRoleManagementDataLoaded();
      provider.ensureStreamModeratorsLoaded();
    }
    provider.ensureChatReportsLoaded();
    // Loaded here rather than only inside CustomPlaceholderReviewView so the
    // tab's pending-count badge is right before anyone opens that tab --
    // TabBarView builds its children lazily.
    provider.ensureCustomPlaceholdersLoaded();
    provider.ensureAcademicCategoriesLoaded();
    provider.ensureTagsLoaded();
    provider.ensureBannedUsersLoaded();
    provider.refreshAdminData();

    final terms = provider.termsAndConditions;

    _termsEnController = TextEditingController(text: terms.termsOfServiceEn);
    _termsArController = TextEditingController(text: terms.termsOfServiceAr);
    _guidelinesEnController =
        TextEditingController(text: terms.broadcasterGuidelinesEn);
    _guidelinesArController =
        TextEditingController(text: terms.broadcasterGuidelinesAr);
    _privacyEnController = TextEditingController(text: terms.privacyPolicyEn);
    _privacyArController = TextEditingController(text: terms.privacyPolicyAr);

    _rtmpIpController = TextEditingController(text: provider.rtmpLaptopIp);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appSearchController.dispose();
    _streamerSearchController.dispose();
    _termsEnController.dispose();
    _termsArController.dispose();
    _guidelinesEnController.dispose();
    _guidelinesArController.dispose();
    _privacyEnController.dispose();
    _privacyArController.dispose();
    _rtmpIpController.dispose();
    super.dispose();
  }

  void _showSuccessNotification(String message) {
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.success,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: const [
              BoxShadow(
                color: AppTheme.shadow,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: AppTheme.onMedia),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.onMedia,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      displayDuration: const Duration(seconds: 4),
    );
  }

  void _showErrorNotification(String message) {
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.danger,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: const [
              BoxShadow(
                color: AppTheme.shadow,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.onMedia),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.onMedia,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      displayDuration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    // context.read for the instance the many mutation calls elsewhere in this
    // file need (approve/rejectBroadcasterApplication, deleteStreamer, etc.).
    // context.select scopes this screen's rebuild to the fields its tabs
    // (governance, applications, streamers, terms, analytics) actually
    // render -- context.watch<AppProvider>() previously rebuilt this whole
    // multi-tab admin dashboard on ANY AppProvider change platform-wide.
    final provider = context.read<AppProvider>();
    context.select<
        AppProvider,
        ({
          bool isAdminUser,
          bool isMasterAdmin,
          String? googleUserName,
          String? googleUserEmail,
          List<BroadcasterApplicationModel> pendingApplications,
          List<StreamerModel> streamers,
          ViewerAnalyticsModel viewerAnalytics,
          List<BroadcasterApplicationModel> applications,
          TermsAndConditionsModel termsAndConditions,
          List<ChatReportModel> chatReports,
          bool isPitchDirectorModeEnabled,
          String rtmpLaptopIp,
          List<TagModerationModel> allTagsForModeration,
          int bannedUsersCount,
        })>((p) => (
          isAdminUser: p.isAdminUser,
          isMasterAdmin: p.isMasterAdmin,
          googleUserName: p.googleUserName,
          googleUserEmail: p.googleUserEmail,
          pendingApplications: p.pendingApplications,
          streamers: p.streamers,
          viewerAnalytics: p.viewerAnalytics,
          applications: p.applications,
          termsAndConditions: p.termsAndConditions,
          chatReports: p.chatReports,
          isPitchDirectorModeEnabled: p.isPitchDirectorModeEnabled,
          rtmpLaptopIp: p.rtmpLaptopIp,
          allTagsForModeration: p.allTagsForModeration,
          bannedUsersCount: p.bannedUsers.length,
        ));
    final isAr = context.locale.languageCode == 'ar';
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    // Access Guard
    if (!provider.isAdminUser) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.textPrimary),
            onPressed: () => context.go('/feed'),
          ),
          title: Text('design_ui.access_denied'.tr()),
        ),
        body: SingleChildScrollView(child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(AppTheme.spaceXl),
            margin: const EdgeInsets.all(AppTheme.spaceLg),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border:
                  Border.all(color: AppTheme.danger.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gpp_bad_rounded,
                    color: AppTheme.danger, size: 54),
                const SizedBox(height: AppTheme.spaceMd),
                Text('design_ui.admin_access_required'.tr(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Text('design_ui.your_account_does_not_have_admin_or_master_admin_access_ask_a_mas'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLg),
                ElevatedButton(
                  onPressed: () => context.go('/settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onMedia,
                  ),
                  child: Text('design_ui.go_to_account_settings'.tr()),
                ),
              ],
            ),
          ),
        )),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          // Top Admin Header
          _buildAdminHeader(context, provider, isAr, isDesktop,
              isMasterAdmin: provider.isMasterAdmin),

          // Horizontal Navigation Tabs
          _buildTabBar(provider),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(context, provider, isAr),
                _buildVerificationQueueTab(context, provider, isAr),
                _buildStreamersRegistryTab(context, provider, isAr),
                const OrgManagementView(orgId: 'org_dalilk_04'),
                _buildViewerAnalyticsTab(context, provider, isAr),
                _buildTermsGovernanceTab(context, provider, isAr),
                const ChatModerationView(),
                const CustomPlaceholderReviewView(),
                const AcademicCategoriesView(),
                const TagModerationView(),
                const BannedAccountsView(),
                if (kDebugMode) _buildTestingToolsTab(context, provider),
                if (_isMasterAdminForTabs) const RolePermissionManagementView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminHeader(
      BuildContext context, AppProvider provider, bool isAr, bool isDesktop,
      {required bool isMasterAdmin}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceSm),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'common.back'.tr(), onPressed: () => context.go('/feed')),
        const SizedBox(width: AppTheme.spaceSm),
        Expanded(child: Text('admin.title'.tr(),
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium)),
        if (isDesktop) ...[
          const SizedBox(width: AppTheme.spaceLg),
          Flexible(child: Text(provider.googleUserName ?? provider.googleUserEmail ?? '',
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ]),
    );
  }

  Widget _buildTabBar(AppProvider provider) {
    final pendingCount = provider.pendingApplications.length;
    final chatReportsCount = provider.chatReports.length;
    final customCardsCount = provider.pendingCustomPlaceholders.length;
    final pendingTagsCount = provider.allTagsForModeration
        .where((t) => t.status == TagStatus.pending)
        .length;
    final bannedCount = provider.bannedUsers.length;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppTheme.primary,
        indicatorWeight: 3,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: [
          Tab(
            icon: const Icon(Icons.dashboard_rounded, size: 18),
            text: 'admin.tab_overview'.tr(),
          ),
          Tab(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.how_to_reg_rounded, size: 18),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.warning,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            text: 'admin.tab_verification'.tr(),
          ),
          Tab(
            icon: const Icon(Icons.groups_rounded, size: 18),
            text: 'admin.tab_streamers'.tr(),
          ),
          Tab(
            icon: const Icon(Icons.apartment_rounded, size: 18),
            text: 'admin.tab_organizations'.tr(),
          ),
          Tab(
            icon: const Icon(Icons.analytics_rounded, size: 18),
            text: 'admin.tab_viewers'.tr(),
          ),
          Tab(
            icon: const Icon(Icons.gavel_rounded, size: 18),
            text: 'admin.tab_terms'.tr(),
          ),
          Tab(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.report_gmailerrorred_rounded, size: 18),
                if (chatReportsCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$chatReportsCount',
                      style: const TextStyle(
                        color: AppTheme.onMedia,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            text: 'admin.tab_chat_moderation'.tr(),
          ),
          Tab(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image_rounded, size: 18),
                if (customCardsCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.warning,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$customCardsCount',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            text: 'admin.tab_custom_cards'.tr(),
          ),
          Tab(
            icon: const Icon(Icons.category_rounded, size: 18),
            text: 'admin.tab_categories'.tr(),
          ),
          Tab(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sell_rounded, size: 18),
                if (pendingTagsCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.warning,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pendingTagsCount',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            text: 'admin.tab_tags'.tr(),
          ),
          Tab(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off_rounded, size: 18),
                if (bannedCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$bannedCount',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            text: 'admin.tab_banned_accounts'.tr(),
          ),
          if (kDebugMode) Tab(
            icon: const Icon(Icons.science_rounded, size: 18),
            text: 'admin.tab_testing'.tr(),
          ),
          if (_isMasterAdminForTabs)
            Tab(
              icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
              text: 'admin.tab_roles'.tr(),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB: TESTING TOOLS (Pitch Director Mode)
  // ==========================================
  // Moved here from the general Settings screen (v0.9 Checkpoint 1 Phase 1)
  // -- these are demo/dev-only overrides (ADR-005), not something every
  // viewer should see in their personal settings.

  Widget _buildTestingToolsTab(BuildContext context, AppProvider provider) {
    final isPitchActive = provider.isPitchDirectorModeEnabled;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_rounded,
                  color: AppTheme.danger, size: 20),
              const SizedBox(width: 8),
              Text(
                'admin.tab_testing'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: isPitchActive
                    ? AppTheme.danger
                    : AppTheme.border,
                width: isPitchActive ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'settings.pitch_mode'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Switch(
                      value: isPitchActive,
                      activeThumbColor: AppTheme.danger,
                      onChanged: (val) => provider.setPitchDirectorMode(val),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'settings.pitch_mode_desc'.tr(),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                TextField(
                  controller: _rtmpIpController,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'settings.rtmp_ip'.tr(),
                    prefixIcon: const Icon(Icons.wifi_tethering_rounded,
                        color: AppTheme.primary, size: 20),
                  ),
                  onSubmitted: (val) => provider.updateRtmpLaptopIp(val),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.notifications_active_outlined,
                        size: 18),
                    label: Text('settings.trigger_notification'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: const BorderSide(color: AppTheme.danger),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                    onPressed: () =>
                        provider.triggerSimulatedNotification(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: EXECUTIVE OVERVIEW & KPIS
  // ==========================================

  Widget _buildOverviewTab(
      BuildContext context, AppProvider provider, bool isAr) {
    final totalBroadcasters = provider.streamers.length;
    final verifiedScholars =
        provider.streamers.where((s) => !s.isOrganization).length;
    final orgVenues = provider.streamers.where((s) => s.isOrganization).length;
    final pendingApps = provider.pendingApplications.length;
    final totalAuditoriumSeats = provider.viewerAnalytics.totalAuditoriumRsvps;
    final activeViewers = provider.viewerAnalytics.totalGuestSessions +
        provider.viewerAnalytics.totalRegisteredGoogleUsers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'admin.tab_overview'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                )),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // KPI Grid
          Wrap(
            spacing: AppTheme.spaceMd,
            runSpacing: AppTheme.spaceMd,
            children: [
              _buildKpiCard(
                title: 'admin.kpi_total_broadcasters'.tr(),
                value: '$totalBroadcasters',
                icon: Icons.cell_tower_rounded,
                color: AppTheme.danger,
              ),
              _buildKpiCard(
                title: 'admin.kpi_verified_scholars'.tr(),
                value: '$verifiedScholars',
                icon: Icons.school_rounded,
                color: AppTheme.primary,
              ),
              _buildKpiCard(
                title: 'admin.kpi_org_venues'.tr(),
                value: '$orgVenues',
                icon: Icons.apartment_rounded,
                color: AppTheme.accent,
              ),
              _buildKpiCard(
                title: 'admin.kpi_pending_apps'.tr(),
                value: '$pendingApps',
                icon: Icons.pending_actions_rounded,
                color: AppTheme.warning,
              ),
              _buildKpiCard(
                title: 'admin.kpi_active_viewers'.tr(),
                value: '$activeViewers',
                icon: Icons.group_rounded,
                color: AppTheme.success,
              ),
              _buildKpiCard(
                title: 'admin.kpi_auditorium_seats'.tr(),
                value: '$totalAuditoriumSeats',
                icon: Icons.event_seat_rounded,
                color: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXl),

          // Quick Action Shortcuts
          Text('design_ui.quick_actions_governance_shortcuts'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                child: _buildActionShortcutCard(
                  title: 'Review Verification Queue',
                  subtitle: '$pendingApps pending applications awaiting review',
                  icon: Icons.rate_review_rounded,
                  color: AppTheme.warning,
                  onTap: () => _tabController.animateTo(1),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                child: _buildActionShortcutCard(
                  title: 'Inspect Spatial GIS Map',
                  subtitle: 'View live auditoriums in Al Khobar & Dhahran',
                  icon: Icons.map_rounded,
                  color: AppTheme.primary,
                  onTap: () => context.go('/map'),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                child: _buildActionShortcutCard(
                  title: 'Edit Platform Terms',
                  subtitle: 'Update bilingual policies and Saudi PDPL terms',
                  icon: Icons.edit_document,
                  color: AppTheme.accent,
                  onTap: () => _tabController.animateTo(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionShortcutCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: color, size: 22),
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
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: VERIFICATION QUEUE
  // ==========================================

  Widget _buildVerificationQueueTab(
      BuildContext context, AppProvider provider, bool isAr) {
    var applications = provider.applications;

    if (_applicationFilter != null) {
      applications =
          applications.where((a) => a.status == _applicationFilter).toList();
    }

    final query = _appSearchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      applications = applications.where((a) {
        return a.applicantNameEn.toLowerCase().contains(query) ||
            a.applicantNameAr.contains(query) ||
            a.email.toLowerCase().contains(query) ||
            (a.institutionEn?.toLowerCase().contains(query) ?? false) ||
            a.venueNameEn.toLowerCase().contains(query);
      }).toList();
    }

    final visiblePendingIds = applications
        .where((a) => a.status == ApplicationStatus.pending)
        .map((a) => a.id)
        .toList();
    final allVisiblePendingSelected = visiblePendingIds.isNotEmpty &&
        visiblePendingIds.every(_selectedApplicationIds.contains);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Bar
          Row(
            children: [
              if (visiblePendingIds.isNotEmpty)
                Tooltip(
                  message: allVisiblePendingSelected
                      ? 'Deselect all pending'
                      : 'Select all pending',
                  child: Checkbox(
                    value: allVisiblePendingSelected,
                    activeColor: AppTheme.primary,
                    onChanged: (_) => setState(() {
                      if (allVisiblePendingSelected) {
                        _selectedApplicationIds
                            .removeWhere(visiblePendingIds.contains);
                      } else {
                        _selectedApplicationIds.addAll(visiblePendingIds);
                      }
                    }),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: _appSearchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'admin.search_applications'.tr(),
                    hintStyle: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppTheme.textSecondary, size: 18),
                    filled: true,
                    fillColor: AppTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide:
                          const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),

              // Filter Chips
              _buildAppFilterChip('admin.filter_all'.tr(), null),
              const SizedBox(width: 6),
              _buildAppFilterChip(
                  'admin.filter_pending'.tr(), ApplicationStatus.pending),
              const SizedBox(width: 6),
              _buildAppFilterChip(
                  'admin.filter_approved'.tr(), ApplicationStatus.approved),
              const SizedBox(width: 6),
              _buildAppFilterChip(
                  'admin.filter_rejected'.tr(), ApplicationStatus.rejected),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh Applications',
                icon: const Icon(Icons.refresh_rounded,
                    color: AppTheme.primary),
                onPressed: () async {
                  await provider.refreshAdminData();
                  setState(() {});
                },
              ),
            ],
          ),

          if (_selectedApplicationIds.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceMd),
            _buildBatchActionBar(context, provider),
          ],
          const SizedBox(height: AppTheme.spaceLg),

          // Applications List
          Expanded(
            child: applications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_rounded,
                            size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        Text('design_ui.no_applications_match_the_selected_filter'.tr(),
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: applications.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppTheme.spaceMd),
                    itemBuilder: (context, index) {
                      final app = applications[index];
                      return _buildApplicationCard(
                          context, provider, app, isAr);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchActionBar(BuildContext context, AppProvider provider) {
    final count = _selectedApplicationIds.length;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_box_rounded,
              size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count application${count == 1 ? '' : 's'} selected',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _selectedApplicationIds.clear()),
            child: Text('design_ui.clear'.tr(),
                style: const TextStyle(color: AppTheme.textSecondary)
                    .copyWith(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: AppTheme.danger),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 15),
            label: Text('design_ui.reject_selected'.tr()),
            onPressed: () => _showBulkRejectDialog(context, provider),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: AppTheme.onMedia,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.done_all_rounded, size: 15),
            label: Text('design_ui.approve_selected'.tr()),
            onPressed: () => _showBulkApproveDialog(context, provider),
          ),
        ],
      ),
    );
  }

  void _showBulkApproveDialog(BuildContext context, AppProvider provider) {
    final ids = _selectedApplicationIds.toList();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: Text('design_ui.approve_selected_applications'.tr(),
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          content: Text(
            'This will approve ${ids.length} pending application${ids.length == 1 ? '' : 's'}, creating a live broadcaster profile for each.',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12),
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
                backgroundColor: AppTheme.success,
                foregroundColor: AppTheme.onMedia,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final result =
                    await provider.bulkApproveBroadcasterApplications(
                  ids,
                  adminNotes:
                      'Batch-verified official credentials and venue facilities.',
                );
                setState(() => _selectedApplicationIds.clear());
                _showSuccessNotification(
                    '${result.succeeded} application${result.succeeded == 1 ? '' : 's'} approved.');
              },
              child: Text('admin.btn_approve'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showBulkRejectDialog(BuildContext context, AppProvider provider) {
    final ids = _selectedApplicationIds.toList();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: Text(
            'Reject ${ids.length} Selected Application${ids.length == 1 ? '' : 's'}?',
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('design_ui.this_feedback_note_is_sent_to_every_selected_applicant'.tr(),
                style:
                    const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'admin.reject_dialog_hint'.tr(),
                  hintStyle: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide:
                        const BorderSide(color: AppTheme.border),
                  ),
                ),
              ),
            ],
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
              onPressed: () async {
                final reason = reasonController.text.trim().isNotEmpty
                    ? reasonController.text.trim()
                    : 'Application rejected due to incomplete accreditation.';
                Navigator.pop(dialogContext);
                final result = await provider.bulkRejectBroadcasterApplications(
                  ids,
                  reason: reason,
                );
                setState(() => _selectedApplicationIds.clear());
                _showSuccessNotification(
                    '${result.succeeded} application${result.succeeded == 1 ? '' : 's'} rejected.');
              },
              child: Text('admin.btn_reject'.tr()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppFilterChip(String label, ApplicationStatus? status) {
    final isSelected = _applicationFilter == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primary : AppTheme.border,
      ),
      onSelected: (_) => setState(() => _applicationFilter = status),
    );
  }

  Widget _buildApplicationCard(BuildContext context, AppProvider provider,
      BroadcasterApplicationModel app, bool isAr) {
    Color statusColor;
    String statusText;

    switch (app.status) {
      case ApplicationStatus.approved:
        statusColor = AppTheme.success;
        statusText = 'APPROVED';
        break;
      case ApplicationStatus.rejected:
        statusColor = AppTheme.danger;
        statusText = 'REJECTED';
        break;
      case ApplicationStatus.pending:
      default:
        statusColor = AppTheme.warning;
        statusText = 'PENDING REVIEW';
        break;
    }

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (app.status == ApplicationStatus.pending)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4, top: 4),
                  child: Checkbox(
                    value: _selectedApplicationIds.contains(app.id),
                    activeColor: AppTheme.primary,
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selectedApplicationIds.add(app.id);
                      } else {
                        _selectedApplicationIds.remove(app.id);
                      }
                    }),
                  ),
                ),
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.surfaceAlt,
                backgroundImage: buildSafeImageProvider(
                  path: app.avatarUrl,
                  defaultAsset:
                      'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
                ),
                child: app.avatarUrl.isEmpty
                    ? Icon(
                        app.isOrganization
                            ? Icons.apartment_rounded
                            : Icons.person_rounded,
                        color: AppTheme.textSecondary)
                    : null,
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
                            isAr ? app.applicantNameAr : app.applicantNameEn,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: app.isOrganization
                                ? AppTheme.accent.withValues(alpha: 0.15)
                                : AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: app.isOrganization
                                  ? AppTheme.accent.withValues(alpha: 0.6)
                                  : AppTheme.primary.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Text(
                            app.isOrganization
                                ? 'ORGANIZATION VENUE'
                                : 'SCHOLAR',
                            style: TextStyle(
                              color: app.isOrganization
                                  ? AppTheme.accent
                                  : AppTheme.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${app.email} • ${app.phone}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app.isOrganization
                          ? 'Venue: ${isAr ? app.venueNameAr : app.venueNameEn} • Capacity: ${app.seatingCapacity} seats • GPS: (${app.latitude.toStringAsFixed(4)}, ${app.longitude.toStringAsFixed(4)})'
                          : 'Title: ${isAr ? (app.academicTitleAr ?? '') : (app.academicTitleEn ?? '')} • Institution: ${isAr ? (app.institutionAr ?? '') : (app.institutionEn ?? '')}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (app.status == ApplicationStatus.pending) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: AppTheme.onMedia,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: Text('admin.btn_approve'.tr()),
                      onPressed: () =>
                          _handleApproveApplication(context, provider, app),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        side: const BorderSide(color: AppTheme.danger),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: Text('admin.btn_reject'.tr()),
                      onPressed: () =>
                          _showRejectDialog(context, provider, app),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side:
                            const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: Text('admin.btn_inspect'.tr()),
                      onPressed: () =>
                          _showApplicationDetailsDialog(context, app, isAr),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppTheme.danger),
                      tooltip: 'admin.btn_delete'.tr(),
                      onPressed: () async {
                        await provider.deleteBroadcasterApplication(app.id);
                        _showSuccessNotification(
                            'admin.app_deleted_toast'.tr());
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (app.adminReviewNotes != null &&
              app.adminReviewNotes!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                    color: AppTheme.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.rate_review_outlined,
                      size: 14, color: AppTheme.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Admin Review Notes: ${app.adminReviewNotes}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleApproveApplication(BuildContext context, AppProvider provider,
      BroadcasterApplicationModel app) async {
    int currentStage = 1;
    String stageDescription = 'Starting verification pipeline...';
    StateSetter? dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          dialogSetState = setDialogState;
          final double progress = currentStage / 5.0;
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: const BorderSide(color: AppTheme.border),
            ),
            title: Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: AppTheme.success, size: 22),
                const SizedBox(width: 8),
                Text('design_ui.approving_broadcaster'.tr(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stage $currentStage of 5: $stageDescription',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.surfaceAlt,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.success),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final success = await provider.approveBroadcasterApplication(
      app.id,
      adminNotes: 'Verified official credentials and venue facilities.',
      onProgress: (stage, desc) {
        if (dialogSetState != null) {
          dialogSetState!(() {
            currentStage = stage;
            stageDescription = desc;
          });
        }
      },
    );

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (success) {
      _showSuccessNotification('admin.app_approved_toast'.tr());
    }
  }

  void _showRejectDialog(BuildContext context, AppProvider provider,
      BroadcasterApplicationModel app) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: Text(
            'admin.reject_dialog_title'.tr(),
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejecting application for "${app.applicantNameEn}". Please specify the feedback note for the applicant:',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'admin.reject_dialog_hint'.tr(),
                  hintStyle: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide:
                        const BorderSide(color: AppTheme.border),
                  ),
                ),
              ),
            ],
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
              onPressed: () async {
                final reason = reasonController.text.trim().isNotEmpty
                    ? reasonController.text.trim()
                    : 'Application rejected due to incomplete accreditation.';
                await provider.rejectBroadcasterApplication(app.id,
                    reason: reason);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                _showSuccessNotification('admin.app_rejected_toast'.tr());
              },
              child: Text('admin.btn_reject'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showApplicationDetailsDialog(
      BuildContext context, BroadcasterApplicationModel app, bool isAr) {
    final provider = context.read<AppProvider>();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
            child: Column(
              children: [
                // Top Header Banner with Floating Avatar
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppTheme.radiusLg)),
                        image: DecorationImage(
                          image: buildSafeImageProvider(
                            path: app.bannerUrl,
                            defaultAsset:
                                'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Container(
                      height: 120,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppTheme.radiusLg)),
                        color: AppTheme.media,
                      ),
                    ),
                    PositionedDirectional(
                      top: 10,
                      end: 10,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppTheme.onMedia, size: 22),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ),
                    PositionedDirectional(
                      bottom: -32,
                      start: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.surface, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 34,
                          backgroundImage: buildSafeImageProvider(
                            path: app.avatarUrl,
                            defaultAsset:
                                'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 38),

                // Title and Metadata
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isAr
                                      ? app.applicantNameAr
                                      : app.applicantNameEn,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.verified_rounded,
                                    color: AppTheme.primary, size: 18),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              app.isOrganization
                                  ? (app.organizationType ??
                                      'Educational Academy')
                                  : (isAr
                                      ? (app.academicTitleAr ?? 'محاضر وباحث')
                                      : (app.academicTitleEn ??
                                          'Academic Scholar')),
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          app.isOrganization ? 'ORGANIZATION' : 'INDIVIDUAL',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),

                // Content Scrollable Details
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Email', app.email),
                        _buildDetailRow('Phone', app.phone),
                        _buildDetailRow(
                            'YouTube Handle', '@${app.youtubeHandle}'),
                        _buildDetailRow(
                            'YouTube Channel', app.youtubeChannelUrl),
                        _buildDetailRow('Category',
                            app.categoryId.replaceAll('_', ' ').toUpperCase()),
                        if (app.tags.isNotEmpty)
                          _buildDetailRow('Tags', app.tags.join(' ')),
                        _buildDetailRow(
                          'Venue & Coordinates',
                          '${app.venueNameEn} (Lat: ${app.latitude.toStringAsFixed(4)}, Lng: ${app.longitude.toStringAsFixed(4)})',
                        ),
                        const SizedBox(height: AppTheme.spaceSm),
                        const Divider(color: AppTheme.border),
                        const SizedBox(height: AppTheme.spaceSm),
                        Text('design_ui.research_biography_english'.tr(),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          app.bioEn.isNotEmpty ? app.bioEn : 'N/A',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: AppTheme.spaceMd),
                        const Text(
                          'نبذة السيرة الذاتية (عربي)',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          app.bioAr.isNotEmpty ? app.bioAr : 'لا يوجد',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Footer
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(AppTheme.radiusLg)),
                    border: Border(
                        top: BorderSide(color: AppTheme.border)),
                  ),
                  child: Row(
                    children: [
                      if (app.status == ApplicationStatus.pending) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: AppTheme.onMedia,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          icon:
                              const Icon(Icons.check_circle_rounded, size: 16),
                          label: Text('design_ui.approve_broadcaster'.tr()),
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _handleApproveApplication(context, provider, app);
                          },
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.danger,
                            side: const BorderSide(color: AppTheme.danger),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: Text('design_ui.reject'.tr()),
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showRejectDialog(context, provider, app);
                          },
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppTheme.danger, size: 20),
                        tooltip: 'Delete Application',
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await provider.deleteBroadcasterApplication(app.id);
                          _showSuccessNotification(
                              'admin.app_deleted_toast'.tr());
                        },
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text('design_ui.close'.tr(),
                            style: const TextStyle(color: AppTheme.textPrimary)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: BROADCASTERS REGISTRY
  // ==========================================

  Widget _buildStreamersRegistryTab(
      BuildContext context, AppProvider provider, bool isAr) {
    var streamers = provider.streamers;

    if (_streamerTypeFilter == 'scholars') {
      streamers = streamers.where((s) => !s.isOrganization).toList();
    } else if (_streamerTypeFilter == 'organizations') {
      streamers = streamers.where((s) => s.isOrganization).toList();
    }

    final query = _streamerSearchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      streamers = streamers.where((s) {
        return s.fullNameEn.toLowerCase().contains(query) ||
            s.fullNameAr.contains(query) ||
            s.titleEn.toLowerCase().contains(query) ||
            s.organizationEn.toLowerCase().contains(query) ||
            (s.venueNameEn.toLowerCase().contains(query));
      }).toList();
    }

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _streamerSearchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'admin.search_streamers'.tr(),
                    hintStyle: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppTheme.textSecondary, size: 18),
                    filled: true,
                    fillColor: AppTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide:
                          const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              _buildStreamerFilterChip('admin.filter_all'.tr(), 'all'),
              const SizedBox(width: 6),
              _buildStreamerFilterChip('Verified Scholars', 'scholars'),
              const SizedBox(width: 6),
              _buildStreamerFilterChip('Organizations', 'organizations'),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // Streamers Table / Cards
          Expanded(
            child: ListView.separated(
              itemCount: streamers.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppTheme.spaceSm),
              itemBuilder: (context, index) {
                final s = streamers[index];
                final isProtected = provider.isProtectedStreamer(s.streamerId);

                return Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.surfaceAlt,
                        backgroundImage: buildSafeImageProvider(
                          path: s.avatarUrl,
                          defaultAsset:
                              'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isAr ? s.fullNameAr : s.fullNameEn,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (s.isVerified)
                                  const Icon(Icons.verified_rounded,
                                      size: 14, color: AppTheme.primary),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: s.isOrganization
                                        ? AppTheme.accent
                                            .withValues(alpha: 0.15)
                                        : AppTheme.primary
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    s.isOrganization ? 'ORG VENUE' : 'SCHOLAR',
                                    style: TextStyle(
                                      color: s.isOrganization
                                          ? AppTheme.accent
                                          : AppTheme.primary,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${isAr ? s.titleAr : s.titleEn} • ${isAr ? s.organizationAr : s.organizationEn}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Live Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: s.isCurrentlyLive
                              ? AppTheme.danger.withValues(alpha: 0.15)
                              : AppTheme.surfaceAlt,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(
                            color: s.isCurrentlyLive
                                ? AppTheme.danger
                                : AppTheme.border,
                          ),
                        ),
                        child: Text(
                          s.isCurrentlyLive ? 'LIVE' : 'OFFLINE',
                          style: TextStyle(
                            color: s.isCurrentlyLive
                                ? AppTheme.danger
                                : AppTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMd),

                      // Manage Org Button (If Organization)
                      if (s.isOrganization)
                        IconButton(
                          icon: const Icon(Icons.apartment_rounded,
                              size: 16, color: AppTheme.warning),
                          tooltip: 'admin.tab_organizations'.tr(),
                          onPressed: () {
                            _tabController.animateTo(3);
                          },
                        ),

                      // Hide from Map Toggle (Cluster 4 Task 18) -- a
                      // moderation action short of a full ban; the profile
                      // stays reachable by direct link.
                      Tooltip(
                        message: 'admin.hide_from_map_toggle'.tr(),
                        child: Switch(
                          value: s.isTemporarilyHiddenFromMap,
                          activeThumbColor: AppTheme.warning,
                          onChanged: (hidden) async {
                            if (hidden) {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  backgroundColor: AppTheme.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd),
                                    side: const BorderSide(
                                        color: AppTheme.border),
                                  ),
                                  title: Text(
                                    'admin.hide_from_map_confirm_title'.tr(),
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  content: Text(
                                    'admin.hide_from_map_confirm_body'.tr(),
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: Text('common.cancel'.tr(),
                                          style: const TextStyle(
                                              color: AppTheme.textMuted)),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.warning),
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: Text('admin.hide_from_map_toggle'
                                          .tr()),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                            }
                            final success = await provider
                                .setStreamerHiddenFromMap(
                                    streamerId: s.streamerId, hidden: hidden);
                            if (!success) {
                              _showErrorNotification(
                                  'Failed to update map visibility.');
                              return;
                            }
                            _showSuccessNotification(hidden
                                ? 'admin.streamer_hidden_from_map_toast'.tr()
                                : 'admin.streamer_shown_on_map_toast'.tr());
                          },
                        ),
                      ),

                      // Edit Button
                      IconButton(
                        icon: const Icon(Icons.edit_rounded,
                            size: 16, color: AppTheme.primary),
                        tooltip: 'Edit Broadcaster',
                        onPressed: () =>
                            StreamerEditorSheet.show(context, streamer: s),
                      ),

                      // Delete Button (Non-Protected)
                      if (!isProtected)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 16, color: AppTheme.danger),
                          tooltip: 'Delete Streamer',
                          onPressed: () async {
                            final success =
                                await provider.deleteStreamer(s.streamerId);
                            if (success) {
                              _showSuccessNotification(
                                  'Broadcaster profile removed.');
                            } else {
                              _showErrorNotification(
                                  'Failed to remove broadcaster profile.');
                            }
                          },
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

  Widget _buildStreamerFilterChip(String label, String value) {
    final isSelected = _streamerTypeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.accent.withValues(alpha: 0.2),
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.accent : AppTheme.border,
      ),
      onSelected: (_) => setState(() => _streamerTypeFilter = value),
    );
  }

  // ==========================================
  // TAB 4: VIEWER ANALYTICS DASHBOARD
  // ==========================================

  Widget _buildViewerAnalyticsTab(
      BuildContext context, AppProvider provider, bool isAr) {
    final analytics = provider.viewerAnalytics;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'admin.tab_viewers'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // Metrics Grid
          Wrap(
            spacing: AppTheme.spaceMd,
            runSpacing: AppTheme.spaceMd,
            children: [
              _buildKpiCard(
                title: 'admin.guest_sessions'.tr(),
                value: '${analytics.totalGuestSessions}',
                icon: Icons.person_outline_rounded,
                color: AppTheme.primary,
              ),
              _buildKpiCard(
                title: 'admin.registered_users'.tr(),
                value: '${analytics.totalRegisteredGoogleUsers}',
                icon: Icons.account_circle_rounded,
                color: AppTheme.success,
              ),
              _buildKpiCard(
                title: 'admin.auditorium_rsvps'.tr(),
                value: '${analytics.totalAuditoriumRsvps}',
                icon: Icons.event_seat_rounded,
                color: AppTheme.accent,
              ),
              _buildKpiCard(
                title: 'admin.lecture_bookmarks'.tr(),
                value: '${analytics.totalLectureBookmarks}',
                icon: Icons.bookmark_added_rounded,
                color: AppTheme.warning,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXl),

          // Geographic Distribution Card
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('design_ui.alsharqia_regional_engagement_breakdown'.tr(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                _buildRegionProgressBar('Al Khobar (Academic Corridor)', 0.45,
                    '45% Active Attendance'),
                const SizedBox(height: AppTheme.spaceSm),
                _buildRegionProgressBar('Dhahran (KFUPM & Research Valley)',
                    0.35, '35% Research Traffic'),
                const SizedBox(height: AppTheme.spaceSm),
                _buildRegionProgressBar('Dammam (Medical & Cultural Centers)',
                    0.20, '20% Institutional Streamers'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionProgressBar(
      String label, double percentage, String detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            Text(detail,
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: AppTheme.surfaceAlt,
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 5: TERMS & GOVERNANCE EDITOR
  // ==========================================

  Widget _buildTermsGovernanceTab(
      BuildContext context, AppProvider provider, bool isAr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.gavel_rounded,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'admin.tab_terms'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onMedia,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.save_rounded, size: 16),
                label: Text('admin.btn_save_terms'.tr()),
                onPressed: () async {
                  final newTerms = TermsAndConditionsModel(
                    version: provider.termsAndConditions.version,
                    termsOfServiceEn: _termsEnController.text,
                    termsOfServiceAr: _termsArController.text,
                    broadcasterGuidelinesEn: _guidelinesEnController.text,
                    broadcasterGuidelinesAr: _guidelinesArController.text,
                    privacyPolicyEn: _privacyEnController.text,
                    privacyPolicyAr: _privacyArController.text,
                    lastUpdated: DateTime.now(),
                  );
                  await provider.updateTermsAndConditions(newTerms);
                  _showSuccessNotification('admin.terms_saved_toast'.tr());
                },
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // 1. Terms of Service (En & Ar)
          _buildTermsEditorSection(
            title: 'Terms of Service',
            controllerEn: _termsEnController,
            controllerAr: _termsArController,
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // 2. Broadcaster Guidelines (En & Ar)
          _buildTermsEditorSection(
            title: 'admin.broadcaster_guidelines'.tr(),
            controllerEn: _guidelinesEnController,
            controllerAr: _guidelinesArController,
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // 3. Privacy Policy (En & Ar)
          _buildTermsEditorSection(
            title: 'admin.privacy_policy'.tr(),
            controllerEn: _privacyEnController,
            controllerAr: _privacyArController,
          ),
        ],
      ),
    );
  }

  Widget _buildTermsEditorSection({
    required String title,
    required TextEditingController controllerEn,
    required TextEditingController controllerAr,
  }) {
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
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'admin.english_content'.tr(),
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: controllerEn,
                      maxLines: 5,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          borderSide: const BorderSide(
                              color: AppTheme.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'admin.arabic_content'.tr(),
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: controllerAr,
                      maxLines: 5,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          borderSide: const BorderSide(
                              color: AppTheme.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
