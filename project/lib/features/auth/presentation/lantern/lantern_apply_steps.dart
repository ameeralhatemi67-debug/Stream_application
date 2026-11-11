import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import 'lantern_apply_view.dart';

/// Step 2: the channel banner and the profile photo. Picking, arranging and
/// their errors stay in ApplyStep2Media; this draws them.
class LanternApplyMedia extends StatelessWidget implements LanternSkinWidget {
  const LanternApplyMedia(
      {super.key,
      required this.banner,
      required this.avatar,
      required this.name,
      required this.onPickBanner,
      required this.onPickAvatar,
      required this.onArrangeBanner,
      required this.onArrangeAvatar,
      this.bannerError,
      this.avatarError});

  final ImageProvider? banner, avatar;
  final String name;
  final VoidCallback onPickBanner, onPickAvatar, onArrangeBanner, onArrangeAvatar;

  /// A picture that could not be read.
  final String? bannerError, avatarError;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final bannerMissing = LanternApplyErrors.errorFor(context, 'banner');
    final avatarMissing = LanternApplyErrors.errorFor(context, 'avatar');
    Widget label(String text) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 8, start: 2),
        child: Text(text,
            style: Lantern.textStyle(13,
                color: t.muted, weight: FontWeight.w600, height: 1.3)));
    Widget problem(String? text) => text == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsetsDirectional.only(top: 6, start: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LIcon(LGlyph.warn, size: 14, color: t.liveText),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(text,
                      style: Lantern.textStyle(12.5,
                          color: t.liveText,
                          weight: FontWeight.w500,
                          height: 1.35))),
            ]));

    final bannerBox = LanternApplyAnchor(
        id: 'banner',
        child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
                key: const ValueKey('lantern-apply-banner'),
                height: 160,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: bannerMissing != null || bannerError != null
                        ? Border.all(color: t.live, width: 1.5)
                        : null),
                child: Stack(fit: StackFit.expand, children: [
                  LNightBand(
                      latticeOpacity: .2,
                      latticeStep: 24,
                      child: banner == null
                          ? const SizedBox.expand()
                          : Image(
                              image: banner!,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink())),
                  Center(
                      child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                        LButton(
                            key: const ValueKey('lantern-apply-pick-banner'),
                            label: banner == null
                                ? 'lantern.apply.pick_banner'.tr()
                                : 'common.change'.tr(),
                            icon: banner == null ? LGlyph.plus : LGlyph.image,
                            kind: LButtonKind.dark,
                            size: LButtonSize.small,
                            onPressed: onPickBanner),
                        if (banner != null)
                          LButton(
                              label: 'common.arrange'.tr(),
                              icon: LGlyph.scale,
                              kind: LButtonKind.dark,
                              size: LButtonSize.small,
                              onPressed: onArrangeBanner),
                      ])),
                ]))));

    final avatarRow = LanternApplyAnchor(
        id: 'avatar',
        child: Row(children: [
          DecoratedBox(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: avatarMissing != null || avatarError != null
                          ? t.live
                          : t.line,
                      width: 2)),
              child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: LAvatar(
                      key: const ValueKey('lantern-apply-avatar'),
                      name: name,
                      image: avatar,
                      size: 84))),
          const SizedBox(width: 16),
          Expanded(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
            LButton(
                key: const ValueKey('lantern-apply-pick-avatar'),
                label: avatar == null
                    ? 'lantern.apply.pick_avatar'.tr()
                    : 'common.change'.tr(),
                icon: LGlyph.upload,
                kind: LButtonKind.tonal,
                size: LButtonSize.small,
                onPressed: onPickAvatar),
            if (avatar != null)
              LButton(
                  label: 'wizard_steps.step2_arrange_btn'.tr(),
                  icon: LGlyph.scale,
                  kind: LButtonKind.ghost,
                  size: LButtonSize.small,
                  onPressed: onArrangeAvatar),
          ])),
        ]));

    return Column(
        key: const ValueKey('lantern-apply-step-media'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LanternApplyStepHead(
              title: 'wizard_steps.step2_title'.tr().split(':').last.trim(),
              description: 'wizard_steps.step2_desc'.tr()),
          label('wizard_steps.step2_banner_label'.tr()),
          bannerBox,
          problem(bannerError ?? bannerMissing),
          const SizedBox(height: 22),
          label('wizard_steps.step2_avatar_label'.tr()),
          avatarRow,
          problem(avatarError ?? avatarMissing),
        ]);
  }
}

