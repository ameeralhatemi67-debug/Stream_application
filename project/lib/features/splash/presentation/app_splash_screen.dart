import '../../../../core/widgets/app_logo.dart';
import '../../../../core/config/app_identity.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';

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
      // Warm up live polling
      provider.ensureLivePollingActive();

      if (provider.googleUserEmail != null &&
          provider.googleUserEmail!.isNotEmpty) {
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

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: AppTheme.surfaceAlt,
        ),
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
                  child: CircularProgressIndicator(
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
