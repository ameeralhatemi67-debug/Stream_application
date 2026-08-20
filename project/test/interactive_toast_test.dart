import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/widgets/interactive_toast_overlay.dart';

void main() {
  testWidgets('TC-TOAST-01: InteractiveToastOverlay renders, handles tap, and dismisses on swipe', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                InteractiveToastOverlay.show(
                  context,
                  title: '🔴 Live Stream Alert',
                  message: 'Amir Al-Hatemi is live now: AI Architecture',
                  onTap: () => tapped = true,
                );
              },
              child: const Text('Show Toast'),
            ),
          ),
        ),
      ),
    );

    // 1. Tap button to show toast
    await tester.tap(find.text('Show Toast'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('🔴 Live Stream Alert'), findsOneWidget);
    expect(find.text('Amir Al-Hatemi is live now: AI Architecture'), findsOneWidget);

    // 2. Tap on the toast to trigger callback
    await tester.tap(find.text('🔴 Live Stream Alert'));
    await tester.pump();
    expect(tapped, isTrue);

    // 3. Re-show and swipe up to dismiss
    await tester.tap(find.text('Show Toast'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('interactive_toast_dismissible')), findsOneWidget);

    // Perform vertical drag up to dismiss
    await tester.drag(find.byKey(const Key('interactive_toast_dismissible')), const Offset(0, -100));
    await tester.pumpAndSettle();

    expect(find.text('🔴 Live Stream Alert'), findsNothing);
  });
}
