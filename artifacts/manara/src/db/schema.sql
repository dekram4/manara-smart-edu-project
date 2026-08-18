-- ============================================================
-- SmartEdu — مخطط قاعدة بيانات Supabase
-- شغّل هذا السكربت مرة واحدة في:
-- لوحة Supabase → SQL Editor → New query → الصق ثم Run
-- ============================================================
-- ملاحظة أمان: هذه السياسات تسمح بالوصول الكامل عبر المفتاح العام (anon)
-- لأن التطبيق يصل عبر خادم Replit إلى Supabase.
-- يمكن لاحقاً تضييق سياسات RLS بعد إضافة مصادقة Supabase للمستخدمين.
-- ============================================================

-- جداول الكيانات: كل صف = سجل واحد، والحقل data يحوي الكائن كاملاً (JSONB)
create table if not exists public.students        (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.parents         (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.teachers        (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.lesson_configs  (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.created_quizzes (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.quiz_results    (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.interactions    (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.private_messages(id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.public_messages (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.certificates    (id text primary key, data jsonb not null, updated_at timestamptz not null default now());

-- جدول مفتاح/قيمة للإعدادات والقوائم والبنى المتشعّبة
create table if not exists public.app_kv (key text primary key, value jsonb not null, updated_at timestamptz not null default now());

-- تفعيل RLS وإضافة سياسات وصول كامل (anon + authenticated)
do $$
declare t text;
begin
  foreach t in array array[
    'students','parents','teachers','lesson_configs','created_quizzes','quiz_results',
    'interactions','private_messages','public_messages','certificates','app_kv'
  ]
  loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('drop policy if exists "allow_all_%s" on public.%I;', t, t);
    execute format(
      'create policy "allow_all_%s" on public.%I for all to anon, authenticated using (true) with check (true);',
      t, t
    );
  end loop;
end $$;
