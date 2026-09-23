import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/providers/app_provider.dart';
import '../../../../../core/theme/app_theme.dart';

class AdminUserDirectoryView extends StatefulWidget {
  const AdminUserDirectoryView({super.key});
  @override
  State<AdminUserDirectoryView> createState() => _AdminUserDirectoryViewState();
}

class _AdminUserDirectoryViewState extends State<AdminUserDirectoryView> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true, _failed = false, _more = false;
  int _offset = 0, _request = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _request++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
      _rows = [];
    });
    try {
      final rows =
          await context.read<AppProvider>().searchAdminUsers(_query, _offset);
      if (!mounted || request != _request) return;
      setState(() {
        _rows = rows.take(25).toList();
        _more = rows.length > 25;
      });
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  String _name(Map<String, dynamic> row) =>
      (row[context.locale.languageCode == 'ar'
                  ? 'display_name_ar'
                  : 'display_name_en'] ??
              row['display_name_en'] ??
              row['email'] ??
              row['id'])
          .toString();

  @override
  Widget build(BuildContext context) {
    final allowed = context.select<AppProvider, bool>((p) => p.isAdminUser);
    if (!allowed) return Center(child: Text('directory.denied'.tr()));
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(children: [
        TextField(
            controller: _search,
            maxLength: 200,
            decoration: InputDecoration(
                labelText: 'directory.search'.tr(),
                suffixIcon: IconButton(
                    tooltip: 'directory.search'.tr(),
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      _query = _search.text.trim();
                      _offset = 0;
                      _load();
                    })),
            onSubmitted: (_) {
              _query = _search.text.trim();
              _offset = 0;
              _load();
            }),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _failed
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('directory.error'.tr()),
                        TextButton(
                            onPressed: _load,
                            child: Text('directory.retry'.tr())),
                      ]))
                    : _rows.isEmpty
                        ? Center(child: Text('directory.empty'.tr()))
                        : ListView.builder(
                            itemCount: _rows.length,
                            itemBuilder: (context, index) {
                              final row = _rows[index];
                              return ListTile(
                                  title: Text(_name(row)),
                                  subtitle: Text([
                                    row['email'],
                                    row['youtube_handle']
                                  ].whereType<String>().join('\n')),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () async {
                                    await showModalBottomSheet<void>(
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (_) =>
                                            ChangeNotifierProvider.value(
                                                value:
                                                    context.read<AppProvider>(),
                                                child: _AccountDetail(
                                                    id: row['id'] as String)));
                                    if (mounted) _load();
                                  });
                            })),
        Wrap(spacing: AppTheme.spaceMd, children: [
          TextButton(
              onPressed: _loading || _offset == 0
                  ? null
                  : () {
                      _offset -= 25;
                      _load();
                    },
              child: Text('directory.previous'.tr())),
          TextButton(
              onPressed: _loading || !_more
                  ? null
                  : () {
                      _offset += 25;
                      _load();
                    },
              child: Text('directory.next'.tr())),
        ]),
      ]),
    );
  }
}

class _AccountDetail extends StatefulWidget {
  const _AccountDetail({required this.id});
  final String id;
  @override
  State<_AccountDetail> createState() => _AccountDetailState();
}

