import 'package:flutter/material.dart';
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
import '../../profile/models/streamer_models.dart';

/// Desktop Admin Moderation & Platform Governance Hub Screen
class AdminHubScreen extends StatefulWidget {
  const AdminHubScreen({super.key});

  @override
  State<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends State<AdminHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);

    final provider = context.read<AppProvider>();
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
            color: AppTheme.accentGreen,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
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
        ));
    final isAr = context.locale.languageCode == 'ar';
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    // Access Guard
    if (!provider.isAdminUser) {
      return Scaffold(
        backgroundColor: AppTheme.darkBgBase,
        appBar: AppBar(
          backgroundColor: AppTheme.darkSurface1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.textPrimaryDark),
            onPressed: () => context.go('/feed'),
          ),
          title: const Text('Access Denied'),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(AppTheme.spaceXl),
            margin: const EdgeInsets.all(AppTheme.spaceLg),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface1,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border:
                  Border.all(color: AppTheme.accentRed.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gpp_bad_rounded,
                    color: AppTheme.accentRed, size: 54),
                const SizedBox(height: AppTheme.spaceMd),
                const Text(
                  'Admin Access Required',
                  style: TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                const Text(
                  'Your account does not have Admin or Master Admin access. Ask a Master Admin to grant your account a role.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondaryDark,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLg),
                ElevatedButton(
                  onPressed: () => context.go('/settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Go to Account Settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBgBase,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminHeader(BuildContext context, AppProvider provider,
      bool isAr, bool isDesktop,
      {required bool isMasterAdmin}) {
    final tierLabel = isMasterAdmin ? 'MASTER ADMIN' : 'ADMIN';
    final tierColor =
        isMasterAdmin ? AppTheme.accentRed : AppTheme.accentBlue;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXl,
        vertical: AppTheme.spaceLg,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface1,
        border: Border(
          bottom: BorderSide(color: AppTheme.darkBorderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.textPrimaryDark),
            tooltip: 'Back to Discovery Feed',
            onPressed: () => context.go('/feed'),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                  color: AppTheme.accentPurple.withValues(alpha: 0.6)),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: AppTheme.accentPurple, size: 24),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'admin.title'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textPrimaryDark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: tierColor.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_rounded,
                              size: 11, color: tierColor),
                          const SizedBox(width: 4),
                          Text(
                            tierLabel,
                            style: TextStyle(
                              color: tierColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'admin.subtitle'.tr(),
                  style: const TextStyle(
                    color: AppTheme.textSecondaryDark,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

          // Admin User Info Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface2,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.darkBorderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.accentBlue.withValues(alpha: 0.2),
                  child: const Icon(Icons.person_rounded,
                      size: 14, color: AppTheme.accentBlue),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.googleUserName ?? 'Amir Al-Hatemi',
                      style: const TextStyle(
                        color: AppTheme.textPrimaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      provider.googleUserEmail ?? 'polkgvd2@gmail.com',
                      style: const TextStyle(
                        color: AppTheme.textMutedDark,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(AppProvider provider) {
    final pendingCount = provider.pendingApplications.length;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface1,
        border: Border(
          bottom: BorderSide(color: AppTheme.darkBorderSubtle, width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppTheme.accentBlue,
        indicatorWeight: 3,
        labelColor: AppTheme.accentBlue,
        unselectedLabelColor: AppTheme.textSecondaryDark,
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
                      color: AppTheme.accentAmber,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(
                        color: Colors.black87,
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
                  color: AppTheme.accentBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'admin.tab_overview'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
                color: AppTheme.accentRed,
              ),
              _buildKpiCard(
                title: 'admin.kpi_verified_scholars'.tr(),
                value: '$verifiedScholars',
                icon: Icons.school_rounded,
                color: AppTheme.accentBlue,
              ),
              _buildKpiCard(
                title: 'admin.kpi_org_venues'.tr(),
                value: '$orgVenues',
                icon: Icons.apartment_rounded,
                color: AppTheme.accentPurple,
              ),
              _buildKpiCard(
                title: 'admin.kpi_pending_apps'.tr(),
                value: '$pendingApps',
                icon: Icons.pending_actions_rounded,
                color: AppTheme.accentAmber,
              ),
              _buildKpiCard(
                title: 'admin.kpi_active_viewers'.tr(),
                value: '$activeViewers',
                icon: Icons.group_rounded,
                color: AppTheme.accentGreen,
              ),
              _buildKpiCard(
                title: 'admin.kpi_auditorium_seats'.tr(),
                value: '$totalAuditoriumSeats',
                icon: Icons.event_seat_rounded,
                color: const Color(0xFF38BDF8),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXl),

          // Quick Action Shortcuts
          const Text(
            'Quick Actions & Governance Shortcuts',
            style: TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            children: [
              Expanded(
                child: _buildActionShortcutCard(
                  title: 'Review Verification Queue',
                  subtitle: '$pendingApps pending applications awaiting review',
                  icon: Icons.rate_review_rounded,
                  color: AppTheme.accentAmber,
                  onTap: () => _tabController.animateTo(1),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: _buildActionShortcutCard(
                  title: 'Inspect Spatial GIS Map',
                  subtitle: 'View live auditoriums in Al Khobar & Dhahran',
                  icon: Icons.map_rounded,
                  color: AppTheme.accentBlue,
                  onTap: () => context.go('/map'),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: _buildActionShortcutCard(
                  title: 'Edit Platform Terms',
                  subtitle: 'Update bilingual policies and Saudi PDPL terms',
                  icon: Icons.edit_document,
                  color: AppTheme.accentPurple,
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
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
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
          color: AppTheme.darkSurface1,
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
                      color: AppTheme.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
                    activeColor: AppTheme.accentBlue,
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
                      color: AppTheme.textPrimaryDark, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'admin.search_applications'.tr(),
                    hintStyle: const TextStyle(
                        color: AppTheme.textSecondaryDark, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppTheme.textSecondaryDark, size: 18),
                    filled: true,
                    fillColor: AppTheme.darkSurface1,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide:
                          const BorderSide(color: AppTheme.darkBorderSubtle),
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
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded,
                            size: 48, color: AppTheme.textSecondaryDark),
                        SizedBox(height: 12),
                        Text(
                          'No applications match the selected filter.',
                          style: TextStyle(color: AppTheme.textSecondaryDark),
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
                      return _buildApplicationCard(context, provider, app, isAr);
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
        color: AppTheme.accentBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_box_rounded,
              size: 16, color: AppTheme.accentBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count application${count == 1 ? '' : 's'} selected',
              style: const TextStyle(
                color: AppTheme.textPrimaryDark,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _selectedApplicationIds.clear()),
            child: Text('Clear',
                style: const TextStyle(color: AppTheme.textSecondaryDark)
                    .copyWith(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentRed,
              side: const BorderSide(color: AppTheme.accentRed),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 15),
            label: const Text('Reject Selected'),
            onPressed: () => _showBulkRejectDialog(context, provider),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.done_all_rounded, size: 15),
            label: const Text('Approve Selected'),
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
          backgroundColor: AppTheme.darkSurface1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: const BorderSide(color: AppTheme.darkBorderSubtle),
          ),
          title: const Text(
            'Approve Selected Applications?',
            style: TextStyle(
                color: AppTheme.textPrimaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          content: Text(
            'This will approve ${ids.length} pending application${ids.length == 1 ? '' : 's'}, creating a live broadcaster profile for each.',
            style:
                const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12),
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
                backgroundColor: AppTheme.accentGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final result = await provider.bulkApproveBroadcasterApplications(
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
          backgroundColor: AppTheme.darkSurface1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: const BorderSide(color: AppTheme.darkBorderSubtle),
          ),
          title: Text(
            'Reject ${ids.length} Selected Application${ids.length == 1 ? '' : 's'}?',
            style: const TextStyle(
                color: AppTheme.textPrimaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This feedback note is sent to every selected applicant:',
                style: TextStyle(
                    color: AppTheme.textSecondaryDark, fontSize: 12),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(
                    color: AppTheme.textPrimaryDark, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'admin.reject_dialog_hint'.tr(),
                  hintStyle: const TextStyle(
                      color: AppTheme.textMutedDark, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.darkSurface2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide:
                        const BorderSide(color: AppTheme.darkBorderSubtle),
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
                style: const TextStyle(color: AppTheme.textMutedDark),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
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
      selectedColor: AppTheme.accentBlue.withValues(alpha: 0.2),
      backgroundColor: AppTheme.darkSurface1,
      labelStyle: TextStyle(
        color:
            isSelected ? AppTheme.accentBlue : AppTheme.textSecondaryDark,
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color:
            isSelected ? AppTheme.accentBlue : AppTheme.darkBorderSubtle,
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
        statusColor = AppTheme.accentGreen;
        statusText = 'APPROVED';
        break;
      case ApplicationStatus.rejected:
        statusColor = AppTheme.accentRed;
        statusText = 'REJECTED';
        break;
      case ApplicationStatus.pending:
      default:
        statusColor = AppTheme.accentAmber;
        statusText = 'PENDING REVIEW';
        break;
    }

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (app.status == ApplicationStatus.pending)
                Padding(
                  padding: const EdgeInsets.only(right: 4, top: 4),
                  child: Checkbox(
                    value: _selectedApplicationIds.contains(app.id),
                    activeColor: AppTheme.accentBlue,
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
                backgroundColor: AppTheme.darkSurface2,
                backgroundImage: AssetImage(app.avatarUrl),
                child: app.avatarUrl.isEmpty
                    ? Icon(
                        app.isOrganization
                            ? Icons.apartment_rounded
                            : Icons.person_rounded,
                        color: AppTheme.textSecondaryDark)
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
                              color: AppTheme.textPrimaryDark,
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
                                ? AppTheme.accentPurple.withValues(alpha: 0.15)
                                : AppTheme.accentBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: app.isOrganization
                                  ? AppTheme.accentPurple.withValues(alpha: 0.6)
                                  : AppTheme.accentBlue.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Text(
                            app.isOrganization
                                ? 'ORGANIZATION VENUE'
                                : 'SCHOLAR',
                            style: TextStyle(
                              color: app.isOrganization
                                  ? AppTheme.accentPurple
                                  : AppTheme.accentBlue,
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
                        color: AppTheme.textMutedDark,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app.isOrganization
                          ? '🏛️ Venue: ${isAr ? app.venueNameAr : app.venueNameEn} • Capacity: ${app.seatingCapacity} seats • GPS: (${app.latitude.toStringAsFixed(4)}, ${app.longitude.toStringAsFixed(4)})'
                          : '🎓 Title: ${isAr ? (app.academicTitleAr ?? '') : (app.academicTitleEn ?? '')} • Institution: ${isAr ? (app.institutionAr ?? '') : (app.institutionEn ?? '')}',
                      style: const TextStyle(
                        color: AppTheme.textSecondaryDark,
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
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.white,
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
                        foregroundColor: AppTheme.accentRed,
                        side: const BorderSide(color: AppTheme.accentRed),
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
                        foregroundColor: AppTheme.accentBlue,
                        side:
                            const BorderSide(color: AppTheme.darkBorderSubtle),
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
                          size: 18, color: AppTheme.accentRed),
                      tooltip: 'admin.btn_delete'.tr(),
                      onPressed: () async {
                        await provider.deleteBroadcasterApplication(app.id);
                        _showSuccessNotification('admin.app_deleted_toast'.tr());
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
                color: AppTheme.darkSurface2,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                    color: AppTheme.accentRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.rate_review_outlined,
                      size: 14, color: AppTheme.accentRed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Admin Review Notes: ${app.adminReviewNotes}',
                      style: const TextStyle(
                          color: AppTheme.textSecondaryDark, fontSize: 11),
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
    final success = await provider.approveBroadcasterApplication(
      app.id,
      adminNotes: 'Verified official credentials and venue facilities.',
    );
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
          backgroundColor: AppTheme.darkSurface1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: const BorderSide(color: AppTheme.darkBorderSubtle),
          ),
          title: Text(
            'admin.reject_dialog_title'.tr(),
            style: const TextStyle(
                color: AppTheme.textPrimaryDark,
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
                    color: AppTheme.textSecondaryDark, fontSize: 12),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(
                    color: AppTheme.textPrimaryDark, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'admin.reject_dialog_hint'.tr(),
                  hintStyle: const TextStyle(
                      color: AppTheme.textMutedDark, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.darkSurface2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide:
                        const BorderSide(color: AppTheme.darkBorderSubtle),
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
                style: const TextStyle(color: AppTheme.textMutedDark),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
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
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.darkSurface1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: const BorderSide(color: AppTheme.darkBorderSubtle),
          ),
          title: Row(
            children: [
              Icon(
                app.isOrganization
                    ? Icons.apartment_rounded
                    : Icons.school_rounded,
                color: AppTheme.accentBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAr ? app.applicantNameAr : app.applicantNameEn,
                  style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Account Type',
                      app.isOrganization ? 'Organization Venue' : 'Individual Scholar'),
                  _buildDetailRow('Email', app.email),
                  _buildDetailRow('Phone', app.phone),
                  if (!app.isOrganization) ...[
                    _buildDetailRow('Academic Title',
                        '${app.academicTitleEn ?? ''} / ${app.academicTitleAr ?? ''}'),
                    _buildDetailRow('Institution',
                        '${app.institutionEn ?? ''} / ${app.institutionAr ?? ''}'),
                  ] else ...[
                    _buildDetailRow('Organization Type',
                        app.organizationType ?? 'Academic Entity'),
                    _buildDetailRow('Auditorium Name',
                        '${app.venueNameEn} / ${app.venueNameAr}'),
                    _buildDetailRow('Seating Capacity',
                        '${app.seatingCapacity} seats'),
                    _buildDetailRow('GPS Coordinates',
                        'Lat: ${app.latitude}, Lng: ${app.longitude}'),
                    _buildDetailRow('Website',
                        app.officialWebsiteUrl ?? 'N/A'),
                  ],
                  _buildDetailRow('YouTube Channel', app.youtubeChannelUrl),
                  _buildDetailRow('YouTube Handle', '@${app.youtubeHandle}'),
                  _buildDetailRow('Research Bio (En)', app.bioEn),
                  _buildDetailRow('Research Bio (Ar)', app.bioAr),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkSurface2,
                foregroundColor: AppTheme.textPrimaryDark,
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
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
                color: AppTheme.textMutedDark,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimaryDark,
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
                      color: AppTheme.textPrimaryDark, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'admin.search_streamers'.tr(),
                    hintStyle: const TextStyle(
                        color: AppTheme.textSecondaryDark, fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppTheme.textSecondaryDark, size: 18),
                    filled: true,
                    fillColor: AppTheme.darkSurface1,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide:
                          const BorderSide(color: AppTheme.darkBorderSubtle),
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
                    color: AppTheme.darkSurface1,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.darkBorderSubtle),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.darkSurface2,
                        backgroundImage: AssetImage(s.avatarUrl),
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
                                    color: AppTheme.textPrimaryDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (s.isVerified)
                                  const Icon(Icons.verified_rounded,
                                      size: 14, color: AppTheme.accentBlue),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: s.isOrganization
                                        ? AppTheme.accentPurple
                                            .withValues(alpha: 0.15)
                                        : AppTheme.accentBlue
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    s.isOrganization ? 'ORG VENUE' : 'SCHOLAR',
                                    style: TextStyle(
                                      color: s.isOrganization
                                          ? AppTheme.accentPurple
                                          : AppTheme.accentBlue,
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
                                color: AppTheme.textSecondaryDark,
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
                              ? AppTheme.accentRed.withValues(alpha: 0.15)
                              : AppTheme.darkSurface2,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(
                            color: s.isCurrentlyLive
                                ? AppTheme.accentRed
                                : AppTheme.darkBorderSubtle,
                          ),
                        ),
                        child: Text(
                          s.isCurrentlyLive ? '🔴 LIVE' : 'OFFLINE',
                          style: TextStyle(
                            color: s.isCurrentlyLive
                                ? AppTheme.accentRed
                                : AppTheme.textMutedDark,
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
                              size: 16, color: AppTheme.accentAmber),
                          tooltip: 'admin.tab_organizations'.tr(),
                          onPressed: () {
                            _tabController.animateTo(3);
                          },
                        ),

                      // Edit Button
                      IconButton(
                        icon: const Icon(Icons.edit_rounded,
                            size: 16, color: AppTheme.accentBlue),
                        tooltip: 'Edit Broadcaster',
                        onPressed: () =>
                            StreamerEditorSheet.show(context, streamer: s),
                      ),

                      // Delete Button (Non-Protected)
                      if (!isProtected)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 16, color: AppTheme.accentRed),
                          tooltip: 'Delete Streamer',
                          onPressed: () {
                            provider.deleteStreamer(s.streamerId);
                            _showSuccessNotification(
                                'Broadcaster profile removed.');
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
      selectedColor: AppTheme.accentPurple.withValues(alpha: 0.2),
      backgroundColor: AppTheme.darkSurface1,
      labelStyle: TextStyle(
        color: isSelected
            ? AppTheme.accentPurple
            : AppTheme.textSecondaryDark,
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? AppTheme.accentPurple
            : AppTheme.darkBorderSubtle,
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
                  color: AppTheme.accentBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'admin.tab_viewers'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimaryDark,
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
                color: AppTheme.accentBlue,
              ),
              _buildKpiCard(
                title: 'admin.registered_users'.tr(),
                value: '${analytics.totalRegisteredGoogleUsers}',
                icon: Icons.account_circle_rounded,
                color: AppTheme.accentGreen,
              ),
              _buildKpiCard(
                title: 'admin.auditorium_rsvps'.tr(),
                value: '${analytics.totalAuditoriumRsvps}',
                icon: Icons.event_seat_rounded,
                color: AppTheme.accentPurple,
              ),
              _buildKpiCard(
                title: 'admin.lecture_bookmarks'.tr(),
                value: '${analytics.totalLectureBookmarks}',
                icon: Icons.bookmark_added_rounded,
                color: AppTheme.accentAmber,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXl),

          // Geographic Distribution Card
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface1,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.darkBorderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AlSharqia Regional Engagement Breakdown',
                  style: TextStyle(
                    color: AppTheme.textPrimaryDark,
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
                    color: AppTheme.textSecondaryDark, fontSize: 12)),
            Text(detail,
                style: const TextStyle(
                    color: AppTheme.accentBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: AppTheme.darkSurface2,
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
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
                      color: AppTheme.accentBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'admin.tab_terms'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
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
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimaryDark,
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
                          color: AppTheme.textSecondaryDark, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: controllerEn,
                      maxLines: 5,
                      style: const TextStyle(
                          color: AppTheme.textPrimaryDark, fontSize: 12),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.darkSurface2,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          borderSide: const BorderSide(
                              color: AppTheme.darkBorderSubtle),
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
                          color: AppTheme.textSecondaryDark, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: controllerAr,
                      maxLines: 5,
                      style: const TextStyle(
                          color: AppTheme.textPrimaryDark, fontSize: 12),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.darkSurface2,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          borderSide: const BorderSide(
                              color: AppTheme.darkBorderSubtle),
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
