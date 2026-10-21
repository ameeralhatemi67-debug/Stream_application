import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/entry_background.dart';
import '../../../core/config/app_identity.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_flags.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/widgets/language_switcher.dart';
import '../../../core/widgets/consent_dialog.dart';
import '../../../core/widgets/hadayah_loading_indicator.dart';

/// Master Welcome & Authentication Landing Screen
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.appFlags});

  /// Defaults to the app-wide switches; tests pass their own.
  final AppFlags? appFlags;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;
  late final AppFlags _flags = widget.appFlags ?? AppFlags.instance;

  @override
  void initState() {
    super.initState();
    _flags.addListener(_onFlagsChanged);
    _flags.refresh();
  }

  @override
  void dispose() {
    _flags.removeListener(_onFlagsChanged);
    super.dispose();
  }

  void _onFlagsChanged() {
    if (mounted) setState(() {});
  }

  /// `registrations_open` is enforced on Auth user creation, so a new account
  /// cannot be made while it is off; existing accounts still sign in.
  Widget _buildRegistrationsPausedNotice() {
    return Container(
      key: const Key('registrations-paused-notice'),
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: paletteColor(context, AppTheme.warning).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: paletteColor(context, AppTheme.warning).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.pause_circle_outline_rounded,
              size: 18, color: paletteColor(context, AppTheme.warning)),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              'auth_welcome.registrations_paused'.tr(),
              style: TextStyle(
                  color: paletteColor(context, AppTheme.textPrimary), fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

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
          backgroundColor: paletteColor(context, AppTheme.danger),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleAuth() async {
    if (_isLoading) return;
    final consented = await _ensureConsent();
    if (!consented || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await context.read<AppProvider>().loginWithApple();
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code != AuthorizationErrorCode.canceled) {
        _showSignInUnavailable();
      }
    } catch (_) {
      _showSignInUnavailable();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSignInUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('auth_welcome.sign_in_failed'.tr()),
      backgroundColor: paletteColor(context, AppTheme.danger),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: paletteColor(context, AppTheme.bg),
      body: EntryBackground(
        child: SafeArea(
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
                        color: paletteColor(context, AppTheme.textPrimary),
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
                        color: paletteColor(context, AppTheme.primary).withValues(alpha: 0.9),
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
                        color: paletteColor(context, AppTheme.surface),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border:
                            Border.all(color: paletteColor(context, AppTheme.surfaceAlt), width: 1.2),
                        boxShadow: paletteShadows(context, AppTheme.entrySurfaceShadow),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'auth_welcome.card_title'.tr(),
                            style: TextStyle(
                              color: paletteColor(context, AppTheme.textPrimary),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (!kIsWeb &&
                                        defaultTargetPlatform ==
                                            TargetPlatform.iOS
                                    ? 'auth_welcome.card_subtitle_ios'
                                    : 'auth_welcome.card_subtitle')
                                .tr(),
                            style: TextStyle(
                              color: paletteColor(context, AppTheme.textPrimary),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppTheme.spaceLg),

                          if (!_flags.registrationsOpen)
                            _buildRegistrationsPausedNotice(),

                          //  1. Sign Up Primary Action (Google)
                          ElevatedButton(
                            key: const Key('welcome-signup'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: paletteColor(context, AppTheme.onMedia),
                              foregroundColor: paletteColor(context, AppTheme.textPrimary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                              ),
                              elevation: 2,
                              shadowColor: paletteColor(context, AppTheme.shadowSoft),
                              surfaceTintColor: Colors.transparent,
                            ),
                            onPressed: _isLoading || !_flags.registrationsOpen
                                ? null
                                : () => _handleGoogleAuth(),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: HadayahLoadingIndicator(
                                      strokeWidth: 2,
                                      color: paletteColor(context, AppTheme.textPrimary),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: paletteColor(context, AppTheme.onMedia),
                                        ),
                                        child: Text(
                                          'G',
                                          style: TextStyle(
                                            color: paletteColor(context, AppTheme.primary),
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
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: AppTheme.spaceMd),

                          if (!kIsWeb &&
                              defaultTargetPlatform == TargetPlatform.iOS) ...[
                            SignInWithAppleButton(
                              key: const Key('welcome-apple'),
                              text: 'auth_welcome.btn_apple'.tr(),
                              height: MediaQuery.textScalerOf(context)
                                  .scale(AppTheme.space2Xl * 2)
                                  .clamp(AppTheme.space2Xl * 2 + AppTheme.spaceLg,
                                      double.infinity),
                              style: SignInWithAppleButtonStyle.whiteOutlined,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                              onPressed: _isLoading ? null : _handleAppleAuth,
                            ),
                            const SizedBox(height: AppTheme.spaceMd),
                          ],

                          //  2. Log In Secondary Action
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: paletteColor(context, AppTheme.textPrimary),
                              side: BorderSide(
                                color: paletteColor(context, AppTheme.border),
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
                                    (!kIsWeb &&
                                                defaultTargetPlatform ==
                                                    TargetPlatform.iOS
                                            ? 'auth_welcome.btn_google_login_ios'
                                            : 'auth_welcome.btn_google_login')
                                        .tr(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.spaceLg),

                          // Divider with OR
                          Row(
                            children: [
                              Expanded(
                                child: Divider(color: paletteColor(context, AppTheme.border)),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'auth_welcome.divider_or'.tr(),
                                  style: TextStyle(
                                    color: paletteColor(context, AppTheme.textMuted),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: paletteColor(context, AppTheme.border)),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spaceMd),

                          //  3. Continue as Guest Viewer Action
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: paletteColor(context, AppTheme.primary),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () async {
                              final consented = await _ensureConsent();
                              if (!consented || !context.mounted) return;
                              // A guest already set up on this device goes
                              // back to browsing, not to the name form.
                              if (context
                                  .read<AppProvider>()
                                  .isReturningGuest) {
                                context.canPop()
                                    ? context.pop()
                                    : context.go('/feed');
                                return;
                              }
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [paletteColor(context, AppTheme.surface), paletteColor(context, AppTheme.surfaceAlt)],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: paletteColor(context, AppTheme.surfaceAlt)),
                        boxShadow: paletteShadows(context, AppTheme.entrySurfaceShadow),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language_rounded,
                              size: 16, color: paletteColor(context, AppTheme.textMuted)),
                          const SizedBox(width: 8),
                          const LanguageSwitcher(),
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
    );
  }
}
