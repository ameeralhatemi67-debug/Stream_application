import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_distribution.dart';
import '../providers/app_provider.dart';
import '../providers/app_update_controller.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';
import 'ds/ca_button.dart';
import 'ds/ca_icon.dart';

/// Covers the app with [UpdateRequiredPage] while this version is below the
/// newest release's minimum (ADR-017). The app below stays mounted, so a
/// check that turns "required" never tears down a screen mid-task, and the
/// page waits until a phone broadcast has ended: a broadcaster must always be
/// able to reach End.
class AppUpdateGate extends StatelessWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final required = context.select<AppUpdateController?, bool>(
        (updates) => updates?.status == AppUpdateStatus.required);
    final live = context
        .select<AppProvider?, bool>((app) => app?.isBroadcastingLive ?? false);
    final blocked = required && !live;
    return Stack(fit: StackFit.expand, children: [
      ExcludeSemantics(
        excluding: blocked,
        child: IgnorePointer(ignoring: blocked, child: child),
      ),
      if (blocked) const UpdateRequiredPage(),
    ]);
  }
}

/// "Update required": what changed, the two versions, and the download (or,
/// for the Play build, the Play listing).
class UpdateRequiredPage extends StatefulWidget {
  const UpdateRequiredPage({super.key});

  @override
  State<UpdateRequiredPage> createState() => _UpdateRequiredPageState();
}

class _UpdateRequiredPageState extends State<UpdateRequiredPage> {
  bool _openFailed = false;
  bool _checking = false;

  Future<void> _download() async {
    final opened = await context.read<AppUpdateController>().openDownload();
    if (mounted) setState(() => _openFailed = !opened);
  }

  Future<void> _checkAgain() async {
    setState(() => _checking = true);
    await context.read<AppUpdateController>().check(force: true);
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final updates = context.watch<AppUpdateController>();
    final release = updates.release;
    final notes = release?.notes(context.locale.languageCode) ?? '';
    final textTheme = Theme.of(context).textTheme;
    return Material(
      key: const Key('update-required-page'),
      color: AppTheme.bg,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceXl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 72),
                  const SizedBox(height: AppTheme.spaceXl),
                  Semantics(
                    header: true,
                    child: Text('update.required_title'.tr(),
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text('update.required_body'.tr(),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge
                          ?.copyWith(color: AppTheme.textSecondary)),
                  if (release != null) ...[
                    const SizedBox(height: AppTheme.spaceMd),
                    Text(
                        'update.versions'.tr(namedArgs: {
                          'current': updates.installedVersion ?? '-',
                          'latest': release.versionName,
                        }),
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppTheme.textMuted)),
                  ],
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spaceLg),
                    _ReleaseNotes(notes: notes),
                  ],
                  const SizedBox(height: AppTheme.spaceXl),
                  SizedBox(
                    width: double.infinity,
                    child: CaButton(
                      key: const Key('update-required-download'),
                      label: updates.distribution == AppDistribution.play
                          ? 'update.open_play'.tr()
                          : 'update.download'.tr(),
                      icon: CaGlyph.download,
                      onPressed: _download,
                    ),
                  ),
                  if (_openFailed) ...[
                    const SizedBox(height: AppTheme.spaceSm),
                    Text('update.open_failed'.tr(),
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppTheme.danger)),
                  ],
                  const SizedBox(height: AppTheme.spaceSm),
                  CaButton(
                    key: const Key('update-required-check'),
                    label: 'update.check_again'.tr(),
                    variant: CaButtonVariant.text,
                    icon: CaGlyph.refresh,
                    loading: _checking,
                    onPressed: _checking ? null : _checkAgain,
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

class _ReleaseNotes extends StatelessWidget {
  const _ReleaseNotes({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('update.whats_new'.tr(),
              style: textTheme.labelLarge?.copyWith(color: AppTheme.textMuted)),
          const SizedBox(height: AppTheme.spaceXs),
          Text(notes, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
