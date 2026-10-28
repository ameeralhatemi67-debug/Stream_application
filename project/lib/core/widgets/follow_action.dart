import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

/// Follows or unfollows [channelId] and, when the server refused, says so.
/// The button has already gone back to its earlier state by then.
Future<void> toggleFollowWithFeedback(
    BuildContext context, String channelId) async {
  final saved = await context.read<AppProvider>().toggleFollow(channelId);
  if (saved || !context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text('profile.follow_failed'.tr())));
}
