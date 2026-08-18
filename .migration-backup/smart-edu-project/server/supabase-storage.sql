-- Run once in the Supabase SQL editor when the project is using the anon key
-- without a service-role key. The server also attempts bucket initialization
-- automatically at startup and before every MP4 upload.

insert into storage.buckets (id, name, public, allowed_mime_types)
values (
  'cinema',
  'cinema',
  true,
  array['video/mp4']::text[]
)
on conflict (id) do update
set public = true,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "cinema public read" on storage.objects;
create policy "cinema public read"
on storage.objects for select
to public
using (bucket_id = 'cinema');

drop policy if exists "cinema upload" on storage.objects;
create policy "cinema upload"
on storage.objects for insert
to anon, authenticated
with check (bucket_id = 'cinema' and lower(name) like '%.mp4');

drop policy if exists "cinema update" on storage.objects;
create policy "cinema update"
on storage.objects for update
to anon, authenticated
using (bucket_id = 'cinema')
with check (bucket_id = 'cinema' and lower(name) like '%.mp4');

drop policy if exists "cinema delete" on storage.objects;
create policy "cinema delete"
on storage.objects for delete
to anon, authenticated
using (bucket_id = 'cinema');