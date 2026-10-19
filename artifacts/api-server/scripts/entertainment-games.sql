-- «الترفيه والألعاب»: ألعابٌ يضيفها المشرف ويُسندها إلى معلّم.
--
-- يُشغَّل مرةً في محرّر SQL في Supabase، وإعادةُ تشغيله آمنة.
--
-- ── وقبل تشغيله لا يتعطّل شيء ──
-- الخادمُ إن وجد الجدول غائباً حفظ الألعاب في `app_kv`
-- (`smartEdu_entertainmentGames`)، ويقرأ المكانين معاً دائماً — فما حُفظ قبل
-- التشغيل يبقى ظاهراً بعده، وينتقل إلى الجدول عند أوّل تعديل.
--
-- ── والوصولُ للخادم وحده ──
-- RLS مفعّل بلا سياسة: مفتاحُ anon لا يقرأ ولا يكتب. المشرفُ يصل عبر
-- `/api/entertainment` بجلسته، والطالبُ عبر `/api/student/entertainment`
-- بجلسته الموقّعة — ولا يرى إلا ألعابَ معلّمه المفعّلة.

create table if not exists public.entertainment_games (
  id text primary key,

  title text not null,
  description text not null default '',
  -- الرابطُ المباشر أو المضمَّن للعبة — يفتحه مشغّلُ الألعاب في التطبيق كما هو.
  embed_url text not null,

  -- المعلمُ المسؤول (إلزاميّ): طلابُه وحدهم يرون اللعبة.
  teacher_id text not null,
  teacher_name text not null default '',

  -- الإظهار: لعبةٌ معطّلة تبقى في اللوحة ولا تظهر لأحد.
  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists entertainment_games_teacher_idx
  on public.entertainment_games (teacher_id, is_active);

alter table public.entertainment_games enable row level security;
revoke all on public.entertainment_games from anon, authenticated;
