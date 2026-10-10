-- سينما منارة مستقلّةً عن الدروس، وصلاحياتُ بطاقات الطالب.
--
-- التشغيل: الصقه كلَّه في محرّر SQL في Supabase وشغّله. يُعاد تشغيله بلا ضرر.
--
-- ── ويُصلح الجدولين إن وُجدا بغير بنيتهما ──
-- كان في Supabase جدولان بالاسمين نفسيهما أُنشئا قبل هذا الملف وبأعمدةٍ
-- أخرى: `cinema_videos` بمعرّفٍ من نوع uuid وبلا `description` ولا
-- `source_type`، و`student_card_permissions` بصفٍّ لكل بطاقة (`card_key`،
-- `is_enabled`). والنسخةُ الأولى من هذا الملف كانت «create table if not
-- exists» وحدها، فتركتهما كما هما — وكلُّ حفظٍ من اللوحة رُفض بـ PGRST204
-- («تعذر حفظ فيديو السينما»).
--
-- ── وقبل تشغيله لا يتعطّل شيء ──
-- الخادمُ إن وجد الجدول غائباً أو بغير بنيته حفظ في `app_kv`
-- (`smartEdu_videos` للسينما و`smartEdu_cardPermissions` للصلاحيات)، ويقرأ
-- المكانين معاً دائماً — فما حُفظ قبل التشغيل يبقى ظاهراً بعده.
--
-- ── والوصولُ للخادم وحده ──
-- RLS مفعّل بلا سياسة: مفتاحُ anon لا يقرأ ولا يكتب. الطالبُ يصل عبر
-- `/api/student/...` بجلسته الموقّعة، والمعلمُ والمشرف عبر `/api/cinema/...`
-- و`/api/card-permissions`.

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
  created_by text not null default '',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- إصلاحُ جدولٍ قديمٍ بالاسم نفسه: كلُّ عمودٍ ناقص يُضاف، والمعرّف يصير نصّاً
-- (الفيديوهات القديمة معرّفاتُها ليست uuid). ولا يُمسّ صفٌّ موجود.
alter table public.cinema_videos alter column id drop default;
alter table public.cinema_videos alter column id type text using id::text;
alter table public.cinema_videos add column if not exists source_type text not null default 'embed';
alter table public.cinema_videos add column if not exists description text not null default '';
alter table public.cinema_videos add column if not exists teacher_name text not null default '';
alter table public.cinema_videos add column if not exists created_by text not null default '';
alter table public.cinema_videos add column if not exists created_at timestamptz not null default now();
alter table public.cinema_videos add column if not exists updated_at timestamptz not null default now();
alter table public.cinema_videos alter column created_by set default '';

create index if not exists cinema_videos_grade_teacher_idx
  on public.cinema_videos (grade_id, teacher_id);

alter table public.cinema_videos enable row level security;

-- ═══════════════════════════════════════════════════════════════════════
-- 2) صلاحيات بطاقات الطالب
-- ═══════════════════════════════════════════════════════════════════════
-- الجدولُ القديم (صفٌّ لكل بطاقة لكل طالب، بلا قواعد صفّ) لا يُرقَّع:
-- بنيتُه غير هذه. فإن كان فارغاً حُذف، وإن كان فيه شيء نُقل جانباً باسم
-- `student_card_permissions_old` بفهارسه — لا يُحذف عملُ أحد.
do $$
declare
  idx record;
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'student_card_permissions'
      and column_name = 'card_key'
  ) then
    if (select count(*) from public.student_card_permissions) = 0 then
      drop table public.student_card_permissions;
    else
      alter table public.student_card_permissions rename to student_card_permissions_old;
      for idx in
        select indexname from pg_indexes
        where schemaname = 'public' and tablename = 'student_card_permissions_old'
      loop
        execute format('alter index public.%I rename to %I', idx.indexname, idx.indexname || '_old');
      end loop;
    end if;
  end if;
end $$;

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

-- يُعلم PostgREST بالبنية الجديدة فورًا بدل انتظار تحديث ذاكرته.
notify pgrst, 'reload schema';
