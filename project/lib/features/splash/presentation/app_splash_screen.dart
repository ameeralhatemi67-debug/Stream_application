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
    final isAr = context.locale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppTheme.darkBgBase,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF18181B),
              Color(0xFF0F0F11),
              AppTheme.darkBgBase,
            ],
          ),
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
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.accentBlue,
                                AppTheme.accentPurple,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentBlue.withValues(
                                  alpha: 0.35 * _fadeAnimation.value,
                                ),
                                blurRadius: 32,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.podcasts_rounded,
                            size: 52,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: AppTheme.spaceXl),

                // Brand Title
                Text(
                  isAr ? 'منصة البث التعليمي' : 'Educational Streamer',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isAr
                      ? 'البثوث الأكاديمية والمحاضرات التفاعلية'
                      : 'Academic Broadcasts & Spatial Discovery',
                  style: const TextStyle(
                    color: AppTheme.textSecondaryDark,
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
                      AppTheme.accentBlue.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Text(
                  isAr
                      ? 'جاري تهيئة المنصة وتحميل الخرائط...'
                      : 'Initializing platform & map assets...',
                  style: const TextStyle(
                    color: AppTheme.textMutedDark,
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
