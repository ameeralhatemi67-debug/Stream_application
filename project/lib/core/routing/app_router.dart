import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/ds/ca_focus_ring.dart';
import '../widgets/ds/ca_icon.dart';
import '../widgets/ds/ca_navigation.dart';
import '../widgets/floating_stream_mini_player.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/auth/presentation/viewer_setup_screen.dart';
import '../../features/auth/presentation/role_select_screen.dart';
import '../../features/auth/presentation/streamer_apply_screen.dart';
import '../../features/auth/presentation/application_pending_screen.dart';
import '../../features/map/presentation/spatial_map_screen.dart';
import '../../features/discovery/presentation/discovery_feed_screen.dart';
import '../../features/profile/presentation/broadcaster_profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/live_stream/presentation/live_broadcast_screen.dart';
// Admin surfaces are loaded on demand (deferred) so every visitor does not
// download the admin hub and organization management code (audit WEB-04).
import '../../features/admin/presentation/admin_hub_screen.dart'
    deferred as admin_hub;
import '../../features/admin/presentation/org_admin_screen.dart'
    deferred as org_admin;
import '../../features/organization/presentation/org_invitation_screen.dart';
import '../../features/organization/presentation/channel_connections_screen.dart';
import '../../features/organization/presentation/channel_consent_return_screen.dart';
import '../../features/organization/presentation/organization_shows_screen.dart';
import '../../features/organization/presentation/organization_hub_screen.dart';
import '../../features/splash/presentation/app_splash_screen.dart';
import '../../features/auth/presentation/screens/account_banned_screen.dart';
import '../widgets/hadayah_loading_indicator.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> _feedNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'feedBranch');
  static final GlobalKey<NavigatorState> _mapNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'mapBranch');

  static GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;

  /// Routes that require a live, authenticated Supabase session.
  /// See doc/Audit/01_Security_Data_Protection_Audit.md VULN-RBAC-01.
  static const Set<String> _authGuardedPaths = {
    '/admin',
    '/org-admin',
    '/channels',
    '/shows',
    '/organizations',
    '/channel-connected',
    '/settings',
    '/streamer-apply',
    '/application-pending',
  };

  /// Builds the app's router bound to a single [AppProvider] instance.
  /// Must be created once (e.g. in a State.initState), not per-build --
  /// GoRouter expects a stable instance so its internal navigation state
  /// survives widget rebuilds.
  static GoRouter build(AppProvider provider) => GoRouter(
        navigatorKey: _rootNavigatorKey,
        initialLocation: '/splash',
        // Re-evaluates `redirect` whenever auth state changes (sign-in
        // completing after the OAuth redirect, sign-out, role refresh) --
        // without this, GoRouter would only re-check on navigation.
        refreshListenable: _RouteGate(provider),
        redirect: (context, state) {
          final path = state.matchedLocation;
          final isLoggedIn = provider.isLoggedInStreamer;
          if (isLoggedIn && provider.authHydrating) {
            return path == '/splash'
                ? null
                : Uri(
                    path: '/splash',
                    queryParameters: {'from': state.uri.toString()}).toString();
          }
          if (isLoggedIn &&
              provider.pendingOrganizationInvitation != null &&
              !path.startsWith('/org-invite/') && !provider.isCurrentUserBanned) {
            return provider.pendingOrganizationInvitation;
          }
          if (isLoggedIn &&
              !provider.hasCompletedRoleSelection &&
              !provider.isApprovedStreamer &&
              !provider.isAdminUser &&
              provider.myApplication == null &&
              path != '/role-select' &&
              !path.startsWith('/org-invite/') &&
              path != '/account-banned' &&
              !provider.isCurrentUserBanned) {
            return '/role-select';
          }

          if (path == '/splash' && state.uri.queryParameters['from'] != null) {
            return state.uri.queryParameters['from'];
          }

          // Cluster 4 Task 16: a platform-banned account is locked out of the
          // entire app (not just guarded paths) until they sign out -- checked
          // ahead of the guarded-paths block so it also covers /feed and /map.
          if (isLoggedIn &&
              provider.isCurrentUserBanned &&
              path != '/account-banned') {
            return '/account-banned';
          }
          if (path == '/account-banned' && !provider.isCurrentUserBanned) {
            return isLoggedIn ? '/feed' : '/welcome';
          }

          if (_authGuardedPaths.contains(path)) {
            if (!isLoggedIn) return '/welcome';
            if (path == '/admin' &&
                !provider.adminRoleLoading &&
                !provider.isAdminUser) {
              return '/feed';
            }
            if (path == '/org-admin' && !provider.isPermittedAdmin) {
              return '/feed';
            }
            return null;
          }

          // Once a session exists, route users who haven't selected a role or applied
          // to the Role Select screen; otherwise route to Discovery feed.
          if (path == '/welcome' && isLoggedIn) {
            if (!provider.hasCompletedRoleSelection &&
                !provider.isApprovedStreamer) {
              return '/role-select';
            }
            return '/feed';
          }

          // Handle OAuth callback deep link redirects (e.g. sa.hadayah.streamerapp://login-callback)
          // gracefully without ever falling through to "Route Not Found". Must
          // mirror the '/welcome'branch's role-select gate above -- routing
          // straight to '/feed'here skipped the broadcaster onboarding prompt
          // entirely on every fresh Google sign-in (issue_log.md: "I did not
          // get a prompt to start the onboarding to be a streamer, it just
          // opened the Discovery tab").
          if (state.uri.host == 'login-callback' ||
              path == '/login-callback' ||
              state.uri.path == '/login-callback') {
            if (!isLoggedIn) return '/welcome';
            if (!provider.hasCompletedRoleSelection &&
                !provider.isApprovedStreamer) {
              return '/role-select';
            }
            return '/feed';
          }

          return null;
        },
        errorBuilder: (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 64, color: AppTheme.danger),
                const SizedBox(height: AppTheme.spaceLg),
                Text(
                  'Route Not Found (${state.error?.message ?? state.uri.toString()})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppTheme.spaceMd),
                ElevatedButton(
                  onPressed: () => context.go('/feed'),
                  child: Text('design_ui.back_to_discovery_feed'.tr()),
                ),
              ],
            ),
          ),
        ),
        routes: [
          GoRoute(parentNavigatorKey:_rootNavigatorKey,path:'/shows',builder:(context,state)=>
            OrganizationShowsScreen(initialOrganizationId:state.uri.queryParameters['org'])),
          GoRoute(parentNavigatorKey:_rootNavigatorKey,path:'/organizations',
            builder:(context,state)=>const OrganizationHubScreen()),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/login-callback',
            name: 'login-callback',
            builder: (context, state) => const AppSplashScreen(),
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/splash',
            name: 'splash',
            builder: (context, state) => const AppSplashScreen(),
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/welcome',
            name: 'welcome',
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/viewer-setup',
            name: 'viewer-setup',
            builder: (context, state) => const ViewerSetupScreen(),
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/role-select',
            name: 'role-select',
            builder: (context, state) => const RoleSelectScreen(),
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/streamer-apply',
            name: 'streamer-apply',
            builder: (context, state) => const StreamerApplyScreen(),
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/application-pending',
            name: 'application-pending',
            builder: (context, state) => const ApplicationPendingScreen(),
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/onboarding',
            name: 'onboarding',
            builder: (context, state) => const WelcomeScreen(),
          ),
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) {
              return ResponsiveScaffoldWithNestedNavigation(
                  navigationShell: navigationShell);
            },
            branches: [
              StatefulShellBranch(
                navigatorKey: _feedNavigatorKey,
                routes: [
                  GoRoute(
                    path: '/feed',
                    name: 'feed',
                    builder: (context, state) => const DiscoveryFeedScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                navigatorKey: _mapNavigatorKey,
                routes: [
                  GoRoute(
                    path: '/map',
                    name: 'map',
                    builder: (context, state) => const SpatialMapScreen(),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/profile/:id',
            name: 'profile',
            // A missing/empty channel id resolves to the feed instead of a sample
            // profile (P1.6).
            redirect: (context, state) =>
                (state.pathParameters['id'] ?? '').isEmpty ? '/feed' : null,
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return BroadcasterProfileScreen(streamerId: id,
                initialTab: state.uri.queryParameters['tab'] == 'upcoming' ? 2 : 0);
            },
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/live/:id',
            name: 'live',
            redirect: (context, state) =>
                (state.pathParameters['id'] ?? '').isEmpty ? '/feed' : null,
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return LiveBroadcastScreen(streamId: id);
            },
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/admin',
            name: 'admin',
            builder: (context, state) => context
                    .select<AppProvider, bool>((p) => p.adminRoleLoading)
                ? const Scaffold(body: Center(child: HadayahLoadingIndicator()))
                : _Deferred(
                    loader: admin_hub.loadLibrary,
                    builder: () => admin_hub.AdminHubScreen(),
                  ),
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/org-admin',
            name: 'orgAdmin',
            builder: (context, state) => _Deferred(
              loader: org_admin.loadLibrary,
              builder: () => org_admin.OrgAdminScreen(),
            ),
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/org-invite/:id',
            builder: (context, state) => OrgInvitationScreen(id: state.pathParameters['id']!,
              token: state.uri.queryParameters['token']),
          ),
          GoRoute(path:'/channels',parentNavigatorKey:_rootNavigatorKey,
            builder:(context,state)=>ChannelConnectionsScreen(returnStatus:state.uri.queryParameters['status'])),
          GoRoute(path:'/channel-connected',parentNavigatorKey:_rootNavigatorKey,
            builder:(context,state)=>ChannelConsentReturnScreen(returnStatus:state.uri.queryParameters['status'],
              navigatorKey:_rootNavigatorKey)),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/account-banned',
            name: 'accountBanned',
            builder: (context, state) => const AccountBannedScreen(),
          ),
        ],
      );
}

