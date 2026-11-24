-- Acesso por unidade + Rotina da recepção com painel do gerente.
-- Regra: administrador vê tudo. Gerente e recepção SÓ veem e mexem nos dados da unidade escolhida para eles.
-- Gerente ou recepção sem unidade definida não enxergam dados de nenhuma unidade (falha segura).
-- Dono, marketing e perfis antigos (editor/viewer) sem unidade continuam enxergando a rede toda.

alter table public.boha_access add column if not exists unit text;
alter table public.boha_access drop constraint if exists boha_access_unit_check;
alter table public.boha_access add constraint boha_access_unit_check check (unit is null or unit in ('cb','te','ma'));

create or replace function public.boha_unit() returns text
language sql stable security definer set search_path = '' as $$
  select a.unit from public.boha_access a where a.email = lower(auth.jwt()->>'email')
$$;

-- A pessoa logada pode ver/alterar dados desta unidade?
create or replace function public.boha_unit_ok(u text) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select case when a.role = 'admin' then true
                when a.unit is not null then a.unit = u
                when a.role in ('gerente','recepcao') then false
                else true end
    from public.boha_access a where a.email = lower(auth.jwt()->>'email')
  ), false)
$$;
create or replace function public.boha_unit_ok_num(n smallint) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.boha_unit_ok(case n when 1 then 'cb' when 2 then 'te' when 3 then 'ma' end)
$$;
create or replace function public.boha_employee_unit_ok(eid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.boha_unit_ok((select e.unit from public.boha_employees e where e.id = eid))
$$;
revoke all on function public.boha_unit(), public.boha_unit_ok(text), public.boha_unit_ok_num(smallint), public.boha_employee_unit_ok(uuid) from public, anon;
grant execute on function public.boha_unit(), public.boha_unit_ok(text), public.boha_unit_ok_num(smallint), public.boha_employee_unit_ok(uuid) to authenticated;

-- Políticas RESTRITIVAS: somam-se às regras de cada módulo (só diminuem o que a pessoa enxerga).
do $$ declare t text; begin
  foreach t in array array['boha_areas','boha_requests','boha_employees','boha_nps_responses','boha_climate_responses','boha_professor_ratings','boha_funnel_entries','boha_ig_weekly','boha_routine_checks'] loop
    execute format('drop policy if exists unit_scope on public.%I', t);
    execute format('create policy unit_scope on public.%I as restrictive for all to authenticated using (public.boha_unit_ok(unit)) with check (public.boha_unit_ok(unit))', t);
  end loop;
  foreach t in array array['boha_evo','boha_evo_history'] loop
    execute format('drop policy if exists unit_scope on public.%I', t);
    execute format('create policy unit_scope on public.%I as restrictive for all to authenticated using (public.boha_unit_ok_num(unit)) with check (public.boha_unit_ok_num(unit))', t);
  end loop;
end $$;
drop policy if exists unit_scope on public.boha_shifts;
create policy unit_scope on public.boha_shifts as restrictive for all to authenticated
  using (public.boha_employee_unit_ok(employee_id)) with check (public.boha_employee_unit_ok(employee_id));
-- Rotinas: "todas as unidades" (unit nula) todos da rede leem, mas só quem não tem unidade fixa altera.
drop policy if exists unit_scope on public.boha_routines;
drop policy if exists unit_scope_sel on public.boha_routines;
drop policy if exists unit_scope_ins on public.boha_routines;
drop policy if exists unit_scope_upd on public.boha_routines;
drop policy if exists unit_scope_del on public.boha_routines;
create policy unit_scope_sel on public.boha_routines as restrictive for select to authenticated using (unit is null or public.boha_unit_ok(unit));
create policy unit_scope_ins on public.boha_routines as restrictive for insert to authenticated with check (public.boha_unit_ok(unit));
create policy unit_scope_upd on public.boha_routines as restrictive for update to authenticated using (public.boha_unit_ok(unit)) with check (public.boha_unit_ok(unit));
create policy unit_scope_del on public.boha_routines as restrictive for delete to authenticated using (public.boha_unit_ok(unit));

-- Rotina: quem cumpre é a recepção (e o administrador); o gerente só acompanha e monta a rotina da própria unidade.
drop policy if exists checks_access on public.boha_routine_checks;
drop policy if exists checks_read on public.boha_routine_checks;
drop policy if exists checks_insert on public.boha_routine_checks;
drop policy if exists checks_delete on public.boha_routine_checks;
create policy checks_read on public.boha_routine_checks for select to authenticated using (public.boha_can('rotina'));
create policy checks_insert on public.boha_routine_checks for insert to authenticated
  with check (public.boha_can('rotina') and public.boha_role() = any (array['recepcao','admin']));
create policy checks_delete on public.boha_routine_checks for delete to authenticated
  using (public.boha_can('rotina') and public.boha_role() = any (array['recepcao','admin']));

-- Lista de funcionários só da unidade da pessoa.
create or replace function public.boha_employee_options()
returns table(id uuid, name text, unit text, unit_label text, title text, photo_path text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.boha_can('checklist') or public.boha_can('hierarquia') or public.boha_can('marketing') or public.boha_can('qualidade') or public.boha_can('calendario') or public.boha_can('escalas') or public.boha_can('campanhas')) then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;
  return query select e.id,e.name,e.unit,
    case e.unit when 'cb' then 'Casa Branca' when 'te' then 'Santa Tereza' else 'Macedônia' end,e.title,e.photo_path
    from public.boha_employees e where e.status='active' and public.boha_unit_ok(e.unit)
    order by case e.unit when 'cb' then 1 when 'te' then 2 else 3 end,e.name;
end $$;
create or replace function public.boha_employee_list()
returns table(id uuid, unit text, name text, title text, permission_note text, collaborators_note text, status text, photo_path text, hub_access boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.boha_can('funcionarios') then raise exception 'Acesso negado.' using errcode='42501'; end if;
  return query
    select e.id,e.unit,e.name,e.title,e.permission_note,e.collaborators_note,e.status,e.photo_path,
      exists(select 1 from public.boha_access a where lower(a.name)=lower(e.name)) as hub_access
    from public.boha_employees e where public.boha_unit_ok(e.unit)
    order by case e.unit when 'cb' then 1 when 'te' then 2 else 3 end,e.status,e.name;
end $$;

-- Quem sou eu (agora com a unidade)
drop function if exists public.boha_me();
create function public.boha_me() returns table(name text, role text, unit text)
language sql stable security definer set search_path = '' as $$
  select coalesce(nullif(trim(a.name), ''), nullif(trim(auth.jwt()->'user_metadata'->>'name'), ''), initcap(split_part(a.email, '@', 1))) as name,
         a.role, a.unit
  from public.boha_access a where a.email = lower(auth.jwt()->>'email')
$$;
revoke all on function public.boha_me() from public, anon;
grant execute on function public.boha_me() to authenticated;

-- Gestão de acessos: lista e salva com unidade
drop function if exists public.boha_access_list();
create function public.boha_access_list()
returns table(email text, name text, role text, unit text, has_account boolean, confirmed boolean, last_sign_in timestamptz, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem fazer isso.' using errcode = '42501'; end if;
  return query
  select coalesce(a.email, lower(u.email))::text,
         coalesce(nullif(trim(a.name), ''), nullif(trim(u.raw_user_meta_data->>'name'), ''))::text,
         a.role::text, a.unit::text,
         (u.id is not null), (u.email_confirmed_at is not null), u.last_sign_in_at, u.created_at
  from public.boha_access a full outer join auth.users u on lower(u.email) = a.email;
end $$;
revoke all on function public.boha_access_list() from public, anon;
grant execute on function public.boha_access_list() to authenticated;

drop function if exists public.boha_access_save(text,text,text);
create function public.boha_access_save(p_email text, p_name text, p_role text, p_unit text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v_email text := lower(trim(coalesce(p_email, '')));
        v_me text := lower(auth.jwt()->>'email');
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem fazer isso.' using errcode='42501'; end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'E-mail inválido.'; end if;
  if p_role is null or p_role not in ('admin','dono','gerente','marketing','recepcao') then raise exception 'Perfil inválido.'; end if;
  if p_unit is not null and p_unit not in ('cb','te','ma') then raise exception 'Unidade inválida.'; end if;
  if v_email = v_me and p_role <> 'admin' then raise exception 'Você não pode tirar o seu próprio acesso de administrador.'; end if;
  insert into public.boha_access(email,name,role,unit)
  values(v_email,nullif(left(trim(coalesce(p_name,'')),60),''),p_role,case when p_role in ('gerente','recepcao') then p_unit end)
  on conflict(email) do update set role=excluded.role,name=coalesce(excluded.name,public.boha_access.name),
    unit=case when excluded.role in ('gerente','recepcao') then coalesce(excluded.unit,public.boha_access.unit) else null end;
end $$;
revoke all on function public.boha_access_save(text,text,text,text) from public, anon;
grant execute on function public.boha_access_save(text,text,text,text) to authenticated;

create or replace function public.boha_access_set_unit(p_email text, p_unit text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_email text := lower(trim(coalesce(p_email, '')));
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem fazer isso.' using errcode='42501'; end if;
  if p_unit is not null and p_unit not in ('cb','te','ma') then raise exception 'Unidade inválida.'; end if;
  update public.boha_access set unit = p_unit where email = v_email and role in ('gerente','recepcao');
  if not found then raise exception 'Só gerente e recepção têm unidade fixa.'; end if;
end $$;
revoke all on function public.boha_access_set_unit(text,text) from public, anon;
grant execute on function public.boha_access_set_unit(text,text) to authenticated;

-- A recepção passa a ter o módulo Rotina (marca o checklist da própria unidade).
update public.boha_role_modules set modules = array_append(modules,'rotina')
  where role = 'recepcao' and not ('rotina' = any(modules));

update public.boha_notices set audience = array['admin','gerente','recepcao'],
  body = 'A recepção marca as tarefas do dia (abertura, manhã, tarde, noite e fechamento) e o gerente acompanha o painel da própria unidade em tempo real.'
  where title = 'Novo: Rotina';
insert into public.boha_notices(title,body,module,audience,created_by)
select 'Acesso por unidade',
  'Gerentes e recepção agora veem e editam apenas os dados da própria unidade. Só o administrador enxerga as três.',
  null,array['admin','gerente','recepcao'],'Sistema BOHA'
where not exists (select 1 from public.boha_notices where title='Acesso por unidade');
