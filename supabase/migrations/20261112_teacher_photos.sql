alter table public.boha_professor_ratings add column if not exists photo boolean not null default false;
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('boha-professores','boha-professores',false,2097152,array['image/jpeg']::text[])
on conflict (id) do update set public=false,file_size_limit=2097152,allowed_mime_types=array['image/jpeg']::text[];
drop policy if exists professor_photo_read on storage.objects;
drop policy if exists professor_photo_insert on storage.objects;
drop policy if exists professor_photo_update on storage.objects;
drop policy if exists professor_photo_delete on storage.objects;
create policy professor_photo_read on storage.objects for select to authenticated
using (bucket_id='boha-professores' and public.boha_role()='admin');
create policy professor_photo_insert on storage.objects for insert to authenticated
with check (bucket_id='boha-professores' and public.boha_role()='admin');
create policy professor_photo_update on storage.objects for update to authenticated
using (bucket_id='boha-professores' and public.boha_role()='admin')
with check (bucket_id='boha-professores' and public.boha_role()='admin');
create policy professor_photo_delete on storage.objects for delete to authenticated
using (bucket_id='boha-professores' and public.boha_role()='admin');
