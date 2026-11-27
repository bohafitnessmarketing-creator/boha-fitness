-- Rotina por função: o checklist de cada função (hierarquia: gerente, estagiário, professor, marketing…) é atribuído sozinho
-- a quem tem login e foi colocado naquela posição da Hierarquia (ligação pelo nome completo). Recepção continua automática.

alter table public.boha_routines add column if not exists fn text
  check (fn is null or fn in ('direcao','geral','financeiro','manutencao','rh','conteudo','campanhas','gerente','tecnico','professor','liderrecepcao','recepcao','limpeza','estagiaria'));
update public.boha_routines set fn = 'recepcao' where fn is null and role_name = 'Recepção';
create or replace function public.boha_routines_default_fn() returns trigger language plpgsql as $$
begin if new.fn is null and new.role_name = 'Recepção' then new.fn := 'recepcao'; end if; return new; end $$;
drop trigger if exists boha_routines_default_fn on public.boha_routines;
create trigger boha_routines_default_fn before insert on public.boha_routines for each row execute function public.boha_routines_default_fn();

create or replace function public.boha_norm(t text) returns text language sql immutable set search_path = '' as $$
  select regexp_replace(trim(regexp_replace(translate(lower(coalesce(t,'')),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'\s*\((cb|te|ma)\)\s*$','')),'\s+',' ','g')
$$;

-- Quem está em qual posição da Hierarquia e tem login (nome da posição = nome do acesso). Uso interno.
create or replace function public.boha_placements() returns table(email text, name text, unit text, fn text)
language sql stable security definer set search_path = '' as $$
  with nodes as (
    select m.id as node_id, public.boha_norm(m.data->>'name') as nm,
      coalesce(o.role, case regexp_replace(regexp_replace(m.id,'^(cb|te|ma)-',''),'[0-9]+$','') when 'professora' then 'professor' else regexp_replace(regexp_replace(m.id,'^(cb|te|ma)-',''),'[0-9]+$','') end) as fn,
      coalesce(o.scope, case when m.id ~ '^(cb|te|ma)-' then substr(m.id,1,2) end) as unit
    from public.boha_members m
    left join public.boha_org_nodes o on o.id = m.id and o.op = 'add'
    where coalesce(m.data->>'name','') <> ''
      and not exists (select 1 from public.boha_org_nodes h where h.id = m.id and h.op = 'hide')
  )
  select distinct a.email, a.name, n.unit, n.fn
    from nodes n join public.boha_access a on public.boha_norm(a.name) = n.nm and a.role <> 'admin'
   where n.fn in ('direcao','geral','financeiro','manutencao','rh','conteudo','campanhas','gerente','tecnico','professor','liderrecepcao','recepcao','limpeza','estagiaria')
$$;
revoke all on function public.boha_placements(), public.boha_norm(text) from public, anon, authenticated;

-- As funções de quem está logado (para montar "Meu checklist")
create or replace function public.boha_my_functions() returns table(fn text, unit text)
language sql stable security definer set search_path = '' as $$
  select p.fn, p.unit from public.boha_placements() p where p.email = lower(auth.jwt()->>'email')
  union
  select 'recepcao', a.unit from public.boha_access a where a.email = lower(auth.jwt()->>'email') and a.role = 'recepcao'
$$;
revoke all on function public.boha_my_functions() from public, anon;
grant execute on function public.boha_my_functions() to authenticated;

-- Painel do gerente: cada pessoa com login que tem checklist (por unidade), com as funções dela
create or replace function public.boha_routine_people() returns table(email text, name text, unit text, role text, fns text[])
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.boha_can('rotina') and public.boha_role() in ('admin','dono','gerente','marketing')) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  return query
  with base as (
    select p.email, p.name, p.unit, p.fn from public.boha_placements() p
    union
    select a.email, coalesce(nullif(trim(a.name),''), initcap(split_part(a.email,'@',1))), a.unit, 'recepcao' from public.boha_access a where a.role = 'recepcao' and a.unit is not null
  ), expanded as (
    select b.email, b.name, u.unit, b.fn
      from base b
      cross join lateral (select x as unit from unnest(case when b.unit is null then array['cb','te','ma'] else array[b.unit] end) x) u
  )
  select e.email::text, max(e.name)::text, e.unit::text, max(a.role)::text, array_agg(distinct e.fn order by e.fn)
    from expanded e join public.boha_access a on a.email = e.email
   where public.boha_unit_ok(e.unit)
   group by e.email, e.unit
   order by max(e.name);
