-- Módulo "Solicitações ao marketing": chamados de gerentes e recepção para o time de marketing.
-- Quem pede só enxerga os próprios chamados. Marketing e administrador enxergam todos e atendem.
-- A identificação de quem pediu é preenchida pelo servidor (não dá para falsificar).

-- Avisos no sino podem ser dirigidos a uma pessoa só (to_email), além do público por perfil.
alter table public.boha_notices add column if not exists to_email text;
drop policy if exists notices_read on public.boha_notices;
create policy notices_read on public.boha_notices for select to authenticated
  using ((public.boha_role() is not null)
    and (audience is null or cardinality(audience) = 0 or public.boha_role() = any (audience))
    and (to_email is null or to_email = lower(auth.jwt()->>'email')));

-- Tarefas do "A fazer" podem vir de um chamado (para fechar sozinhas e não duplicar).
alter table public.boha_tasks add column if not exists source_ref text;
create unique index if not exists boha_tasks_source on public.boha_tasks(owner, source_ref) where source_ref is not null;

create sequence if not exists public.boha_mkt_seq;
create table if not exists public.boha_mkt_requests (
  id uuid primary key default gen_random_uuid(),
  num integer not null unique default nextval('public.boha_mkt_seq'),
  kind text not null check (kind in ('arte','video','flyer','cartaz','depoimento','outro')),
  title text not null check (char_length(title) between 3 and 140),
  description text not null default '' check (char_length(description) <= 3000),
  deadline date check (deadline is null or deadline between date '2020-01-01' and date '2100-01-01'),
  urgent boolean not null default false,
  link text check (link is null or (char_length(link) <= 600 and link ~* '^https?://[^[:space:]]+$')),
  unit text check (unit is null or unit in ('cb','te','ma')),
  requester_email text not null check (requester_email = lower(requester_email)),
  requester_name text not null check (char_length(requester_name) <= 80),
  requester_role text not null,
  assignee_email text,
  assignee_name text check (assignee_name is null or char_length(assignee_name) <= 80),
  status text not null default 'nova' check (status in ('nova','andamento','aguardando','concluida','cancelada')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  last_activity_at timestamptz not null default now(),
  last_actor text not null default 'requester' check (last_actor in ('requester','marketing')),
  requester_seen_at timestamptz default now(),
  marketing_seen_at timestamptz
);
create index if not exists boha_mkt_requests_req on public.boha_mkt_requests(requester_email, created_at desc);
create index if not exists boha_mkt_requests_status on public.boha_mkt_requests(status, deadline);

create table if not exists public.boha_mkt_comments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.boha_mkt_requests(id) on delete cascade,
  author_email text not null,
  author_name text not null check (char_length(author_name) <= 80),
  author_role text not null,
  kind text not null default 'msg' check (kind in ('msg','entrega','sistema')),
  body text not null default '' check (char_length(body) <= 2000),
  link text check (link is null or (char_length(link) <= 600 and link ~* '^https?://[^[:space:]]+$')),
  created_at timestamptz not null default now()
);
create index if not exists boha_mkt_comments_req on public.boha_mkt_comments(request_id, created_at);

create table if not exists public.boha_mkt_files (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.boha_mkt_requests(id) on delete cascade,
  comment_id uuid references public.boha_mkt_comments(id) on delete cascade,
  path text not null unique check (path ~ '^[0-9a-f-]{36}/[a-z0-9-]{8,60}\.(jpg|png|webp|pdf)$'),
  name text not null check (char_length(name) between 1 and 120),
  mime text not null check (mime in ('image/jpeg','image/png','image/webp','application/pdf')),
  size integer not null check (size between 1 and 10485760),
  created_by text not null,
  created_at timestamptz not null default now()
);
create index if not exists boha_mkt_files_req on public.boha_mkt_files(request_id);

-- Quem é do time de marketing (marketing e administrador com o módulo liberado)
create or replace function public.boha_mkt_is_team() returns boolean
language sql stable security definer set search_path = '' as $$
  select public.boha_can('solicitacoes') and public.boha_role() in ('marketing','admin')
