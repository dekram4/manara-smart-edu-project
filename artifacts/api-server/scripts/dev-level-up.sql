-- ════════════════════════════════════════════════════════════════════
-- للتجربة: رفعُ طالبٍ إلى المستوى 6 ليفتح كلَّ ألعاب «عالم الترفيه».
--
-- المستوى = ⌊XP / 100⌋، فالمستوى 6 يحتاج 600 XP. وما عند الطالب أكثرُ من ذلك لا
-- يُنقص. يُكتب في students.data.gamification — حيث يقرؤه الخادمُ والتطبيق.
--
-- ١) اعثر على الحساب (غيّر الاسم):
--      select id, data->>'name' as name, data->>'username' as username,
--             data->'gamification'->>'xp' as xp, data->'gamification'->>'gems' as gems
--      from public.students
--      where data->>'name' ilike '%اكتب جزءاً من الاسم%'
--         or data->>'username' ilike '%اكتب جزءاً من اسم المستخدم%';
--
-- ٢) ضع اسم المستخدم في السطر المعلَّم أدناه وشغّل.
-- ٣) في التطبيق: اخرج من الشاشة الرئيسية وادخلها (أو سجّل الدخول من جديد).
-- ════════════════════════════════════════════════════════════════════

update public.students
set data = data || jsonb_build_object(
  'gamification',
  coalesce(data->'gamification', '{}'::jsonb) || jsonb_build_object(
    'xp',    greatest(coalesce((data->'gamification'->>'xp')::int, 0), 650),
    'level', greatest(coalesce((data->'gamification'->>'xp')::int, 0), 650) / 100,
    'gems',  greatest(coalesce((data->'gamification'->>'gems')::int, 0), 150)
  )
)
where data->>'username' = 'اكتب_اسم_المستخدم_هنا'   -- ← هنا
returning id, data->>'name' as name, data->'gamification' as gamification;
