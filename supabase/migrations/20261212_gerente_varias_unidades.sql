-- Gerente (e dono/marketing com unidade) pode enxergar mais de uma unidade.
-- A unidade principal continua em boha_access.unit; as demais ficam em extra_units.
-- Administrador segue vendo tudo; recepção continua com uma unidade só.

alter table public.boha_access add column if not exists extra_units text[] not null default '{}';
alter table public.boha_access drop constraint if exists boha_access_extra_units_check;
alter table public.boha_access add constraint boha_access_extra_units_check
  check (extra_units <@ array['cb','te','ma']::text[]);

-- Unidades liberadas para a pessoa logada (principal primeiro). Vazio = rede toda / sem unidade.
create or replace function public.boha_units() returns text[]
language sql stable security definer set search_path = '' as $$
  select coalesce((select case when a.unit is null then '{}'::text[]
                               else array[a.unit] || array(select x from unnest(a.extra_units) x where x <> a.unit) end
                   from public.boha_access a where a.email = lower(auth.jwt()->>'email')), '{}'::text[])
$$;
revoke all on function public.boha_units() from public, anon;
grant execute on function public.boha_units() to authenticated;

create or replace function public.boha_unit_ok(u text) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select case when a.role = 'admin' then true
                when a.unit is not null then (a.unit = u or u = any(a.extra_units))
                when a.role in ('gerente','recepcao') then false
                else true end
    from public.boha_access a where a.email = lower(auth.jwt()->>'email')
  ), false)
$$;

create or replace function public.boha_hier_ok(p_id text, p_scope text default null) returns boolean
language sql stable security definer set search_path = '' as $$
  select case
    when public.boha_role() is distinct from 'gerente' then true
    else coalesce((
      select a.unit is not null and exists (
        select 1 from unnest(array[a.unit] || a.extra_units) as un(u) where
               (p_scope is not null and p_scope = un.u)
            or (p_scope is null and (p_id like un.u || '-%'
                 or exists (select 1 from public.boha_org_nodes n where n.id = p_id and n.op = 'add' and n.scope = un.u))))
        from public.boha_access a where a.email = lower(auth.jwt()->>'email')), false)
  end
$$;

-- Quem sou eu: agora com a lista de unidades
drop function if exists public.boha_me();
create function public.boha_me() returns table(name text, role text, unit text, units text[])
language sql stable security definer set search_path = '' as $$
  select coalesce(nullif(trim(a.name), ''), nullif(trim(auth.jwt()->'user_metadata'->>'name'), ''), initcap(split_part(a.email, '@', 1))) as name,
         a.role, a.unit,
         case when a.unit is null then '{}'::text[] else array[a.unit] || array(select x from unnest(a.extra_units) x where x <> a.unit) end
  from public.boha_access a where a.email = lower(auth.jwt()->>'email')
$$;
revoke all on function public.boha_me() from public, anon;
grant execute on function public.boha_me() to authenticated;

-- Gestão de acessos: a lista devolve as unidades extras
drop function if exists public.boha_access_list();
create function public.boha_access_list()
returns table(email text, name text, role text, unit text, extra_units text[], has_account boolean, confirmed boolean, last_sign_in timestamptz, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem fazer isso.' using errcode = '42501'; end if;
  return query
  select coalesce(a.email, lower(u.email))::text,
         coalesce(nullif(trim(a.name), ''), nullif(trim(u.raw_user_meta_data->>'name'), ''))::text,
         a.role::text, a.unit::text, coalesce(a.extra_units, '{}'::text[]),
         (u.id is not null), (u.email_confirmed_at is not null), u.last_sign_in_at, u.created_at
  from public.boha_access a full outer join auth.users u on lower(u.email) = a.email;
end $$;
revoke all on function public.boha_access_list() from public, anon;
grant execute on function public.boha_access_list() to authenticated;

-- Definir as unidades de uma pessoa (a primeira é a principal). Só gerente, dono e marketing podem ter mais de uma.
create or replace function public.boha_access_set_units(p_email text, p_units text[]) returns void
language plpgsql security definer set search_path = '' as $$
declare v_email text := lower(trim(coalesce(p_email, ''))); v_role text; v_list text[];
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem fazer isso.' using errcode='42501'; end if;
  select a.role into v_role from public.boha_access a where a.email = v_email;
  if v_role is null then raise exception 'Pessoa não encontrada.'; end if;
  if v_role = 'admin' then raise exception 'Administrador sempre vê todas as unidades.'; end if;
  select coalesce(array_agg(x order by ord), '{}') into v_list from (
    select x, min(ord) ord from unnest(coalesce(p_units, '{}'::text[])) with ordinality as t(x, ord) group by x) s;
  if exists (select 1 from unnest(v_list) x where x not in ('cb','te','ma')) then raise exception 'Unidade inválida.'; end if;
  if array_length(v_list, 1) > 1 and v_role not in ('gerente','dono','marketing') then
    raise exception 'Só gerente, dono ou marketing podem ver mais de uma unidade.'; end if;
  update public.boha_access set unit = v_list[1], extra_units = coalesce(v_list[2:], '{}'::text[]) where email = v_email;
end $$;
revoke all on function public.boha_access_set_units(text,text[]) from public, anon;
grant execute on function public.boha_access_set_units(text,text[]) to authenticated;

-- Trocar só a unidade principal (seletor antigo): zera as extras para não sobrar acesso escondido
create or replace function public.boha_access_set_unit(p_email text, p_unit text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_email text := lower(trim(coalesce(p_email, '')));
begin
  if not public.boha_is_admin() then raise exception 'Só administradores podem fazer isso.' using errcode='42501'; end if;
  if p_unit is not null and p_unit not in ('cb','te','ma') then raise exception 'Unidade inválida.'; end if;
  update public.boha_access set unit = p_unit, extra_units = '{}' where email = v_email and role <> 'admin';
  if not found then raise exception 'Administrador sempre vê todas as unidades.'; end if;
end $$;

-- Mudar o perfil para algo que não aceita várias unidades limpa as extras
create or replace function public.boha_access_save(p_email text, p_name text, p_role text, p_unit text default null) returns void
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
  values(v_email,nullif(left(trim(coalesce(p_name,'')),60),''),p_role,case when p_role <> 'admin' then p_unit end)
  on conflict(email) do update set role=excluded.role,name=coalesce(excluded.name,public.boha_access.name),
    unit=case when excluded.role = 'admin' then null else coalesce(excluded.unit,public.boha_access.unit) end,
    extra_units=case when excluded.role in ('gerente','dono','marketing') then public.boha_access.extra_units else '{}'::text[] end;
end $$;