class _AccountDetailState extends State<_AccountDetail> {
  late Future<Map<String, dynamic>> _detail;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _detail = context.read<AppProvider>().loadAdminUserDetail(widget.id);
  }

  Future<void> _act(String action) async {
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: Text('directory.$action'.tr()),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (action == 'delete_account' || action == 'revoke_sessions' || action == 'force_end' || action == 'remove_from_feed')
                    Text('directory.${action}_warning'.tr()),
                  TextField(
                    controller: reason,
                    maxLength: 500,
                    maxLines: 3,
                    decoration:
                        InputDecoration(labelText: 'directory.reason'.tr())),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text('common.cancel'.tr())),
                  TextButton(
                      onPressed: () {
                        if (reason.text.trim().isNotEmpty) {
                          Navigator.pop(dialogContext, true);
                        }
                      },
                      child: Text('directory.confirm'.tr()))
                ]));
    final text = reason.text.trim();
    // Dialog exit animation may still use its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    reason.dispose();
    if (accepted != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context
          .read<AppProvider>()
          .updateAdminAccount(widget.id, action, text);
      if (mounted) {
        if (action == 'delete_account') {
          Navigator.pop(context);
        } else {
          setState(_reload);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('directory.action_error'.tr())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = context.select<AppProvider, bool>((p) => p.isAdminUser);
    if (!allowed) return SafeArea(child: Text('directory.denied'.tr()));
    return SafeArea(
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .85,
            child: FutureBuilder<Map<String, dynamic>>(
                future: _detail,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('directory.error'.tr()),
                      TextButton(
                          onPressed: () => setState(_reload),
                          child: Text('directory.retry'.tr())),
                    ]));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final row = snapshot.data!;
                  final ar = context.locale.languageCode == 'ar';
                  final roles = (row['roles'] as List? ?? []).cast<String>();
                  return SingleChildScrollView(
                      padding: const EdgeInsets.all(AppTheme.spaceXl),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('directory.detail'.tr(),
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            Text(
                                '${row[ar ? 'display_name_ar' : 'display_name_en'] ?? row['email'] ?? ''}'),
                            SelectableText(
                                '${row['email'] ?? ''}\n${row['id']}'),
                            Text(
                                '${'directory.roles'.tr()}: ${roles.isEmpty ? 'directory.user'.tr() : roles.map((r) => 'directory.role_$r'.tr()).join(', ')}'),
                            Text(
                                '${'directory.streamer'.tr()}: ${'directory.${row['is_streamer'] == true ? 'yes' : 'no'}'.tr()}'),
                            Text(
                                '${'directory.verified'.tr()}: ${'directory.${row['is_verified'] == true ? 'yes' : 'no'}'.tr()}'),
                            Text(
                                '${'directory.reports'.tr()}: ${row['report_count'] ?? 0}'),
                            Text('directory.organizations'.tr(),
                                style: Theme.of(context).textTheme.titleMedium),
                            for (final org
                                in row['organizations'] as List? ?? [])
                              Text('${org[ar ? 'name_ar' : 'name_en']}'),
                            Text('directory.devices'.tr(),
                                style: Theme.of(context).textTheme.titleMedium),
                            Text('directory.device_note'.tr()),
                            for (final device in row['devices'] as List? ?? [])
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                      '${device['device_name']} (${device['platform']})'),
                                  subtitle: Text(
                                      '${device['last_active_at']}\n${'directory.${device['is_primary_broadcaster'] == true ? 'primary' : 'secondary'}'.tr()}')),
                            if (row['ban'] != null)
                              Text(
                                  '${'directory.ban_record'.tr()}: ${row['ban']['reason']}\n${row['ban']['expires_at'] ?? 'directory.permanent'.tr()}'),
                            const SizedBox(height: AppTheme.spaceLg),
                            Wrap(
                                spacing: AppTheme.spaceSm,
                                runSpacing: AppTheme.spaceSm,
                                children: [
                                  for (final action in [
                                    row['is_banned'] == true ? 'unban' : 'ban',
                                    if (row['is_streamer'] == true)
                                      'revoke_streamer',
                                    if (row['is_verified'] == true)
                                      'revoke_verified',
                                      'revoke_sessions',
                                      'delete_account',
                                      'force_end',
                                      'remove_from_feed'
                                  ])
                                    OutlinedButton(
                                        onPressed:
                                            _busy ? null : () => _act(action),
                                        child: Text('directory.$action'.tr())),
                                ]),
                            Text('directory.scope_note'.tr()),
                            TextButton(
                                onPressed:
                                    _busy ? null : () => Navigator.pop(context),
                                child: Text('directory.close'.tr())),
                          ]));
                })));
  }
}
