import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/floating_stream_mini_player.dart';
import '../widgets/language_switcher.dart';
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
import '../../features/admin/presentation/admin_hub_screen.dart';
import '../../features/admin/presentation/org_admin_screen.dart';
import '../../features/splash/presentation/app_splash_screen.dart';

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
    refreshListenable: provider,
    redirect: (context, state) {
      final path = state.matchedLocation;
      final isLoggedIn = provider.isLoggedInStreamer;

      if (_authGuardedPaths.contains(path)) {
        if (!isLoggedIn) return '/welcome';
        if (path == '/admin' && !provider.isAdminUser) return '/feed';
        if (path == '/org-admin' && !provider.isPermittedAdmin) return '/feed';
        return null;
      }

      // Once a session exists, leave the auth landing screen behind. Needed
      // because the Google sign-in button (welcome_screen.dart) only
      // launches the OAuth browser flow and can't navigate synchronously
      // after it -- this is what actually completes that flow.
      if (path == '/welcome' && isLoggedIn) return '/feed';

      // Handle OAuth callback deep link redirects (e.g. com.example.streamerapp://login-callback)
      // gracefully without ever falling through to "Route Not Found".
      if (state.uri.host == 'login-callback' ||
          path == '/login-callback' ||
          state.uri.path == '/login-callback') {
        return isLoggedIn ? '/feed' : '/welcome';
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.accentRed),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              'Route Not Found (${state.error?.message ?? state.uri.toString()})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            ElevatedButton(
              onPressed: () => context.go('/feed'),
              child: const Text('Back to Discovery Feed'),
            ),
          ],
        ),
      ),
    ),
    routes: [
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
          return ResponsiveScaffoldWithNestedNavigation(navigationShell: navigationShell);
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
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'prof_alghamdi_01';
          return BroadcasterProfileScreen(streamerId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/live/:id',
        name: 'live',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'stream_live_992';
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
        builder: (context, state) => const AdminHubScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/org-admin',
        name: 'orgAdmin',
        builder: (context, state) => const OrgAdminScreen(),
      ),
    ],
  );
}

/// Responsive Scaffold supporting Desktop NavigationRail and Mobile BottomNav
class ResponsiveScaffoldWithNestedNavigation extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ResponsiveScaffoldWithNestedNavigation({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final (isStreamerModeEnabled, isAdminUser, isPermittedAdmin, hasPendingApplications, pendingCount) =
        context.select<AppProvider, (bool, bool, bool, bool, int)>((p) => (
              p.isStreamerModeEnabled,
              p.isAdminUser,
              p.isPermittedAdmin,
              p.pendingApplications.isNotEmpty,
              p.pendingApplications.length,
            ));

    return Scaffold(
      backgroundColor: AppTheme.darkBgBase,
      body: Stack(
        children: [
          if (isDesktop)
            Row(
              children: [
                // Desktop Persistent Sidebar NavigationRail
                Container(
                  width: 220,
                  decoration: const BoxDecoration(
                    color: AppTheme.darkSurface1,
                    border: Border(
                      right: BorderSide(color: AppTheme.darkBorderSubtle, width: 1.0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App Branding Header
                      Padding(
                        padding: const EdgeInsets.all(AppTheme.spaceLg),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.accentRed.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                border: Border.all(color: AppTheme.accentRed, width: 1.5),
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: AppTheme.accentRed,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spaceMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'STREAMER',
                                    style: TextStyle(
                                      color: AppTheme.textPrimaryDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    'AlSharqia Hub',
                                    style: TextStyle(
                                      color: AppTheme.accentBlue.withValues(alpha: 0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: AppTheme.darkBorderSubtle, height: 1),
                      const SizedBox(height: AppTheme.spaceMd),

                      // Navigation Items
                      _DesktopNavItem(
                        icon: Icons.grid_view_rounded,
                        label: 'Discovery Hub',
                        isSelected: navigationShell.currentIndex == 0,
                        onTap: () => navigationShell.goBranch(0),
                      ),
                      _DesktopNavItem(
                        icon: Icons.map_rounded,
                        label: 'Spatial GIS Map',
                        isSelected: navigationShell.currentIndex == 1,
                        onTap: () => navigationShell.goBranch(1),
                      ),
                      _DesktopNavItem(
                        icon: Icons.person_rounded,
                        label: isStreamerModeEnabled ? 'Studio Profile' : 'My Profile',
                        isSelected: false,
                        onTap: () => context.push('/profile/prof_alghamdi_01'),
                      ),
                      _DesktopNavItem(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        isSelected: false,
                        onTap: () => context.push('/settings'),
                      ),
                      if (isAdminUser) ...[
                        const SizedBox(height: 4),
                        _DesktopNavItem(
                          icon: Icons.admin_panel_settings_rounded,
                          label: 'Admin Hub',
                          badge: hasPendingApplications ? '$pendingCount' : null,
                          isSelected: false,
                          onTap: () => context.push('/admin'),
                        ),
                      ],
                      if (isPermittedAdmin) ...[
                        const SizedBox(height: 4),
                        _DesktopNavItem(
                          icon: Icons.apartment_rounded,
                          label: 'Org Admin',
                          isSelected: false,
                          onTap: () => context.push('/org-admin'),
                        ),
                      ],

                      const Spacer(),

                      // Streamer Mode Status Card
                      Container(
                        margin: const EdgeInsets.all(AppTheme.spaceMd),
                        padding: const EdgeInsets.all(AppTheme.spaceMd),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface2,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                            color: isStreamerModeEnabled ? AppTheme.accentRed : AppTheme.darkBorderSubtle,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isStreamerModeEnabled ? Icons.videocam_rounded : Icons.visibility_rounded,
                              size: 18,
                              color: isStreamerModeEnabled ? AppTheme.accentRed : AppTheme.accentBlue,
                            ),
                            const SizedBox(width: AppTheme.spaceSm),
                            Expanded(
                              child: Text(
                                isStreamerModeEnabled ? 'Streamer Mode' : 'Viewer Mode',
                                style: const TextStyle(
                                  color: AppTheme.textPrimaryDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Language Switcher in Sidebar
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                        child: LanguageSwitcher(),
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                    ],
                  ),
                ),
                // Main Content
                Expanded(child: navigationShell),
              ],
            )
          else
            navigationShell,

          // Global Floating Picture-in-Picture Mini-Player Overlay
          const FloatingStreamMiniPlayer(),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppTheme.darkSurface1,
                border: Border(
                  top: BorderSide(color: AppTheme.darkBorderSubtle, width: 1.0),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: navigationShell.currentIndex,
                backgroundColor: AppTheme.darkSurface1,
                selectedItemColor: AppTheme.accentRed,
                unselectedItemColor: AppTheme.textMutedDark,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
                onTap: (index) {
                  navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  );
                },
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.grid_view_rounded),
                    activeIcon: Icon(Icons.grid_view_rounded, color: AppTheme.accentRed),
                    label: 'Discovery',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.map_rounded),
                    activeIcon: Icon(Icons.map_rounded, color: AppTheme.accentRed),
                    label: 'Spatial Map',
                  ),
                ],
              ),
            ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  final IconData icon;
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
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentRed.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: isSelected ? Border.all(color: AppTheme.accentRed.withValues(alpha: 0.5)) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.accentRed : AppTheme.textSecondaryDark,
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.textPrimaryDark : AppTheme.textSecondaryDark,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
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
      ),
    );
  }
}
