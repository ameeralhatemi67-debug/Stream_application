import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../live_stream/presentation/widgets/chat_message_actions_sheet.dart'
    show chatBlockFailureKey;
import '../../../live_stream/services/chat_block_list.dart';

/// Lists the chat accounts this viewer has blocked, straight from the server
/// (P6), and lets them unblock one. Opening the sheet refreshes the list, so
/// a block made on another device shows up here.
class BlockedAccountsSheet extends StatefulWidget {
  const BlockedAccountsSheet({super.key, this.blockList});

  /// Defaults to the app-wide list; tests pass their own.
  final ChatBlockList? blockList;

  static Future<void> show(BuildContext context, {ChatBlockList? blockList}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd)),
      ),
      builder: (_) => BlockedAccountsSheet(blockList: blockList),
    );
  }

  @override
  State<BlockedAccountsSheet> createState() => _BlockedAccountsSheetState();
}

class _BlockedAccountsSheetState extends State<BlockedAccountsSheet> {
  late final ChatBlockList _list = widget.blockList ?? ChatBlockList.instance;
  final Map<String, String> _names = {};
  final Set<String> _pending = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _list.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    _list.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await _list.refresh();
    final missing =
        _list.blockedIds.where((id) => !_names.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      try {
        _names.addAll(await _list.resolveNames(missing));
      } catch (e) {
        debugPrint('BlockedAccountsSheet: name lookup failed: $e');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _unblock(String id) async {
    setState(() => _pending.add(id));
    String? errorKey;
    try {
      await _list.unblock(id);
    } on ChatBlockException catch (e) {
      errorKey = chatBlockFailureKey(e.failure);
    } catch (_) {
      errorKey = chatBlockFailureKey(ChatBlockFailure.network);
    }
    if (!mounted) return;
    setState(() => _pending.remove(id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text((errorKey ?? 'settings.unblocked_toast').tr()),
        backgroundColor: errorKey == null ? null : AppTheme.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ids = _list.blockedIds.toList()..sort();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'settings.blocked_accounts_title'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                'settings.blocked_accounts_hint'.tr(),
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
              ),
              if (_list.isStale && !_loading) ...[
                const SizedBox(height: AppTheme.spaceSm),
                Row(
                  key: const Key('blocked-accounts-stale'),
                  children: [
                    const Icon(Icons.cloud_off_rounded,
                        size: 16, color: AppTheme.warning),
                    const SizedBox(width: AppTheme.spaceXs),
                    Expanded(
                      child: Text(
                        'settings.blocked_accounts_stale'.tr(),
                        style: const TextStyle(
                            color: AppTheme.warning, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _loading = true);
                        _load();
                      },
                      child: Text('common.retry'.tr()),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppTheme.spaceMd),
              if (_loading && ids.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (ids.isEmpty)
                Text(
                  'settings.blocked_accounts_empty'.tr(),
                  key: const Key('blocked-accounts-empty'),
                  style: const TextStyle(color: AppTheme.textMuted),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: ids.length,
                    itemBuilder: (context, i) {
                      final id = ids[i];
                      final name = _names[id];
                      return ListTile(
                        key: Key('blocked-account-$id'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.block_rounded,
                            color: AppTheme.textMuted),
                        title: Text(
                          (name == null || name.isEmpty)
                              ? 'settings.blocked_account_unknown'.tr()
                              : name,
                          style: const TextStyle(color: AppTheme.textPrimary),
                        ),
                        trailing: _pending.contains(id)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : TextButton(
                                onPressed: () => _unblock(id),
                                child: Text('settings.unblock'.tr()),
                              ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
