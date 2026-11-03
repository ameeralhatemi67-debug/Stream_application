-- One-off data load (owner request 2026-11-03): the 68 preachers named in
-- "البيان الشامل للأرباع الثلاث الأولى من عام 26.xlsx" (Q1-Q3 2026). Preachers
-- only: no mosques, no lessons yet. Run with:
--   npx supabase db query --linked -f brief/lessons_import/2026-11-03_preachers.sql
--
-- * Hidden (listed = false) until the owner decides; the admin's add-lesson
--   list still shows them.
-- * No home mosque yet (the hosted directory is empty).
-- * Affiliation: ministry (رسمي) only where the file never calls the person
--   cooperating (متعاون); two people appear as both and are stored as coop.
-- * Safe to run twice: a name already present (same letters after folding
--   alef and teh marbuta variants) is skipped.
with src(name_ar, affiliation) as (values
  ('ماطر بن علي أبو شملة', 'coop'),
  ('محمد بن عبدالعزيز الباروت', 'coop'),
  ('عادل بن علي السبعان', 'coop'),
  ('صالح بن محمد بن صالح السويح', 'coop'),
  ('سلطان بن عبدالله الشثري', 'coop'),
  ('عبدالرحمن بن زكي العبدالقادر', 'coop'),
  ('ثامر عائض سفر البقمي', 'coop'),
  ('محمد بن خالد باحبيل', 'coop'),
  ('صلاح بن عبدالله بوجليع', 'coop'),
  ('سلمان بن محمد الذوادي', 'ministry'),
  ('عبدالعزيز بن أحمد العرفج', 'coop'),
  ('عبدالعزيز بن مهيني المهيني', 'coop'),
  ('خالد بن عبداللطيف المزهر', 'coop'),
  ('راشد بن يوسف الدوسري', 'coop'),
  ('عبدالرحمن بن عبدالعزيز العقل', 'coop'),
  ('خالد بن حمد الخالدي', 'coop'),
  ('ثلاب سعيد بن حمد الهاجري', 'coop'),
  ('سليمان بن محمد النجران', 'coop'),
  ('أنس بن حسين العلي', 'coop'),
  ('علي بن عبدالعزيز الشبل', 'coop'),
  ('محمد ذياب سلطان بن سفران', 'coop'),
  ('أحمد بن غرم الله الزهراني', 'coop'),
  ('حميد علي بن محمد هزازي', 'coop'),
  ('خالد بن أحمد الزامل', 'ministry'),
  ('نافع مهدي آل بحري', 'coop'),
  ('صالح بن محمد الشريدة', 'coop'),
  ('عبدالمجيد بن حامد الأسمري', 'coop'),
  ('بدر حمد محمد الدوله', 'ministry'),
  ('عبدالرحمن بن محسن النعمي', 'coop'),
  ('سعود بن فهد الهويمل', 'coop'),
  ('حسن بن صالح القرني', 'coop'),
  ('رياض بن عبدالله البراك', 'coop'),
  ('مهدي سعيد القحطاني', 'coop'),
  ('أحمد بن عبدالله السلمي', 'coop'),
  ('بندر عايض صنيتان العتيبي', 'coop'),
  ('سعيد بن حسين القحطاني', 'coop'),
  ('عبدالرحمن بن محمد الحمادي', 'coop'),
  ('فيصل بن عبدالله الصعب', 'coop'),
  ('خالد علي بن محمد المشيقح', 'coop'),
  ('نايف فهد ظافر الدوسري', 'coop'),
  ('مسفر محمد مسفر الشهراني', 'ministry'),
  ('بدر بن محمد بن نايف الجبعاء الدويش', 'coop'),
  ('أحمد بن جزاع الرميضان', 'coop'),
  ('صالح بن أحمد الحمدان', 'coop'),
  ('مسفر بن دسمان السبيعي', 'coop'),
  ('أحمد بن خليفة المجناء', 'coop'),
  ('إبراهيم بن سليمان الفهيد', 'coop'),
  ('مدعث فارس العتيبي', 'coop'),
  ('عبدالمنعم إبراهيم أحمد المقهوي', 'coop'),
  ('عبدالعزيز بن سليمان التويجري', 'coop'),
  ('سامي بن سلمان الحيمود', 'coop'),
  ('علي بن عامر الشديدي', 'coop'),
  ('مساعد بن عاصي الظفيري', 'coop'),
  ('عبدالرحمن بن محمد بن علي القحطاني', 'coop'),
  ('علي بن عبدالرحمن بن عبدالله العويشز', 'coop'),
  ('عبدالباقي بن محمد آل الشيخ مبارك', 'coop'),
  ('خالد علي بن سليمان الجريش', 'coop'),
  ('عبدالعزيز بن مبارك بن محمد السليم', 'coop'),
  ('بريك بن محمد الدوسري', 'coop'),
  ('محمد بن سليمان المهوس', 'coop'),
  ('خالد بن راشد الخضير', 'coop'),
  ('عادل بن نافع الرشيدي', 'coop'),
  ('أحمد بن محمد الجراح', 'coop'),
  ('سلطان بن ابراهيم بن محمد الفايز', 'coop'),
  ('آدم بن عبدالرحمن أباحسين', 'coop'),
  ('عبدالله بن محمد الذياب', 'coop'),
  ('عبدالرحمن بن سعد المطر', 'coop'),
  ('بندر بن عبده شراحيلي', 'coop')
),
ins as (
  insert into public.preachers(name_ar, affiliation, city, listed)
  select s.name_ar, s.affiliation, 'khobar', false
  from src s
  where not exists (
    select 1 from public.preachers p
    where translate(btrim(p.name_ar), 'أإآة', 'اااه') = translate(s.name_ar, 'أإآة', 'اااه')
  )
  returning id
)
insert into public.lesson_audit(action, target_ar, target_en, actor_name, actor_email, note)
select 'import', 'استيراد ' || count(*) || ' داعية', 'Imported ' || count(*) || ' preachers',
  'Excel import', '', 'البيان الشامل للأرباع الثلاث الأولى من عام 2026م'
from ins
having count(*) > 0;
