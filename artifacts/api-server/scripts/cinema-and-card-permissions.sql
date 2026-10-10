-- سينما منارة مستقلّةً عن الدروس، وصلاحياتُ بطاقات الطالب.
--
-- التشغيل: الصقه في محرّر SQL في Supabase وشغّله مرّةً واحدة. يُعاد تشغيله
-- بلا ضرر (كلُّ شيءٍ فيه «if not exists»).
--
-- ── وقبل تشغيله لا يتعطّل شيء ──
-- الخادمُ يكتشف غيابَ الجدولين فيرتدّ إلى مفاتيح `app_kv`
-- (`smartEdu_videos` للسينما و`smartEdu_cardPermissions` للصلاحيات).
-- وبعد تشغيله ينتقل إليهما وحده، وفيديوهاتُ `smartEdu_videos` القديمة تبقى
-- ظاهرةً معهما حتى تُعدَّل أو تُحذف.
--
-- ── والوصولُ للخادم وحده ──
-- RLS مفعّل بلا سياسة واحدة: مفتاحُ anon لا يقرأ ولا يكتب. الطالبُ يصل إلى
-- الفيديوهات والصلاحيات عبر `/api/student/...` بجلسته الموقّعة، والمعلمُ
-- والمشرف عبر `/api/cinema/...` و`/api/card-permissions`.

-- ═══════════════════════════════════════════════════════════════════════
-- 1) فيديوهات سينما منارة
-- ═══════════════════════════════════════════════════════════════════════
create table if not exists public.cinema_videos (
  id text primary key,

  title text not null,
  -- الرابطُ المضمَّن (YouTube…) أو رابطُ ملف MP4 المرفوع.
  embed_url text not null,
  -- embed | mp4
  source_type text not null default 'embed',
  description text not null default '',

  -- ── الربطُ الأساسيّ، ولا شيء غيره ──
  -- الصفُّ الدراسيّ كما يُكتب في سجلّ الطالب (`students.data->>'grade'`).
  -- لا مادة ولا وحدة ولا درس: الفيديو للصفّ كلّه.
  grade_id text not null,
  -- المعلمُ المسؤول: طلابُه في هذا الصفّ هم من يرونه.
  teacher_id text not null,
  teacher_name text not null default '',
  -- من أضافه فعلاً: «admin» للمشرف، أو معرّفُ المعلم.
  created_by text not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists cinema_videos_grade_teacher_idx
  on public.cinema_videos (grade_id, teacher_id);

alter table public.cinema_videos enable row level security;

-- ═══════════════════════════════════════════════════════════════════════
-- 2) صلاحيات بطاقات الطالب
-- ═══════════════════════════════════════════════════════════════════════
-- صفٌّ لكل قاعدة. نطاقان:
--   class   : لكل طلاب معلمٍ في صفّ   → id = 'class:<teacher_id>:<grade_id>'
--   student : لطالبٍ واحد             → id = 'student:<student_id>'
-- وقاعدةُ الطالب تغلب قاعدةَ صفّه في كل بطاقةٍ ذكرتها، وما لم تذكره قاعدةٌ
-- فهو مفتوح.
--
-- `cards` خريطةٌ من معرّف البطاقة إلى true/false، مثل:
--   {"tutor": false, "cinema": true}
-- والمعرّفات: lesson, cinema, games, personality, tutor, quiz, solver,
-- meeting, chat, challenge, study.
create table if not exists public.student_card_permissions (
  id text primary key,
  scope text not null check (scope in ('class', 'student')),
  student_id text,
  teacher_id text not null,
  grade_id text,
  cards jsonb not null default '{}'::jsonb,
  updated_by text not null,
  updated_at timestamptz not null default now(),
  check (
    (scope = 'student' and student_id is not null) or
    (scope = 'class' and grade_id is not null)
  )
);

create index if not exists student_card_permissions_teacher_idx
  on public.student_card_permissions (teacher_id);

alter table public.student_card_permissions enable row level security;

-- يُعلم PostgREST بالجدولين الجديدين فورًا بدل انتظار تحديث ذاكرته.
notify pgrst, 'reload schema';
