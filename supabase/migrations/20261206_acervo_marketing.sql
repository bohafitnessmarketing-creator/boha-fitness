-- Acervo de marketing: materiais prontos (artes, vídeos, impressos) organizados por mês.
-- Marketing e administrador publicam e organizam. Gerente, recepção e dono só enxergam o publicado e baixam.
-- Gerente e recepção com unidade fixa só veem material da própria unidade ou da rede toda.

create table if not exists public.boha_acervo_items (
  id uuid primary key default gen_random_uuid(),
  month date not null check (month = date_trunc('month', month)::date),
  title text not null check (char_length(title) between 1 and 120),
  kind text not null default 'arte' check (kind in ('arte','video','impresso','outro')),
  unit text check (unit is null or unit in ('cb','te','ma')),
  campaign text check (campaign is null or char_length(campaign) <= 80),
  caption text check (caption is null or char_length(caption) <= 2200),
  pinned boolean not null default false,
  published boolean not null default false,
  published_at timestamptz,
  created_by text not null default lower(coalesce(auth.jwt()->>'email','')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists boha_acervo_items_month on public.boha_acervo_items(month desc);

create table if not exists public.boha_acervo_files (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.boha_acervo_items(id) on delete cascade,
  path text not null unique check (path ~ '^[0-9a-f-]{36}/[a-z0-9-]{8,60}\.(jpg|png|webp|mp4|mov|pdf)$'),
  thumb_path text check (thumb_path is null or thumb_path ~ '^[0-9a-f-]{36}/[a-z0-9-]{8,60}\.(jpg|png|webp)$'),
  name text not null check (char_length(name) between 1 and 160),
  label text check (label is null or char_length(label) <= 40),
  mime text not null check (mime in ('image/jpeg','image/png','image/webp','video/mp4','video/quicktime','application/pdf')),
  size bigint not null check (size between 1 and 52428800),
  width integer check (width is null or width between 1 and 20000),
  height integer check (height is null or height between 1 and 20000),
  position integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists boha_acervo_files_item on public.boha_acervo_files(item_id, position);

create table if not exists public.boha_acervo_dl (
  id bigserial primary key,
  file_id uuid not null references public.boha_acervo_files(id) on delete cascade,
  item_id uuid not null references public.boha_acervo_items(id) on delete cascade,
  email text not null,
  unit text,
  created_at timestamptz not null default now()
);
create index if not exists boha_acervo_dl_item on public.boha_acervo_dl(item_id);

create or replace function public.boha_acervo_touch() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists boha_acervo_items_touch on public.boha_acervo_items;
create trigger boha_acervo_items_touch before update on public.boha_acervo_items for each row execute function public.boha_acervo_touch();

-- ---------------------------------------------------------------- permissões
create or replace function public.boha_acervo_is_team() returns boolean
language sql stable security definer set search_path = '' as $$
  select public.boha_can('acervo') and public.boha_role() in ('marketing','admin')
$$;
create or replace function public.boha_acervo_item_ok(iid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.boha_can('acervo') and exists (
    select 1 from public.boha_acervo_items i
    where i.id = iid
      and (public.boha_role() in ('marketing','admin')
           or (i.published and (i.unit is null or public.boha_unit_ok(i.unit)))))
$$;
create or replace function public.boha_acervo_path_ok(p text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
begin
  return public.boha_acervo_item_ok(((storage.foldername(p))[1])::uuid);
exception when others then return false;
end $$;
revoke all on function public.boha_acervo_is_team(), public.boha_acervo_item_ok(uuid), public.boha_acervo_path_ok(text) from public, anon;
grant execute on function public.boha_acervo_is_team(), public.boha_acervo_item_ok(uuid), public.boha_acervo_path_ok(text) to authenticated;

alter table public.boha_acervo_items enable row level security;
alter table public.boha_acervo_files enable row level security;
alter table public.boha_acervo_dl enable row level security;
revoke all on public.boha_acervo_items, public.boha_acervo_files, public.boha_acervo_dl from anon, authenticated;
grant select, insert, update, delete on public.boha_acervo_items, public.boha_acervo_files to authenticated;
grant select on public.boha_acervo_dl to authenticated;

drop policy if exists acv_item_read on public.boha_acervo_items;
create policy acv_item_read on public.boha_acervo_items for select to authenticated
  using (public.boha_can('acervo') and (public.boha_role() in ('marketing','admin')
         or (published and (unit is null or public.boha_unit_ok(unit)))));
drop policy if exists acv_item_ins on public.boha_acervo_items;
create policy acv_item_ins on public.boha_acervo_items for insert to authenticated
  with check (public.boha_acervo_is_team() and created_by = lower(auth.jwt()->>'email'));
drop policy if exists acv_item_upd on public.boha_acervo_items;
create policy acv_item_upd on public.boha_acervo_items for update to authenticated
  using (public.boha_acervo_is_team()) with check (public.boha_acervo_is_team());
drop policy if exists acv_item_del on public.boha_acervo_items;
create policy acv_item_del on public.boha_acervo_items for delete to authenticated using (public.boha_acervo_is_team());

drop policy if exists acv_file_read on public.boha_acervo_files;
create policy acv_file_read on public.boha_acervo_files for select to authenticated using (public.boha_acervo_item_ok(item_id));
drop policy if exists acv_file_ins on public.boha_acervo_files;
create policy acv_file_ins on public.boha_acervo_files for insert to authenticated
  with check (public.boha_acervo_is_team() and (storage.foldername(path))[1] = item_id::text);
drop policy if exists acv_file_upd on public.boha_acervo_files;
create policy acv_file_upd on public.boha_acervo_files for update to authenticated
  using (public.boha_acervo_is_team()) with check (public.boha_acervo_is_team());
drop policy if exists acv_file_del on public.boha_acervo_files;
create policy acv_file_del on public.boha_acervo_files for delete to authenticated using (public.boha_acervo_is_team());

drop policy if exists acv_dl_read on public.boha_acervo_dl;
create policy acv_dl_read on public.boha_acervo_dl for select to authenticated using (public.boha_acervo_is_team());

-- Unidade fixa: gerente e recepção só veem a própria unidade (ou material da rede toda).
drop policy if exists unit_scope on public.boha_acervo_items;
create policy unit_scope on public.boha_acervo_items as restrictive for select to authenticated
  using (unit is null or public.boha_unit_ok(unit));

-- Arquivos (privados), sempre numa pasta com o id do material.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('boha-acervo','boha-acervo',false,52428800,array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime','application/pdf']::text[])
on conflict (id) do update set public=false, file_size_limit=52428800,
  allowed_mime_types=array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime','application/pdf']::text[];
drop policy if exists acv_obj_read on storage.objects;
create policy acv_obj_read on storage.objects for select to authenticated using (bucket_id='boha-acervo' and public.boha_acervo_path_ok(name));
drop policy if exists acv_obj_insert on storage.objects;
create policy acv_obj_insert on storage.objects for insert to authenticated with check (bucket_id='boha-acervo' and public.boha_acervo_is_team());
drop policy if exists acv_obj_update on storage.objects;
create policy acv_obj_update on storage.objects for update to authenticated
  using (bucket_id='boha-acervo' and public.boha_acervo_is_team()) with check (bucket_id='boha-acervo' and public.boha_acervo_is_team());
drop policy if exists acv_obj_delete on storage.objects;
create policy acv_obj_delete on storage.objects for delete to authenticated using (bucket_id='boha-acervo' and public.boha_acervo_is_team());

-- ---------------------------------------------------------------- funções
-- Publica o material (visível para as unidades) e, se pedido, avisa gerentes e recepção no sino.
create or replace function public.boha_acervo_publish(p_id uuid, p_notify boolean default true) returns void
language plpgsql security definer set search_path = '' as $$
declare i public.boha_acervo_items%rowtype; v_mes text; v_un text;
begin
  if not public.boha_acervo_is_team() then raise exception 'Acesso negado.' using errcode='42501'; end if;
  select * into i from public.boha_acervo_items where id = p_id;
  if not found then raise exception 'Material não encontrado.'; end if;
  if not exists (select 1 from public.boha_acervo_files where item_id = p_id) then raise exception 'Anexe pelo menos um arquivo antes de publicar.'; end if;
  update public.boha_acervo_items set published = true, published_at = coalesce(published_at, now()) where id = p_id;
  if p_notify and not i.published then
    v_mes := (array['janeiro','fevereiro','março','abril','maio','junho','julho','agosto','setembro','outubro','novembro','dezembro'])[extract(month from i.month)::int];
    v_un := case i.unit when 'cb' then 'Casa Branca' when 'te' then 'Santa Tereza' when 'ma' then 'Macedônia' else null end;
    insert into public.boha_notices(title, body, module, audience, created_by)
    values (left('Novo no Acervo: ' || i.title, 120),
            left('Material de ' || v_mes || case when v_un is not null then ' (' || v_un || ')' else '' end || ' pronto para baixar e postar.', 300),
            'acervo', array['gerente','recepcao']::text[], 'Sistema BOHA');
  end if;
end $$;

-- Registra o download (para o marketing saber o que as unidades estão usando).
create or replace function public.boha_acervo_dl(p_file uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_item uuid; v_email text := lower(auth.jwt()->>'email');
begin
  select f.item_id into v_item from public.boha_acervo_files f where f.id = p_file;
  if v_item is null or not public.boha_acervo_item_ok(v_item) then return; end if;
  if exists (select 1 from public.boha_acervo_dl d where d.file_id = p_file and d.email = v_email and d.created_at > now() - interval '10 minutes') then return; end if;
  insert into public.boha_acervo_dl(file_id, item_id, email, unit) values (p_file, v_item, v_email, public.boha_unit());
end $$;

-- Quantos downloads cada material teve, por unidade (só marketing e administrador).
create or replace function public.boha_acervo_stats() returns table(item_id uuid, n bigint, cb bigint, te bigint, ma bigint, last_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.boha_acervo_is_team() then raise exception 'Acesso negado.' using errcode='42501'; end if;
  return query select d.item_id, count(*), count(*) filter (where d.unit='cb'), count(*) filter (where d.unit='te'),
    count(*) filter (where d.unit='ma'), max(d.created_at)
    from public.boha_acervo_dl d group by d.item_id;
end $$;
revoke all on function public.boha_acervo_publish(uuid,boolean), public.boha_acervo_dl(uuid), public.boha_acervo_stats() from public, anon;
grant execute on function public.boha_acervo_publish(uuid,boolean), public.boha_acervo_dl(uuid), public.boha_acervo_stats() to authenticated;

-- ---------------------------------------------------------------- módulo na lista de permissões
alter table public.boha_role_modules drop constraint if exists boha_role_modules_valid;
alter table public.boha_role_modules add constraint boha_role_modules_valid
  check (modules <@ array['hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas','rotina','artes','solicitacoes','acervo']::text[]);
create or replace function public.boha_role_modules_save(p_role text, p_modules text[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem editar perfis.' using errcode='42501'; end if;
  if p_role not in ('dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_modules is null or exists (select 1 from unnest(p_modules) m where m is null or m not in ('hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas','rotina','artes','solicitacoes','acervo')) then raise exception 'Módulo inválido.'; end if;
  insert into public.boha_role_modules(role,modules,updated_at)
    values (p_role,(select coalesce(array_agg(distinct m),'{}'::text[]) from unnest(p_modules) m),now())
    on conflict (role) do update set modules=excluded.modules,updated_at=now();
end $$;
revoke all on function public.boha_role_modules_save(text,text[]) from public, anon;
grant execute on function public.boha_role_modules_save(text,text[]) to authenticated;
update public.boha_role_modules set modules = array_append(modules,'acervo')
  where role in ('gerente','recepcao','marketing','dono') and not ('acervo' = any(modules));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Novo: Acervo de marketing',
  'Artes, vídeos e impressos prontos, separados por mês. Escolha o mês, baixe e poste.',
  'acervo',array['admin','gerente','recepcao','marketing','dono'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Novo: Acervo de marketing');