end $$;
revoke all on function public.boha_routine_people() from public, anon;
grant execute on function public.boha_routine_people() to authenticated;

-- Marcar o próprio checklist: qualquer perfil com o módulo (antes só recepção/administrador)
drop policy if exists checks_insert on public.boha_routine_checks;
create policy checks_insert on public.boha_routine_checks for insert to authenticated with check (public.boha_can('rotina') and public.boha_role() is not null);
drop policy if exists checks_delete on public.boha_routine_checks;
create policy checks_delete on public.boha_routine_checks for delete to authenticated using (public.boha_can('rotina') and done_by = lower(auth.jwt()->>'email'));

create or replace function public.boha_routine_answer(p_routine uuid, p_unit text, p_answer text, p_student text default null, p_note text default null)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me text := lower(auth.jwt()->>'email'); v_role text := public.boha_role();
        v_today date := (now() at time zone 'America/Sao_Paulo')::date;
        r record; c record; v_id uuid; v_name text; v_unitname text;
        v_stu text := trim(coalesce(p_student,'')); v_note text := trim(coalesce(p_note,''));
begin
  if not (public.boha_can('rotina') and v_role in ('recepcao','gerente','marketing','admin')) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if p_unit is null or p_unit not in ('cb','te','ma') or not public.boha_unit_ok(p_unit) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if p_answer not in ('sim','nao') then raise exception 'Responda Sim ou Não.'; end if;
  select * into r from public.boha_routines x where x.id = p_routine and x.active and x.ask is not null and (x.unit is null or x.unit = p_unit);
  if not found then raise exception 'Tarefa não encontrada.'; end if;
  select coalesce(nullif(trim(a.name),''), initcap(split_part(v_me,'@',1))) into v_name from public.boha_access a where a.email = v_me;
  select * into c from public.boha_routine_checks k where k.routine_id = p_routine and k.unit = p_unit and k.check_date = v_today;
  if found and c.done_by <> v_me and v_role <> 'admin' then raise exception 'Esta tarefa já foi respondida por outra pessoa hoje.'; end if;
  if p_answer = 'nao' then
    if found then
      if exists (select 1 from public.boha_routine_records z where z.check_id = c.id) then raise exception 'Já existem registros de Sim. Apague-os antes de responder Não.'; end if;
      update public.boha_routine_checks set answer = 'nao' where id = c.id;
      return c.id;
    end if;
    insert into public.boha_routine_checks(routine_id, unit, check_date, done_by, done_by_name, answer)
      values (p_routine, p_unit, v_today, v_me, left(v_name,80), 'nao') returning id into v_id;
    return v_id;
  end if;
  if char_length(v_stu) < 1 or char_length(v_stu) > 40 then raise exception 'Informe o ID do aluno.'; end if;
  if char_length(v_note) < 1 or char_length(v_note) > 1000 then raise exception 'Escreva a anotação (até 1000 caracteres).'; end if;
  if (select count(*) from public.boha_routine_records z where z.routine_id = p_routine and z.unit = p_unit and z.check_date = v_today) >= 30 then
    raise exception 'Limite de registros do dia atingido.'; end if;
  if found then
    v_id := c.id; update public.boha_routine_checks set answer = 'sim' where id = c.id;
  else
    insert into public.boha_routine_checks(routine_id, unit, check_date, done_by, done_by_name, answer)
      values (p_routine, p_unit, v_today, v_me, left(v_name,80), 'sim') returning id into v_id;
  end if;
  insert into public.boha_routine_records(check_id, routine_id, unit, check_date, student_id, note, done_by, done_by_name)
    values (v_id, p_routine, p_unit, v_today, v_stu, v_note, v_me, left(v_name,80));
  perform public.boha_notify_unit_managers(p_unit,
    left('Registro na Rotina · ' || public.boha_unit_name(p_unit), 120),
    left(coalesce(v_name,'A recepção') || ' registrou em "' || r.title || '" · aluno ID ' || v_stu || ': ' || v_note, 560), 'rotina');
  return v_id;
end $$;


