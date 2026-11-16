-- Link nas pautas + anexos (imagem ou PDF) em pautas e ideias do Calendário editorial.
alter table public.boha_editorial_items add column if not exists link text;
alter table public.boha_editorial_items drop constraint if exists boha_editorial_items_link_check;
alter table public.boha_editorial_items add constraint boha_editorial_items_link_check
  check (link is null or (char_length(link) <= 600 and link ~* '^https?://[^[:space:]]+$'));

create table if not exists public.boha_editorial_files (
  id uuid primary key default gen_random_uuid(),
  item_id uuid references public.boha_editorial_items(id) on delete cascade,
  idea_id uuid references public.boha_editorial_ideas(id) on delete cascade,
  path text not null check (path ~ '^[a-z0-9-]{8,80}\.(jpg|png|webp|pdf)$'),
  name text not null check (char_length(name) between 1 and 160),
  mime text not null check (mime in ('image/jpeg','image/png','image/webp','application/pdf')),
  size integer not null check (size between 0 and 10485760),
  created_by text,
  created_at timestamptz not null default now(),
  check ((item_id is not null)::int + (idea_id is not null)::int = 1)
);
create index if not exists boha_editorial_files_item on public.boha_editorial_files(item_id);
create index if not exists boha_editorial_files_idea on public.boha_editorial_files(idea_id);
create index if not exists boha_editorial_files_path on public.boha_editorial_files(path);
alter table public.boha_editorial_files enable row level security;
revoke all on public.boha_editorial_files from anon;
grant select, insert, update, delete on public.boha_editorial_files to authenticated;
drop policy if exists editorial_files_access on public.boha_editorial_files;
create policy editorial_files_access on public.boha_editorial_files for all to authenticated
  using (public.boha_can('calendario')) with check (public.boha_can('calendario'));
create or replace function public.boha_editorial_files_guard() returns trigger language plpgsql as $$
begin
  new.created_by := coalesce(lower(auth.jwt()->>'email'), new.created_by);
  if (select count(*) from public.boha_editorial_files f
        where (new.item_id is not null and f.item_id = new.item_id) or (new.idea_id is not null and f.idea_id = new.idea_id)) >= 20 then
    raise exception 'Limite de 20 anexos por pauta ou ideia.' using errcode = '23514';
  end if;
  return new;
end $$;
drop trigger if exists boha_editorial_files_guard on public.boha_editorial_files;
create trigger boha_editorial_files_guard before insert on public.boha_editorial_files for each row execute function public.boha_editorial_files_guard();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('boha-editorial','boha-editorial',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf']::text[])
on conflict (id) do update set public=false, file_size_limit=10485760, allowed_mime_types=array['image/jpeg','image/png','image/webp','application/pdf']::text[];
drop policy if exists editorial_file_read on storage.objects;
drop policy if exists editorial_file_insert on storage.objects;
drop policy if exists editorial_file_delete on storage.objects;
create policy editorial_file_read on storage.objects for select to authenticated using (bucket_id='boha-editorial' and public.boha_can('calendario'));
create policy editorial_file_insert on storage.objects for insert to authenticated with check (bucket_id='boha-editorial' and public.boha_can('calendario') and name ~ '^[a-z0-9-]{8,80}\.(jpg|png|webp|pdf)$');
create policy editorial_file_delete on storage.objects for delete to authenticated using (bucket_id='boha-editorial' and public.boha_can('calendario'));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Calendário editorial: link e anexos',
  'Cada pauta e cada ideia agora aceita um link e anexos (imagem ou PDF, até 10 MB cada). Abra a pauta ou a ideia, arraste os arquivos para a área de anexos e salve.',
  'calendario',array['admin','marketing'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Calendário editorial: link e anexos');
