-- Mapas mentais: ferramenta exclusiva do marketing (e administrador).
-- Todos do marketing enxergam e editam os mesmos mapas (recurso da equipe). Cada gravação confere se mais ninguém alterou
-- o mapa no meio do caminho (evita um sobrescrever o trabalho do outro) e guarda versões para voltar atrás.

create table if not exists public.boha_mindmaps (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 120),
  data jsonb not null check (pg_column_size(data) < 4000000),
  node_count integer not null default 0 check (node_count between 0 and 5000),
  thumb text check (thumb is null or char_length(thumb) <= 40000),
  created_by text not null default lower(coalesce(auth.jwt()->>'email','')),
  updated_by text,
  deleted_at timestamptz,
  deleted_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists boha_mindmaps_updated on public.boha_mindmaps(updated_at desc);

create table if not exists public.boha_mindmap_versions (
  id uuid primary key default gen_random_uuid(),
  map_id uuid not null references public.boha_mindmaps(id) on delete cascade,
  title text not null,
  data jsonb not null,
  node_count integer not null default 0,
  note text check (note is null or char_length(note) <= 120),
  created_by text not null default lower(coalesce(auth.jwt()->>'email','')),
  created_at timestamptz not null default now()
);
create index if not exists boha_mindmap_versions_map on public.boha_mindmap_versions(map_id, created_at desc);

create or replace function public.boha_mm_ok() returns boolean
language sql stable security definer set search_path = '' as $$
  select public.boha_can('mapas') and public.boha_role() in ('marketing','admin')
$$;
revoke all on function public.boha_mm_ok() from public, anon;
grant execute on function public.boha_mm_ok() to authenticated;

alter table public.boha_mindmaps enable row level security;
alter table public.boha_mindmap_versions enable row level security;
revoke all on public.boha_mindmaps, public.boha_mindmap_versions from anon, authenticated;
grant select, delete on public.boha_mindmaps to authenticated;
grant select, delete on public.boha_mindmap_versions to authenticated;

drop policy if exists mm_read on public.boha_mindmaps;
create policy mm_read on public.boha_mindmaps for select to authenticated using (public.boha_mm_ok());
drop policy if exists mm_del on public.boha_mindmaps;
create policy mm_del on public.boha_mindmaps for delete to authenticated using (public.boha_mm_ok());
drop policy if exists mmv_read on public.boha_mindmap_versions;
create policy mmv_read on public.boha_mindmap_versions for select to authenticated using (public.boha_mm_ok());
drop policy if exists mmv_del on public.boha_mindmap_versions;
create policy mmv_del on public.boha_mindmap_versions for delete to authenticated using (public.boha_mm_ok());

