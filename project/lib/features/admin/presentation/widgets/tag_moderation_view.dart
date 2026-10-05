import '../../../../core/widgets/ds/ca_cards.dart';
import '../admin_surface.dart';
import '../../../../core/widgets/phone_input_guard.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../models/tag_moderation_model.dart';
import '../../../../core/widgets/hadayah_loading_indicator.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';

/// Admin Tag Moderation manager (Cluster 3 Task 12): approve, merge/rename,
/// or blacklist tags submitted via the streamer application form before
/// they're suggested/filterable anywhere public.
class TagModerationView extends StatefulWidget {
  const TagModerationView({super.key});

  @override
  State<TagModerationView> createState() => _TagModerationViewState();
}

class _TagModerationViewState extends State<TagModerationView> {
  final Set<String> _actingOnNames = {};

  @override
  void initState() {
    super.initState();
    context.read<AppProvider>().ensureTagsLoaded();
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Canopy.liveCrimson : Canopy.leaf,
      ),
    );
  }

  Future<void> _run(String name, Future<void> Function() action,
      String successMessage) async {
    setState(() => _actingOnNames.add(name));
    try {
      await action();
      _showToast(successMessage);
    } catch (e) {
      _showToast('$e', isError: true);
    } finally {
      if (mounted) setState(() => _actingOnNames.remove(name));
    }
  }

  void _showMergeDialog(AppProvider provider, String oldName) {
    final controller = TextEditingController(text: oldName);
    showCaDialog(
      context: context,
      builder: (dialogContext) => CaAlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: const BorderSide(color: Canopy.hairline),
        ),
        title: Text('admin.tag_merge_dialog_title'.tr(),
            style: const TextStyle(
                color: Canopy.ink, fontWeight: FontWeight.bold)),
        content: PhoneInputGuard(builder: (context, blocked) => TextField(
                  readOnly: blocked,
                  controller: controller,
                  autofocus: (true) && !blocked,
                  style: const TextStyle(color: Canopy.ink),
                  decoration: InputDecoration(
                    hintText: 'admin.tag_merge_dialog_hint'.tr(),
                    hintStyle: const TextStyle(color: Canopy.haze),
                    filled: true,
                    fillColor: Canopy.mint,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  ),
                )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('common.cancel'.tr(),
                style: const TextStyle(color: Canopy.haze)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onMedia),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(dialogContext);
              _run(
                oldName,
                () =>
                    provider.mergeRenameTag(oldName: oldName, newName: newName),
                'admin.tag_merged_toast'.tr(),
              );
            },
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final allTags = context.select<AppProvider, List<TagModerationModel>>(
        (p) => p.allTagsForModeration);

    final pending =
        allTags.where((t) => t.status == TagStatus.pending).toList();
    final approved =
        allTags.where((t) => t.status == TagStatus.approved).toList();
    final blacklisted =
        allTags.where((t) => t.status == TagStatus.blacklisted).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminFlow(
            children: [
              const Icon(Icons.sell_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'admin.tag_moderation_title'.tr(),
                style: const TextStyle(
                  color: Canopy.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              if (pending.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Canopy.warningTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${pending.length}',
                      style: const TextStyle(
                          color: Canopy.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text('admin.tag_moderation_desc'.tr(),
              style:
                  const TextStyle(color: Canopy.slate, fontSize: 12)),
          const SizedBox(height: AppTheme.spaceLg),
          _buildSection(
            provider,
            title: 'admin.tag_pending_section'.tr(),
            tags: pending,
            emptyLabel: 'admin.no_pending_tags'.tr(),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          _buildSection(
            provider,
            title: 'admin.tag_approved_section'.tr(),
            tags: approved,
            emptyLabel: null,
          ),
          const SizedBox(height: AppTheme.spaceLg),
          _buildSection(
            provider,
            title: 'admin.tag_blacklisted_section'.tr(),
            tags: blacklisted,
            emptyLabel: null,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    AppProvider provider, {
    required String title,
    required List<TagModerationModel> tags,
    required String? emptyLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Canopy.ink,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: AppTheme.spaceSm),
        if (tags.isEmpty && emptyLabel != null)
          Text(emptyLabel,
              style: const TextStyle(color: Canopy.haze, fontSize: 12))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) => _buildTagChip(provider, tag)).toList(),
          ),
      ],
    );
  }

  /// Task 12: modal bottom sheet listing every broadcaster currently
  /// tagged with [tag] -- the "Inspect Broadcasters"drill-down.
  void _showInspectBroadcastersSheet(AppProvider provider, String tag) {
    showCaSheet(context, title: '', framed: false, useRootNavigator: false,
        body: Builder(builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return FutureBuilder<List<TaggedBroadcasterSummary>>(
            future: provider.loadBroadcastersForTag(tag),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceLg),
                    child: Row(
                      children: [
                        const Icon(Icons.groups_rounded,
                            color: AppTheme.primary, size: 20),
                        const SizedBox(width: AppTheme.spaceSm),
                        Expanded(
                          child: Text(
                            '#$tag',
                            style: const TextStyle(
                              color: Canopy.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(AppTheme.spaceXl),
                      child: Center(
                          child:
                              HadayahLoadingIndicator(color: AppTheme.primary)),
                    )
                  else if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceLg),
                      child: Text(
                        'admin.tag_no_broadcasters'.tr(),
                        style: const TextStyle(
                            color: Canopy.slate, fontSize: 12),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceLg),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Canopy.hairline, height: 1),
                        itemBuilder: (context, index) {
                          final b = items[index];
                          return ListTile(
                            leading: CaAvatar(
                              name: b.nameEn,
                              url: b.avatarUrl,
                              org: b.isOrganization,
                              ring: CaAvatarRing.brand,
                            ),
                            title: Text(b.nameEn,
                                style: const TextStyle(
                                    color: Canopy.ink, fontSize: 13)),
                            trailing: b.isOrganization
                                ? const Icon(Icons.apartment_rounded,
                                    color: AppTheme.warning, size: 16)
                                : const Icon(Icons.person_rounded,
                                    color: AppTheme.primary, size: 16),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      );
    }));
  }

  Widget _buildTagChip(AppProvider provider, TagModerationModel tag) {
    final isActing = _actingOnNames.contains(tag.name);
    return AdminCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Wrap(
          spacing: AppTheme.spaceSm,
          runSpacing: AppTheme.spaceXs,
          children: [
            Text(tag.name,
                style:
                    const TextStyle(color: Canopy.ink, fontSize: 12)),
            if (tag.status == TagStatus.approved) ...[
              const SizedBox(width: 5),
              InkWell(
                onTap: () => _showInspectBroadcastersSheet(provider, tag.name),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    'admin.tag_broadcaster_count'
                        .tr(namedArgs: {'count': '${tag.usageCount}'}),
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            if (isActing)
              const SizedBox(
                width: 12,
                height: 12,
                child: HadayahLoadingIndicator(
                    strokeWidth: 2, color: AppTheme.primary),
              )
            else ...[
              if (tag.status != TagStatus.approved)
                Tooltip(
                  message: 'admin.tag_approve'.tr(),
                  child: InkWell(
                    onTap: () => _run(
                      tag.name,
                      () => provider.approveTag(tag.name),
                      'admin.tag_approved_toast'.tr(),
                    ),
                    child: const SizedBox.square(
                      dimension: CanopySize.target,
                      child: Icon(Icons.check_circle_outline_rounded,
                          size: 15, color: Canopy.leaf),
                    ),
                  ),
                ),
              Tooltip(
                message: 'admin.tag_merge_rename'.tr(),
                child: InkWell(
                  onTap: () => _showMergeDialog(provider, tag.name),
                  child: const SizedBox.square(
                    dimension: CanopySize.target,
                    child: Icon(Icons.drive_file_rename_outline_rounded,
                        size: 15, color: AppTheme.primary),
                  ),
                ),
              ),
              if (tag.status != TagStatus.blacklisted)
                Tooltip(
                  message: 'admin.tag_blacklist'.tr(),
                  child: InkWell(
                    onTap: () => _run(
                      tag.name,
                      () => provider.blacklistTag(tag.name),
                      'admin.tag_blacklisted_toast'.tr(),
                    ),
                    child: const SizedBox.square(
                      dimension: CanopySize.target,
                      child: Icon(Icons.block_rounded,
                          size: 15, color: Canopy.liveCrimson),
                    ),
                  ),
                ),
            ],
          ],
        ));
  }
}
