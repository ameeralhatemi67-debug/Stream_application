import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_flags.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/admin_safety_backend.dart';
import '../../../../core/theme/app_theme.dart';

enum _SafetySection { live, audit, keywords, switches }

/// The P6 admin safety console: what is live right now, the audit trail, the
/// chat keyword blocklist and (Master Admin only) the platform switches. Each
/// section reads the server directly and shows its own loading, empty and
/// error states; none of them has a local or sample fallback.
class AdminSafetyView extends StatefulWidget {
  const AdminSafetyView({super.key, this.backend, this.appFlags});

  /// Defaults to Supabase and the app-wide switches; tests pass fakes.
  final AdminSafetyBackend? backend;
  final AppFlags? appFlags;

  @override
  State<AdminSafetyView> createState() => _AdminSafetyViewState();
}

class _AdminSafetyViewState extends State<AdminSafetyView> {
  _SafetySection _section = _SafetySection.live;

  AdminSafetyBackend get _backend =>
      widget.backend ?? const SupabaseAdminSafetyBackend();
  AppFlags get _flags => widget.appFlags ?? AppFlags.instance;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AppProvider, bool>((p) => p.isAdminUser);
    final isMaster = context.select<AppProvider, bool>((p) => p.isMasterAdmin);
    if (!isAdmin) {
      return Center(child: Text('directory.denied'.tr()));
    }
    final sections = [
      _SafetySection.live,
      _SafetySection.audit,
      _SafetySection.keywords,
      if (isMaster) _SafetySection.switches,
    ];
    final section = sections.contains(_section) ? _section : sections.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg, AppTheme.spaceMd,
              AppTheme.spaceLg, AppTheme.spaceSm),
          child: Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            children: [
              for (final s in sections)
                ChoiceChip(
                  key: Key('safety-section-${s.name}'),
                  label: Text('safety.section_${s.name}'.tr()),
                  selected: s == section,
                  onSelected: (_) => setState(() => _section = s),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (section) {
            _SafetySection.live => _LiveSection(backend: _backend),
            _SafetySection.audit => _AuditSection(backend: _backend),
            _SafetySection.keywords => _KeywordSection(backend: _backend),
            _SafetySection.switches => _SwitchesSection(flags: _flags),
          },
        ),
      ],
    );
  }
}

String safetyFailureKey(Object error) {
  final failure = error is AdminSafetyException
      ? error.failure
      : error is AppFlagException
          ? switch (error.failure) {
              AppFlagFailure.notPermitted => AdminSafetyFailure.notPermitted,
              AppFlagFailure.invalid => AdminSafetyFailure.invalid,
              AppFlagFailure.network => AdminSafetyFailure.network,
            }
          : AdminSafetyFailure.network;
  return 'safety.error_${failure.name}';
}

void _showResult(BuildContext context, {String? errorKey, String? okKey}) {
  final key = errorKey ?? okKey;
  if (key == null) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(key.tr()),
    backgroundColor: errorKey == null ? null : AppTheme.danger,
  ));
}

/// Every privileged action here needs a stated reason; the server rejects a
/// blank one, so the dialog will not submit one either.
Future<String?> askSafetyReason(BuildContext context,
    {required String title, required String body}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(title: title, body: body),
  );
}

