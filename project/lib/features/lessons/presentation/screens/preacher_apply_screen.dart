import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../domain/lessons_models.dart';
import '../../domain/lessons_vocab.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';
import '../lessons_widgets.dart';
import '../preacher_form_kit.dart';

/// Applying to give lessons (ADR-020), from the welcome page or Settings.
/// The person is signed in; an admin approves (his preacher card is created,
/// linked to this account) or declines with a reason. Written for older
/// readers: large text, one question at a time down the page, Arabic first.
class PreacherApplyScreen extends StatefulWidget {
  const PreacherApplyScreen({super.key});
  @override
  State<PreacherApplyScreen> createState() => _PreacherApplyScreenState();
}

class _PreacherApplyScreenState extends State<PreacherApplyScreen> {
  final nameAr = TextEditingController(), nameEn = TextEditingController(), titleAr = TextEditingController();
  final bioAr = TextEditingController(), phone = TextEditingController(), email = TextEditingController();
  final experience = TextEditingController(), sample = TextEditingController();
  String? photo, mosque, newMosque, newArea;
  var city = 'khobar';
  var langs = <String>{'ar'};
  var agreed = false, sending = false, again = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    nameAr.text = app.googleUserName ?? '';
    email.text = app.currentUserEmail ?? '';
    unawaited(context.read<LessonsController>().refresh());
  }

  @override
  void dispose() {
    for (final t in [nameAr, nameEn, titleAr, bioAr, phone, email, experience, sample]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final c = context.read<LessonsController>();
    String? problem;
    final mail = email.text.trim(), link = sample.text.trim();
    if (nameAr.text.trim().length < 3) {
      problem = 'lessons.preacher_admin.name_needed';
    } else if (mosque == null && ((newMosque ?? '').trim().length < 2 || newArea == null)) {
      problem = 'lessons.apply.mosque_needed';
    } else if (phone.text.replaceAll(RegExp(r'[^0-9+]'), '').length < 7) {
      problem = 'lessons.apply.phone_needed';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
      problem = 'lessons.preacher_admin.email_bad';
    } else if (link.isNotEmpty && !link.startsWith('https://')) {
      problem = 'lessons.apply.link_https';
    } else if (!agreed) {
      problem = 'lessons.apply.agree_needed';
    }
    if (problem != null) return tToast(context, problem.tr(), warn: true);
    setState(() => sending = true);
    final id = await tRun(
        context,
        () => c.apply(PreacherApplicationDraft(
            nameAr: nameAr.text.trim(),
            nameEn: nameEn.text.trim(),
            titleAr: titleAr.text.trim(),
            bioAr: bioAr.text.trim(),
            photoUrl: photo,
            city: city,
            mosqueId: mosque,
            newMosqueName: mosque == null ? newMosque?.trim() : null,
            newMosqueDistrict: mosque == null ? newArea : null,
            languages: langs.toList(),
            phone: phone.text.trim(),
            email: mail,
            experience: experience.text.trim(),
            sampleUrl: link.isEmpty ? null : link)));
    if (!mounted) return;
    setState(() {
      sending = false;
      if (id != null) again = false;
    });
    if (id != null) tToast(context, 'lessons.apply.sent'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final mine = c.myApplication;
    final Widget body;
    if (!c.loaded) {
      body = const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator(color: TC.gold)));
    } else if (c.myPreacherId != null) {
      body = _Status(
        icon: TGlyph.check,
        tone: TTone.success,
        title: 'lessons.apply.is_preacher'.tr(),
        body: 'lessons.apply.is_preacher_body'.tr(),
        action: TButton('lessons.me.preacher_page'.tr(), kind: TBtn.minted, large: true, expand: true, icon: TGlyph.user,
            onPressed: () => context.go('/lessons/me/preacher')),
      );
    } else if (mine != null && mine.pending) {
      body = _Status(
        key: const ValueKey('apply-pending'),
        icon: TGlyph.clock,
        tone: TTone.info,
        title: 'lessons.apply.pending'.tr(),
        body: 'lessons.apply.pending_body'.tr(args: [mine.createdAt == null ? '' : agoText(mine.createdAt!)]),
        action: TButton('lessons.apply.withdraw'.tr(), kind: TBtn.ghost, large: true, expand: true, icon: TGlyph.x,
            onPressed: () => tRun(context, c.withdrawApplication, success: 'lessons.apply.withdrawn'.tr())),
      );
    } else if (mine != null && mine.status == 'rejected' && !again) {
      body = _Status(
        icon: TGlyph.info,
        tone: TTone.warning,
        title: 'lessons.apply.rejected'.tr(),
        body: (mine.reason ?? '').isEmpty ? 'lessons.apply.rejected_body'.tr() : '${'lessons.auditlog.reason'.tr()}: ${mine.reason}',
        action: TButton('lessons.apply.again'.tr(), kind: TBtn.minted, large: true, expand: true, icon: TGlyph.refresh,
            onPressed: () => setState(() => again = true)),
      );
    } else {
      body = _form(context);
    }
    return Scaffold(
      backgroundColor: TC.page,
      appBar: AppBar(
        backgroundColor: TC.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: TC.hair)),
        title: Text('lessons.apply.title'.tr(), style: tDisplay(19)),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 40), child: body),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    Widget label(String t, {bool required = false}) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text.rich(
              TextSpan(text: t, children: [if (required) const TextSpan(text: ' *', style: TextStyle(color: TC.dangerFg))]),
              style: tStrong(17)),
        );
    final big = tBody(17, color: TC.ink);
    return Column(key: const ValueKey('apply-form'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('lessons.apply.intro_title'.tr(), style: tDisplay(24)),
      const SizedBox(height: 8),
      Text('lessons.apply.intro'.tr(), style: tBody(16, color: TC.ink2)),
      const SizedBox(height: 10),
      TCallout(tone: TTone.info, icon: TGlyph.mosque, child: Text('lessons.apply.any_mosque'.tr(), style: tBody(15))),
      label('lessons.apply.q_photo'.tr()),
      PhotoField(name: nameAr.text, url: photo, application: true, large: true, onChanged: (v) => setState(() => photo = v)),
      label('lessons.link.f_name'.tr(), required: true),
      TextField(key: const ValueKey('apply-name'), controller: nameAr, style: big, maxLength: 120, decoration: tInput(),
          onChanged: (_) => setState(() {})),
      label('lessons.roster.name_en'.tr()),
      TextField(controller: nameEn, style: big, maxLength: 120, textDirection: TextDirection.ltr, decoration: tInput()),
      label('lessons.link.f_title'.tr()),
      TextField(controller: titleAr, style: big, maxLength: 120, decoration: tInput(hint: 'lessons.roster.title_hint'.tr())),
      label('lessons.apply.q_mosque'.tr(), required: true),
      Text('lessons.apply.q_mosque_note'.tr(), style: tBody(15, color: TC.muted)),
      const SizedBox(height: 10),
      CityMosquePicker(
        key: const ValueKey('apply-mosque'),
        city: city,
        mosqueId: mosque,
        large: true,
        newMosqueName: newMosque,
        newMosqueDistrict: newArea,
        onChanged: (ci, m) => setState(() {
          city = ci;
          mosque = m;
          if (m != null) newMosque = null;
        }),
        onNewMosque: (name, area) => setState(() {
          newMosque = name;
          newArea = area;
          if (name != null) mosque = null;
        }),
      ),
      label('lessons.link.f_languages'.tr()),
      TChips([
        for (final x in LessonsVocab.languages)
          TChip(LessonsVocab.languageNative[x]!, selected: langs.contains(x),
              onTap: () => setState(() => langs.contains(x) && langs.length > 1 ? langs.remove(x) : langs.add(x))),
      ]),
      label('lessons.roster.phone'.tr(), required: true),
      TextField(key: const ValueKey('apply-phone'), controller: phone, style: big, keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr, decoration: tInput(hint: '05XXXXXXXX')),
      label('lessons.roster.email'.tr(), required: true),
      TextField(key: const ValueKey('apply-email'), controller: email, style: big, keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr, decoration: tInput()),
      Padding(padding: const EdgeInsets.only(top: 6), child: Text('lessons.apply.contact_note'.tr(), style: tBody(14, color: TC.muted))),
      label('lessons.apply.experience'.tr()),
      TextField(controller: experience, style: big, maxLines: 4, maxLength: 2000, decoration: tInput(hint: 'lessons.apply.experience_hint'.tr())),
      label('lessons.link.f_bio'.tr()),
      TextField(controller: bioAr, style: big, maxLines: 4, maxLength: 1500, decoration: tInput(hint: 'lessons.link.bio_hint'.tr())),
      label('lessons.apply.sample'.tr()),
      TextField(controller: sample, style: big, keyboardType: TextInputType.url, textDirection: TextDirection.ltr,
          decoration: tInput(hint: 'https://')),
      const SizedBox(height: 16),
      CheckboxListTile(
        key: const ValueKey('apply-agree'),
        value: agreed,
        activeColor: TC.gold,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text('lessons.apply.agree'.tr(), style: tBody(15, color: TC.ink)),
        onChanged: (v) => setState(() => agreed = v ?? false),
      ),
      const SizedBox(height: 12),
      TButton('lessons.apply.send'.tr(), key: const ValueKey('apply-send'), kind: TBtn.minted, large: true, expand: true,
          icon: TGlyph.send, onPressed: sending ? null : _send),
    ]);
  }
}

class _Status extends StatelessWidget {
  const _Status({super.key, required this.icon, required this.tone, required this.title, required this.body, required this.action});
  final TGlyph icon;
  final TTone tone;
  final String title, body;
  final Widget action;
  @override
  Widget build(BuildContext context) => TCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: toneColors(tone).$1, shape: BoxShape.circle),
              child: TIcon(icon, size: 24, color: toneColors(tone).$2),
            ),
          ),
          const SizedBox(height: 14),
          Text(title, style: tDisplay(22)),
          const SizedBox(height: 8),
          Text(body, style: tBody(16, color: TC.ink2)),
          const SizedBox(height: 18),
          action,
        ]),
      );
}