/// How far the YouTube check has come, as ApplyStep3Professional knows it.
enum LanternYoutubeCheck { none, checking, verified, formatOk, invalid }

/// Step 3: individual or organization, affiliation, the YouTube channel
/// with its check, the subject fields and the tags. Every choice and the
/// YouTube check stay in ApplyStep3Professional.
class LanternApplyProfessional extends StatelessWidget
    implements LanternSkinWidget {
  const LanternApplyProfessional(
      {super.key,
      required this.isOrganization,
      required this.organizationsOpen,
      required this.orgName,
      required this.affiliation,
      required this.youtube,
      required this.youtubeCheck,
      required this.youtubeMessage,
      required this.onYoutubeChanged,
      required this.categories,
      required this.selectedCategories,
      required this.onCategory,
      required this.onAddCategory,
      required this.tags,
      required this.selectedTags,
      required this.pendingTags,
      required this.onTag,
      required this.customTag,
      required this.onSubmitTag,
      required this.onType,
      this.organizationOnly = false,
      this.onOrganizationOnly});

  final bool isOrganization, organizationsOpen, organizationOnly;
  final TextEditingController orgName, affiliation, youtube, customTag;
  final LanternYoutubeCheck youtubeCheck;
  final String youtubeMessage;
  final ValueChanged<String> onYoutubeChanged;

  /// Subject fields: id and label.
  final List<(String, String)> categories;
  final List<String> selectedCategories;
  final ValueChanged<String> onCategory;
  final VoidCallback onAddCategory, onSubmitTag;
  final List<String> tags, selectedTags, pendingTags;
  final ValueChanged<String> onTag;

  /// Individual (false) or organization (true).
  final ValueChanged<bool> onType;
  final ValueChanged<bool>? onOrganizationOnly;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    Widget head(String text, {Widget? trailing}) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 8, start: 2),
        child: Row(children: [
          Expanded(
              child: Text(text,
                  style: Lantern.textStyle(13,
                      color: t.muted, weight: FontWeight.w600, height: 1.3))),
          if (trailing != null) trailing,
        ]));
    Widget typeOption(
            {required bool selected,
            required LGlyph icon,
            required String title,
            required String sub,
            required VoidCallback onTap,
            bool unavailable = false,
            required Key key}) =>
        LCard(
            key: key,
            onTap: onTap,
            selected: selected,
            dim: unavailable,
            label: '$title, $sub',
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              LIcon(icon, size: 22, color: t.goldInk),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text(title,
                        style: Lantern.textStyle(14.5,
                            color: t.fg, weight: FontWeight.w600, height: 1.3)),
                    Text(sub,
                        style: Lantern.textStyle(12.5,
                            color: t.muted, height: 1.35)),
                  ])),
              if (unavailable) ...[
                const SizedBox(width: 6),
                LBadge('lantern.apply.soon'.tr(),
                    kind: LBadgeKind.soon, small: true),
              ],
            ]));
    final individual = typeOption(
        key: const ValueKey('lantern-apply-type-individual'),
        selected: !isOrganization,
        icon: LGlyph.person,
        title: 'wizard_steps.step3_type_individual'.tr(),
        sub: 'wizard_steps.step3_type_individual_sub'.tr(),
        onTap: () => onType(false));
    final org = typeOption(
        key: const ValueKey('lantern-apply-type-org'),
        selected: isOrganization,
        icon: LGlyph.org,
        title: 'wizard_steps.step3_type_org'.tr(),
        sub: organizationsOpen
            ? 'wizard_steps.step3_type_org_sub'.tr()
            : 'application.organization_coming_soon'.tr(),
        unavailable: !organizationsOpen,
        onTap: () => onType(true));
    final narrow = !context.lanternWide && MediaQuery.sizeOf(context).width < 640;

    final ytError = LanternApplyErrors.errorFor(context, 'youtube');
    final ytTone = switch (youtubeCheck) {
      LanternYoutubeCheck.verified => t.ok,
      LanternYoutubeCheck.invalid => t.liveText,
      _ => t.muted,
    };

    return Column(
        key: const ValueKey('lantern-apply-step-professional'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LanternApplyStepHead(
              title: 'wizard_steps.step3_title'.tr().split(':').last.trim(),
              description: 'wizard_steps.step3_desc'.tr()),
          head('wizard_steps.step3_entity_type'.tr()),
          if (narrow) ...[
            individual,
            const SizedBox(height: 10),
            org,
          ] else
            IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Expanded(child: individual),
                  const SizedBox(width: 12),
                  Expanded(child: org),
                ])),
          const SizedBox(height: 18),
          if (isOrganization) ...[
            LanternApplyAnchor(
                id: 'org_name',
                child: LField(
                    key: const ValueKey('lantern-apply-field-org_name'),
                    controller: orgName,
                    label: 'wizard_steps.step3_org_name_label'.tr(),
                    hint: 'wizard_steps.step3_org_name_hint'.tr(),
                    icon: LGlyph.org,
                    onChanged: (_) =>
                        LanternApplyErrors.edited(context, 'org_name'),
                    error: LanternApplyErrors.errorFor(context, 'org_name'))),
            const SizedBox(height: 16),
          ],
          LField(
              key: const ValueKey('lantern-apply-field-affiliation'),
              controller: affiliation,
              label: (isOrganization
                      ? 'wizard_steps.step3_affiliation_org'
                      : 'wizard_steps.step3_affiliation_ind')
                  .tr(),
              hint: (isOrganization
                      ? 'wizard_steps.step3_org_name_hint'
                      : 'wizard_steps.step3_affiliation_ind_hint')
                  .tr(),
              icon: LGlyph.book),
          const SizedBox(height: 16),
          if (!isOrganization && onOrganizationOnly != null) ...[
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text('organization_v1.apply_org_only'.tr(),
                        style: Lantern.textStyle(14.5,
                            color: t.fg, weight: FontWeight.w600, height: 1.3)),
                    Text('organization_v1.apply_org_only_hint'.tr(),
                        style: Lantern.textStyle(12.5,
                            color: t.muted, height: 1.4)),
                  ])),
              const SizedBox(width: 12),
              LSwitch(
                  key: const ValueKey('lantern-apply-org-only'),
                  value: organizationOnly,
                  label: 'organization_v1.apply_org_only'.tr(),
                  onChanged: onOrganizationOnly),
            ]),
            const SizedBox(height: 16),
          ],
          if (!organizationOnly) ...[
            LanternApplyAnchor(
                id: 'youtube',
                child: LField(
                    key: const ValueKey('lantern-apply-field-youtube'),
                    controller: youtube,
                    label: 'wizard_steps.step3_youtube_label'.tr(),
                    hint: '@handle',
                    icon: LGlyph.link,
                    keyboardType: TextInputType.url,
                    textDirection: TextDirection.ltr,
                    onChanged: (v) {
                      LanternApplyErrors.edited(context, 'youtube');
                      onYoutubeChanged(v);
                    },
                    error: ytError,
                    trailing: switch (youtubeCheck) {
                      LanternYoutubeCheck.checking => const Padding(
                          padding: EdgeInsets.all(12),
                          child: LStarLoader(size: 18)),
                      LanternYoutubeCheck.verified => Padding(
                          padding: const EdgeInsets.all(12),
                          child: LIcon(LGlyph.verified, size: 20, color: t.ok)),
                      LanternYoutubeCheck.formatOk => Padding(
                          padding: const EdgeInsets.all(12),
                          child:
                              LIcon(LGlyph.check, size: 20, color: t.goldInk)),
                      LanternYoutubeCheck.invalid => Padding(
                          padding: const EdgeInsets.all(12),
                          child: LIcon(LGlyph.warn, size: 20, color: t.live)),
                      LanternYoutubeCheck.none => null,
                    })),
            if (ytError == null && youtubeMessage.isNotEmpty)
              Container(
                  key: ValueKey('lantern-apply-youtube-${youtubeCheck.name}'),
                  margin: const EdgeInsets.only(top: 8),
                  padding: youtubeCheck == LanternYoutubeCheck.verified
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                      : EdgeInsets.zero,
                  decoration: youtubeCheck == LanternYoutubeCheck.verified
                      ? BoxDecoration(
                          color: t.okSoft,
                          borderRadius:
                              BorderRadius.circular(Lantern.radiusTile))
                      : null,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (youtubeCheck == LanternYoutubeCheck.verified) ...[
                          LIcon(LGlyph.check, size: 16, color: t.ok),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                            child: Text(youtubeMessage,
                                style: Lantern.textStyle(12.5,
                                    color: ytTone,
                                    weight: FontWeight.w500,
                                    height: 1.4))),
                      ])),
            const SizedBox(height: 18),
          ],
          LanternApplyAnchor(
              id: 'categories',
              child: head(
                  'wizard_steps.step3_categories_title'
                      .tr(args: ['${selectedCategories.length}']),
                  trailing: LLink('wizard_steps.step3_add_custom_field'.tr(),
                      icon: LGlyph.plus, arrow: false, onTap: onAddCategory))),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (id, name) in categories)
              LChip(
                  key: ValueKey('lantern-apply-category-$id'),
                  label: name,
                  selected: selectedCategories.contains(id) ||
                      selectedCategories.contains(name),
                  onTap: () => onCategory(id)),
          ]),
          if (LanternApplyErrors.errorFor(context, 'categories') != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(LanternApplyErrors.errorFor(context, 'categories')!,
                    style: Lantern.textStyle(12.5, color: t.liveText))),
          const SizedBox(height: 22),
          head('wizard_steps.step3_tags_title'.tr()),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final tag in tags)
              LChip(
                  label: tag,
                  dense: true,
                  selected: selectedTags.contains(tag),
                  onTap: () => onTag(tag)),
            for (final tag in pendingTags)
              LChip(
                  label: tag,
                  dense: true,
                  icon: LGlyph.clock,
                  selected: true,
                  onTap: () => onTag(tag)),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: LField(
                    controller: customTag,
                    label: 'wizard_steps.step3_custom_tag_hint'.tr(),
                    hint: '#',
                    onSubmitted: (_) => onSubmitTag())),
            const SizedBox(width: 8),
            Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: LIconButton(
                    icon: LGlyph.plus,
                    label: 'wizard_steps.step3_custom_tag_hint'.tr(),
                    onPressed: onSubmitTag)),
          ]),
        ]);
  }
}

