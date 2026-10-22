import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import 'legacy_links.dart';
import '../widgets/app_logo.dart';
import '../widgets/ds/ca_focus_ring.dart';
import '../widgets/ds/ca_icon.dart';
import '../widgets/ds/ca_navigation.dart';
import '../widgets/ds/canopy_motion.dart';
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
import '../../features/web/presentation/hidayah_web_header.dart';
import '../../features/web/presentation/hidayah_web_kit.dart';
import '../widgets/hadayah_loading_indicator.dart';
import '../../features/lessons/domain/lessons_rules.dart';
import '../../features/lessons/presentation/screens/account_screens.dart';
import '../../features/lessons/presentation/screens/console_screen.dart';
import '../../features/lessons/presentation/screens/detail_screens.dart';
import '../../features/lessons/presentation/screens/discover_screen.dart';
import '../../features/lessons/presentation/screens/lessons_screen.dart';
import '../../features/lessons/presentation/screens/preacher_screens.dart';
import '../../features/lessons/presentation/lessons_shell.dart';
import '../../features/lessons/state/lessons_controller.dart';

class AppRouter {
  /// Opens a page from the card that was tapped (its rectangle arrives as
  /// [GoRouterState.extra]); without one it is the regular page push.
  static Page<void> _canopyPage(
      BuildContext context, GoRouterState state, Widget child) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return CupertinoPage<void>(key: state.pageKey, child: child);
    }
    final origin = state.extra is Rect ? state.extra as Rect : null;
    return CustomTransitionPage<void>(
        key: state.pageKey,
        child: child,
        transitionDuration: CanopyMotion.reduced(context)
            ? CanopyMotion.none
            : origin == null
                ? CanopyMotion.pagePush
                : CanopyMotion.cardToPage,
        reverseTransitionDuration: CanopyMotion.reduced(context)
            ? CanopyMotion.none
            : CanopyMotion.sheetOut,
        transitionsBuilder: (context, animation, secondary, child) =>
            canopyPageTransition(context, animation, child, origin: origin));
  }

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> _feedNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'feedBranch');
  static final GlobalKey<NavigatorState> _mapNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'mapBranch');
  static final GlobalKey<NavigatorState> _lessonsNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'lessonsBranch');

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
  static GoRouter build(AppProvider provider) {
    // Pages opened with push (channel, live, sign-in) show their own address
    // on the web, so a channel or live link can be copied, shared and
    // reloaded; it used to stay on #/feed (audit 2026-10-21, P0-5).
    GoRouter.optionURLReflectsImperativeAPIs = true;
    return GoRouter(
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
              !path.startsWith('/org-invite/') &&
              !provider.isCurrentUserBanned) {
            return provider.pendingOrganizationInvitation;
          }
          if (provider.needsRoleSelection &&
              path != '/role-select' &&
              !path.startsWith('/org-invite/') &&
              path != '/account-banned' &&
              !provider.isCurrentUserBanned) {
            return '/role-select';
          }

          if (path == '/splash' && state.uri.queryParameters['from'] != null) {
            return state.uri.queryParameters['from'];
          }

          // Links from before the lessons were renamed (2026-10-22).
          final legacy = legacyLessonsLocation(state.uri);
          if (legacy != null) return legacy;

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
          // to the Role Select screen; otherwise back to the page that asked
          // for sign-in (chat, reminders), or the Discovery feed.
          if (path == '/welcome' && isLoggedIn) {
            if (!provider.hasCompletedRoleSelection &&
                !provider.isApprovedStreamer) {
              return '/role-select';
            }
            return provider.takeSignInReturn() ?? '/feed';
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
            return provider.takeSignInReturn() ?? '/feed';
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
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/shows',
              builder: (context, state) => OrganizationShowsScreen(
                  initialOrganizationId: state.uri.queryParameters['org'])),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/organizations',
              builder: (context, state) => const OrganizationHubScreen()),
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
                    // ?mosque= opens on a mosque's lessons (links from
                    // lesson and mosque pages).
                    builder: (context, state) => SpatialMapScreen(
                        initialMosque: state.uri.queryParameters['mosque']),
                  ),
                ],
              ),
              // Mosque lessons are a tab of Hadayah Live (ADR-014). Public
              // pages need no sign-in; screens that act check roles
              // themselves and the server enforces every write. Lesson pages
              // and the console open above the tabs.
              StatefulShellBranch(
                navigatorKey: _lessonsNavigatorKey,
                routes: [
                  GoRoute(
                    path: '/lessons',
                    name: 'lessons',
                    builder: (context, state) =>
                        const LessonsTab(child: LessonsDiscoverScreen()),
                    routes: [
                      GoRoute(
                          path: 'calendar',
                          builder: (context, state) {
                            final q = state.uri.queryParameters;
                            return LessonsTab(
                                titleKey: 'lessons.nav.lessons',
                                child: LessonsScreen(
                                    key: ValueKey(state.uri.query),
                                    initial: LessonFilter(
                                        language: q['lang'],
                                        topic: q['topic'],
                                        mosqueId: q['mosque'],
                                        preacherId: q['preacher'],
                                        city: q['city'])));
                          }),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Old /taysir links (up to three segments deep) open their new
          // address.
          GoRoute(
              path: '/taysir',
              redirect: (context, state) => legacyLessonsLocation(state.uri),
              routes: [
                GoRoute(
                    path: ':a',
                    redirect: (context, state) =>
                        legacyLessonsLocation(state.uri),
                    routes: [
                      GoRoute(
                          path: ':b',
                          redirect: (context, state) =>
                              legacyLessonsLocation(state.uri),
                          routes: [
                            GoRoute(
                                path: ':c',
                                redirect: (context, state) =>
                                    legacyLessonsLocation(state.uri)),
                          ]),
                    ]),
              ]),
          // Mosques and their lessons are on the one map now.
          GoRoute(
              path: '/lessons/map',
              redirect: (context, state) => Uri(
                      path: '/map',
                      queryParameters: state.uri.queryParameters.isEmpty
                          ? null
                          : state.uri.queryParameters)
                  .toString()),
          // A person's programme pages, opened from Settings.
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/me',
              builder: (context, state) => const LessonsMeScreen()),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/lesson/:id',
              builder: (context, state) => LessonScreen(id: state.pathParameters['id']!)),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/requests/:id',
              redirect: (context, state) {
                final c = context.read<LessonsController>();
                final id = state.pathParameters['id'];
                final hit = c.catalog.lessons.values.where((l) => l.requestId == id).toList()..sort(compareLessons);
                return hit.isEmpty ? '/lessons/calendar' : '/lessons/lesson/${hit.first.id}';
              }),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/series/:id',
              builder: (context, state) => LessonSeriesScreen(id: state.pathParameters['id']!)),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/preachers/:id',
              builder: (context, state) => PreacherScreen(id: state.pathParameters['id']!)),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/mosques/:id',
              builder: (context, state) => MosqueScreen(id: state.pathParameters['id']!)),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/me/notifications',
              builder: (context, state) => const LessonsNotificationsScreen()),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/me/saved',
              builder: (context, state) => LessonsSavedScreen(tab: state.uri.queryParameters['tab'])),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/me/lessons',
              builder: (context, state) => LessonsMyLessonsScreen(tab: state.uri.queryParameters['tab'])),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/submit',
              builder: (context, state) => LessonsSubmitScreen(
                  key: ValueKey(state.uri.query),
                  fromLessonId: state.uri.queryParameters['from'],
                  replaces: state.uri.queryParameters['replaces'])),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/report/:id',
              builder: (context, state) => LessonsReportScreen(lessonId: state.pathParameters['id']!)),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/claim/:token',
              builder: (context, state) => LessonsClaimScreen(token: state.pathParameters['token']!)),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/permissions',
              builder: (context, state) => const LessonsPermissionsScreen()),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/console',
              builder: (context, state) => LessonsConsoleScreen(filter: state.uri.queryParameters['filter'])),
          GoRoute(
              parentNavigatorKey: _rootNavigatorKey,
              path: '/lessons/console/:tab',
              builder: (context, state) => LessonsConsoleScreen(
                  key: ValueKey(state.uri.toString()),
                  tab: state.pathParameters['tab']!,
                  filter: state.uri.queryParameters['filter'])),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/profile/:id',
            name: 'profile',
            // A missing/empty channel id resolves to the feed instead of a sample
            // profile (P1.6).
            redirect: (context, state) =>
                (state.pathParameters['id'] ?? '').isEmpty ? '/feed' : null,
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return _canopyPage(
                  context,
                  state,
                  BroadcasterProfileScreen(
                      streamerId: id,
                      initialTab: state.uri.queryParameters['tab'] == 'upcoming'
                          ? 2
                          : 0));
            },
          ),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/live/:id',
            name: 'live',
            redirect: (context, state) =>
                (state.pathParameters['id'] ?? '').isEmpty ? '/feed' : null,
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return _canopyPage(
                  context, state, LiveBroadcastScreen(streamId: id));
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
            builder: (context, state) => OrgInvitationScreen(
                id: state.pathParameters['id']!,
                token: state.uri.queryParameters['token']),
          ),
          GoRoute(
              path: '/channels',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => ChannelConnectionsScreen(
                  returnStatus: state.uri.queryParameters['status'])),
          GoRoute(
              path: '/channel-connected',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => ChannelConsentReturnScreen(
                  returnStatus: state.uri.queryParameters['status'],
                  navigatorKey: _rootNavigatorKey)),
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: '/account-banned',
            name: 'accountBanned',
            builder: (context, state) => const AccountBannedScreen(),
          ),
        ],
      );
  }
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
    // Gold palette on a laptop: a website with a top navigation bar instead
    // of the app's side rail. The branches keep their own stacks either way.
    if (context.usesHidayahWeb) {
      return Scaffold(
          backgroundColor: HidayahGold.g50,
          body: Stack(children: [
            // No system bars on a browser; a landscape tablet has them.
            SafeArea(
                child: Column(children: [
              HidayahWebHeader(
                  active: const [
                    HidayahWebSection.discover,
                    HidayahWebSection.map,
                    HidayahWebSection.lessons,
                  ][navigationShell.currentIndex],
                  onBranch: (index) => navigationShell.goBranch(index,
                      initialLocation: index == navigationShell.currentIndex)),
              Expanded(child: navigationShell),
            ])),
            const FloatingStreamMiniPlayer(),
          ]));
    }
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
                                        child:
                                            AppLogo(size: CanopySize.railLogo)),
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
                                    _DesktopNavItem(
                                      icon: CaGlyph.cal,
                                      label: 'nav.lessons'.tr(),
                                      isSelected:
                                          navigationShell.currentIndex == 2,
                                      onTap: () => navigationShell.goBranch(2),
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
                                        label:
                                            'design_ui.organization_admin'.tr(),
                                        isSelected: false,
                                        onTap: () => context.push('/org-admin'),
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
                                            color: AppPalette.ink,
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
                                                      color: AppPalette.ink,
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
    final color = isSelected ? HidayahGold.g200 : Canopy.brandGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: CaFocusRing(
          onDark: isSelected,
          radius: CanopyRadius.input,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(CanopyRadius.input),
              child: ExcludeSemantics(
                child: Container(
                  constraints:
                      const BoxConstraints(minHeight: CanopySize.target),
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    gradient: isSelected ? HidayahGradients.selected : null,
                    borderRadius: BorderRadius.circular(CanopyRadius.input),
                  ),
                  child: Row(
                    children: [
                      CaIcon(icon, color: color),
                      const SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: isSelected ? HidayahGold.g200 : Canopy.slate,
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
          return const Scaffold(body: Center(child: HadayahLoadingIndicator()));
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
