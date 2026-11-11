import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_button.dart';
import 'package:streamer_app/core/widgets/ds/ca_cards.dart';
import 'package:streamer_app/core/widgets/ds/ca_fields.dart';
import 'package:streamer_app/core/widgets/ds/ca_navigation.dart';
import 'package:streamer_app/core/widgets/ds/ca_rows.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';
import 'package:streamer_app/features/auth/presentation/application_pending_screen.dart';
import 'package:streamer_app/features/auth/presentation/lantern/lantern_application_status_view.dart';
import 'package:streamer_app/features/auth/presentation/lantern/lantern_apply_steps.dart';
import 'package:streamer_app/features/auth/presentation/lantern/lantern_apply_view.dart';
import 'package:streamer_app/features/auth/presentation/streamer_apply_screen.dart';

import 'support/lantern_harness.dart';
import 'support/localized_app.dart';

/// The broadcaster application and its status page in Lantern and Arch
/// (ADR-026): the same fields, checks and steps as the older form, with the
/// messages of the checks shown under their fields.

const _phone = Size(390, 844), _laptop = Size(1440, 900);

/// A signed-in viewer who has not applied, or one whose application is
/// [status] (pictures and name filled in, handle and bio empty).
AppProvider _applicant(
    {ApplicationStatus? status,
    LanternAppearance appearance = LanternAppearance.day}) {
  return lanternProvider(appearance: appearance)
    ..debugSetSignedInForTests(
        email: 'applicant@example.invalid',
        name: 'Saad Al-Ghamdi',
        isStreamer: false,
        ownedStreamerId: status == null ? null : 'app-1',
        ownedApplicationStatus: status ?? ApplicationStatus.pending);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    await loadAppFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> tapKey(WidgetTester tester, LanternApp app, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(f);
    await app.settle();
  }

  Future<void> next(WidgetTester tester, LanternApp app) =>
      tapKey(tester, app, 'lantern-apply-next');

  Future<void> type(
      WidgetTester tester, LanternApp app, String field, String text) async {
    final f = find.descendant(
        of: find.byKey(ValueKey('lantern-apply-field-$field')),
        matching: find.byType(TextField));
    await tester.ensureVisible(f);
    await tester.enterText(f, text);
    await app.settle(2);
  }

  void expectLanternOnly(WidgetTester tester) {
    final view = find.byType(LanternApplyView);
    for (final type in [CaButton, CaCard, CaInput, CaStepper, CaAppBar]) {
      expect(find.descendant(of: view, matching: find.byType(type)),
          findsNothing,
          reason: '$type belongs to the older designs');
    }
  }

  for (final (label, size) in [('phone', _phone), ('laptop', _laptop)]) {
    for (final lang in ['en', 'ar']) {
      for (final night in [false, true]) {
        testWidgets(
            'lays out on a $label in $lang, ${night ? 'night' : 'day'}, through every converted step',
            (tester) async {
          final app = await LanternApp.start(tester,
              size: size,
              lang: lang,
              location: '/streamer-apply',
              provider: _applicant(
                  status: ApplicationStatus.pending,
                  appearance: night
                      ? LanternAppearance.night
                      : LanternAppearance.day));
          expect(tester.takeException(), isNull);
          expect(find.byType(LanternApplyView), findsOneWidget);
          expect(
              find.byKey(ValueKey(size == _phone
                  ? 'lantern-apply-stepper'
                  : 'lantern-apply-rail')),
              findsOneWidget);
          expectLanternOnly(tester);
          await type(tester, app, 'handle', '@saad.alghamdi');
          await type(tester, app, 'bio', 'Weekly lessons in Al Khobar.');
          await next(tester, app);
          expect(find.byType(LanternApplyMedia), findsOneWidget);
          await next(tester, app);
          expect(find.byType(LanternApplyProfessional), findsOneWidget);
          await type(tester, app, 'youtube', '@saad.alghamdi');
          await app.settle();
          await next(tester, app);
          expect(find.byType(LanternApplyVenue), findsOneWidget);
          await next(tester, app);
          expect(find.byKey(const ValueKey('lantern-apply-step-review')),
              findsOneWidget);
          expect(tester.takeException(), isNull);
          expectLanternOnly(tester);
          await app.close();
        });
      }
    }
  }

  testWidgets(
      'Next with an empty field: the message under it, a banner, no step forward',
      (tester) async {
    final app = await LanternApp.start(tester,
        location: '/streamer-apply',
        provider: _applicant(status: ApplicationStatus.pending));
    await next(tester, app);
    expect(find.byKey(const ValueKey('lantern-apply-error')), findsOneWidget);
    expect(
        find.text('Complete this field to continue: Public Broadcast Handle'),
        findsOneWidget);
    final handle = tester.widget<LField>(
        find.byKey(const ValueKey('lantern-apply-field-handle')));
    expect(handle.error, 'This field is required.');
    // Still the first step.
    expect(find.byKey(const ValueKey('lantern-apply-step-identity')),
        findsOneWidget);
    expect(find.byType(LanternApplyMedia), findsNothing);
    // The older snack bar is not used.
    expect(find.byType(SnackBar), findsNothing);

    await type(tester, app, 'handle', '@saad');
    await next(tester, app);
    expect(
        tester
            .widget<LField>(find.byKey(const ValueKey('lantern-apply-field-bio')))
            .error,
        'This field is required.');
    await type(tester, app, 'bio', 'Weekly lessons.');
    await next(tester, app);
    expect(find.byKey(const ValueKey('lantern-apply-error')), findsNothing);
    expect(find.byType(LanternApplyMedia), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('pictures are required on the media step', (tester) async {
    // A new applicant without a Google photo has neither picture.
    final app = await LanternApp.start(tester,
        location: '/streamer-apply', provider: _applicant());
    await type(tester, app, 'bio', 'Weekly lessons.');
    await next(tester, app);
    expect(find.byType(LanternApplyMedia), findsOneWidget);
    expect(find.byKey(const ValueKey('lantern-apply-pick-banner')),
        findsOneWidget);
    await next(tester, app);
    expect(find.text('Add a picture to continue.'), findsOneWidget);
    expect(find.byKey(const ValueKey('lantern-apply-error')), findsOneWidget);
    expect(find.byType(LanternApplyMedia), findsOneWidget);
    await app.close();
  });

  testWidgets('YouTube: a malformed channel says why under the field',
      (tester) async {
    final app = await LanternApp.start(tester,
        location: '/streamer-apply',
        provider: _applicant(status: ApplicationStatus.pending));
    await type(tester, app, 'handle', '@saad');
    await type(tester, app, 'bio', 'Weekly lessons.');
    await next(tester, app);
    await next(tester, app);
    expect(find.byType(LanternApplyProfessional), findsOneWidget);
    await next(tester, app);
    expect(
        tester
            .widget<LField>(
                find.byKey(const ValueKey('lantern-apply-field-youtube')))
            .error,
        'This field is required.');
    await type(tester, app, 'youtube', 'not a channel');
    await app.settle();
    expect(find.byKey(const ValueKey('lantern-apply-youtube-invalid')),
        findsOneWidget);
    await type(tester, app, 'youtube', '@saad.alghamdi');
    await app.settle();
    expect(find.byKey(const ValueKey('lantern-apply-youtube-formatOk')),
        findsOneWidget);
    await next(tester, app);
    expect(find.byType(LanternApplyVenue), findsOneWidget);
    await app.close();
  });

  testWidgets(
      'review: each step with an Edit link; submit without a map point says so',
      (tester) async {
    final app = await LanternApp.start(tester,
        location: '/streamer-apply',
        provider: _applicant(status: ApplicationStatus.pending));
    await type(tester, app, 'handle', '@saad');
    await type(tester, app, 'bio', 'Weekly lessons.');
    await next(tester, app);
    await next(tester, app);
    await type(tester, app, 'youtube', '@saad.alghamdi');
    await app.settle();
    await next(tester, app);
    await next(tester, app);
    expect(find.byKey(const ValueKey('lantern-apply-step-review')),
        findsOneWidget);
    for (final page in [0, 1, 2, 3]) {
      expect(find.byKey(ValueKey('lantern-apply-edit-$page')), findsOneWidget);
    }
    expect(find.textContaining('Saad Al-Ghamdi · @saad'), findsOneWidget);
    expect(find.widgetWithText(LButton, 'Submit Application'), findsOneWidget);

    // No point on the map: the existing check stops the submission.
    await next(tester, app);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('lantern-apply-error')),
            matching: find.textContaining('outside our supported map area')),
        findsOneWidget);
    expect(app.location, '/streamer-apply');

    // Edit opens the step again.
    await tapKey(tester, app, 'lantern-apply-edit-0');
    expect(find.byKey(const ValueKey('lantern-apply-step-identity')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('lantern-apply-error')), findsNothing);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('the terms switch and the terms sheet', (tester) async {
    final app = await LanternApp.start(tester,
        location: '/streamer-apply',
        provider: _applicant(status: ApplicationStatus.pending));
    await type(tester, app, 'handle', '@saad');
    await type(tester, app, 'bio', 'Weekly lessons.');
    for (var i = 0; i < 2; i++) {
      await next(tester, app);
    }
    await type(tester, app, 'youtube', '@saad.alghamdi');
    await app.settle();
    await next(tester, app);
    await next(tester, app);
    final agree = find.byKey(const ValueKey('lantern-apply-agree'));
    expect(tester.widget<LSwitch>(agree).value, isFalse);
    await tapKey(tester, app, 'lantern-apply-agree');
    expect(tester.widget<LSwitch>(agree).value, isTrue);
    await tester.tap(find.text('Read the terms'));
    await app.settle();
    expect(find.text('Terms and Conditions for Streamers'), findsWidgets);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('leaving after the first step asks first, in a Lantern dialog',
      (tester) async {
    final app = await LanternApp.start(tester,
        location: '/feed',
        provider: _applicant(status: ApplicationStatus.pending));
    await app.push('/streamer-apply');
    await type(tester, app, 'handle', '@saad');
    await type(tester, app, 'bio', 'Weekly lessons.');
    await next(tester, app);
    await tester.tap(find.byKey(const Key('wizard-exit')));
    await app.settle();
    expect(find.text('Leave the application?'), findsOneWidget);
    await tapKey(tester, app, 'lantern-apply-stay');
    expect(app.location, '/streamer-apply');
    await tester.tap(find.byKey(const Key('wizard-exit')));
    await app.settle();
    await tapKey(tester, app, 'lantern-apply-leave');
    expect(app.location, '/feed');
    await app.close();
  });

  testWidgets('the website rail opens a finished step again', (tester) async {
    final app = await LanternApp.start(tester,
        size: _laptop,
        location: '/streamer-apply',
        provider: _applicant(status: ApplicationStatus.pending));
    await type(tester, app, 'handle', '@saad');
    await type(tester, app, 'bio', 'Weekly lessons.');
    await next(tester, app);
    expect(find.bySemanticsLabel('Identity, done'), findsOneWidget);
    expect(find.bySemanticsLabel('Media, current step'), findsOneWidget);
    await tapKey(tester, app, 'lantern-apply-rail-0');
    expect(find.byKey(const ValueKey('lantern-apply-step-identity')),
        findsOneWidget);
    await app.close();
  });

  for (final status in [
    ApplicationStatus.pending,
    ApplicationStatus.approved,
    ApplicationStatus.rejected,
  ]) {
    for (final (label, size) in [('phone', _phone), ('laptop', _laptop)]) {
      for (final lang in ['en', 'ar']) {
        testWidgets('status page: ${status.name} on a $label in $lang',
            (tester) async {
          final app = await LanternApp.start(tester,
              size: size,
              lang: lang,
              location: '/application-pending',
              provider: _applicant(status: status));
          expect(tester.takeException(), isNull);
          expect(find.byType(LanternApplicationStatusView), findsOneWidget);
          expect(find.byKey(const ValueKey('lantern-status-track')),
              findsOneWidget);
          expect(find.byKey(const ValueKey('lantern-status-sent')),
              findsOneWidget);
          final stage = switch (status) {
            ApplicationStatus.approved => 'lantern-status-stage-2-done',
            ApplicationStatus.rejected => 'lantern-status-stage-2-warn',
            _ => 'lantern-status-stage-1-current',
          };
          expect(find.byKey(ValueKey(stage)), findsOneWidget);
          expect(
              find.byKey(const ValueKey('lantern-status-edit')),
              status == ApplicationStatus.approved
                  ? findsNothing
                  : findsOneWidget);
          for (final type in [CaButton, CaCard, CaAppBar]) {
            expect(
                find.descendant(
                    of: find.byType(LanternApplicationStatusView),
                    matching: find.byType(type)),
                findsNothing);
          }
          await app.close();
        });
      }
    }
  }

  testWidgets('status page: Explore goes to Discover, Edit to the form',
      (tester) async {
    final app = await LanternApp.start(tester,
        location: '/application-pending',
        provider: _applicant(status: ApplicationStatus.pending));
    await tapKey(tester, app, 'lantern-status-edit');
    expect(app.location, '/streamer-apply');
    await app.go('/application-pending');
    await tapKey(tester, app, 'lantern-status-explore');
    expect(app.location, '/feed');
    await app.close();
  });

  testWidgets('the older designs build none of it', (tester) async {
    for (final skin in [AppSkin.gold, AppSkin.hedayah]) {
      final provider = lanternProvider(skin: skin)
        ..debugSetSignedInForTests(
            email: 'applicant@example.invalid',
            isStreamer: false,
            ownedStreamerId: 'app-1',
            ownedApplicationStatus: ApplicationStatus.pending);
      final app = await LanternApp.start(tester,
          skin: skin, provider: provider, location: '/streamer-apply');
      tester.takeException();
      expect(find.byType(StreamerApplyScreen), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is LanternSkinWidget),
          findsNothing,
          reason: '${skin.name} form');
      await app.go('/application-pending');
      tester.takeException();
      expect(find.byType(ApplicationPendingScreen), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is LanternSkinWidget),
          findsNothing,
          reason: '${skin.name} status');
      await app.close();
    }
  });
}
