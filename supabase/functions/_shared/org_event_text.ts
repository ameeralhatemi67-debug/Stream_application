// Push text for Organization V1 recipient events. Kept free of Deno APIs so
// the wording can be checked with Node.

export type OrgEvent = {
  kind: string;
  payload: Record<string, unknown>;
};

type Text = { title: string; body: string };

function pick(payload: Record<string, unknown>, en: string, ar: string, language: string): string {
  const first = String(payload[language === 'ar' ? ar : en] ?? '').trim();
  return first || String(payload[language === 'ar' ? en : ar] ?? '').trim();
}

const roles: Record<string, [string, string]> = {
  co_owner: ['co-owner', 'مالك مشارك'],
  manager: ['manager', 'مدير'],
  moderator: ['moderator', 'مشرف'],
  broadcaster: ['presenter', 'مقدم'],
  owner: ['owner', 'مالك'],
};

export function orgEventText(event: OrgEvent, language: string): Text {
  const ar = language === 'ar';
  const p = event.payload ?? {};
  const org = pick(p, 'organization_name_en', 'organization_name_ar', language) || (ar ? 'المؤسسة' : 'Your organization');
  const title = pick(p, 'title_en', 'title_ar', language) || (ar ? 'برنامج' : 'Show');
  const role = roles[String(p.role ?? '')]?.[ar ? 1 : 0] ?? (ar ? 'عضو' : 'member');
  const accepted = p.accepted === true;
  switch (event.kind) {
    case 'invitation':
      return ar ? { title: 'دعوة من مؤسسة', body: `دعتك ${org} للانضمام بصفة ${role}.` }
        : { title: 'Organization invitation', body: `${org} invited you to join as ${role}.` };
    case 'invitation_answered':
      return ar ? { title: accepted ? 'تم قبول الدعوة' : 'تم رفض الدعوة', body: `${org}: ${String(p.email ?? '')}` }
        : { title: accepted ? 'Invitation accepted' : 'Invitation declined', body: `${org}: ${String(p.email ?? '')}` };
    case 'join_request':
      return ar ? { title: 'طلب انضمام', body: `طلب جديد للانضمام إلى ${org}.` }
        : { title: 'Join request', body: `A new request to join ${org}.` };
    case 'join_request_answered':
      return ar ? { title: accepted ? 'تم قبول طلبك' : 'تم رفض طلبك', body: org }
        : { title: accepted ? 'Request accepted' : 'Request declined', body: org };
    case 'assignment':
      return ar ? { title: 'تكليف ببرنامج', body: `${org}: ${title}. اقبل كل موعد من صفحة البرامج.` }
        : { title: 'New show assignment', body: `${org}: ${title}. Accept each occurrence in Shows.` };
    case 'assignment_changed':
      return ar ? { title: 'تغيّر موعد البرنامج', body: `${title}: راجع الموعد واقبله من جديد.` }
        : { title: 'Show changed', body: `${title}: review and accept it again.` };
    case 'assignment_cancelled':
      return ar ? { title: 'أُلغي البرنامج', body: `${org}: ${title}` }
        : { title: 'Show cancelled', body: `${org}: ${title}` };
    case 'assignment_answered':
      return ar ? { title: accepted ? 'قبل المقدم البرنامج' : 'اعتذر المقدم عن البرنامج', body: title }
        : { title: accepted ? 'Presenter accepted' : 'Presenter declined', body: title };
    case 'assignment_reminder':
      return ar ? { title: 'برنامجك يبدأ قريباً', body: `${title} — ${org}` }
        : { title: 'Your show starts soon', body: `${title} — ${org}` };
    case 'membership_changed':
      return ar ? { title: 'تحديث صلاحياتك', body: `تغيّر دورك أو صلاحياتك في ${org}.` }
        : { title: 'Your access changed', body: `Your role or grants in ${org} changed.` };
    case 'show_live':
      return ar ? { title: 'بث مباشر الآن', body: `${title} — ${org}` }
        : { title: 'Live now', body: `${title} — ${org}` };
    case 'show_ending':
      return ar ? { title: 'يجري إنهاء برنامجك', body: `${title}: أوقف البث من جهازك.` }
        : { title: 'Your show is being ended', body: `${title}: stop sending from your device.` };
    case 'transfer_proposed':
      return ar ? { title: 'طلب نقل الملكية', body: `اقتُرحت مالكاً لـ ${org}. راجع الطلب قبل انتهائه.` }
        : { title: 'Ownership transfer', body: `You were proposed as owner of ${org}. Review it before it expires.` };
    case 'transfer_cancelled':
      return ar ? { title: 'أُلغي نقل الملكية', body: org } : { title: 'Ownership transfer withdrawn', body: org };
    case 'transfer_completed':
      return ar ? { title: 'اكتمل نقل الملكية', body: `${org}: على المالك الجديد إعادة ربط القناة.` }
        : { title: 'Ownership transferred', body: `${org}: the new owner must reconnect the channel.` };
    default:
      return ar ? { title: 'تحديث من المؤسسة', body: org } : { title: 'Organization update', body: org };
  }
}