-- Criar mapa
create or replace function public.boha_mm_create(p_title text, p_data jsonb, p_count integer, p_thumb text)
returns table(id uuid, updated_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_at timestamptz;
begin
  if not public.boha_mm_ok() then raise exception 'Acesso negado.' using errcode = '42501'; end if;
  delete from public.boha_mindmaps m where m.deleted_at is not null and m.deleted_at < now() - interval '30 days';
  insert into public.boha_mindmaps(title, data, node_count, thumb, created_by, updated_by)
  values (left(trim(coalesce(nullif(p_title,''),'Mapa sem título')),120), p_data, greatest(0,least(coalesce(p_count,0),5000)), p_thumb,
          lower(auth.jwt()->>'email'), lower(auth.jwt()->>'email'))
  returning boha_mindmaps.id, boha_mindmaps.updated_at into v_id, v_at;
  return query select v_id, v_at;
end $$;

-- Gravar mapa: só grava se ninguém alterou desde a última leitura (p_expected). Devolve o novo carimbo de data.
create or replace function public.boha_mm_save(p_id uuid, p_expected text, p_title text, p_data jsonb, p_count integer, p_thumb text)
returns timestamptz
language plpgsql security definer set search_path = '' as $$
declare cur timestamptz; nw timestamptz := clock_timestamp();
begin
  if not public.boha_mm_ok() then raise exception 'Acesso negado.' using errcode = '42501'; end if;
  select m.updated_at into cur from public.boha_mindmaps m where m.id = p_id for update;
  if not found then raise exception 'MAPA_NAO_ENCONTRADO'; end if;
  if p_expected is not null and cur <> p_expected::timestamptz then raise exception 'CONFLITO'; end if;
  update public.boha_mindmaps set title = left(trim(coalesce(nullif(p_title,''),'Mapa sem título')),120), data = p_data,
    node_count = greatest(0,least(coalesce(p_count,0),5000)), thumb = p_thumb, updated_by = lower(auth.jwt()->>'email'), updated_at = nw
  where id = p_id;
  return nw;
end $$;

-- Guardar versão do que está gravado agora (mantém as 60 últimas)
create or replace function public.boha_mm_snapshot(p_id uuid, p_note text default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_mm_ok() then raise exception 'Acesso negado.' using errcode = '42501'; end if;
  insert into public.boha_mindmap_versions(map_id, title, data, node_count, note, created_by)
    select m.id, m.title, m.data, m.node_count, nullif(left(trim(coalesce(p_note,'')),120),''), lower(auth.jwt()->>'email')
      from public.boha_mindmaps m where m.id = p_id;
  delete from public.boha_mindmap_versions v where v.map_id = p_id and v.id not in
    (select x.id from public.boha_mindmap_versions x where x.map_id = p_id order by x.created_at desc limit 60);
end $$;

revoke all on function public.boha_mm_create(text,jsonb,integer,text), public.boha_mm_save(uuid,text,text,jsonb,integer,text), public.boha_mm_snapshot(uuid,text) from public, anon;
grant execute on function public.boha_mm_create(text,jsonb,integer,text), public.boha_mm_save(uuid,text,text,jsonb,integer,text), public.boha_mm_snapshot(uuid,text) to authenticated;

-- Lixeira: excluir manda para a lixeira (30 dias para recuperar); excluir definitivamente é o DELETE da tabela.
create or replace function public.boha_mm_trash(p_id uuid, p_on boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_mm_ok() then raise exception 'Acesso negado.' using errcode = '42501'; end if;
  update public.boha_mindmaps set deleted_at = case when p_on then now() else null end,
         deleted_by = case when p_on then lower(auth.jwt()->>'email') else null end where id = p_id;
end $$;
revoke all on function public.boha_mm_trash(uuid,boolean) from public, anon;
grant execute on function public.boha_mm_trash(uuid,boolean) to authenticated;

-- Renomear sem contar como edição do conteúdo
create or replace function public.boha_mm_rename(p_id uuid, p_title text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_mm_ok() then raise exception 'Acesso negado.' using errcode = '42501'; end if;
  update public.boha_mindmaps set title = left(trim(coalesce(nullif(p_title,''),'Mapa sem título')),120) where id = p_id;
end $$;
revoke all on function public.boha_mm_rename(uuid,text) from public, anon;
grant execute on function public.boha_mm_rename(uuid,text) to authenticated;

-- Módulo na lista de permissões (só marketing; administrador tem tudo)
alter table public.boha_role_modules drop constraint if exists boha_role_modules_valid;
alter table public.boha_role_modules add constraint boha_role_modules_valid
  check (modules <@ array['hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas','rotina','artes','solicitacoes','acervo','talentos','mapas']::text[]);
create or replace function public.boha_role_modules_save(p_role text, p_modules text[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem editar perfis.' using errcode='42501'; end if;
  if p_role not in ('dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_modules is null or exists (select 1 from unnest(p_modules) m where m is null or m not in ('hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas','rotina','artes','solicitacoes','acervo','talentos','mapas')) then raise exception 'Módulo inválido.'; end if;
  insert into public.boha_role_modules(role,modules,updated_at)
    values (p_role,(select coalesce(array_agg(distinct m),'{}'::text[]) from unnest(p_modules) m),now())
    on conflict (role) do update set modules=excluded.modules,updated_at=now();
end $$;
revoke all on function public.boha_role_modules_save(text,text[]) from public, anon;
grant execute on function public.boha_role_modules_save(text,text[]) to authenticated;
update public.boha_role_modules set modules = array_append(modules,'mapas')
  where role = 'marketing' and not ('mapas' = any(modules));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Novo: Mapas mentais',
  'Monte mapas mentais de campanhas, pautas e estratégias: ramos, ícones, relações, modelos prontos e exportação em imagem, PDF e texto.',
  'mapas',array['admin','marketing']::text[],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Novo: Mapas mentais');
