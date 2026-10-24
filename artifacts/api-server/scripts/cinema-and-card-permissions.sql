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

-- ═══════════════════════════════════════════════════════════════════════
-- 3) تطبيقُ الطالب يقرأ صلاحيات البطاقات من Supabase مباشرةً
-- ═══════════════════════════════════════════════════════════════════════
-- الخادمُ يحفظ كلَّ قاعدةٍ في الجدول وفي `app_kv/smartEdu_cardPermissions`
-- معاً. والتطبيقُ يسأل الخادمَ أولاً، فإن لم يصل إليه — نسخةٌ بُنيت بعنوان
-- خادمٍ قديم، وهو ما أبقى البطاقاتِ المقفلة مفتوحةً عند الطالبة — قرأ
-- المفتاحَ مباشرةً. وسياسةُ `anon_read_app_kv` (harden-rls.sql) قائمةُ
-- مفاتيح لا يرد فيها هذا، فتُضاف له سياسةٌ مستقلّة: سياساتُ القراءة تُجمع
-- بـ «أو»، فلا يُمسّ ما سواه. وما فيه حالةُ بطاقاتٍ ومعرّفات، لا بياناتٌ شخصية.
drop policy if exists "anon_read_card_permissions" on public.app_kv;
create policy "anon_read_card_permissions" on public.app_kv
  for select to anon, authenticated
  using (key = 'smartEdu_cardPermissions');

-- ═══════════════════════════════════════════════════════════════════════
-- 4) نقلُ فيديوهات `app_kv/smartEdu_videos` إلى الجدول
-- ═══════════════════════════════════════════════════════════════════════
-- ما حُفظ قبل وجود الجدول يُقرأ «قديماً» وتظهر عليه في اللوحة علامةُ
-- الحفظ المؤقّت. يُنقل هنا بالحقول نفسها التي يقرؤها `fromLegacyRecord`
-- في `src/lib/cinema.ts`، ثم يُحذف من المفتاح ما صار له صفٌّ في الجدول.
-- الصفُّ الموجود في الجدول يغلب (كما في `mergeCinemaVideos`)، والمحذوفُ في
-- `smartEdu_deletedVideos` لا يُنقل.
with legacy as (
  select r.value as rec
  from public.app_kv kv,
       jsonb_array_elements(
         case when jsonb_typeof(kv.value::jsonb) = 'array' then kv.value::jsonb else '[]'::jsonb end
       ) as r(value)
  where kv.key = 'smartEdu_videos' and jsonb_typeof(r.value) = 'object'
),
deleted as (
  select btrim(d.value) as id
  from public.app_kv kv,
       jsonb_array_elements_text(
         case when jsonb_typeof(kv.value::jsonb) = 'array' then kv.value::jsonb else '[]'::jsonb end
       ) as d(value)
  where kv.key = 'smartEdu_deletedVideos'
),
shaped as (
  select
    btrim(coalesce(rec->>'id', '')) as id,
    btrim(coalesce(rec->>'title', '')) as title,
    coalesce(nullif(btrim(rec->>'embedUrl'), ''), btrim(coalesce(rec->>'url', ''))) as embed_url,
    rec->>'sourceType' as source_type,
    btrim(coalesce(rec->>'description', '')) as description,
    coalesce(nullif(btrim(rec->>'gradeId'), ''), nullif(btrim(rec->>'grade_id'), ''),
             btrim(coalesce(rec->>'grade', ''))) as grade_id,
    coalesce(nullif(btrim(rec->>'teacher_id'), ''), nullif(btrim(rec->>'teacherId'), ''),
             btrim(coalesce(rec->>'createdBy', ''))) as teacher_id,
    btrim(coalesce(rec->>'teacherName', '')) as teacher_name,
    nullif(btrim(coalesce(rec->>'created_by', rec->>'addedBy', '')), '') as created_by,
    btrim(coalesce(rec->>'createdAt', '')) as created_at,
    coalesce(nullif(btrim(rec->>'updatedAt'), ''), btrim(coalesce(rec->>'createdAt', ''))) as updated_at
  from legacy
)
insert into public.cinema_videos
  (id, title, embed_url, source_type, description, grade_id, teacher_id,
   teacher_name, created_by, created_at, updated_at)
select distinct on (s.id)
  s.id,
  s.title,
  s.embed_url,
  case
    when s.source_type in ('mp4', 'embed') then s.source_type
    when s.embed_url ~* '\.mp4($|[?#])' then 'mp4'
    else 'embed'
  end,
  s.description,
  s.grade_id,
  s.teacher_id,
  s.teacher_name,
  coalesce(s.created_by, s.teacher_id),
  -- تاريخٌ ISO أو ميلي‌ثوانٍ؛ وما سواهما «الآن» بدل أن يُفشل النقلَ كله.
  case
    when s.created_at ~ '^\d{4}-\d{2}-\d{2}([T ][0-9:.]+)?(Z|[+-]\d{2}(:?\d{2})?)?$' then s.created_at::timestamptz
    when s.created_at ~ '^\d{10,13}$' then to_timestamp(s.created_at::bigint / case when length(s.created_at) > 10 then 1000.0 else 1 end)
    else now()
  end,
  case
    when s.updated_at ~ '^\d{4}-\d{2}-\d{2}([T ][0-9:.]+)?(Z|[+-]\d{2}(:?\d{2})?)?$' then s.updated_at::timestamptz
    when s.updated_at ~ '^\d{10,13}$' then to_timestamp(s.updated_at::bigint / case when length(s.updated_at) > 10 then 1000.0 else 1 end)
    else now()
  end
from shaped s
where s.id <> '' and s.embed_url <> ''
  and not exists (select 1 from deleted d where d.id = s.id)
order by s.id
on conflict (id) do nothing;

-- ما صار في الجدول يُرفع من المفتاح، فلا يُقرأ بعد اليوم نسخةً قديمة.
update public.app_kv kv
set value = coalesce((
  select jsonb_agg(r.value)
  from jsonb_array_elements(kv.value::jsonb) as r(value)
  where not exists (
    select 1 from public.cinema_videos c
    where c.id = btrim(coalesce(r.value->>'id', ''))
  )
), '[]'::jsonb)
where kv.key = 'smartEdu_videos'
  and jsonb_typeof(kv.value::jsonb) = 'array';

-- يُعلم PostgREST بالبنية الجديدة فورًا بدل انتظار تحديث ذاكرته.
notify pgrst, 'reload schema';