create or replace function public.boha_rnote_add(p_person text, p_date date, p_body text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me text := lower(auth.jwt()->>'email'); v_role text := public.boha_role(); v_unit text; v_kind text;
        v_body text := trim(coalesce(p_body,'')); v_person text := lower(trim(coalesce(p_person,'')));
        v_today date := (now() at time zone 'America/Sao_Paulo')::date; v_id uuid; v_name text;
begin
  if not public.boha_can('rotina') then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if char_length(v_body) < 1 or char_length(v_body) > 1000 then raise exception 'Escreva a anotação (até 1000 caracteres).'; end if;
  if p_date is null or p_date > v_today or p_date < v_today - 120 then raise exception 'Data inválida.'; end if;
  if v_role = 'recepcao' then
    select a.unit into v_unit from public.boha_access a where a.email = v_me;
    if v_unit is null then raise exception 'Sua unidade ainda não foi definida.'; end if;
    if p_date <> v_today then raise exception 'A recepção anota apenas o dia de hoje.'; end if;
    v_person := v_me; v_kind := 'recepcao';
  elsif v_role in ('gerente','admin') then
    select coalesce(a.unit, public.boha_unit(), 'cb') into v_unit from public.boha_access a where a.email = v_person and a.role <> 'admin';
    if v_unit is null then raise exception 'Pessoa não encontrada.'; end if;
    if not public.boha_unit_ok(v_unit) then raise exception 'Acesso negado.' using errcode='42501'; end if;
    v_kind := 'gestor';
  else raise exception 'Acesso negado.' using errcode='42501'; end if;
  if (select count(*) from public.boha_routine_notes n where n.person_email = v_person and n.note_date = p_date and n.author_email = v_me) >= 20 then
    raise exception 'Limite de anotações deste dia atingido.'; end if;
  select coalesce(nullif(trim(a.name),''), initcap(split_part(a.email,'@',1))) into v_name from public.boha_access a where a.email = v_me;
  insert into public.boha_routine_notes(unit, person_email, note_date, kind, body, author_email, author_name)
    values (v_unit, v_person, p_date, v_kind, v_body, v_me, left(v_name, 80)) returning id into v_id;
  if v_kind = 'recepcao' then
    perform public.boha_notify_unit_managers(v_unit, left('Anotação da recepção · ' || public.boha_unit_name(v_unit), 120),
      left(coalesce(v_name,'A recepção') || ': ' || v_body, 560), 'rotina');
  end if;
  return v_id;
end $$;



create or replace function public.boha_rnote_task_add(p_routine uuid, p_unit text, p_body text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_me text := lower(auth.jwt()->>'email'); v_role public.boha_access.role%type := public.boha_role();
        v_today date := (now() at time zone 'America/Sao_Paulo')::date; v_body text := trim(coalesce(p_body,''));
        v_id uuid; v_name text; r record;
begin
  if not (public.boha_can('rotina') and v_role in ('recepcao','gerente','marketing','admin')) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if p_unit is null or p_unit not in ('cb','te','ma') or not public.boha_unit_ok(p_unit) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if char_length(v_body) < 1 or char_length(v_body) > 1000 then raise exception 'Escreva a anotação (até 1000 caracteres).'; end if;
  select * into r from public.boha_routines x where x.id = p_routine and x.active and (x.unit is null or x.unit = p_unit);
  if not found then raise exception 'Tarefa não encontrada.'; end if;
  if (select count(*) from public.boha_routine_notes n where n.routine_id = p_routine and n.note_date = v_today and n.author_email = v_me) >= 10 then
    raise exception 'Limite de anotações desta tarefa hoje atingido.'; end if;
  select coalesce(nullif(trim(a.name),''), initcap(split_part(v_me,'@',1))) into v_name from public.boha_access a where a.email = v_me;
  insert into public.boha_routine_notes(unit, person_email, note_date, kind, body, author_email, author_name, routine_id)
    values (p_unit, v_me, v_today, 'recepcao', v_body, v_me, left(v_name,80), p_routine) returning id into v_id;
  perform public.boha_notify_unit_managers(p_unit, left('Anotação na Rotina · ' || public.boha_unit_name(p_unit), 120),
    left(coalesce(v_name,'A recepção') || ' em "' || r.title || '": ' || v_body, 560), 'rotina');
  return v_id;
end $$;
