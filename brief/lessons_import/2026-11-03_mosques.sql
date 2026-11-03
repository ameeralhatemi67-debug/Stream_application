-- One-off data load (owner request 2026-11-03): the 52 mosques named in
-- "البيان الشامل للأرباع الثلاث الأولى من عام 26.xlsx" (Q1-Q3 2026). Mosques
-- only: no lessons yet. Needs migration 20261103120000 (the "unassigned" area).
-- Run with:
--   npx supabase db query --linked -f brief/lessons_import/2026-11-03_mosques.sql
--
-- * The file names no neighbourhood, so every mosque waits in Khobar's
--   "Not set yet" area; an admin moves each one from the mosque directory.
-- * Names are kept exactly as written (جامع / مسجد included). No map pin yet.
-- * Safe to run twice: a name already present (same letters after folding
--   alef and teh marbuta variants) is skipped.
with src(name_ar) as (values
  ('جامع خديجة بامردوف'),
  ('جامع محمد المانع'),
  ('جامع إبراهيم العجمي'),
  ('جامع عمر بن عبدالعزيز'),
  ('جامع عبدالله فؤاد'),
  ('جامع ابن القيم'),
  ('جامع راشد تميم القحطاني'),
  ('مسجد التقوى'),
  ('جامع مكة'),
  ('جامع خادم الحرمين الشريفين الملك فهد'),
  ('جامع ابن عثيمين'),
  ('جامع أبي بكر الصديق'),
  ('جامع ابن حجر'),
  ('جامع فاطمة الدوسري'),
  ('جامع البستان'),
  ('جامع عبدالكريم الخريجي'),
  ('جامع أحمد بن حنبل'),
  ('مسجد والدة إبراهيم المجدوعي'),
  ('جامع سالم بن محمد النعيمي'),
  ('مسجد عبدالله الزغيبي'),
  ('جامع ابن مفلح'),
  ('جامع هيلة العبدالله الغنام'),
  ('مسجد أسامة بن زيد'),
  ('جامع بلال بن رباح'),
  ('جامع محمد العرفج'),
  ('جامع ابن قدامة'),
  ('جامع الهدى'),
  ('مسجد طارق بن زياد'),
  ('جامع الأمير محمد بن فهد'),
  ('جامع عبدالعزيز التركي'),
  ('جامع الثقبة الكبير'),
  ('جامع أبي عائشة'),
  ('جامع الأندلس'),
  ('جامع الأبرار'),
  ('جامع عيضة الحارثي'),
  ('جامع ابن تيمية'),
  ('مسجد الجوزاء'),
  ('جامع محمد بن عبدالوهاب'),
  ('مسجد السعدي'),
  ('جامع زين العابدين'),
  ('جامع نورة المهيدب'),
  ('جامع عبدالرحمن بن عوف'),
  ('مسجد العمير'),
  ('مسجد سعد بن أبي وقاص'),
  ('جامع محمد حمد الدوسري'),
  ('جامع الهداية'),
  ('مسجد الفاتح'),
  ('جامع جعفر بن أبي طالب'),
  ('جامع الفرج'),
  ('جامع عبدالرحمن العرفج'),
  ('مسجد سليمان الشارخ'),
  ('جامع أنس الصقير')
),
ins as (
  insert into public.mosques(name_ar, district_id)
  select s.name_ar, 'unassigned'
  from src s
  where not exists (
    select 1 from public.mosques m
    where translate(btrim(m.name_ar), 'أإآة', 'اااه') = translate(s.name_ar, 'أإآة', 'اااه')
  )
  returning id
)
insert into public.lesson_audit(action, target_ar, target_en, actor_name, actor_email, note)
select 'import', 'استيراد ' || count(*) || ' مسجد', 'Imported ' || count(*) || ' mosques',
  'Excel import', '', 'البيان الشامل للأرباع الثلاث الأولى من عام 2026م'
from ins
having count(*) > 0;
