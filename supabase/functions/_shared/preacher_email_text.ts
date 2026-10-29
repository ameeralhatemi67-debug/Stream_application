// Email text for preachers (20261029120000). Arabic first, then English, in
// one message: a preacher has no saved language. Written for older readers:
// short sentences, the lesson's day, prayer and mosque spelled out. Kept free
// of Deno APIs so the wording can be checked with Node.

export type PreacherEmailData = Record<string, unknown> & { kind?: string };

export type PreacherEmail = { subject: string; html: string; text: string };

type Lang = 'ar' | 'en';
type Block = { greeting: string; lines: string[]; details: [string, string][]; action?: [string, string] };

const prayers: Record<string, [string, string]> = {
  fajr: ['بعد صلاة الفجر', 'after Fajr'],
  dhuhr: ['بعد صلاة الظهر', 'after Dhuhr'],
  asr: ['بعد صلاة العصر', 'after Asr'],
  maghrib: ['بعد صلاة المغرب', 'after Maghrib'],
  isha: ['بعد صلاة العشاء', 'after Isha'],
};

function str(v: unknown): string {
  return v === null || v === undefined ? '' : String(v).trim();
}

export function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

// "Saturday 31 October 2026", and in Arabic with the Hijri date after it.
export function dayLabel(iso: string, lang: Lang): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  if (!m) return iso;
  const date = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]), 12));
  try {
    const opts: Intl.DateTimeFormatOptions = { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' };
    if (lang === 'en') return new Intl.DateTimeFormat('en-GB', opts).format(date);
    const greg = new Intl.DateTimeFormat('ar-SA-u-ca-gregory-nu-latn', opts).format(date);
    const hijri = new Intl.DateTimeFormat('ar-SA-u-ca-islamic-umalqura-nu-latn',
      { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' }).format(date);
    return `${greg} (${hijri})`;
  } catch (_) {
    return iso.slice(0, 10);
  }
}

function timeLabel(d: PreacherEmailData, lang: Lang): string {
  const exact = str(d.exact_time).slice(0, 5);
  const prayer = prayers[str(d.slot)]?.[lang === 'ar' ? 0 : 1] ?? '';
  if (!exact) return prayer;
  return prayer ? `${prayer} (${exact})` : exact;
}

function name(d: PreacherEmailData, lang: Lang): string {
  return lang === 'ar' ? str(d.name_ar) || str(d.name_en) : str(d.name_en) || str(d.name_ar);
}

function title(d: PreacherEmailData, lang: Lang): string {
  return lang === 'ar' ? str(d.title_ar) || str(d.title_en) : str(d.title_en) || str(d.title_ar);
}

function mosque(d: PreacherEmailData, lang: Lang): string {
  return lang === 'ar' ? str(d.mosque_ar) || str(d.mosque_en) : str(d.mosque_en) || str(d.mosque_ar);
}

// A reason ends the sentence it is quoted in.
function reason(d: PreacherEmailData): string {
  return str(d.reason).replace(/[.!?؟。]+$/u, '');
}

function lessonDetails(d: PreacherEmailData, lang: Lang): [string, string][] {
  const ar = lang === 'ar';
  const rows: [string, string][] = [];
  if (title(d, lang)) rows.push([ar ? 'الدرس' : 'Lesson', title(d, lang)]);
  const dates = Array.isArray(d.dates) ? (d.dates as unknown[]).map(str).filter(Boolean) : [];
  if (dates.length > 1) {
    rows.push([ar ? 'المواعيد' : 'Dates', dates.map((x) => dayLabel(x, lang)).join(ar ? '، ' : '; ')]);
  } else if (str(d.date)) {
    rows.push([ar ? 'اليوم' : 'Day', dayLabel(str(d.date), lang)]);
  }
  if (timeLabel(d, lang)) rows.push([ar ? 'الوقت' : 'Time', timeLabel(d, lang)]);
  if (mosque(d, lang)) rows.push([ar ? 'المسجد' : 'Mosque', mosque(d, lang)]);
  return rows;
}

function block(d: PreacherEmailData, lang: Lang, site: string): Block {
  const ar = lang === 'ar';
  const n = name(d, lang);
  const greeting = ar ? (n ? `السلام عليكم ${n}،` : 'السلام عليكم،') : (n ? `Dear ${n},` : 'Hello,');
  const why = reason(d);
  const count = Number(d.count ?? 1);
  // A preacher with an account opens his page from the app; one without
  // keeps the link the admins sent him.
  const page: [string, string] | undefined = d.account === true
    ? [ar ? 'افتح صفحتك' : 'Open your page', `${site}/lessons/me/preacher`]
    : undefined;
  const pageLine = d.account === true
    ? (ar ? 'تجد التفاصيل في صفحتك: الإعدادات ← صفحتي داعيةً.' : 'Details are on your page: Settings → My preacher page.')
    : (ar ? 'تجد التفاصيل في الرابط الذي أرسله لك المشرفون.' : 'Details are on the link the admins sent you.');
  switch (d.kind) {
    case 'invite': {
      const until = str(d.valid_until);
      const once = str(d.link_kind) !== 'window';
      return {
        greeting,
        lines: [
          ar ? 'يسعدنا انضمامك إلى برنامج دروس المساجد. هذا رابط صفحتك، لا يحتاج إلى حساب ولا كلمة مرور.'
            : 'We are glad to have you in the mosque lessons programme. This is the link to your page; it needs no account or password.',
          ar ? 'من صفحتك ترى دروسك، وتطلب درسًا جديدًا في أي مسجد، وتقترح تعديل بطاقتك.'
            : 'On your page you see your lessons, ask for a new lesson at any mosque, and suggest changes to your card.',
          once
            ? (ar ? 'افتح الرابط على جوالك: يعمل على أول جوال يُفتح عليه فقط، فلا تشاركه.'
              : 'Open it on your phone: it works only on the first phone that opens it, so please do not share it.')
            : (ar ? 'يعمل الرابط على أي جهاز خلال المدة المحددة.' : 'The link works on any device during its period.'),
          ...(until ? [ar ? `ينتهي الرابط في ${dayLabel(until, lang)}.` : `The link ends on ${dayLabel(until, lang)}.`] : []),
        ],
        details: [],
        action: [ar ? 'افتح صفحتك' : 'Open your page', `${site}/preacher/${str(d.token)}`],
      };
    }
    case 'application_received':
      return {
        greeting,
        lines: [ar ? 'وصلنا طلب انضمامك داعيةً في برنامج الدروس، وسيراجعه المشرفون قريبًا. سنرسل لك رسالة بالقرار.'
          : 'We received your application to give lessons. The admins will review it soon, and we will email you the decision.'],
        details: mosque(d, lang) ? [[ar ? 'مسجدك الأول' : 'Your first mosque', mosque(d, lang)]] : [],
      };
    case 'application_approved':
      return {
        greeting,
        lines: [
          ar ? 'يسرّنا إبلاغك بقبول طلبك. أصبحتَ داعيةً في برنامج الدروس.' : 'Your application was approved. You are now a preacher in the lessons programme.',
          ar ? 'تبدأ من مسجدك الأول، ويمكنك بعد ذلك طلب دروس في أي مسجد.' : 'You start at your first mosque; after that you can ask for lessons at any mosque.',
          ar ? 'افتح تطبيق هداية بحسابك نفسه، ثم: الإعدادات ← صفحتي داعيةً.' : 'Open Hadayah with the same account, then Settings → My preacher page.',
        ],
        details: mosque(d, lang) ? [[ar ? 'مسجدك الأول' : 'Your first mosque', mosque(d, lang)]] : [],
        action: [ar ? 'افتح صفحتك' : 'Open your page', `${site}/lessons/me/preacher`],
      };
    case 'application_rejected':
      return {
        greeting,
        lines: [
          ar ? 'شكرًا لتقديمك. لم يُقبل طلب انضمامك هذه المرة.' : 'Thank you for applying. Your application was not accepted this time.',
          ...(why ? [ar ? `ملاحظة المشرف: ${why}.` : `Admin's note: ${why}.`] : []),
          ar ? 'يمكنك التقديم مرة أخرى من الإعدادات.' : 'You can apply again from Settings.',
        ],
        details: [],
        action: [ar ? 'قدّم مرة أخرى' : 'Apply again', `${site}/lessons/apply`],
      };
    case 'lesson_assigned':
      return {
        greeting,
        lines: [count > 1
          ? (ar ? `أضاف المشرفون لك سلسلة دروس أسبوعية (${count} مواعيد).` : `The admins added a weekly series for you (${count} sessions).`)
          : (ar ? 'أضاف المشرفون لك درسًا.' : 'The admins added a lesson for you.'), pageLine],
        details: lessonDetails(d, lang),
        action: page,
      };
    case 'request_approved':
      return {
        greeting,
        lines: [ar ? 'قُبل طلب درسك، وأصبح ظاهرًا للناس في التطبيق.' : 'Your lesson request was approved and is now public in the app.', pageLine],
        details: lessonDetails(d, lang),
        action: page,
      };
    case 'request_rejected':
      return {
        greeting,
        lines: [
          ar ? 'لم يُقبل طلب درسك هذه المرة.' : 'Your lesson request was not accepted this time.',
          ...(why ? [ar ? `السبب: ${why}.` : `Reason: ${why}.`] : []),
          ar ? 'يمكنك طلب موعد آخر من صفحتك.' : 'You can ask for another date from your page.',
        ],
        details: lessonDetails(d, lang),
        action: page,
      };
    case 'lesson_cancelled':
      return {
        greeting,
        lines: [
          ar ? 'أُلغي هذا الموعد، وأُبلغ من سجّل تذكيرًا به.' : 'This session was cancelled, and everyone with a reminder was told.',
          ...(why ? [ar ? `السبب: ${why}.` : `Reason: ${why}.`] : []),
        ],
        details: lessonDetails(d, lang),
        action: page,
      };
    case 'lesson_changed':
      return {
        greeting,
        lines: [ar ? 'تغيّر موعد درسك أو مكانه. هذه التفاصيل الجديدة:' : 'Your lesson moved. These are the new details:'],
        details: lessonDetails(d, lang),
        action: page,
      };
    case 'lesson_tomorrow':
      return {
        greeting,
        lines: [ar ? 'تذكير بدرسك غدًا، بإذن الله.' : 'A reminder: your lesson is tomorrow.'],
        details: lessonDetails(d, lang),
        action: str(d.maps_url) ? [ar ? 'الاتجاهات إلى المسجد' : 'Directions to the mosque', str(d.maps_url)] : page,
      };
    case 'card_approved':
      return {
        greeting,
        lines: [ar ? 'اعتمد المشرفون التعديل الذي اقترحته على بطاقتك، وأصبح ظاهرًا.' : 'The admins approved the change you suggested to your card. It is now shown.'],
        details: [],
        action: page,
      };
    case 'card_rejected':
      return {
        greeting,
        lines: [
          ar ? 'لم يعتمد المشرفون التعديل الذي اقترحته على بطاقتك.' : 'The admins did not approve the change you suggested to your card.',
          ...(why ? [ar ? `السبب: ${why}.` : `Reason: ${why}.`] : []),
        ],
        details: [],
        action: page,
      };
    default:
      return { greeting, lines: [pageLine], details: [] };
  }
}

const subjects: Record<string, [string, string]> = {
  invite: ['دعوة للانضمام إلى برنامج الدروس', 'Invitation to the lessons programme'],
  application_received: ['وصل طلبك للانضمام داعيةً', 'We received your preacher application'],
  application_approved: ['قُبل طلبك داعيةً', 'Your preacher application was approved'],
  application_rejected: ['بشأن طلب انضمامك داعيةً', 'About your preacher application'],
  lesson_assigned: ['أُضيف لك درس', 'A lesson was added for you'],
  request_approved: ['قُبل طلب درسك', 'Your lesson request was approved'],
  request_rejected: ['بشأن طلب درسك', 'About your lesson request'],
  lesson_cancelled: ['أُلغي موعد درسك', 'Your session was cancelled'],
  lesson_changed: ['تغيّر موعد درسك أو مكانه', 'Your lesson moved'],
  lesson_tomorrow: ['تذكير: درسك غدًا', 'Reminder: your lesson is tomorrow'],
  card_approved: ['اعتُمد تعديل بطاقتك', 'Your card change was approved'],
  card_rejected: ['بشأن تعديل بطاقتك', 'About your card change'],
};

function blockText(b: Block): string {
  return [b.greeting, '', ...b.lines, ...(b.details.length ? [''] : []), ...b.details.map(([k, v]) => `${k}: ${v}`),
    ...(b.action ? ['', `${b.action[0]}: ${b.action[1]}`] : [])].join('\n');
}

function blockHtml(b: Block, lang: Lang): string {
  const dir = lang === 'ar' ? 'rtl' : 'ltr';
  const align = lang === 'ar' ? 'right' : 'left';
  const rows = b.details.map(([k, v]) =>
    `<tr><td style="padding:4px 0;color:#6B7981;white-space:nowrap;vertical-align:top">${escapeHtml(k)}</td>` +
    `<td style="padding:4px 12px;color:#1F1A14;font-weight:600">${escapeHtml(v)}</td></tr>`).join('');
  const button = b.action
    ? `<p style="margin:20px 0 4px"><a href="${escapeHtml(b.action[1])}" style="display:inline-block;background:#BD933F;color:#1F1A14;` +
      `text-decoration:none;font-weight:700;padding:12px 22px;border-radius:10px">${escapeHtml(b.action[0])}</a></p>`
    : '';
  return `<div dir="${dir}" lang="${lang}" style="text-align:${align};font-size:17px;line-height:1.7;color:#1F1A14">` +
    `<p style="margin:0 0 12px">${escapeHtml(b.greeting)}</p>` +
    b.lines.map((l) => `<p style="margin:0 0 10px">${escapeHtml(l)}</p>`).join('') +
    (rows ? `<table role="presentation" style="margin:12px 0;border-collapse:collapse">${rows}</table>` : '') +
    button + '</div>';
}

export function preacherEmail(d: PreacherEmailData, site: string): PreacherEmail {
  const base = site.replace(/\/+$/, '');
  const ar = block(d, 'ar', base);
  const en = block(d, 'en', base);
  const kind = str(d.kind);
  const [sAr, sEn] = subjects[kind] ?? ['برنامج الدروس', 'Lessons programme'];
  const t = ['lesson_assigned', 'request_approved', 'request_rejected', 'lesson_cancelled', 'lesson_changed', 'lesson_tomorrow']
    .includes(kind) ? title(d, 'ar') : '';
  const subject = `${sAr}${t ? `: ${t}` : ''} | ${sEn}`;
  const footerAr = 'هداية — برنامج دروس المساجد. رسالة آلية من التطبيق.';
  const footerEn = 'Hadayah — mosque lessons programme. An automatic message from the app.';
  const html = '<!doctype html><html><body style="margin:0;background:#FAF6EE;font-family:Tahoma,Arial,sans-serif">' +
    '<div style="max-width:600px;margin:0 auto;padding:24px 16px">' +
    '<div style="background:#FFFFFF;border:1px solid #E8DFCC;border-radius:14px;padding:24px">' +
    blockHtml(ar, 'ar') +
    '<hr style="border:none;border-top:1px solid #E8DFCC;margin:24px 0">' +
    blockHtml(en, 'en') +
    '</div>' +
    `<p dir="rtl" style="text-align:center;color:#6B7981;font-size:13px;margin:16px 0 0">${escapeHtml(footerAr)}</p>` +
    `<p dir="ltr" style="text-align:center;color:#6B7981;font-size:13px;margin:4px 0 0">${escapeHtml(footerEn)}</p>` +
    '</div></body></html>';
  const text = `${blockText(ar)}\n\n— — —\n\n${blockText(en)}\n\n${footerAr}\n${footerEn}\n`;
  return { subject, html, text };
}
