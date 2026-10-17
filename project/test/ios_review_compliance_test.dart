import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/config/app_identity.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/consent_dialog.dart';
import 'package:streamer_app/core/widgets/ios_support_contact.dart';
import 'package:streamer_app/features/live_stream/models/chat_message_model.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/chat_message_actions_sheet.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';
import 'package:streamer_app/features/profile/presentation/settings/legal_settings_section.dart';
import 'package:streamer_app/features/profile/presentation/settings/privacy_settings_section.dart';
import 'package:streamer_app/features/profile/presentation/widgets/legal_document_reader_screen.dart';

import 'support/localized_app.dart';

class _PrivacyProvider extends AppProvider {
  int deletions = 0;
  @override
  Future<String?> deleteOwnAccount() async {
    deletions++;
    return 'failed';
  }
}

Widget _app(AppProvider provider, Widget home, String language) =>
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(language),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: Builder(
            builder: (context) => MaterialApp(
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  theme: AppTheme.forLocale(context.locale),
                  home: home,
                )),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const urlChannel = MethodChannel('plugins.flutter.io/url_launcher');
  setUpAll(initializeTestLocalization);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlChannel, null);
  });

  for (final language in ['en', 'ar']) {
    testWidgets(
        'iOS pre-auth policy and support address are reachable ($language)',
        (tester) async {
      final provider = AppProvider();
      final launched = <Uri>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(urlChannel,
          (call) async {
        launched.add(Uri.parse((call.arguments as Map)['url'] as String));
        return false;
      });
      try {
        await tester.binding.setSurfaceSize(const Size(390, 1000));
        await tester.pumpWidget(_app(
            provider,
            Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () => ConsentDialog.show(context),
                        child: const Text('Consent')))),
            language));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Consent'));
        await tester.pumpAndSettle();
        expect(provider.currentUserSessionId, isNull);
        expect(find.text(AppIdentity.supportEmail), findsOneWidget);
        await tester
            .ensureVisible(find.byKey(const Key('ios-support-contact')));
        await tester.tap(find.byKey(const Key('ios-support-contact')));
        await tester.pumpAndSettle();
        expect(launched.single.scheme, 'mailto');
        expect(launched.single.path, AppIdentity.supportEmail);
        expect(
            find.descendant(
                of: find.byType(AlertDialog).last,
                matching: find.text(AppIdentity.supportEmail)),
            findsOneWidget);
        await tester.tap(find.text('organization_v1.close'.tr()));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('consent.view_full_policy'.tr()));
        await tester.tap(find.text('consent.view_full_policy'.tr()));
        await tester.pumpAndSettle();
        expect(
            find.text(
                provider.termsAndConditions.getLocalizedPrivacy(language)),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
        debugDefaultTargetPlatformOverride = null;
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('iOS Settings privacy entry opens the legal reader ($language)',
        (tester) async {
      final provider = AppProvider();
      try {
        await tester.pumpWidget(_app(
            provider,
            const Scaffold(
                body: SingleChildScrollView(child: LegalSettingsSection())),
            language));
        await tester.pumpAndSettle();
        expect(find.text(AppIdentity.supportEmail), findsOneWidget);
        await tester.tap(find.text('settings.view_privacy'.tr()));
        await tester.pumpAndSettle();
        expect(find.byType(LegalDocumentReaderScreen), findsOneWidget);
        expect(
            find.text(
                provider.termsAndConditions.getLocalizedPrivacy(language)),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
        'iOS deletion asks first and shows a refused request ($language)',
        (tester) async {
      final provider = _PrivacyProvider();
      try {
        await tester.pumpWidget(_app(
            provider,
            const Scaffold(
                body: SingleChildScrollView(
                    child: PrivacySettingsSection(dangerOnly: true))),
            language));
        await tester.pumpAndSettle();
        await tester
            .ensureVisible(find.widgetWithText(OutlinedButton, 'settings.delete_account_btn'.tr()));
        await tester.tap(find.widgetWithText(OutlinedButton, 'settings.delete_account_btn'.tr()));
        await tester.pumpAndSettle();
        expect(find.text('settings.delete_account_confirm_title'.tr()),
            findsOneWidget);
        expect(provider.deletions, 0);
        await tester.tap(find.text('settings.cancel'.tr()));
        await tester.pumpAndSettle();
        expect(provider.deletions, 0);
        await tester.tap(find.widgetWithText(OutlinedButton, 'settings.delete_account_btn'.tr()));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'settings.delete_account_confirm_btn'.tr()));
        await tester.pumpAndSettle();
        expect(provider.deletions, 1);
        expect(find.text('settings.delete_account_error_toast'.tr()),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('iOS viewer can reach report and block ($language)',
        (tester) async {
      final provider = AppProvider();
      final chat = LiveChatController(streamId: 'ios-review-room');
      chat.debugSetStateForTests(currentUserId: 'viewer', canModerate: false);
      final message = ChatMessageModel(
          id: 'review-message',
          streamId: 'ios-review-room',
          senderId: 'other',
          senderName: 'Other viewer',
          body: 'hello',
          createdAt: DateTime(2026));
      try {
        await tester.pumpWidget(_app(
            provider,
            Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () => showChatMessageActionsSheet(context,
                            message: message, controller: chat),
                        child: const Text('Actions')))),
            language));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Actions'));
        await tester.pumpAndSettle();
        expect(find.text('live.report_message'.tr()), findsOneWidget);
        expect(find.text('live.block_user'.tr()), findsOneWidget);
        expect(find.text('live.mute_user'.tr()), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        chat.dispose();
        provider.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('iOS moderator can reach mute', (tester) async {
    final provider = AppProvider();
    final chat = LiveChatController(streamId: 'ios-review-room');
    chat.debugSetStateForTests(currentUserId: 'moderator', canModerate: true);
    final message = ChatMessageModel(
        id: 'review-message',
        streamId: 'ios-review-room',
        senderId: 'other',
        senderName: 'Other viewer',
        body: 'hello',
        createdAt: DateTime(2026));
    try {
      await tester.pumpWidget(_app(
          provider,
          Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showChatMessageActionsSheet(context,
                          message: message, controller: chat),
                      child: const Text('Actions')))),
          'en'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      expect(find.text('live.mute_user'.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      chat.dispose();
      provider.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS support addition leaves Android UI empty', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final provider = AppProvider();
    try {
      await tester.pumpWidget(
          _app(provider, const Scaffold(body: IosSupportContact()), 'en'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ios-support-contact')), findsNothing);
      expect(find.text(AppIdentity.supportEmail), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('iOS keyword refusal stays non-retryable', () {
    final chat = LiveChatController(streamId: 'ios-review-room');
    try {
      final failure = chat.debugClassifyForTests('banned keyword');
      expect(failure.retryable, isFalse);
      expect(failure.message, contains('blocked'));
    } finally {
      chat.dispose();
    }
  });
}
