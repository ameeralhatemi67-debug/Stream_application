import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/entry_background.dart';
import '../../../../core/config/app_identity.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../core/widgets/hadayah_loading_indicator.dart';
import '../../../core/widgets/hedayah/hedayah_kit.dart';

/// Clean, stutter-free App Startup Splash Screen.
/// Displays high-fidelity branding, warms up provider services,
/// and provides a smooth fade transition into the app experience.
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key});

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoPulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _logoPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _logoPulseController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoPulseController,
        curve: Curves.easeInOut,
      ),
    );

    _scheduleNavigation();
  }

  void _scheduleNavigation() {
    _navigationTimer = Timer(const Duration(milliseconds: 1350), () {
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      if (provider.authHydrating || !provider.localStateRestored) {
        _scheduleNavigation();
        return;
      }
      // Warm up live polling
      provider.ensureLivePollingActive();

      if (provider.googleUserEmail != null &&
          provider.googleUserEmail!.isNotEmpty) {
        // After the web sign-in redirect, back to the page that asked. A new
        // account meets the role picker first, which then takes the page.
        context.go(provider.needsRoleSelection
            ? '/feed'
            : provider.takeSignInReturn() ?? '/feed');
      } else if (provider.isReturningGuest) {
        // A guest who already agreed and chose a name on this device is not
        // walked through the welcome gate again (audit 2026-10-21, P0-2).
        context.go('/feed');
      } else {
        context.go('/welcome');
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _logoPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.isHedayahSkin) return const _HedayahSplash();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: EntryBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Animated Glowing Emblem Logo
                AnimatedBuilder(
                  animation: _logoPulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: const AppLogo(size: 104),
                      ),
                    );
                  },
                ),

                const SizedBox(height: AppTheme.spaceXl),

                // Brand Title
                Text(
                  AppIdentity.name(context.locale.languageCode),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'design_copy.academic_broadcasts_spatial_discovery'.tr(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),

                const Spacer(flex: 2),

                // Smooth Initializing Loader Indicator
                SizedBox(
                  width: 28,
                  height: 28,
                  child: HadayahLoadingIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Text(
                  'design_copy.initializing_platform_map_assets'.tr(),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11.5,
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Hedayah skin's opening (ADR-016): all gold with the lattice, the
/// reversed lockup drawing itself, and the association's tagline in ink.
class _HedayahSplash extends StatelessWidget {
  const _HedayahSplash();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900;
    // A phone on its side has little height: a smaller lockup keeps it all in.
    final lockup = size.height < 600 ? 72.0 : (wide ? 140.0 : 112.0);
    return Scaffold(
      backgroundColor: HedayahSkin.gold,
      body: HedayahGoldBand(
        step: wide ? 36 : 30,
        veil: HedayahVeil.centre(at: const Alignment(0, -.1), radius: 1.1),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  HedayahLockup(size: lockup, reversed: true, draw: true),
                  const SizedBox(height: 26),
                  Text(
                    AppIdentity.name(context.locale.languageCode),
                    textAlign: TextAlign.center,
                    style: HedayahSkin.displayStyle(wide ? 32 : 26,
                        weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      'skin.tagline'.tr(),
                      textAlign: TextAlign.center,
                      style: HedayahSkin.displayStyle(15,
                          weight: FontWeight.w400,
                          color: HedayahSkin.ink.withValues(alpha: .86),
                          height: 1.8),
                    ),
                  ),
                  const Spacer(flex: 3),
                  HedayahCalm(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 128,
                          height: 4,
                          child: LinearProgressIndicator(
                            color: HedayahSkin.ink,
                            backgroundColor:
                                HedayahSkin.paper.withValues(alpha: .45),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'design_copy.initializing_platform_map_assets'.tr(),
                        textAlign: TextAlign.center,
                        style: HedayahSkin.textStyle(12,
                            color: HedayahSkin.ink.withValues(alpha: .9),
                            height: 1.5),
                      ),
                    ]),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
