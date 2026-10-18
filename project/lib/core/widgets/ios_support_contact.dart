import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_identity.dart';
import '../theme/app_theme.dart';

/// Contact information available before sign-in and alongside the legal reader.
class IosSupportContact extends StatelessWidget {
  const IosSupportContact({super.key});

  Future<void> _openSupport(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri(scheme: 'mailto', path: AppIdentity.supportEmail),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // A simulator or a phone without Mail still needs a usable address.
    }
    if (opened || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ios_review.contact_support'.tr()),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTheme.spaceLg * 3),
          child: const SelectableText(AppIdentity.supportEmail),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('organization_v1.close'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppTheme.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            key: const Key('ios-support-contact'),
            onPressed: () => _openSupport(context),
            icon: const Icon(Icons.mail_outline_rounded),
            label: Text('ios_review.contact_support'.tr()),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppTheme.spaceLg * 3),
            child: SelectableText(AppIdentity.supportEmail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: paletteColor(context, AppTheme.textPrimary), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
