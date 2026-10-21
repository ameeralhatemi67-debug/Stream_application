import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// Opens the sign-in screen over the current page and remembers [returnTo]
/// (by default the page on top) so a finished sign-in lands back there
/// instead of on Discovery (audit 2026-10-21, P0-4). The screen is pushed, so
/// Back without signing in also returns to the page.
Future<void> openSignIn(BuildContext context, {String? returnTo}) async {
  final location = returnTo ?? GoRouter.of(context).state.uri.toString();
  await context.read<AppProvider>().rememberSignInReturn(location);
  if (context.mounted) context.push('/welcome');
}
