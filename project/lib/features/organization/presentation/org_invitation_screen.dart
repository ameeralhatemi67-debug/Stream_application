import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';

class OrgInvitationScreen extends StatefulWidget {
  const OrgInvitationScreen({super.key, required this.id, this.token});
  final String id;
  final String? token;
  @override
  State<OrgInvitationScreen> createState() => _OrgInvitationScreenState();
}
class _OrgInvitationScreenState extends State<OrgInvitationScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _answer(bool accept) async {
    setState(() { _busy = true; _error = null; });
    final provider = context.read<AppProvider>();
    try {
      await provider.answerOrganizationInvite(widget.id, accept, token: widget.token);
      await provider.rememberOrganizationInvitation(null);
      if (mounted) context.go('/feed');
    } catch (_) {
      if (mounted) setState(() => _error = 'organization_v1.failure'.tr());
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final signedIn = context.select<AppProvider, bool>((p) => p.isLoggedInStreamer);
    return Scaffold(appBar: AppBar(title: Text('organization_v1.invitation'.tr()),
      leading: IconButton(icon: const Icon(Icons.close), onPressed: () async {
        await context.read<AppProvider>().rememberOrganizationInvitation(null);
        if (context.mounted) context.go('/feed');
      })), body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(padding: const EdgeInsets.all(AppTheme.spaceLg), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            Text('organization_v1.invite_hint'.tr()),
            if (_error != null) Text(_error!, style: const TextStyle(color: AppTheme.danger)),
            const SizedBox(height: AppTheme.spaceLg),
            if (signedIn) Wrap(spacing: AppTheme.spaceMd, children: [
              FilledButton(onPressed: _busy ? null : () => _answer(true), child: Text('organization_v1.accept'.tr())),
              TextButton(onPressed: _busy ? null : () => _answer(false), child: Text('organization_v1.decline'.tr())),
            ]) else FilledButton(onPressed: _busy ? null : () async {
              final p = context.read<AppProvider>();
              final destination = Uri(path: '/org-invite/${widget.id}',
                queryParameters: widget.token == null ? null : {'token': widget.token!}).toString();
              await p.rememberOrganizationInvitation(destination);
              try { await p.loginWithGoogle(); }
              catch (_) { if (mounted) setState(() => _error = 'organization_v1.failure'.tr()); }
            }, child: Text('auth_welcome.btn_google_login'.tr())),
          ])))));
  }
}