$$;
create or replace function public.boha_mkt_can_access(rid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.boha_can('solicitacoes') and exists (
    select 1 from public.boha_mkt_requests r
    where r.id = rid and (public.boha_role() in ('marketing','admin') or r.requester_email = lower(auth.jwt()->>'email')))
$$;
-- Versão para o caminho do arquivo (primeira pasta = id do chamado); não quebra com nomes inválidos.
create or replace function public.boha_mkt_path_ok(p text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
begin
  return public.boha_mkt_can_access(((storage.foldername(p))[1])::uuid);
exception when others then return false;
end $$;
revoke all on function public.boha_mkt_is_team(), public.boha_mkt_can_access(uuid), public.boha_mkt_path_ok(text) from public, anon;
grant execute on function public.boha_mkt_is_team(), public.boha_mkt_can_access(uuid), public.boha_mkt_path_ok(text) to authenticated;

alter table public.boha_mkt_requests enable row level security;
alter table public.boha_mkt_comments enable row level security;
alter table public.boha_mkt_files enable row level security;
revoke all on public.boha_mkt_requests, public.boha_mkt_comments, public.boha_mkt_files from anon;
revoke all on public.boha_mkt_requests, public.boha_mkt_comments, public.boha_mkt_files from authenticated;
grant select on public.boha_mkt_requests, public.boha_mkt_comments to authenticated;
grant select, insert, delete on public.boha_mkt_files to authenticated;
drop policy if exists mkt_req_read on public.boha_mkt_requests;
create policy mkt_req_read on public.boha_mkt_requests for select to authenticated
  using (public.boha_can('solicitacoes') and (public.boha_role() in ('marketing','admin') or requester_email = lower(auth.jwt()->>'email')));
drop policy if exists unit_scope on public.boha_mkt_requests;
create policy unit_scope on public.boha_mkt_requests as restrictive for select to authenticated
  using (unit is null or public.boha_unit_ok(unit));
drop policy if exists mkt_com_read on public.boha_mkt_comments;
create policy mkt_com_read on public.boha_mkt_comments for select to authenticated using (public.boha_mkt_can_access(request_id));
drop policy if exists mkt_file_read on public.boha_mkt_files;
create policy mkt_file_read on public.boha_mkt_files for select to authenticated using (public.boha_mkt_can_access(request_id));
drop policy if exists mkt_file_insert on public.boha_mkt_files;
create policy mkt_file_insert on public.boha_mkt_files for insert to authenticated
  with check (created_by = lower(auth.jwt()->>'email') and public.boha_mkt_can_access(request_id)
    and (storage.foldername(path))[1] = request_id::text);
drop policy if exists mkt_file_delete on public.boha_mkt_files;
create policy mkt_file_delete on public.boha_mkt_files for delete to authenticated
  using (public.boha_mkt_can_access(request_id) and (created_by = lower(auth.jwt()->>'email') or public.boha_mkt_is_team()));

-- Arquivos (privados), sempre numa pasta com o id do chamado.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('boha-solicitacoes','boha-solicitacoes',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf']::text[])
on conflict (id) do update set public=false, file_size_limit=10485760, allowed_mime_types=array['image/jpeg','image/png','image/webp','application/pdf']::text[];
drop policy if exists mkt_obj_read on storage.objects;
create policy mkt_obj_read on storage.objects for select to authenticated using (bucket_id='boha-solicitacoes' and public.boha_mkt_path_ok(name));
drop policy if exists mkt_obj_insert on storage.objects;
create policy mkt_obj_insert on storage.objects for insert to authenticated with check (bucket_id='boha-solicitacoes' and public.boha_mkt_path_ok(name));
drop policy if exists mkt_obj_delete on storage.objects;
create policy mkt_obj_delete on storage.objects for delete to authenticated
  using (bucket_id='boha-solicitacoes' and public.boha_mkt_path_ok(name) and (owner = auth.uid() or public.boha_mkt_is_team()));

-- ---------------------------------------------------------------- funções internas
create or replace function public.boha_mkt_kind_label(k text) returns text language sql immutable as $$
  select case k when 'arte' then 'Arte' when 'video' then 'Vídeo' when 'flyer' then 'Flyer' when 'cartaz' then 'Cartaz' when 'depoimento' then 'Depoimento' else 'Outro' end $$;
create or replace function public.boha_mkt_unit_label(u text) returns text language sql immutable as $$
  select case u when 'cb' then 'Casa Branca' when 'te' then 'Santa Tereza' when 'ma' then 'Macedônia' else null end $$;

create or replace function public.boha_mkt_notice(p_title text, p_body text, p_audience text[], p_to text) returns void
language sql security definer set search_path = '' as $$
  insert into public.boha_notices(title, body, module, audience, created_by, to_email)
  values (left(p_title, 120), left(coalesce(p_body,''), 300), 'solicitacoes', p_audience, 'Sistema BOHA', p_to)
$$;

create or replace function public.boha_mkt_me(out v_email text, out v_name text, out v_role text, out v_unit text) returns record
language sql stable security definer set search_path = '' as $$
  select a.email,
    coalesce(nullif(trim(a.name),''), nullif(trim(auth.jwt()->'user_metadata'->>'name'),''), initcap(split_part(a.email,'@',1))),
    a.role, a.unit
  from public.boha_access a where a.email = lower(auth.jwt()->>'email')
$$;
revoke all on function public.boha_mkt_kind_label(text), public.boha_mkt_unit_label(text), public.boha_mkt_notice(text,text,text[],text), public.boha_mkt_me() from public, anon, authenticated;

-- ---------------------------------------------------------------- RPCs
-- Cria o chamado. Nome, perfil e unidade vêm do servidor.
create or replace function public.boha_mkt_create(p_kind text, p_title text, p_description text, p_deadline date, p_urgent boolean, p_link text, p_unit text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare me record; v_id uuid; v_unit text; v_n integer;
begin
  if not public.boha_can('solicitacoes') then raise exception 'Seu perfil não tem acesso a este módulo.' using errcode='42501'; end if;
  select * into me from public.boha_mkt_me();
  if me.v_email is null then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if p_kind is null or p_kind not in ('arte','video','flyer','cartaz','depoimento','outro') then raise exception 'Escolha o tipo da solicitação.'; end if;
  if char_length(trim(coalesce(p_title,''))) < 3 then raise exception 'Escreva um título para o pedido.'; end if;
  select count(*) into v_n from public.boha_mkt_requests where requester_email = me.v_email and created_at > now() - interval '1 day';
  if v_n >= 30 then raise exception 'Você já fez muitas solicitações hoje. Fale com o marketing.'; end if;
  v_unit := coalesce(me.v_unit, case when p_unit in ('cb','te','ma') then p_unit end);
  insert into public.boha_mkt_requests(kind,title,description,deadline,urgent,link,unit,requester_email,requester_name,requester_role)
  values (p_kind, trim(p_title), trim(coalesce(p_description,'')), p_deadline, coalesce(p_urgent,false), nullif(trim(coalesce(p_link,'')),''), v_unit, me.v_email, me.v_name, me.v_role)
  returning id into v_id;
  perform public.boha_mkt_notice('Nova solicitação · ' || public.boha_mkt_kind_label(p_kind) || case when coalesce(p_urgent,false) then ' (urgente)' else '' end,
    me.v_name || coalesce(' · ' || public.boha_mkt_unit_label(v_unit), '') || ': ' || trim(p_title), array['marketing','admin'], null);
  return v_id;
end $$;

-- Mensagem ou entrega na conversa do chamado.
create or replace function public.boha_mkt_comment(p_id uuid, p_body text, p_link text default null, p_kind text default 'msg')
returns uuid language plpgsql security definer set search_path = '' as $$
declare me record; r public.boha_mkt_requests; team boolean; v_id uuid; v_kind text; v_body text;
begin
  if not public.boha_mkt_can_access(p_id) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  select * into me from public.boha_mkt_me();
  select * into r from public.boha_mkt_requests where id = p_id for update;
  team := me.v_role in ('marketing','admin');
  if r.status = 'cancelada' then raise exception 'Esta solicitação foi cancelada.'; end if;
  v_body := trim(coalesce(p_body,''));
  if v_body = '' and nullif(trim(coalesce(p_link,'')),'') is null then raise exception 'Escreva uma mensagem ou cole um link.'; end if;
  v_kind := case when team and p_kind = 'entrega' then 'entrega' else 'msg' end;
  insert into public.boha_mkt_comments(request_id,author_email,author_name,author_role,kind,body,link)
  values (p_id, me.v_email, me.v_name, me.v_role, v_kind, v_body, nullif(trim(coalesce(p_link,'')),'')) returning id into v_id;
  update public.boha_mkt_requests set updated_at = now(), last_activity_at = now(), last_actor = case when team then 'marketing' else 'requester' end,
    requester_seen_at = case when team then requester_seen_at else now() end,
    marketing_seen_at = case when team then now() else marketing_seen_at end,
    status = case when not team and status in ('aguardando','concluida') then 'andamento' else status end,
    completed_at = case when not team and status = 'concluida' then null else completed_at end
  where id = p_id;
  if not team and r.status = 'concluida' then
    insert into public.boha_mkt_comments(request_id,author_email,author_name,author_role,kind,body) values (p_id, me.v_email, me.v_name, me.v_role, 'sistema', 'Pedido reaberto pelo solicitante.');
    update public.boha_tasks set done_at = null where source_ref = 'mkt:' || p_id::text and done_at is not null;
  end if;
  if team then
    perform public.boha_mkt_notice(case when v_kind = 'entrega' then 'Entrega da sua solicitação' else 'Resposta do marketing' end,
      '#' || r.num || ' · ' || r.title || ': ' || left(v_body, 160), array[r.requester_role], r.requester_email);
  else
    if r.assignee_email is not null then
      perform public.boha_mkt_notice('Resposta no pedido #' || r.num, me.v_name || ': ' || left(v_body, 160), array['marketing','admin'], r.assignee_email);
    else
      perform public.boha_mkt_notice('Resposta no pedido #' || r.num, me.v_name || ': ' || left(v_body, 160), array['marketing','admin'], null);
    end if;
  end if;
  return v_id;
end $$;

create or replace function public.boha_mkt_set_status(p_id uuid, p_status text) returns void
language plpgsql security definer set search_path = '' as $$
declare me record; r public.boha_mkt_requests; team boolean; lbl text;
begin
  if not public.boha_mkt_can_access(p_id) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if p_status is null or p_status not in ('nova','andamento','aguardando','concluida','cancelada') then raise exception 'Status inválido.'; end if;
  select * into me from public.boha_mkt_me();
  select * into r from public.boha_mkt_requests where id = p_id for update;
  team := me.v_role in ('marketing','admin');
  if not team and not (p_status = 'cancelada' and r.status not in ('concluida','cancelada')) then raise exception 'Você só pode cancelar a própria solicitação enquanto ela não foi concluída.' using errcode='42501'; end if;
  if r.status = p_status then return; end if;
  update public.boha_mkt_requests set status = p_status, updated_at = now(), last_activity_at = now(),
    last_actor = case when team then 'marketing' else 'requester' end,
    completed_at = case when p_status = 'concluida' then now() when p_status in ('nova','andamento','aguardando') then null else completed_at end,
    marketing_seen_at = case when team then now() else marketing_seen_at end,
    requester_seen_at = case when team then requester_seen_at else now() end
  where id = p_id;
  lbl := case p_status when 'nova' then 'Nova' when 'andamento' then 'Em andamento' when 'aguardando' then 'Aguardando o solicitante' when 'concluida' then 'Concluída' else 'Cancelada' end;
  insert into public.boha_mkt_comments(request_id,author_email,author_name,author_role,kind,body) values (p_id, me.v_email, me.v_name, me.v_role, 'sistema', 'Status: ' || lbl);
  if p_status in ('concluida','cancelada') then
    update public.boha_tasks set done_at = coalesce(done_at, now()) where source_ref = 'mkt:' || p_id::text;
  elsif r.status in ('concluida','cancelada') then
    update public.boha_tasks set done_at = null where source_ref = 'mkt:' || p_id::text;
  end if;
  if team and p_status in ('andamento','aguardando','concluida') then
    perform public.boha_mkt_notice(case p_status when 'andamento' then 'Sua solicitação está em andamento' when 'aguardando' then 'O marketing precisa de uma informação sua' else 'Sua solicitação foi concluída' end,
      '#' || r.num || ' · ' || r.title, array[r.requester_role], r.requester_email);
  end if;
end $$;

-- Assume (ou passa para outra pessoa do marketing). Cria a tarefa no "A fazer" de quem assumiu.
create or replace function public.boha_mkt_assign(p_id uuid, p_email text) returns void
language plpgsql security definer set search_path = '' as $$
declare me record; r public.boha_mkt_requests; v_nm text; v_email text := nullif(lower(trim(coalesce(p_email,''))),'');
begin
  if not public.boha_mkt_is_team() then raise exception 'Só o marketing pode atribuir.' using errcode='42501'; end if;
  select * into me from public.boha_mkt_me();
  select * into r from public.boha_mkt_requests where id = p_id for update;
  if not found then raise exception 'Solicitação não encontrada.'; end if;
  if v_email is not null then
    select coalesce(nullif(trim(name),''), initcap(split_part(email,'@',1))) into v_nm from public.boha_access where email = v_email and role in ('marketing','admin');
    if v_nm is null then raise exception 'Essa pessoa não é do marketing.'; end if;
  end if;
  if r.assignee_email is distinct from v_email then
    if r.assignee_email is not null then
      update public.boha_tasks set done_at = coalesce(done_at, now()) where owner = r.assignee_email and source_ref = 'mkt:' || p_id::text;
    end if;
    update public.boha_mkt_requests set assignee_email = v_email, assignee_name = v_nm, updated_at = now(), last_activity_at = now(), last_actor = 'marketing',
      status = case when v_email is not null and status = 'nova' then 'andamento' else status end, marketing_seen_at = now() where id = p_id;
    insert into public.boha_mkt_comments(request_id,author_email,author_name,author_role,kind,body)
      values (p_id, me.v_email, me.v_name, me.v_role, 'sistema', case when v_email is null then 'Responsável removido.' else 'Responsável: ' || v_nm end);
    if v_email is not null then
      if r.status in ('concluida','cancelada') then null; else
        insert into public.boha_tasks(owner, title, notes, due_date, source_ref)
        values (v_email, left('Marketing #' || r.num || ' · ' || public.boha_mkt_kind_label(r.kind) || ' — ' || r.title, 200),
          left('Pedido de ' || r.requester_name || coalesce(' (' || public.boha_mkt_unit_label(r.unit) || ')', '') || E'\n' ||
               coalesce('Prazo: ' || to_char(r.deadline, 'DD/MM/YYYY') || E'\n', '') || left(r.description, 600) || E'\n\nAbra: Solicitações ao marketing.', 4000),
          r.deadline, 'mkt:' || p_id::text)
        on conflict (owner, source_ref) where source_ref is not null do update set done_at = null, title = excluded.title, due_date = excluded.due_date, notes = excluded.notes;
      end if;
      perform public.boha_mkt_notice('Sua solicitação foi assumida', '#' || r.num || ' · ' || r.title || ' · responsável: ' || v_nm, array[r.requester_role], r.requester_email);
    end if;
  end if;
end $$;

create or replace function public.boha_mkt_seen(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare team boolean := public.boha_role() in ('marketing','admin');
begin
  if not public.boha_mkt_can_access(p_id) then return; end if;
  if team then update public.boha_mkt_requests set marketing_seen_at = now() where id = p_id;
  else update public.boha_mkt_requests set requester_seen_at = now() where id = p_id and requester_email = lower(auth.jwt()->>'email'); end if;
end $$;

create or replace function public.boha_mkt_team() returns table(email text, name text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.boha_mkt_is_team() then raise exception 'Acesso negado.' using errcode='42501'; end if;
  return query select a.email::text, coalesce(nullif(trim(a.name),''), initcap(split_part(a.email,'@',1)))::text
    from public.boha_access a where a.role in ('marketing','admin') order by 2;
end $$;

revoke all on function public.boha_mkt_create(text,text,text,date,boolean,text,text), public.boha_mkt_comment(uuid,text,text,text), public.boha_mkt_set_status(uuid,text),
  public.boha_mkt_assign(uuid,text), public.boha_mkt_seen(uuid), public.boha_mkt_team() from public, anon;
grant execute on function public.boha_mkt_create(text,text,text,date,boolean,text,text), public.boha_mkt_comment(uuid,text,text,text), public.boha_mkt_set_status(uuid,text),
  public.boha_mkt_assign(uuid,text), public.boha_mkt_seen(uuid), public.boha_mkt_team() to authenticated;

-- Módulo na lista de permissões: gerente, recepção, marketing e dono podem pedir; marketing e administrador atendem.
alter table public.boha_role_modules drop constraint if exists boha_role_modules_valid;
alter table public.boha_role_modules add constraint boha_role_modules_valid
  check (modules <@ array['hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas','rotina','artes','solicitacoes']::text[]);
create or replace function public.boha_role_modules_save(p_role text, p_modules text[]) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem editar perfis.' using errcode='42501'; end if;
  if p_role not in ('dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_modules is null or exists (select 1 from unnest(p_modules) m where m is null or m not in ('hierarquia','resultados','qualidade','checklist','compras','marketing','manuais','funcionarios','calendario','nps','clima','mural','instagram','campanhas','escalas','rotina','artes','solicitacoes')) then raise exception 'Módulo inválido.'; end if;
  insert into public.boha_role_modules(role,modules,updated_at)
    values (p_role,(select coalesce(array_agg(distinct m),'{}'::text[]) from unnest(p_modules) m),now())
    on conflict (role) do update set modules=excluded.modules,updated_at=now();
end $$;
revoke all on function public.boha_role_modules_save(text,text[]) from public, anon;
grant execute on function public.boha_role_modules_save(text,text[]) to authenticated;
update public.boha_role_modules set modules = array_append(modules,'solicitacoes')
  where role in ('gerente','recepcao','marketing','dono') and not ('solicitacoes' = any(modules));

insert into public.boha_notices(title,body,module,audience,created_by)
select 'Novo: Solicitações ao marketing',
  'Precisa de arte, vídeo, flyer, cartaz ou depoimento? Abra uma solicitação, anexe links e imagens e acompanhe a resposta do marketing por aqui.',
  'solicitacoes',array['admin','gerente','recepcao','marketing','dono'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Novo: Solicitações ao marketing');
