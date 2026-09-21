import '../../../core/widgets/app_logo.dart';
import '../../../core/config/app_identity.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/widgets/language_switcher.dart';
import '../../../core/widgets/consent_dialog.dart';

/// Master Welcome & Authentication Landing Screen
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;

  /// PDPL onboarding consent gate (v0.9 Checkpoint 3 Phase 1) -- both the
  /// Google sign-in and guest flows route through this before gathering any
  /// personal data. Returns true only once consent is on record (already
  /// accepted, or just accepted now).
  Future<bool> _ensureConsent() async {
    final provider = context.read<AppProvider>();
    if (provider.hasAcceptedCurrentConsent) return true;
    final accepted = await ConsentDialog.show(context);
    if (!accepted) return false;
    await provider.recordConsent();
    return true;
  }

  Future<void> _handleGoogleAuth() async {
    final consented = await _ensureConsent();
    if (!consented || !mounted) return;

    setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();

    try {
      // Only launches the Google OAuth browser flow. Once the user
      // completes sign-in and the app resumes via the OAuth redirect,
      // AppProvider's auth listener picks up the new session and
      // GoRouter's redirect (app_router.dart) takes it from there --
      // there's nothing left to navigate to here.
      await provider.loginWithGoogle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('auth_welcome.sign_in_failed'.tr()),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceLg,
              vertical: AppTheme.spaceMd,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 680 : 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  //  Animated Logo & Identity Badge
                  const AppLogo(size: 96),
                  const SizedBox(height: AppTheme.spaceMd),

                  // Brand Title
                  Text(
                    AppIdentity.name(context.locale.languageCode),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing:
                          context.locale.languageCode == 'ar' ? 0.0 : 2.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),

                  // Subtitle & Regional Scope
                  Text(
                    'auth_welcome.subtitle'.tr(),
                    style: TextStyle(
                      color: AppTheme.primary.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spaceXl),

                  //  Authentication Card Container
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceLg),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                          color: AppTheme.border, width: 1.2),

                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'auth_welcome.card_title'.tr(),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'auth_welcome.card_subtitle'.tr(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spaceLg),

                        //  1. Sign Up Primary Action (Google)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.onMedia,
                            foregroundColor: AppTheme.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            elevation: 2,
                          ),
                          onPressed:
                              _isLoading ? null : () => _handleGoogleAuth(),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.textPrimary,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
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
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        'auth_welcome.btn_google_signup'.tr(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: AppTheme.spaceMd),

                        //  2. Log In Secondary Action
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            side: const BorderSide(
                              color: AppTheme.border,
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                          onPressed:
                              _isLoading ? null : () => _handleGoogleAuth(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.login_rounded, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'auth_welcome.btn_google_login'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceLg),

                        // Divider with OR
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: AppTheme.border),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'auth_welcome.divider_or'.tr(),
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: AppTheme.border),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spaceMd),

                        //  3. Continue as Guest Viewer Action
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () async {
                            final consented = await _ensureConsent();
                            if (!consented || !context.mounted) return;
                            context.go('/viewer-setup');
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.explore_outlined, size: 17),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'auth_welcome.btn_guest'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXl),

                  //  Bottom Language Switcher Bar
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.language_rounded,
                            size: 16, color: AppTheme.textMuted),
                        SizedBox(width: 8),
                        LanguageSwitcher(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