/// Owns its text controller so the field is only disposed with the dialog
/// itself, after the exit animation, not when the returned future completes.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.body});
  final String title;
  final String body;
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.body,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: AppTheme.spaceMd),
            TextField(
              key: const Key('safety-reason-field'),
              controller: _controller,
              autofocus: true,
              maxLength: 500,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration:
                  InputDecoration(labelText: 'safety.reason_label'.tr()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        ElevatedButton(
          key: const Key('safety-reason-confirm'),
          onPressed:
              text.isEmpty ? null : () => Navigator.of(context).pop(text),
          child: Text('common.confirm'.tr()),
        ),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage(this.messageKey, {this.onRetry, super.key});
  final String messageKey;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(messageKey.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spaceSm),
              TextButton(onPressed: onRetry, child: Text('common.retry'.tr())),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live now
// ---------------------------------------------------------------------------

class _LiveSection extends StatefulWidget {
  const _LiveSection({required this.backend});
  final AdminSafetyBackend backend;
  @override
  State<_LiveSection> createState() => _LiveSectionState();
}

class _LiveSectionState extends State<_LiveSection> {
  List<LiveBroadcastRow>? _rows;
  Object? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final rows = await widget.backend.loadLiveBroadcasts();
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _act(LiveBroadcastRow row, String action) async {
    final reason = await askSafetyReason(
      context,
      title: 'safety.live_$action'.tr(),
      body: 'safety.live_${action}_body'.tr(namedArgs: {'name': row.name}),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy.add(row.profileId));
    String? errorKey;
    try {
      await context
          .read<AppProvider>()
          .updateAdminAccount(row.profileId, action, reason);
    } catch (e) {
      errorKey = safetyFailureKey(AdminSafetyException.from(e));
    }
    if (!mounted) return;
    setState(() => _busy.remove(row.profileId));
    _showResult(context,
        errorKey: errorKey, okKey: 'safety.live_${action}_done');
    if (errorKey == null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (_error != null) {
      return _StatusMessage(safetyFailureKey(_error!),
          key: const Key('safety-live-error'), onRetry: _load);
    }
    if (rows == null) return const Center(child: CircularProgressIndicator());
    final known = rows.where((r) => r.viewerCount != null);
    final totalViewers = known.fold<int>(0, (a, r) => a + r.viewerCount!);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        children: [
          Text(
            'safety.live_summary'.tr(namedArgs: {
              'streams': '${rows.length}',
              'viewers': '$totalViewers',
            }),
            key: const Key('safety-live-summary'),
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
          ),
          if (known.length < rows.length)
            Text('safety.live_counts_partial'.tr(),
                style:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: AppTheme.spaceMd),
          if (rows.isEmpty)
            const _StatusMessage('safety.live_empty',
                key: Key('safety-live-empty'))
          else
            for (final r in rows)
              Card(
                key: Key('safety-live-${r.profileId}'),
                color: AppTheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppTheme.spaceXs),
                      Text(
                        [
                          (r.broadcastType == 'liveAudio'
                                  ? 'safety.live_audio'
                                  : 'safety.live_video')
                              .tr(),
                          r.viewerCount == null
                              ? 'safety.live_viewers_unknown'.tr()
                              : 'safety.live_viewers'.tr(namedArgs: {
                                  'count': '${r.viewerCount}'
                                }),
                        ].join(' · '),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      if (_busy.contains(r.profileId))
                        const LinearProgressIndicator()
                      else
                        Wrap(
                          spacing: AppTheme.spaceSm,
                          children: [
                            OutlinedButton(
                              key: Key('safety-end-${r.profileId}'),
                              onPressed: () => _act(r, 'force_end'),
                              child: Text('safety.live_force_end'.tr()),
                            ),
                            OutlinedButton(
                              key: Key('safety-remove-${r.profileId}'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.danger),
                              onPressed: () => _act(r, 'remove_from_feed'),
                              child: Text('safety.live_remove_from_feed'.tr()),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Audit log
// ---------------------------------------------------------------------------

/// Filter values offered in the audit viewer: the platform safety events.
/// Organization events stay visible under "All".
const safetyAuditActions = [
  'accountBanned',
  'accountUnbanned',
  'accountDeleted',
  'accountSessionsRevoked',
  'accountStreamerRevoked',
  'accountVerificationRevoked',
  'streamForceEnded',
  'streamRemovedFromFeed',
  'appFlagChanged',
  'chatKeywordAdded',
  'chatKeywordUpdated',
  'chatKeywordRemoved',
  'chatReportDismissed',
  'chatMessageDeleted',
  'chatSenderMuted',
  'chatSenderBanned',
];

class _AuditSection extends StatefulWidget {
  const _AuditSection({required this.backend});
  final AdminSafetyBackend backend;
  @override
  State<_AuditSection> createState() => _AuditSectionState();
}

class _AuditSectionState extends State<_AuditSection> {
  final List<AdminAuditEntry> _entries = [];
  String? _action;
  bool _hasMore = false;
  bool _loading = true;
  Object? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _entries.clear();
    });
    try {
      final page = await widget.backend
          .loadAudit(action: _action, offset: reset ? 0 : _entries.length);
      if (!mounted || request != _request) return;
      setState(() {
        _entries.addAll(page.entries);
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    final dateFormat = DateFormat.yMMMd(context.locale.languageCode).add_Hm();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
          child: DropdownButton<String?>(
            key: const Key('safety-audit-filter'),
            isExpanded: true,
            value: _action,
            items: [
              DropdownMenuItem(
                  value: null, child: Text('safety.audit_all'.tr())),
              for (final a in safetyAuditActions)
                DropdownMenuItem(value: a, child: Text('safety.action_$a'.tr())),
            ],
            onChanged: (value) {
              setState(() => _action = value);
              _load(reset: true);
            },
          ),
        ),
        Expanded(
          child: _error != null && _entries.isEmpty
              ? _StatusMessage(safetyFailureKey(_error!),
                  key: const Key('safety-audit-error'),
                  onRetry: () => _load(reset: true))
              : _loading && _entries.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? const _StatusMessage('safety.audit_empty',
                          key: Key('safety-audit-empty'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.spaceLg),
                          itemCount: _entries.length + 1,
                          itemBuilder: (context, i) {
                            if (i == _entries.length) {
                              if (_error != null) {
                                return _StatusMessage(
                                    safetyFailureKey(_error!),
                                    onRetry: () => _load(reset: false));
                              }
                              if (!_hasMore) return const SizedBox.shrink();
                              return Center(
                                child: _loading
                                    ? const CircularProgressIndicator()
                                    : TextButton(
                                        key: const Key('safety-audit-more'),
                                        onPressed: () => _load(reset: false),
                                        child:
                                            Text('safety.audit_more'.tr()),
                                      ),
                              );
                            }
                            final e = _entries[i];
                            final label = safetyAuditActions.contains(e.action)
                                ? 'safety.action_${e.action}'.tr()
                                : e.action;
                            return ListTile(
                              key: Key('safety-audit-${e.id}'),
                              contentPadding: EdgeInsets.zero,
                              title: Text(label,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                [
                                  isAr ? e.descriptionAr : e.descriptionEn,
                                  'safety.audit_by'.tr(namedArgs: {
                                    'actor': e.actorName.isNotEmpty
                                        ? e.actorName
                                        : e.actorEmail,
                                    'date': dateFormat
                                        .format(e.createdAt.toLocal()),
                                  }),
                                ].where((t) => t.isNotEmpty).join('\n'),
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Keyword blocklist
// ---------------------------------------------------------------------------

class _KeywordSection extends StatefulWidget {
  const _KeywordSection({required this.backend});
  final AdminSafetyBackend backend;
  @override
  State<_KeywordSection> createState() => _KeywordSectionState();
}

class _KeywordSectionState extends State<_KeywordSection> {
  List<BlocklistKeyword>? _keywords;
  Object? _error;
  final _input = TextEditingController();
  String _newMode = 'word';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await widget.backend.loadKeywords();
      if (mounted) setState(() => _keywords = list);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _run(Future<void> Function() write, String okKey) async {
    setState(() => _saving = true);
    String? errorKey;
    try {
      await write();
    } catch (e) {
      errorKey = safetyFailureKey(AdminSafetyException.from(e));
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _showResult(context, errorKey: errorKey, okKey: okKey);
    await _load();
  }

  Future<void> _add() async {
    final keyword = _input.text.trim();
    if (keyword.isEmpty || keyword.length > 100) {
      _showResult(context, errorKey: 'safety.keyword_invalid');
      return;
    }
    await _run(() => widget.backend.addKeyword(keyword, _newMode),
        'safety.keyword_added');
    if (mounted) _input.clear();
  }

  Future<void> _remove(BlocklistKeyword k) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('safety.keyword_remove_title'
            .tr(namedArgs: {'keyword': k.keyword})),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('common.cancel'.tr())),
          ElevatedButton(
              key: const Key('safety-keyword-remove-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('common.confirm'.tr())),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => widget.backend.removeKeyword(k.id),
        'safety.keyword_removed');
  }

  Widget _modeMenu(String value, ValueChanged<String> onChanged, {Key? key}) {
    return DropdownButton<String>(
      key: key,
      value: value,
      items: [
        DropdownMenuItem(
            value: 'word', child: Text('safety.keyword_mode_word'.tr())),
        DropdownMenuItem(
            value: 'substring',
            child: Text('safety.keyword_mode_substring'.tr())),
      ],
      onChanged: _saving ? null : (v) => v == null ? null : onChanged(v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keywords = _keywords;
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      children: [
        Text('safety.keyword_hint'.tr(),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: AppTheme.spaceSm),
        Wrap(
          spacing: AppTheme.spaceSm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                key: const Key('safety-keyword-input'),
                controller: _input,
                maxLength: 100,
                decoration: InputDecoration(
                    labelText: 'safety.keyword_label'.tr(), counterText: ''),
                onSubmitted: (_) => _add(),
              ),
            ),
            _modeMenu(_newMode, (v) => setState(() => _newMode = v)),
            ElevatedButton(
              key: const Key('safety-keyword-add'),
              onPressed: _saving ? null : _add,
              child: Text('safety.keyword_add'.tr()),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMd),
        if (_error != null)
          _StatusMessage(safetyFailureKey(_error!),
              key: const Key('safety-keyword-error'), onRetry: _load)
        else if (keywords == null)
          const Center(child: CircularProgressIndicator())
        else if (keywords.isEmpty)
          const _StatusMessage('safety.keyword_empty',
              key: Key('safety-keyword-empty'))
        else
          for (final k in keywords)
            ListTile(
              key: Key('safety-keyword-${k.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(k.keyword,
                  style: const TextStyle(color: AppTheme.textPrimary)),
              trailing: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _modeMenu(
                    k.matchMode,
                    (v) => _run(() => widget.backend.setKeywordMode(k.id, v),
                        'safety.keyword_updated'),
                    key: Key('safety-keyword-mode-${k.id}'),
                  ),
                  IconButton(
                    key: Key('safety-keyword-remove-${k.id}'),
                    tooltip: 'safety.keyword_remove'.tr(),
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.danger),
                    onPressed: _saving ? null : () => _remove(k),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Platform switches (Master Admin)
// ---------------------------------------------------------------------------

class _SwitchesSection extends StatefulWidget {
  const _SwitchesSection({required this.flags});
  final AppFlags flags;
  @override
  State<_SwitchesSection> createState() => _SwitchesSectionState();
}

class _SwitchesSectionState extends State<_SwitchesSection> {
  final Set<AppFlagKey> _busy = {};

  @override
  void initState() {
    super.initState();
    widget.flags.addListener(_onChanged);
    widget.flags.refresh();
  }

  @override
  void dispose() {
    widget.flags.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle(AppFlagKey key, bool enabled) async {
    final reason = await askSafetyReason(
      context,
      title: 'safety.switch_${key.column}'.tr(),
      body: (enabled ? 'safety.switch_on_body' : 'safety.switch_off_body')
          .tr(),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy.add(key));
    String? errorKey;
    try {
      await widget.flags.setFlag(key, enabled, reason);
    } catch (e) {
      errorKey = safetyFailureKey(e);
    }
    if (!mounted) return;
    setState(() => _busy.remove(key));
    _showResult(context, errorKey: errorKey, okKey: 'safety.switch_saved');
  }

  @override
  Widget build(BuildContext context) {
    final flags = widget.flags;
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      children: [
        Text('safety.switches_hint'.tr(),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        if (flags.status == AppFlagsStatus.failed)
          _StatusMessage('safety.switches_unknown',
              key: const Key('safety-switches-error'),
              onRetry: flags.refresh),
        const SizedBox(height: AppTheme.spaceSm),
        for (final key in AppFlagKey.values)
          SwitchListTile(
            key: Key('safety-switch-${key.column}'),
            contentPadding: EdgeInsets.zero,
            title: Text('safety.switch_${key.column}'.tr(),
                style: const TextStyle(color: AppTheme.textPrimary)),
            subtitle: Text(
              !flags.isKnown(key)
                  ? 'safety.switch_state_unknown'.tr()
                  : (flags.isEnabled(key)
                          ? 'safety.switch_state_on'
                          : 'safety.switch_state_off')
                      .tr(),
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            value: flags.isEnabled(key),
            onChanged: _busy.contains(key) || !flags.isKnown(key)
                ? null
                : (v) => _toggle(key, v),
          ),
      ],
    );
  }
}
