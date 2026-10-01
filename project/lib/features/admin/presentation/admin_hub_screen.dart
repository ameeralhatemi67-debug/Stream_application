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
import '../../../../core/widgets/language_switcher.dart';
import '../../../../core/layout/content_width.dart';
import '../models/chat_report_model.dart';
import '../models/tag_moderation_model.dart';
import '../../profile/models/streamer_models.dart';
import 'widgets/role_permission_management_view.dart';
import 'widgets/chat_moderation_view.dart';
import 'widgets/custom_placeholder_review_view.dart';
import 'widgets/academic_categories_view.dart';
import 'widgets/tag_moderation_view.dart';
import 'widgets/banned_accounts_view.dart';
import 'widgets/admin_user_directory_view.dart';
import 'widgets/admin_safety_view.dart';
import '../../../../core/widgets/safe_image_provider.dart';

/// Desktop Admin Moderation & Platform Governance Hub Screen
class AdminHubScreen extends StatefulWidget {
  const AdminHubScreen({super.key});

  @override
  State<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends State<AdminHubScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  // Rebuild the controller if the backend role changes while the hub is open.
  late bool _isMasterAdminForTabs;

  // Search & Filter Controllers
  final TextEditingController _appSearchController = TextEditingController();
  final TextEditingController _streamerSearchController =
      TextEditingController();
  ApplicationStatus? _applicationFilter;
  bool _showReviewLog = false;
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
    // viewer is also a Master Admin (Checkpoint 2 Phase 3), +1 for the
    // always-present Safety console (P6).
    _tabController = TabController(
        length: (_isMasterAdminForTabs ? 14 : 13) + (kDebugMode ? 1 : 0),
        vsync: this);
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
          List<BroadcasterApplicationModel> applications,
          List<Map<String, dynamic>> reviewEvents,
          TermsAndConditionsModel termsAndConditions,
          List<ChatReportModel> chatReports,
          bool isPitchDirectorModeEnabled,
          List<TagModerationModel> allTagsForModeration,
          int bannedUsersCount,
        })>((p) => (
          isAdminUser: p.isAdminUser,
          isMasterAdmin: p.isMasterAdmin,
          googleUserName: p.googleUserName,
          googleUserEmail: p.googleUserEmail,
          pendingApplications: p.pendingApplications,
          streamers: p.streamers,
          applications: p.applications,
          reviewEvents: p.applicationReviewEvents,
          termsAndConditions: p.termsAndConditions,
          chatReports: p.chatReports,
          isPitchDirectorModeEnabled: p.isPitchDirectorModeEnabled,
          allTagsForModeration: p.allTagsForModeration,
          bannedUsersCount: p.bannedUsers.length,
        ));
    final isAr = context.locale.languageCode == 'ar';
    final isDesktop =
        MediaQuery.of(context).size.width >= AppBreakpoints.expanded;
    if (_isMasterAdminForTabs != provider.isMasterAdmin) {
      final oldIndex = _tabController.index;
      const rolesIndex = 11 + (kDebugMode ? 1 : 0);
      final hadMaster = _isMasterAdminForTabs;
      _isMasterAdminForTabs = provider.isMasterAdmin;
      var index = oldIndex;
      if (hadMaster && oldIndex == rolesIndex) index = 0;
      if (hadMaster && oldIndex > rolesIndex) index--;
      if (!hadMaster && oldIndex >= rolesIndex) index++;
      _tabController.dispose();
      _tabController = TabController(
          length: (_isMasterAdminForTabs ? 14 : 13) + (kDebugMode ? 1 : 0),
          initialIndex: index,
          vsync: this);
    }

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
        body: SingleChildScrollView(
            child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(AppTheme.spaceXl),
            margin: const EdgeInsets.all(AppTheme.spaceLg),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gpp_bad_rounded,
                    color: AppTheme.danger, size: 54),
                const SizedBox(height: AppTheme.spaceMd),
                Text(
                  'design_ui.admin_access_required'.tr(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  'design_ui.your_account_does_not_have_admin_or_master_admin_access_ask_a_mas'
                      .tr(),
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

    final views = TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(),
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
        const AdminUserDirectoryView(),
        const AdminSafetyView(),
      ],
    );
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        leading: isDesktop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'common.back'.tr(),
                onPressed: () => context.go('/feed'))
            : null,
        title: Text('admin.title'.tr(),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: const [
          Padding(
              padding: EdgeInsetsDirectional.only(end: AppTheme.spaceMd),
              child: Center(child: LanguageSwitcher()))
        ],
      ),
      drawer: isDesktop
          ? null
          : Drawer(
              child: SafeArea(
                  child: _buildNavigation(provider, closeDrawer: true))),
      body: Row(children: [
        if (isDesktop) ...[
          SizedBox(width: 260, child: _buildNavigation(provider)),
          const VerticalDivider(width: 1),
        ],
        Expanded(child: views),
      ]),
    );
  }

  Widget _buildNavigation(AppProvider provider, {bool closeDrawer = false}) {
    final entries = <({String label, IconData icon, int count})>[
      (label: 'admin.tab_overview', icon: Icons.dashboard_outlined, count: 0),
      (
        label: 'admin.tab_verification',
        icon: Icons.how_to_reg_outlined,
        count: provider.pendingApplications.length
      ),
      (label: 'admin.tab_streamers', icon: Icons.groups_outlined, count: 0),
      (
        label: 'admin.tab_organizations',
        icon: Icons.apartment_outlined,
        count: 0
      ),
      (label: 'admin.tab_viewers', icon: Icons.analytics_outlined, count: 0),
      (label: 'admin.tab_terms', icon: Icons.gavel_outlined, count: 0),
      (
        label: 'admin.tab_chat_moderation',
        icon: Icons.report_outlined,
        count: provider.chatReports.length
      ),
      (
        label: 'admin.tab_custom_cards',
        icon: Icons.image_outlined,
        count: provider.pendingCustomPlaceholders.length
      ),
      (label: 'admin.tab_categories', icon: Icons.school_outlined, count: 0),
      (
        label: 'admin.tab_tags',
        icon: Icons.label_outline,
        count: provider.allTagsForModeration
            .where((t) => t.status == TagStatus.pending)
            .length
      ),
      (
        label: 'admin.tab_banned_accounts',
        icon: Icons.person_off_outlined,
        count: provider.bannedUsers.length
      ),
      if (kDebugMode)
        (label: 'admin.tab_testing', icon: Icons.science_outlined, count: 0),
      if (_isMasterAdminForTabs)
        (
          label: 'admin.tab_roles',
          icon: Icons.admin_panel_settings_outlined,
          count: 0
        ),
      (label: 'directory.title', icon: Icons.people_outline, count: 0),
      (label: 'safety.tab', icon: Icons.shield_outlined, count: 0),
    ];
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) => ListView(
        key: const ValueKey('admin-navigation'),
        padding: const EdgeInsets.all(AppTheme.spaceSm),
        children: [
          if (closeDrawer)
            ListTile(
                leading: const Icon(Icons.arrow_back_rounded),
                title: Text('common.back'.tr()),
                onTap: () => context.go('/feed')),
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceXs),
              child: ListTile(
                key: ValueKey(entries[i].label),
                selected: _tabController.index == i,
                selectedColor: AppTheme.primary,
                selectedTileColor: AppTheme.surfaceAlt,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                leading: Icon(entries[i].icon),
                title: Text(entries[i].label.tr()),
                trailing: entries[i].count > 0
                    ? Text(entries[i].count.toString())
                    : null,
                onTap: () {
                  _tabController.animateTo(i);
                  if (closeDrawer) Navigator.of(context).pop();
                },
              ),
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
                color: isPitchActive ? AppTheme.danger : AppTheme.border,
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
    final verifiedScholars = provider.streamers
        .where((s) => !s.isOrganization && s.isVerified)
        .length;
    final orgVenues = provider.streamers.where((s) => s.isOrganization).length;
    final pendingApps = provider.pendingApplications.length;

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
              Expanded(
                child: Text('admin.tab_overview'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),

          Text('admin.overview_data_note'.tr()),
          const SizedBox(height: AppTheme.spaceMd),
          // KPI Grid
          Wrap(
            spacing: AppTheme.spaceMd,
            runSpacing: AppTheme.spaceMd,
            children: [
              _buildKpiCard(
                title: 'admin.loaded_broadcasters'.tr(),
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
                title: 'admin.loaded_organizations'.tr(),
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
                value: 'admin.unavailable'.tr(),
                icon: Icons.group_rounded,
                color: AppTheme.success,
              ),
              _buildKpiCard(
                title: 'admin.kpi_auditorium_seats'.tr(),
                value: 'admin.unavailable'.tr(),
                icon: Icons.event_seat_rounded,
                color: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXl),

          // Quick Action Shortcuts
          Text(
            'design_ui.quick_actions_governance_shortcuts'.tr(),
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
                  title: 'admin.review_queue'.tr(),
                  subtitle: 'admin.pending_review'.tr(args: ['$pendingApps']),
                  icon: Icons.rate_review_rounded,
                  color: AppTheme.warning,
                  onTap: () => _tabController.animateTo(1),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                child: _buildActionShortcutCard(
                  title: 'admin.inspect_map'.tr(),
                  subtitle: 'admin.inspect_map_hint'.tr(),
                  icon: Icons.map_rounded,
                  color: AppTheme.primary,
                  onTap: () => context.go('/map'),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                child: _buildActionShortcutCard(
                  title: 'admin.edit_terms'.tr(),
                  subtitle: 'admin.edit_terms_hint'.tr(),
                  icon: Icons.edit_document,
                  color: AppTheme.accent,
                  onTap: () => _tabController.animateTo(5),
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
              Expanded(
                child: Text(title,
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
    var applications = verificationQueueRows(provider.applications);

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
          Wrap(
            spacing: AppTheme.spaceSm,
            children: [
              ChoiceChip(
                label: Text('admin.queue_tab'.tr()),
                selected: !_showReviewLog,
                onSelected: (_) => setState(() => _showReviewLog = false),
              ),
              ChoiceChip(
                label: Text('admin.review_log_tab'.tr()),
                selected: _showReviewLog,
                onSelected: (_) => setState(() => _showReviewLog = true),
              ),
              IconButton(
                tooltip: 'admin.refresh_reviews'.tr(),
                icon:
                    const Icon(Icons.refresh_rounded, color: AppTheme.primary),
                onPressed: () => provider.refreshAdminData(),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          if (_showReviewLog)
            Expanded(child: _buildReviewLog(context, provider, isAr))
          else ...[
            // Filter Bar
            Wrap(
              spacing: AppTheme.spaceSm,
              runSpacing: AppTheme.spaceSm,
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
                SizedBox(
                  width: double.infinity,
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
                        borderSide: const BorderSide(color: AppTheme.border),
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
                          Text(
                            'design_ui.no_applications_match_the_selected_filter'
                                .tr(),
                            style:
                                const TextStyle(color: AppTheme.textSecondary),
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
        ],
      ),
    );
  }

  Widget _buildReviewLog(
      BuildContext context, AppProvider provider, bool isAr) {
    final events = provider.applicationReviewEvents;
    if (events.isEmpty) {
      return Center(child: Text('admin.review_log_empty'.tr()));
    }
    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceSm),
      itemBuilder: (context, index) {
        final event = events[index];
        final action = event['action'] as String? ?? '';
        final id = event['application_id'] as String? ?? '';
        final latest = events.firstWhere(
            (e) => e['application_id'] == id && e['action'] != 'removed',
            orElse: () => event);
        final current =
            provider.applications.where((a) => a.id == id).firstOrNull;
        final localOnly = (event['id'] as String? ?? '').startsWith('local-');
        final reversible = !localOnly &&
            latest['id'] == event['id'] &&
            (action == 'approved' || action == 'rejected') &&
            (current == null || current.status.name == action);
        final name = isAr
            ? event['applicant_name_ar'] as String? ?? ''
            : event['applicant_name_en'] as String? ?? '';
        final when = DateTime.tryParse(event['created_at'] as String? ?? '')
                ?.toLocal()
                .toString()
                .split('.')
                .first ??
            '';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                    spacing: AppTheme.spaceSm,
                    runSpacing: AppTheme.spaceXs,
                    children: [
                      Text(name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('admin.log_$action'.tr()),
                    ]),
                Text('${event['actor_name'] ?? 'Admin'} • $when',
                    style: const TextStyle(color: AppTheme.textSecondary)),
                if ((event['reason'] as String? ?? '').isNotEmpty)
                  Text(event['reason'] as String),
                if (localOnly)
                  Text('admin.local_log_notice'.tr(),
                      style: const TextStyle(color: AppTheme.textSecondary)),
                Wrap(spacing: AppTheme.spaceSm, children: [
                  TextButton.icon(
                    onPressed: () =>
                        _showReviewEventDetails(context, event, isAr),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text('admin.btn_inspect'.tr()),
                  ),
                  if (reversible)
                    TextButton.icon(
                      onPressed: () =>
                          _reverseReviewEvent(context, provider, event),
                      icon: const Icon(Icons.undo_rounded),
                      label: Text(action == 'approved'
                          ? 'admin.reverse_approval'.tr()
                          : 'admin.approve_instead'.tr()),
                    ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReviewEventDetails(
      BuildContext context, Map<String, dynamic> event, bool isAr) {
    final snapshot = Map<String, dynamic>.from(
        event['application_snapshot'] as Map? ?? const {});
    final base =
        Map<String, dynamic>.from(event['base_snapshot'] as Map? ?? const {});
    final changes = <Widget>[];
    if (base.isNotEmpty) {
      for (final (key, label) in [
        ('email', 'admin.field_email'),
        ('phone', 'admin.field_phone'),
        ('city_id', 'profile.city'),
        (isAr ? 'venue_name_ar' : 'venue_name_en', 'admin.venue'),
        ('latitude', 'admin.location'),
        ('longitude', 'admin.location'),
        ('youtube_channel_url', 'admin.field_youtube'),
        ('youtube_handle', 'admin.field_youtube'),
      ]) {
        if (base[key] != snapshot[key]) {
          changes.add(_buildDetailRow(
              label.tr(), '${base[key] ?? ''} → ${snapshot[key] ?? ''}'));
        }
      }
    }
    showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text('admin.review_log_tab'.tr()),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('admin.audit_actor'.tr(),
                        event['actor_name'] as String? ?? ''),
                    _buildDetailRow('admin.audit_action'.tr(),
                        'admin.log_${event['action']}'.tr()),
                    _buildDetailRow('admin.reject_reason_label'.tr(),
                        event['reason'] as String? ?? ''),
                    if (changes.isNotEmpty) ...[
                      const Divider(),
                      Text('admin.edit_after_verification'.tr(),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      ...changes,
                      const Divider(),
                    ],
                    _buildDetailRow(
                        'admin.applicant'.tr(),
                        isAr
                            ? snapshot['applicant_name_ar'] as String? ?? ''
                            : snapshot['applicant_name_en'] as String? ?? ''),
                    _buildDetailRow('admin.field_email'.tr(),
                        snapshot['email'] as String? ?? ''),
                    _buildDetailRow('admin.field_phone'.tr(),
                        snapshot['phone'] as String? ?? ''),
                    _buildDetailRow(
                        'admin.venue'.tr(),
                        isAr
                            ? snapshot['venue_name_ar'] as String? ?? ''
                            : snapshot['venue_name_en'] as String? ?? ''),
                    _buildDetailRow('admin.field_youtube'.tr(),
                        snapshot['youtube_channel_url'] as String? ?? ''),
                  ],
                )),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('design_ui.close'.tr()),
                )
              ],
            ));
  }

  Future<void> _reverseReviewEvent(BuildContext context, AppProvider provider,
      Map<String, dynamic> event) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text('admin.reverse_title'.tr()),
              content: TextField(
                controller: reasonController,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                    labelText: 'admin.reject_reason_label'.tr()),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('settings.cancel'.tr())),
                TextButton(
                    onPressed: () {
                      final reason = reasonController.text.trim();
                      if (reason.isNotEmpty) {
                        Navigator.pop(dialogContext, reason);
                      }
                    },
                    child: Text('admin.reverse_confirm'.tr())),
              ],
            ));
    reasonController.dispose();
    if (reason == null || !mounted) return;
    try {
      if (event['action'] == 'approved') {
        await provider.reverseApprovedApplication(
            event['id'] as String, reason);
      } else {
        final success = await provider.approveRejectedApplication(
            event['application_id'] as String,
            adminNotes: reason);
        if (!success) throw StateError('Review changed');
      }
      if (mounted) _showSuccessNotification('admin.review_reversed'.tr());
    } catch (_) {
      if (mounted) _showErrorNotification('admin.review_changed'.tr());
    }
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
              'admin.selected_count'.tr(namedArgs: {'count': '$count'}),
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
          title: Text(
            'design_ui.approve_selected_applications'.tr(),
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          content: Text(
            'This will approve ${ids.length} pending application${ids.length == 1 ? '' : 's'}, creating a live broadcaster profile for each.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
            'admin.batch_reject_title'
                .tr(namedArgs: {'count': '${ids.length}'}),
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
                'design_ui.this_feedback_note_is_sent_to_every_selected_applicant'
                    .tr(),
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'admin.reject_dialog_hint'.tr(),
                  hintStyle:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: AppTheme.border),
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
                final reason = reasonController.text.trim();
                if (reason.isEmpty) return;
                Navigator.pop(dialogContext);
                final result = await provider.bulkRejectBroadcasterApplications(
                  ids,
                  reason: reason,
                );
                setState(() => _selectedApplicationIds.clear());
                final message = 'admin.batch_reject_result'.tr(namedArgs: {
                  'succeeded': '${result.succeeded}',
                  'failed': '${result.failed}',
                });
                if (result.failed == 0) {
                  _showSuccessNotification(message);
                } else {
                  _showErrorNotification(message);
                }
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
        statusText = 'admin.filter_approved'.tr();
        break;
      case ApplicationStatus.rejected:
        statusColor = AppTheme.danger;
        statusText = 'admin.filter_rejected'.tr();
        break;
      case ApplicationStatus.suspended:
        statusColor = AppTheme.danger;
        statusText = 'admin.suspended'.tr();
        break;
      case ApplicationStatus.pending:
        statusColor = AppTheme.warning;
        statusText = 'admin.filter_pending'.tr();
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
          Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
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
                backgroundImage: resolveImageProviderOrNull(app.avatarUrl),
                child: app.avatarUrl.isEmpty
                    ? Icon(
                        app.isOrganization
                            ? Icons.apartment_rounded
                            : Icons.person_rounded,
                        color: AppTheme.textSecondary)
                    : null,
              ),
              const SizedBox(width: AppTheme.spaceMd),
              SizedBox(
                width: MediaQuery.sizeOf(context).width < 900
                    ? double.infinity
                    : 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppTheme.spaceSm,
                      runSpacing: AppTheme.spaceSm,
                      children: [
                        Text(
                          isAr ? app.applicantNameAr : app.applicantNameEn,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
                                ? 'admin.application_org'.tr()
                                : 'admin.application_scholar'.tr(),
                            style: TextStyle(
                              color: app.isOrganization
                                  ? AppTheme.accent
                                  : AppTheme.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (app.revisionOf != null)
                          Chip(
                              label:
                                  Text('admin.edit_after_verification'.tr())),
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
                          ? '${'admin.venue'.tr()}: ${isAr ? app.venueNameAr : app.venueNameEn} • ${'admin.field_capacity'.tr()}: ${app.seatingCapacity} ${'admin.field_seats'.tr()} • ${'admin.location'.tr()}: (${app.latitude.toStringAsFixed(4)}, ${app.longitude.toStringAsFixed(4)})'
                          : '${'admin.field_title'.tr()}: ${isAr ? (app.academicTitleAr ?? '') : (app.academicTitleEn ?? '')} • ${'admin.field_institution'.tr()}: ${isAr ? (app.institutionAr ?? '') : (app.institutionEn ?? '')}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Wrap(
                spacing: AppTheme.spaceSm,
                runSpacing: AppTheme.spaceSm,
                children: [
                  if (app.status == ApplicationStatus.pending) ...[
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showApplicationDetailsDialog(context, app, isAr),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: Text('admin.btn_inspect'.tr()),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: AppTheme.onMedia,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: Text(app.revisionOf == null
                          ? 'admin.btn_approve'.tr()
                          : 'admin.approve_edit'.tr()),
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
                      label: Text(app.revisionOf == null
                          ? 'admin.btn_reject'.tr()
                          : 'admin.reject_edit'.tr()),
                      onPressed: () =>
                          _showRejectDialog(context, provider, app),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.border),
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
                      onPressed: () =>
                          _removeApplicationFromQueue(context, provider, app),
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
                border:
                    Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.rate_review_outlined,
                      size: 14, color: AppTheme.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${'admin.review_notes'.tr()}: ${app.adminReviewNotes}',
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
                Text(
                  'design_ui.approving_broadcaster'.tr(),
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
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.success),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    var success = false;
    try {
      success = await provider.approveBroadcasterApplication(
        app.id,
        onProgress: (stage, desc) {
          if (dialogSetState != null) {
            dialogSetState!(() {
              currentStage = stage;
              stageDescription = desc;
            });
          }
        },
      );
    } catch (_) {
      success = false;
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (success) {
      _showSuccessNotification('admin.app_approved_toast'.tr());
    } else if (mounted) {
      _showErrorNotification('admin.review_changed'.tr());
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
                (app.revisionOf == null
                        ? 'admin.reject_application_body'
                        : 'admin.reject_edit_body')
                    .tr(namedArgs: {
                  'name': app
                      .getLocalizedApplicantName(context.locale.languageCode),
                }),
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'admin.reject_dialog_hint'.tr(),
                  hintStyle:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: const BorderSide(color: AppTheme.border),
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
                final reason = reasonController.text.trim();
                if (reason.isEmpty) return;
                try {
                  final success = await provider
                      .rejectBroadcasterApplication(app.id, reason: reason);
                  if (!success) throw StateError('Review changed');
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    _showSuccessNotification('admin.app_rejected_toast'.tr());
                  }
                } catch (_) {
                  if (mounted) {
                    _showErrorNotification('admin.review_changed'.tr());
                  }
                }
              },
              child: Text(app.revisionOf == null
                  ? 'admin.btn_reject'.tr()
                  : 'admin.reject_edit'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showApplicationDetailsDialog(
      BuildContext context, BroadcasterApplicationModel app, bool isAr) {
    final provider = context.read<AppProvider>();
    final bannerImage = resolveImageProviderOrNull(app.bannerUrl);
    final base =
        provider.applications.where((a) => a.id == app.revisionOf).firstOrNull;
    final changes = <({String label, String before, String after})>[];
    if (base != null) {
      void compare(String label, String before, String after) {
        if (before != after) {
          changes.add((label: label, before: before, after: after));
        }
      }

      compare('admin.field_email'.tr(), base.email, app.email);
      compare('admin.field_phone'.tr(), base.phone, app.phone);
      compare('profile.city'.tr(), base.cityId, app.cityId);
      compare('admin.venue'.tr(), isAr ? base.venueNameAr : base.venueNameEn,
          isAr ? app.venueNameAr : app.venueNameEn);
      compare('admin.location'.tr(), '${base.latitude}, ${base.longitude}',
          '${app.latitude}, ${app.longitude}');
      compare('YouTube', base.youtubeChannelUrl, app.youtubeChannelUrl);
      compare('YouTube @', base.youtubeHandle, app.youtubeHandle);
    }
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
                        image: bannerImage == null
                            ? null
                            : DecorationImage(
                                image: bannerImage,
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
                          border: Border.all(color: AppTheme.surface, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 34,
                          backgroundImage:
                              resolveImageProviderOrNull(app.avatarUrl),
                          child: app.avatarUrl.isEmpty
                              ? const Icon(Icons.person_outline_rounded)
                              : null,
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
                            Wrap(
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
                                Icon(
                                    app.isApproved
                                        ? Icons.verified_rounded
                                        : Icons.pending_outlined,
                                    color: AppTheme.primary,
                                    size: 18),
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
                        if (app.revisionOf != null) ...[
                          Text('admin.edit_after_verification'.tr(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          if (changes.isEmpty)
                            Text('admin.no_reviewed_changes'.tr()),
                          for (final change in changes)
                            _buildDetailRow(change.label,
                                '${change.before} → ${change.after}'),
                          const Divider(),
                        ],
                        _buildDetailRow('admin.field_email'.tr(), app.email),
                        _buildDetailRow('admin.field_phone'.tr(), app.phone),
                        _buildDetailRow('admin.field_youtube'.tr(),
                            '@${app.youtubeHandle}'),
                        _buildDetailRow(
                            'admin.field_youtube'.tr(), app.youtubeChannelUrl),
                        _buildDetailRow('admin.field_category'.tr(),
                            app.categoryId.replaceAll('_', ' ').toUpperCase()),
                        if (app.tags.isNotEmpty)
                          _buildDetailRow(
                              'admin.field_tags'.tr(), app.tags.join(' ')),
                        _buildDetailRow(
                          'admin.location'.tr(),
                          '${isAr ? app.venueNameAr : app.venueNameEn} (${app.latitude.toStringAsFixed(4)}, ${app.longitude.toStringAsFixed(4)})',
                        ),
                        const SizedBox(height: AppTheme.spaceSm),
                        const Divider(color: AppTheme.border),
                        const SizedBox(height: AppTheme.spaceSm),
                        Text(
                          'design_ui.research_biography_english'.tr(),
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
                    border: Border(top: BorderSide(color: AppTheme.border)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppTheme.spaceXs,
                    runSpacing: AppTheme.spaceXs,
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
                          label: Text(app.revisionOf == null
                              ? 'design_ui.approve_broadcaster'.tr()
                              : 'admin.approve_edit'.tr()),
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
                          label: Text(app.revisionOf == null
                              ? 'design_ui.reject'.tr()
                              : 'admin.reject_edit'.tr()),
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showRejectDialog(context, provider, app);
                          },
                        ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppTheme.danger, size: 20),
                        tooltip: 'Delete Application',
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _removeApplicationFromQueue(
                              context, provider, app);
                        },
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text('design_ui.close'.tr(),
                            style:
                                const TextStyle(color: AppTheme.textPrimary)),
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
    final title = Text(label,
        style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600));
    final detail = Text(value,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12));
    return LayoutBuilder(
        builder: (context, constraints) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: constraints.maxWidth < 400
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, detail])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          SizedBox(width: 140, child: title),
                          Expanded(child: detail),
                        ]),
            ));
  }

  Future<void> _removeApplicationFromQueue(BuildContext context,
      AppProvider provider, BroadcasterApplicationModel app) async {
    final remove = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text('admin.remove_queue_title'.tr()),
              content: Text('admin.remove_queue_body'.tr()),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text('settings.cancel'.tr())),
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text('admin.btn_delete'.tr())),
              ],
            ));
    if (remove != true || !mounted) return;
    try {
      final success = await provider.deleteBroadcasterApplication(app.id);
      if (!success) throw StateError('Application changed');
      if (mounted) _showSuccessNotification('admin.app_deleted_toast'.tr());
    } catch (_) {
      if (mounted) _showErrorNotification('admin.review_changed'.tr());
    }
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
          Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            children: [
              SizedBox(
                width: double.infinity,
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
                      borderSide: const BorderSide(color: AppTheme.border),
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
                  child: Wrap(
                    spacing: AppTheme.spaceSm,
                    runSpacing: AppTheme.spaceSm,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                      SizedBox(
                        width: MediaQuery.sizeOf(context).width < 600
                            ? MediaQuery.sizeOf(context).width - 160
                            : 320,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
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
                            // The server records who changed map visibility
                            // and why; it refuses a blank reason.
                            final reason = await askSafetyReason(
                              context,
                              title: (hidden
                                      ? 'admin.hide_from_map_confirm_title'
                                      : 'admin.show_on_map_title')
                                  .tr(),
                              body: (hidden
                                      ? 'admin.hide_from_map_confirm_body'
                                      : 'admin.show_on_map_body')
                                  .tr(),
                            );
                            if (reason == null || !context.mounted) return;
                            final success =
                                await provider.setStreamerHiddenFromMap(
                                    streamerId: s.streamerId,
                                    hidden: hidden,
                                    reason: reason);
                            if (!success) {
                              _showErrorNotification(
                                  'admin.map_visibility_failed'.tr());
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

                      // Revoke broadcaster approval (Non-Protected). This
                      // withdraws broadcasting rights through the audited
                      // server action; it does not delete the account --
                      // account deletion lives in User Directory (P6-R09).
                      if (!isProtected)
                        IconButton(
                          icon: const Icon(Icons.person_off_rounded,
                              size: 16, color: AppTheme.danger),
                          tooltip: 'admin.revoke_broadcaster_tooltip'.tr(),
                          onPressed: () async {
                            final reason = await askSafetyReason(
                              context,
                              title: 'admin.revoke_broadcaster_title'.tr(),
                              body: 'admin.revoke_broadcaster_body'.tr(),
                            );
                            if (reason == null || !context.mounted) return;
                            final success = await provider
                                .revokeBroadcasterApproval(s.streamerId,
                                    reason: reason);
                            if (success) {
                              _showSuccessNotification(
                                  'admin.revoke_broadcaster_done'.tr());
                            } else {
                              _showErrorNotification(
                                  'admin.revoke_broadcaster_failed'.tr());
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('admin.tab_viewers'.tr(),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppTheme.spaceLg),
        Text('admin.analytics_unavailable'.tr()),
      ]),
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
          Wrap(
            spacing: AppTheme.spaceMd,
            runSpacing: AppTheme.spaceMd,
            children: [
              Wrap(
                spacing: AppTheme.spaceSm,
                crossAxisAlignment: WrapCrossAlignment.center,
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
          Wrap(
            spacing: AppTheme.spaceMd,
            runSpacing: AppTheme.spaceMd,
            children: [
              SizedBox(
                width: MediaQuery.sizeOf(context).width < 900
                    ? double.infinity
                    : 320,
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
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              SizedBox(
                width: MediaQuery.sizeOf(context).width < 900
                    ? double.infinity
                    : 320,
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
                          borderSide: const BorderSide(color: AppTheme.border),
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