/// Step 4: city, venue and its point on the map, branches of an
/// organization, the phone number and how the admins should reach you.
/// The map picker, the branch dialog and the phone check stay in
/// ApplyStep4Location.
class LanternApplyVenue extends StatelessWidget implements LanternSkinWidget {
  const LanternApplyVenue(
      {super.key,
      required this.cities,
      required this.city,
      required this.onCity,
      required this.venue,
      required this.isOrganization,
      required this.pinned,
      required this.onPin,
      required this.branches,
      required this.onAddBranch,
      required this.onRemoveBranch,
      required this.phone,
      required this.onPhoneChanged,
      required this.contact,
      required this.onContact,
      this.phoneProblem});

  final List<(String, String)> cities;
  final String city;
  final ValueChanged<String> onCity;
  final TextEditingController venue, phone;
  final bool isOrganization;

  /// The pinned point in words, or null when none was chosen.
  final String? pinned;
  final VoidCallback onPin, onAddBranch;

  /// Name and address of each branch.
  final List<(String, String)> branches;
  final ValueChanged<int> onRemoveBranch;
  final ValueChanged<String> onPhoneChanged;

  /// The live check of the number while typing.
  final String? phoneProblem;
  final String contact;
  final ValueChanged<String> onContact;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    Widget head(String text) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 8, start: 2),
        child: Text(text,
            style: Lantern.textStyle(13,
                color: t.muted, weight: FontWeight.w600, height: 1.3)));
    final cityError = LanternApplyErrors.errorFor(context, 'city');
    final mapError = LanternApplyErrors.errorFor(context, 'map');
    return Column(
        key: const ValueKey('lantern-apply-step-venue'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LanternApplyStepHead(
              title: (isOrganization
                      ? 'wizard_steps.step4_title_org'
                      : 'wizard_steps.step4_title_ind')
                  .tr()
                  .split(':')
                  .last
                  .trim(),
              description: 'wizard_steps.step4_desc'.tr()),
          LanternApplyAnchor(id: 'city', child: head('map.select_city'.tr())),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (id, name) in cities)
              LChip(
                  key: ValueKey('lantern-apply-city-$id'),
                  label: name,
                  selected: city == id,
                  onTap: () => onCity(id)),
          ]),
          if (cityError != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(cityError,
                    style: Lantern.textStyle(12.5, color: t.liveText))),
          const SizedBox(height: 18),
          LanternApplyAnchor(
              id: 'venue',
              child: LField(
                  key: const ValueKey('lantern-apply-field-venue'),
                  controller: venue,
                  label: (isOrganization
                          ? 'wizard_steps.step4_venue_org_label'
                          : 'wizard_steps.step4_venue_ind_label')
                      .tr(),
                  icon: LGlyph.mosque,
                  onChanged: (_) => LanternApplyErrors.edited(context, 'venue'),
                  error: LanternApplyErrors.errorFor(context, 'venue'))),
          const SizedBox(height: 10),
          LanternApplyAnchor(
              id: 'map',
              child: Container(
                  key: const ValueKey('lantern-apply-pin'),
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
                  decoration: BoxDecoration(
                      color: t.sunk,
                      borderRadius: BorderRadius.circular(Lantern.radiusField),
                      border: Border.all(
                          color: mapError != null ? t.live : t.line)),
                  child: Row(children: [
                    LIcon(pinned == null ? LGlyph.pin : LGlyph.check,
                        size: 18, color: pinned == null ? t.muted : t.ok),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(pinned ?? 'map.picker_no_point'.tr(),
                            style: Lantern.textStyle(13.5,
                                color: t.fg, height: 1.4))),
                    LButton(
                        key: const ValueKey('lantern-apply-pin-button'),
                        label: 'wizard_steps.step4_pinpoint_btn'.tr(),
                        icon: LGlyph.map,
                        kind: LButtonKind.tonal,
                        size: LButtonSize.small,
                        onPressed: onPin),
                  ]))),
          if (mapError != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(mapError,
                    style: Lantern.textStyle(12.5, color: t.liveText))),
          if (isOrganization) ...[
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                  child: head('design_copy.branches_count'
                      .tr(namedArgs: {'count': '${branches.length}'}))),
              LButton(
                  label: 'design_ui.add_branch'.tr(),
                  icon: LGlyph.plus,
                  kind: LButtonKind.tonal,
                  size: LButtonSize.small,
                  onPressed: onAddBranch),
            ]),
            for (final (i, (name, address)) in branches.indexed)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LRow(
                      title: name,
                      subtitle: address,
                      icon: LGlyph.org,
                      trailing: LIconButton(
                          icon: LGlyph.trash,
                          label: 'common.delete'.tr(),
                          onPressed: () => onRemoveBranch(i)))),
          ],
          const SizedBox(height: 18),
          LanternApplyAnchor(
              id: 'phone',
              child: LField(
                  key: const ValueKey('lantern-apply-field-phone'),
                  controller: phone,
                  label: 'wizard_steps.step4_phone_label'.tr(),
                  hint: '05X XXX XXXX',
                  icon: LGlyph.phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  onChanged: (v) {
                    LanternApplyErrors.edited(context, 'phone');
                    onPhoneChanged(v);
                  },
                  error: LanternApplyErrors.errorFor(context, 'phone') ??
                      phoneProblem,
                  helper: 'design_ui.accepts_05xxxxxxxx_9665xxxxxxxx_or_9665xxxxxxxx_without_spaces_e_'
                      .tr())),
          const SizedBox(height: 18),
          head('design_ui.preferred_admin_contact_method'.tr()),
          LSegmented<String>(
              key: const ValueKey('lantern-apply-contact'),
              expand: true,
              value: contact,
              onChanged: onContact,
              segments: [
                (
                  value: 'whatsapp',
                  label: 'lantern.apply.contact_whatsapp'.tr(),
                  icon: LGlyph.chat
                ),
                (
                  value: 'phone',
                  label: 'lantern.apply.contact_call'.tr(),
                  icon: LGlyph.phone
                ),
                (
                  value: 'email',
                  label: 'lantern.apply.contact_email'.tr(),
                  icon: LGlyph.mail
                ),
              ]),
        ]);
  }
}
