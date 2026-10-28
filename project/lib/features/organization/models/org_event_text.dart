import 'org_event.dart';

/// In-app wording for [OrgEvent]s in both languages. It mirrors the push text
/// in `supabase/functions/_shared/org_event_text.ts` so a notification reads
/// the same whether it arrived by push or was loaded from the event list.
({String title, String body}) orgEventText(OrgEvent event, String language) {
  final ar = language == 'ar';
  final orgName = event.organizationName(language);
  final org = orgName.isNotEmpty ? orgName : (ar ? 'المؤسسة' : 'Your organization');
  final presenter = event.text('presenter_name', language);
  final name = event.text('name', language);
  final channel = event.payload['organization'] == true
      ? (ar ? 'مؤسستك' : 'Your organization')
      : (ar ? 'قناتك' : 'Your channel');
  // A reviewer's note ends the sentence it is quoted in.
  final reason = (event.payload['reason'] as String? ?? '')
      .trim()
      .replaceFirst(RegExp(r'[.!?؟。]+$'), '');
  final edit = event.payload['edit'] == true;
  // A personal live has no organization; name the presenter instead.
  final liveBy = orgName.isNotEmpty ? orgName : presenter;
  final title = event.title(language).isNotEmpty ? event.title(language) : (ar ? 'برنامج' : 'Show');
  const roles = {
    'co_owner': ('co-owner', 'مالك مشارك'),
    'manager': ('manager', 'مدير'),
    'moderator': ('moderator', 'مشرف'),
    'broadcaster': ('presenter', 'مقدم'),
    'owner': ('owner', 'مالك'),
  };
  final roleNames = roles[event.role];
  final role = roleNames == null ? (ar ? 'عضو' : 'member') : (ar ? roleNames.$2 : roleNames.$1);
  final accepted = event.accepted;
  final email = event.payload['email'] as String? ?? '';
  return switch (event.kind) {
    'invitation' => ar
        ? (title: 'دعوة من مؤسسة', body: 'دعتك $org للانضمام بصفة $role.')
        : (title: 'Organization invitation', body: '$org invited you to join as $role.'),
    'invitation_answered' => ar
        ? (title: accepted ? 'تم قبول الدعوة' : 'تم رفض الدعوة', body: '$org: $email')
        : (title: accepted ? 'Invitation accepted' : 'Invitation declined', body: '$org: $email'),
    'join_request' => ar
        ? (title: 'طلب انضمام', body: 'طلب جديد للانضمام إلى $org.')
        : (title: 'Join request', body: 'A new request to join $org.'),
    'join_request_answered' => ar
        ? (title: accepted ? 'تم قبول طلبك' : 'تم رفض طلبك', body: org)
        : (title: accepted ? 'Request accepted' : 'Request declined', body: org),
    'assignment' => ar
        ? (title: 'تكليف ببرنامج', body: '$org: $title. اقبل كل موعد من صفحة البرامج.')
        : (title: 'New show assignment', body: '$org: $title. Accept each occurrence in Shows.'),
    'assignment_changed' => ar
        ? (title: 'تغيّر موعد البرنامج', body: '$title: راجع الموعد واقبله من جديد.')
        : (title: 'Show changed', body: '$title: review and accept it again.'),
    'assignment_cancelled' => ar
        ? (title: 'أُلغي البرنامج', body: '$org: $title')
        : (title: 'Show cancelled', body: '$org: $title'),
    'assignment_answered' => ar
        ? (title: accepted ? 'قبل المقدم البرنامج' : 'اعتذر المقدم عن البرنامج', body: title)
        : (title: accepted ? 'Presenter accepted' : 'Presenter declined', body: title),
    'assignment_reminder' => ar
        ? (title: 'برنامجك يبدأ قريباً', body: '$title — $org')
        : (title: 'Your show starts soon', body: '$title — $org'),
    'membership_changed' => ar
        ? (title: 'تحديث صلاحياتك', body: 'تغيّر دورك أو صلاحياتك في $org.')
        : (title: 'Your access changed', body: 'Your role or grants in $org changed.'),
    'show_live' => (
        title: ar ? 'بث مباشر الآن' : 'Live now',
        body: liveBy.isEmpty ? title : '$title — $liveBy'),
    'application_approved' => edit
        ? (ar
            ? (title: 'اعتُمدت تعديلاتك', body: '$channel تظهر الآن بالبيانات الجديدة.')
            : (title: 'Your changes were approved', body: '$channel now shows the new details.'))
        : (ar
            ? (title: 'تمت الموافقة على طلبك',
                body: '${name.isEmpty ? '' : 'أهلاً $name، '}$channel موثّقة ويمكنك البث الآن.')
            : (title: 'Your application was approved',
                body: '${name.isEmpty ? '' : 'Welcome, $name. '}$channel is verified and you can go live.')),
    'application_rejected' => edit
        ? (ar
            ? (title: 'لم تُعتمد تعديلاتك',
                body: '${reason.isEmpty ? '' : 'ملاحظة المراجع: $reason. '}$channel تبقى ببياناتها المعتمدة.')
            : (title: 'Your changes were not approved',
                body: "${reason.isEmpty ? '' : "Reviewer's note: $reason. "}$channel keeps its approved details."))
        : (ar
            ? (title: 'طلبك يحتاج إلى تعديل',
                body: '${reason.isEmpty ? '' : 'ملاحظة المراجع: $reason. '}عدّله من الإعدادات وأعد التقديم.')
            : (title: 'Your application needs changes',
                body: "${reason.isEmpty ? '' : "Reviewer's note: $reason. "}Update it in Settings and apply again.")),
    'show_ending' => ar
        ? (title: 'يجري إنهاء برنامجك', body: '$title: أوقف البث من جهازك.')
        : (title: 'Your show is being ended', body: '$title: stop sending from your device.'),
    'transfer_proposed' => ar
        ? (title: 'طلب نقل الملكية', body: 'اقتُرحت مالكاً لـ $org. راجع الطلب قبل انتهائه.')
        : (title: 'Ownership transfer', body: 'You were proposed as owner of $org. Review it before it expires.'),
    'transfer_cancelled' => ar
        ? (title: 'أُلغي نقل الملكية', body: org)
        : (title: 'Ownership transfer withdrawn', body: org),
    'transfer_completed' => ar
        ? (title: 'اكتمل نقل الملكية', body: '$org: على المالك الجديد إعادة ربط القناة.')
        : (title: 'Ownership transferred', body: '$org: the new owner must reconnect the channel.'),
    _ => ar ? (title: 'تحديث من المؤسسة', body: org) : (title: 'Organization update', body: org),
  };
}
