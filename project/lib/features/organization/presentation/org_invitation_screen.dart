import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/org_invitation.dart';

/// Opens an invitation link. The server binds it to the invited, verified
/// email address; this screen only explains and forwards the answer.
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<AppProvider>();
      if (!provider.isLoggedInStreamer) return;
      try { await provider.refreshOrganizationInvitations(); } catch (_) {/* The answer reports failures. */}
    });
  }

  static String _errorKey(Object error) => switch (error) {
        PostgrestException(code: '42501') => 'organization_v1.invite_wrong_account',
        PostgrestException(code: '55000') => 'organization_v1.invite_expired',
        _ => 'organization_v1.failure',
      };

  Future<void> _answer(bool accept) async {
    setState(() { _busy = true; _error = null; });
    final provider = context.read<AppProvider>();
    try {
      await provider.answerOrganizationInvite(widget.id, accept, token: widget.token);
      await provider.rememberOrganizationInvitation(null);
      try { await provider.refreshOrganizationInvitations(); } catch (_) {}
      if (mounted) context.go('/organizations');
    } catch (error) {
      if (mounted) setState(() => _error = _errorKey(error));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select<AppProvider, bool>((p) => p.isLoggedInStreamer);
    final invitation = context.select<AppProvider, OrgInvitation?>((p) =>
        p.myOrganizationInvitations.where((i) => i.id == widget.id).firstOrNull);
    final language = context.locale.languageCode;
    return Scaffold(appBar: AppBar(title: Text('organization_v1.invitation'.tr()),
      leading: IconButton(icon: const Icon(Icons.close), tooltip: 'organization_v1.close'.tr(), onPressed: () async {
        await context.read<AppProvider>().rememberOrganizationInvitation(null);
        if (context.mounted) context.go('/feed');
      })), body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(padding: const EdgeInsets.all(AppTheme.spaceLg), child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (invitation != null) ...[
              Text(invitation.organizationName(language), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppTheme.spaceSm),
              Text('organization_v1.invited_as'.tr(namedArgs: {'role': 'organization_v1.${invitation.role}'.tr()})),
              const SizedBox(height: AppTheme.spaceSm),
            ],
            Text('organization_v1.invite_hint'.tr()),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: AppTheme.spaceSm),
              child: Text(_error!.tr(), style: const TextStyle(color: AppTheme.danger))),
            const SizedBox(height: AppTheme.spaceLg),
            if (signedIn) Wrap(spacing: AppTheme.spaceMd, runSpacing: AppTheme.spaceSm, children: [
              FilledButton(onPressed: _busy ? null : () => _answer(true), child: Text('organization_v1.accept'.tr())),
              OutlinedButton(onPressed: _busy ? null : () => _answer(false), child: Text('organization_v1.decline'.tr())),
            ]) else FilledButton(onPressed: _busy ? null : () async {
              final p = context.read<AppProvider>();
              final destination = Uri(path: '/org-invite/${widget.id}',
                queryParameters: widget.token == null ? null : {'token': widget.token!}).toString();
              await p.rememberOrganizationInvitation(destination);
              try { await p.loginWithGoogle(); }
              catch (_) { if (mounted) setState(() => _error = 'organization_v1.failure'); }
            }, child: Text('auth_welcome.btn_google_login'.tr())),
          ])))));
  }
}
