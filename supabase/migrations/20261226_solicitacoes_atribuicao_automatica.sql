-- Solicitações ao marketing: todo pedido novo é atribuído sozinho ao responsável padrão (Victoria) e já cai no "A fazer" dela.
create table if not exists public.boha_mkt_settings (
  id integer primary key default 1 check (id = 1),
  default_assignee text,
  updated_at timestamptz not null default now()
);
alter table public.boha_mkt_settings enable row level security;
revoke all on public.boha_mkt_settings from anon, authenticated;
insert into public.boha_mkt_settings(id, default_assignee) values (1, 'victoria.atns@gmail.com') on conflict (id) do nothing;

-- Atribui o pedido ao responsável padrão e cria a tarefa dele no A fazer (uso interno).
create or replace function public.boha_mkt_auto_assign(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare r public.boha_mkt_requests; v_email text; v_nm text;
begin
  select default_assignee into v_email from public.boha_mkt_settings where id = 1;
  if v_email is null then return; end if;
  select coalesce(nullif(trim(a.name),''), initcap(split_part(a.email,'@',1))) into v_nm from public.boha_access a where a.email = v_email and a.role in ('marketing','admin');
  if v_nm is null then return; end if;
  select * into r from public.boha_mkt_requests where id = p_id for update;
  if not found or r.assignee_email is not null then return; end if;
  update public.boha_mkt_requests set assignee_email = v_email, assignee_name = v_nm, updated_at = now(), last_activity_at = now() where id = p_id;
  insert into public.boha_mkt_comments(request_id, author_email, author_name, author_role, kind, body)
    values (p_id, 'sistema', 'Sistema', 'sistema', 'sistema', 'Atribuída automaticamente a ' || v_nm);
  insert into public.boha_tasks(owner, title, notes, due_date, source_ref)
  values (v_email, left('Marketing #' || r.num || ' · ' || public.boha_mkt_kind_label(r.kind) || ' — ' || r.title, 200),
    left('Pedido de ' || r.requester_name || coalesce(' (' || public.boha_mkt_unit_label(r.unit) || ')', '') || E'\n' ||
         coalesce('Prazo: ' || to_char(r.deadline, 'DD/MM/YYYY') || E'\n', '') || left(r.description, 600) || E'\n\nAbra: Solicitações ao marketing.', 4000),
    r.deadline, 'mkt:' || p_id::text)
  on conflict (owner, source_ref) where source_ref is not null do update set done_at = null, title = excluded.title, due_date = excluded.due_date, notes = excluded.notes;
  perform public.boha_mkt_notice('Nova solicitação para você · ' || public.boha_mkt_kind_label(r.kind) || case when r.urgent then ' (urgente)' else '' end,
    r.requester_name || coalesce(' · ' || public.boha_mkt_unit_label(r.unit), '') || ': ' || r.title, array['marketing','admin'], v_email);
end $$;
revoke all on function public.boha_mkt_auto_assign(uuid) from public, anon, authenticated;

-- Criar o pedido: atribui automaticamente (sem responsável padrão, avisa a equipe como antes).
create or replace function public.boha_mkt_create(p_kind text, p_title text, p_description text, p_deadline date, p_urgent boolean, p_link text, p_unit text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare me record; v_id uuid; v_unit text; v_n integer; v_def boolean;
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
  perform public.boha_mkt_auto_assign(v_id);
  select assignee_email is not null into v_def from public.boha_mkt_requests where id = v_id;
  if not coalesce(v_def,false) then
    perform public.boha_mkt_notice('Nova solicitação · ' || public.boha_mkt_kind_label(p_kind) || case when coalesce(p_urgent,false) then ' (urgente)' else '' end,
      me.v_name || coalesce(' · ' || public.boha_mkt_unit_label(v_unit), '') || ': ' || trim(p_title), array['marketing','admin'], null);
  end if;
  return v_id;
end $$;

-- Quem é o responsável padrão (equipe do marketing e administrador veem; só o administrador troca)
create or replace function public.boha_mkt_default_get() returns text
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.boha_mkt_is_team() then raise exception 'Acesso negado.' using errcode='42501'; end if;
  return (select default_assignee from public.boha_mkt_settings where id = 1);
end $$;
create or replace function public.boha_mkt_default_set(p_email text) returns void
language plpgsql security definer set search_path = '' as $$
declare v text := nullif(lower(trim(coalesce(p_email,''))),'');
begin
  if not public.boha_is_admin() then raise exception 'Só o administrador define o responsável padrão.' using errcode='42501'; end if;
  if v is not null and not exists (select 1 from public.boha_access where email = v and role in ('marketing','admin')) then raise exception 'Essa pessoa não é do marketing.'; end if;
  insert into public.boha_mkt_settings(id, default_assignee, updated_at) values (1, v, now())
    on conflict (id) do update set default_assignee = excluded.default_assignee, updated_at = now();
end $$;
revoke all on function public.boha_mkt_default_get(), public.boha_mkt_default_set(text) from public, anon;
grant execute on function public.boha_mkt_default_get(), public.boha_mkt_default_set(text) to authenticated;
