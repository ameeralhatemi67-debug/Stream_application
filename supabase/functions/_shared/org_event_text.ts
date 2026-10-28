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

// A reviewer's note ends the sentence it is quoted in.
function note(payload: Record<string, unknown>): string {
  return String(payload.reason ?? '').trim().replace(/[.!?؟。]+$/u, '');
}

export function orgEventText(event: OrgEvent, language: string): Text {
  const ar = language === 'ar';
  const p = event.payload ?? {};
  const orgName = pick(p, 'organization_name_en', 'organization_name_ar', language);
  const org = orgName || (ar ? 'المؤسسة' : 'Your organization');
  const presenter = pick(p, 'presenter_name_en', 'presenter_name_ar', language);
  const name = pick(p, 'name_en', 'name_ar', language);
  const channel = p.organization === true ? (ar ? 'مؤسستك' : 'Your organization') : (ar ? 'قناتك' : 'Your channel');
  const reason = note(p);
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
    case 'show_live': {
      // A personal live has no organization; name the presenter instead.
      const by = orgName || presenter;
      const body = by ? `${title} — ${by}` : title;
      return ar ? { title: 'بث مباشر الآن', body } : { title: 'Live now', body };
    }
    case 'application_approved':
      if (p.edit === true) {
        return ar ? { title: 'اعتُمدت تعديلاتك', body: `${channel} تظهر الآن بالبيانات الجديدة.` }
          : { title: 'Your changes were approved', body: `${channel} now shows the new details.` };
      }
      return ar ? { title: 'تمت الموافقة على طلبك', body: `${name ? `أهلاً ${name}، ` : ''}${channel} موثّقة ويمكنك البث الآن.` }
        : { title: 'Your application was approved', body: `${name ? `Welcome, ${name}. ` : ''}${channel} is verified and you can go live.` };
    case 'application_rejected':
      if (p.edit === true) {
        return ar ? { title: 'لم تُعتمد تعديلاتك', body: `${reason ? `ملاحظة المراجع: ${reason}. ` : ''}${channel} تبقى ببياناتها المعتمدة.` }
          : { title: 'Your changes were not approved', body: `${reason ? `Reviewer's note: ${reason}. ` : ''}${channel} keeps its approved details.` };
      }
      return ar ? { title: 'طلبك يحتاج إلى تعديل', body: `${reason ? `ملاحظة المراجع: ${reason}. ` : ''}عدّله من الإعدادات وأعد التقديم.` }
        : { title: 'Your application needs changes', body: `${reason ? `Reviewer's note: ${reason}. ` : ''}Update it in Settings and apply again.` };
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
