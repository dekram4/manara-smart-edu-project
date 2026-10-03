-- ════════════════════════════════════════════════════════════════════
-- للتجربة: رفعُ طالبٍ إلى المستوى 6 ليفتح كلَّ ألعاب «عالم الترفيه».
--
-- ── أين يقرأ التطبيقُ المستوى ──
-- من students.data.gamification.xp وحده، والمستوى يُحسب منه: level = ⌊xp / 100⌋.
-- فحقلُ level لا يُقرأ أبداً، و xp/gems في جذر data (خارج gamification) لا تُقرأ.
-- المستوى 6 = 600 XP فأكثر، واللعبةُ رقم n تُفتح عند المستوى n — فالستُّ كلُّها عند 6.
--
-- ١) اعرض الحساب كما هو الآن (غيّر اسم المستخدم):
--      select id, data->>'name' as name, data->>'username' as username,
--             data->'gamification' as gamification,
--             data->'level' as root_level, data->'xp' as root_xp, data->'gems' as root_gems
--      from public.students where data->>'username' = 'اكتب_اسم_المستخدم_هنا';
--    وإن ظهر name أو username فارغاً فقد استُبدل حقلُ data كلُّه: أعده من نسخةٍ سابقة.
--
-- ٢) ضع اسم المستخدم في السطر المعلَّم أدناه وشغّل: يكتب القيمَ في gamification،
--    ويحذف level/xp/gems من جذر data إن كانت هناك. ولا ينقص ما عند الطالب.
-- ٣) في التطبيق: اخرج من الشاشة الرئيسية وادخلها (أو سجّل الدخول من جديد).
-- ════════════════════════════════════════════════════════════════════

update public.students
set data = (data - 'level' - 'xp' - 'gems') || jsonb_build_object(
  'gamification',
  coalesce(data->'gamification', '{}'::jsonb) || jsonb_build_object(
    'xp', greatest(
      coalesce((data->'gamification'->>'xp')::int, 0),
      coalesce((data->>'xp')::int, 0),
      650
    ),
    'level', greatest(
      coalesce((data->'gamification'->>'xp')::int, 0),
      coalesce((data->>'xp')::int, 0),
      650
    ) / 100,
    'gems', greatest(
      coalesce((data->'gamification'->>'gems')::int, 0),
      coalesce((data->>'gems')::int, 0),
      150
    )
  )
)
where data->>'username' = 'اكتب_اسم_المستخدم_هنا'   -- ← هنا
returning id, data->>'name' as name, data->'gamification' as gamification;