/// Responsive Scaffold supporting the persistent laptop side navigation and the
/// phone bottom navigation. Structure is master's; the look is the Canopy
/// design system's (CaNavBar pill on phones, gradient pill items on laptops).
class ResponsiveScaffoldWithNestedNavigation extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ResponsiveScaffoldWithNestedNavigation({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final (
      isStreamerModeEnabled,
      isAdminUser,
      isPermittedAdmin,
      hasPendingApplications,
      pendingCount
    ) = context.select<AppProvider, (bool, bool, bool, bool, int)>((p) => (
          p.isStreamerModeEnabled,
          p.isAdminUser,
          p.isPermittedAdmin,
          p.pendingApplications.isNotEmpty,
          p.pendingApplications.length,
        ));

    return Scaffold(
      backgroundColor: Canopy.dawn,
      body: Stack(
        children: [
          if (isDesktop)
            Row(
              children: [
                // Desktop persistent side navigation.
                SizedBox(
                  width: CanopySize.railExpanded,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Canopy.paper,
                      border: BorderDirectional(
                        end: BorderSide(color: Canopy.hairline, width: 1.0),
                      ),
                    ),
                    child: SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                minHeight: constraints.maxHeight),
                            child: IntrinsicHeight(
                              child: Padding(
                                padding: const EdgeInsets.all(AppTheme.spaceSm),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: AppTheme.spaceLg),
                                    const Center(
                                        child: AppLogo(
                                            size: CanopySize.railLogo)),
                                    const SizedBox(height: AppTheme.spaceXl),

                                    // Navigation Items
                                    _DesktopNavItem(
                                      icon: CaGlyph.list,
                                      label: 'nav.discovery_hub'.tr(),
                                      isSelected:
                                          navigationShell.currentIndex == 0,
                                      onTap: () => navigationShell.goBranch(0),
                                    ),
                                    _DesktopNavItem(
                                      icon: CaGlyph.map,
                                      label: 'nav.spatial_gis_map'.tr(),
                                      isSelected:
                                          navigationShell.currentIndex == 1,
                                      onTap: () => navigationShell.goBranch(1),
                                    ),
                                    if (isStreamerModeEnabled)
                                      _DesktopNavItem(
                                        icon: CaGlyph.user,
                                        label: 'ds.studio_profile'.tr(),
                                        isSelected: false,
                                        onTap: () {
                                          final ownId = context
                                              .read<AppProvider>()
                                              .currentUserStreamerId;
                                          context.push(
                                              ownId == null || ownId.isEmpty
                                                  ? '/feed'
                                                  : '/profile/$ownId');
                                        },
                                      ),
                                    _DesktopNavItem(
                                      icon: CaGlyph.gear,
                                      label: 'nav.settings'.tr(),
                                      isSelected: false,
                                      onTap: () => context.push('/settings'),
                                    ),
                                    if (isAdminUser)
                                      _DesktopNavItem(
                                        icon: CaGlyph.shield,
                                        label: 'settings.admin_hub_title'.tr(),
                                        badge: hasPendingApplications
                                            ? '$pendingCount'
                                            : null,
                                        isSelected: false,
                                        onTap: () => context.push('/admin'),
                                      ),
                                    if (isPermittedAdmin)
                                      _DesktopNavItem(
                                        icon: CaGlyph.home,
                                        label: 'design_ui.organization_admin'
                                            .tr(),
                                        isSelected: false,
                                        onTap: () =>
                                            context.push('/org-admin'),
                                      ),

                                    const Spacer(),

                                    // Streamer / Viewer Mode card
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: AppTheme.spaceMd,
                                          vertical: AppTheme.spaceSm),
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.pill,
                                        borderRadius: BorderRadius.circular(
                                            CanopyRadius.input),
                                      ),
                                      child: Row(
                                        children: [
                                          CaIcon(
                                            isStreamerModeEnabled
                                                ? CaGlyph.video
                                                : CaGlyph.user,
                                            color: Canopy.paper,
                                          ),
                                          const SizedBox(
                                              width: AppTheme.spaceSm),
                                          Expanded(
                                            child: Text(
                                              isStreamerModeEnabled
                                                  ? 'nav.streamer_mode'.tr()
                                                  : 'nav.viewer_mode'.tr(),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                      color: Canopy.paper,
                                                      fontWeight:
                                                          FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Main Content
                Expanded(child: navigationShell),
              ],
            )
          else
            navigationShell,

          // Global "Return to broadcast" shortcut (not a player; no PiP)
          const FloatingStreamMiniPlayer(),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : CaNavBar(
              index: navigationShell.currentIndex,
              onChanged: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
            ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  final CaGlyph icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Canopy.paper : Canopy.brandGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: CaFocusRing(
          onDark: isSelected,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(CanopyRadius.pill),
              child: ExcludeSemantics(
                child: Container(
                  constraints:
                      const BoxConstraints(minHeight: CanopySize.target),
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppGradients.pill : null,
                    borderRadius: BorderRadius.circular(CanopyRadius.pill),
                  ),
                  child: Row(
                    children: [
                      CaIcon(icon, color: color),
                      const SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Text(
                          label,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: isSelected
                                        ? Canopy.paper
                                        : Canopy.slate,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: AppTheme.spaceSm,
                              vertical: AppTheme.spaceXs / 2),
                          decoration: BoxDecoration(
                            color: Canopy.warning,
                            borderRadius:
                                BorderRadius.circular(CanopyRadius.pill),
                          ),
                          child: Text(
                            badge!,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: Canopy.paper,
                                    fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Notifies the router only when a field its `redirect` reads has changed.
/// The router used to listen to the whole [AppProvider], so each of its 150+
/// notifications (heartbeats, chat reports, toasts...) re-parsed the current
/// location and re-ran the redirect for nothing (audit RT-03).
class _RouteGate extends ChangeNotifier {
  _RouteGate(this._provider) {
    _signature = _read();
    _provider.addListener(_onProviderChanged);
  }

  final AppProvider _provider;
  late List<Object?> _signature;

  List<Object?> _read() => [
        _provider.isLoggedInStreamer,
        _provider.authHydrating,
        _provider.pendingOrganizationInvitation,
        _provider.isCurrentUserBanned,
        _provider.hasCompletedRoleSelection,
        _provider.isApprovedStreamer,
        _provider.isAdminUser,
        _provider.myApplication != null,
        _provider.adminRoleLoading,
        _provider.isPermittedAdmin,
      ];

  void _onProviderChanged() {
    final next = _read();
    var same = next.length == _signature.length;
    for (var i = 0; same && i < next.length; i++) {
      same = next[i] == _signature[i];
    }
    if (same) return;
    _signature = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    super.dispose();
  }
}

/// Shows [builder]'s widget once [loader] (a deferred library's loadLibrary)
/// has finished. On native targets deferred libraries are already present and
/// this resolves immediately.
class _Deferred extends StatefulWidget {
  const _Deferred({required this.loader, required this.builder});

  final Future<void> Function() loader;
  final Widget Function() builder;

  @override
  State<_Deferred> createState() => _DeferredState();
}

class _DeferredState extends State<_Deferred> {
  late final Future<void> _loaded = widget.loader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loaded,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: HadayahLoadingIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('offline_experience.offline_title'.tr(),
                  textAlign: TextAlign.center),
            ),
          );
        }
        return widget.builder();
      },
    );
  }
}
